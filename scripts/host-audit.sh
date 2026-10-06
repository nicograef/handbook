#!/usr/bin/env bash
# host-audit.sh – read-only audit of the state setup-server.sh leaves on a host
#
# Usage (on the server; pass the Configuration values setup-server.sh ran with):
#   curl -fsSL https://raw.githubusercontent.com/nicograef/handbook/main/scripts/host-audit.sh -o host-audit.sh
#   sudo bash host-audit.sh | tee "audit-$(hostname)-$(date +%F).txt"
#   sudo USERNAME=deploy EXTRA_UFW_PORTS= bash host-audit.sh   # an SSH-only host
#
# What it does:
#   1. Prints one verdict per check: ok, FAIL or note, with what was expected and what was read.
#   2. Prints the raw reading beneath where a human judges it: authorized keys, login users, listeners.
#   3. Exits 1 if any check FAILs. Changes nothing. Prints key fingerprints and forced
#      commands, never a key blob or a secret value.
#   Without root, the checks that need it print "needs root" notes instead of verdicts.

# No -e: a failing reading is a verdict, not a reason to stop the audit.
set -u

# ── Configuration ────────────────────────────────────────────────────────────
USERNAME="${USERNAME:-nico}"
EXTRA_UFW_PORTS="${EXTRA_UFW_PORTS-80/tcp 443/tcp}"  # space-separated; empty expects only SSH
SWAP_SIZE_GB="${SWAP_SIZE_GB:-auto}"                # "0" expects no swap
SYSTEM_LOCALE="${SYSTEM_LOCALE:-en_US.UTF-8}"       # the system's LANG
EXTRA_LOCALES="${EXTRA_LOCALES:-en_GB.UTF-8}"       # space-separated; each expected generated
# ─────────────────────────────────────────────────────────────────────────────

fails=0

section() { printf '\n== %s\n' "$1"; }

# verdict <ok|FAIL|note> <check> <expected and read>
verdict() {
  [[ "$1" == FAIL ]] && fails=$((fails + 1))
  printf '%-4s  %s: %s\n' "$1" "$2" "$3"
}

# raw indents a reading beneath its verdict.
raw() { sed 's/^/        /'; }

is_root() { [[ $EUID -eq 0 ]]; }

# needs_root <check> — true as root, else prints the skip note.
needs_root() {
  is_root && return 0
  verdict note "$1" "needs root"
  return 1
}

# apt_value <key> — the last value apt-config holds for <key>, unquoted.
apt_value() {
  apt-config dump 2>/dev/null \
    | awk -v k="$1" '$1 == k { v = $2 } END { gsub(/[";]/, "", v); print v }'
}

# elide_keys prints authorized_keys lines without comments and with every key blob elided.
elide_keys() {
  grep -Ev '^[[:space:]]*(#|$)' "$1" \
    | sed -E 's/(^|[[:space:]])((ssh|ecdsa|sk)-[^[:space:]]+)[[:space:]]+[A-Za-z0-9+\/=]{40,}/\1<\2 key>/' \
    | sed -E 's/[A-Za-z0-9+\/]{60,}={0,2}/<blob>/g'
}

section "host"
echo "$(hostname) $(date -u +%FT%TZ) $(awk -F= '$1 == "PRETTY_NAME" { gsub(/"/, "", $2); print $2 }' /etc/os-release)"
is_root && echo "running as root" || echo "running as $(id -un), not root: root-only checks print notes"
echo "expected: USERNAME=$USERNAME EXTRA_UFW_PORTS='$EXTRA_UFW_PORTS' SWAP_SIZE_GB=$SWAP_SIZE_GB SYSTEM_LOCALE=$SYSTEM_LOCALE EXTRA_LOCALES='$EXTRA_LOCALES'"

section "sshd effective config"
if needs_root "sshd -T"; then
  if sshd_out="$(sshd -T 2>&1)"; then
    for pair in passwordauthentication:no kbdinteractiveauthentication:no permitrootlogin:no pubkeyauthentication:yes; do
      key="${pair%%:*}" want="${pair#*:}"
      got="$(awk -v k="$key" '$1 == k { print $2 }' <<<"$sshd_out")"
      [[ "$got" == "$want" ]] && v=ok || v=FAIL
      verdict "$v" "sshd $key" "expected $want, read ${got:-unset}"
    done
  else
    verdict FAIL "sshd -T" "expected the effective config, read: $(head -1 <<<"$sshd_out")"
  fi
fi

section "root account"
if needs_root "root password"; then
  status="$(passwd -S root 2>/dev/null | awk '{ print $2 }')"
  case "$status" in
    L)  verdict ok "root password" "expected L (locked), read L" ;;
    NP) verdict FAIL "root password" "expected L (locked), read NP: an empty password lets any local session su to root; run passwd -l root" ;;
    *)  verdict FAIL "root password" "expected L (locked), read ${status:-nothing}: setup-server.sh locks it; run passwd -l root" ;;
  esac
fi

section "login users"
if id "$USERNAME" >/dev/null 2>&1; then
  groups=" $(id -nG "$USERNAME" | xargs) "
  missing=""
  for g in sudo docker; do [[ "$groups" == *" $g "* ]] || missing+=" $g"; done
  if [[ -z "$missing" ]]; then
    verdict ok "user $USERNAME" "expected to exist in groups sudo and docker, read${groups% }"
  else
    verdict FAIL "user $USERNAME" "expected groups sudo and docker, missing$missing"
  fi
else
  verdict FAIL "user $USERNAME" "expected to exist, read no such user"
fi
if needs_root "sudo for $USERNAME"; then
  if grep -qs 'NOPASSWD' "/etc/sudoers.d/$USERNAME"; then
    verdict note "sudo for $USERNAME" "passwordless (PASSWORDLESS_SUDO=true in setup-server.sh)"
  elif [[ "$(passwd -S "$USERNAME" 2>/dev/null | awk '{ print $2 }')" == P ]]; then
    verdict ok "sudo for $USERNAME" "expected password-prompted, read a password set"
  else
    verdict FAIL "sudo for $USERNAME" "expected a password or NOPASSWD, read neither: sudo cannot be used"
  fi
fi
verdict note "login users" "every account whose shell can log in; judge each"
getent passwd | awk -F: '$7 !~ /(nologin|false|sync)$/ { print $1, $3, $7 }' | raw

section "authorized keys"
user_keys="/home/$USERNAME/.ssh/authorized_keys"
if needs_root "authorized keys"; then
  count="$(ssh-keygen -lf "$user_keys" 2>/dev/null | wc -l)"
  if (( count > 0 )); then
    verdict ok "keys of $USERNAME" "expected at least one key, read $count"
  else
    verdict FAIL "keys of $USERNAME" "expected at least one key in $user_keys, read none"
  fi
  modes="$(stat -c '%a %U' "/home/$USERNAME/.ssh" "$user_keys" 2>/dev/null | paste -sd ' ')"
  if [[ "$modes" == "700 $USERNAME 600 $USERNAME" ]]; then
    verdict ok "key file modes" "expected 700 and 600 owned by $USERNAME, read $modes"
  else
    verdict FAIL "key file modes" "expected 700 and 600 owned by $USERNAME, read ${modes:-nothing}"
  fi
  verdict note "authorized keys" "fingerprints, then each line with its key blob elided; judge each"
  for file in /root/.ssh/authorized_keys /home/*/.ssh/authorized_keys; do
    [[ -f "$file" ]] || continue
    {
      echo "-- $file"
      ssh-keygen -lf "$file" 2>&1
      elide_keys "$file"
    } | raw
  done
fi

section "firewall (ufw)"
if needs_root "ufw"; then
  ufw_out="$(ufw status verbose 2>&1)"
  enabled="$(systemctl is-enabled ufw 2>/dev/null)"
  if grep -q '^Status: active' <<<"$ufw_out" && [[ "$enabled" == enabled ]]; then
    verdict ok "ufw" "expected active and enabled, read active and $enabled"
  else
    verdict FAIL "ufw" "expected active and enabled, read $(grep '^Status:' <<<"$ufw_out" | head -1) and ${enabled:-unknown}"
  fi
  if grep -q 'Default: deny (incoming)' <<<"$ufw_out"; then
    verdict ok "ufw default" "expected deny (incoming), read deny (incoming)"
  else
    verdict FAIL "ufw default" "expected deny (incoming), read $(grep '^Default:' <<<"$ufw_out")"
  fi
  rules="$(awk 'seen && NF { i = ($2 == "(v6)") ? 3 : 2; print $1, $i, $(i + 1) } /^--/ { seen = 1 }' <<<"$ufw_out" | sort -u)"
  expected="22/tcp LIMIT IN"
  for port in $EXTRA_UFW_PORTS; do expected+=$'\n'"$port ALLOW IN"; done
  missing="$(comm -13 <(printf '%s\n' "$rules") <(sort -u <<<"$expected") | paste -sd ',')"
  extra="$(comm -23 <(printf '%s\n' "$rules") <(sort -u <<<"$expected") | paste -sd ',')"
  if [[ -z "$missing" && -z "$extra" ]]; then
    verdict ok "ufw rules" "expected $(paste -sd ',' <<<"$expected"), read the same"
  else
    verdict FAIL "ufw rules" "missing: ${missing:-none}; not in EXTRA_UFW_PORTS: ${extra:-none}"
    printf '%s\n' "$rules" | raw
  fi
fi

section "listening TCP sockets"
# The reverse proxy publishes 80 and 443 through Docker, which bypasses UFW.
allowed=" 22 80 443 "
for port in $EXTRA_UFW_PORTS; do
  [[ "$allowed" == *" ${port%%/*} "* ]] || allowed+="${port%%/*} "
done
ss_flags=(-Htln)
is_root && ss_flags+=(-p)
public="$(ss "${ss_flags[@]}" | awk '{
  addr = $4; port = addr; sub(/.*:/, "", port); sub(/:[^:]*$/, "", addr)
  gsub(/[][]/, "", addr); sub(/%.*/, "", addr)
  if (addr ~ /^127\./ || addr == "::1" || addr ~ /^::ffff:127\./) next
  print port, $4 ($6 == "" ? "" : " " $6)
}')"
bad="$(awk -v ok="$allowed" 'index(ok, " " $1 " ") == 0 { print $1 }' <<<"$public" | sort -un | paste -sd ' ')"
read_ports="$(awk '{ print $1 }' <<<"$public" | sort -un | paste -sd ' ')"
if [[ -z "$bad" ]]; then
  verdict ok "public ports" "expected only${allowed% }, read ${read_ports:-none}"
else
  verdict FAIL "public ports" "expected only${allowed% }, read $read_ports; bind $bad to loopback or close it"
fi
[[ -n "$public" ]] && cut -d' ' -f2- <<<"$public" | raw

section "fail2ban"
state="$(systemctl is-active fail2ban 2>/dev/null)"
[[ "$state" == active ]] && v=ok || v=FAIL
verdict "$v" "fail2ban" "expected active, read ${state:-unknown}"
if needs_root "fail2ban sshd jail"; then
  match="$(fail2ban-client get sshd journalmatch 2>&1 | grep -v '^Current match filter:' | paste -sd ' ')"
  missing=""
  for token in _SYSTEMD_UNIT=ssh.service _COMM=sshd _COMM=sshd-session; do
    [[ " $match " == *" $token "* ]] || missing+=" $token"
  done
  if [[ -z "$missing" ]]; then
    verdict ok "sshd journalmatch" "expected ssh.service, sshd and sshd-session, read $match"
  else
    verdict FAIL "sshd journalmatch" "missing$missing, read ${match:-nothing}"
  fi
  limits="$(fail2ban-client get sshd maxretry 2>/dev/null) $(fail2ban-client get sshd bantime 2>/dev/null)"
  [[ "$limits" == "5 3600" ]] && v=ok || v=FAIL
  verdict "$v" "sshd maxretry bantime" "expected 5 3600, read $limits"
fi

section "docker"
if ! command -v docker >/dev/null; then
  verdict FAIL "docker" "expected installed, read no docker binary"
else
  state="$(systemctl is-active docker 2>/dev/null)"
  [[ "$state" == active ]] && v=ok || v=FAIL
  verdict "$v" "docker" "expected active, read ${state:-unknown}"
  conf=/etc/docker/daemon.json
  if [[ ! -f "$conf" ]]; then
    verdict FAIL "docker log rotation" "expected $conf with json-file 10m x 3, read no file: container logs grow unbounded"
  elif ! command -v jq >/dev/null; then
    verdict note "docker log rotation" "jq missing, cannot parse $conf"
  else
    rot="$(jq -r '[."log-driver" // "unset", ."log-opts"."max-size" // "unset", ."log-opts"."max-file" // "unset"] | join(" ")' "$conf" 2>&1)"
    case "$rot" in
      "json-file 10m 3") verdict ok "docker log rotation" "expected json-file 10m 3, read $rot" ;;
      journald*)         verdict note "docker log rotation" "expected json-file 10m 3, read journald: journald's retention bounds container logs" ;;
      *)                 verdict FAIL "docker log rotation" "expected json-file 10m 3, read $rot"; raw <"$conf" ;;
    esac
    if ! ip -4 route get 1.1.1.1 >/dev/null 2>&1; then
      v6="$(jq -r '[.ipv6, ."fixed-cidr-v6" != null, ."default-network-opts".bridge."com.docker.network.enable_ipv4"] | map(tostring) | join(" ")' "$conf" 2>&1)"
      [[ "$v6" == "true true false" ]] && v=ok || v=FAIL
      verdict "$v" "docker IPv6-only networking" "no IPv4 route; expected ipv6, fixed-cidr-v6 and IPv4 off as true true false, read $v6"
    fi
    if running="$(docker info --format '{{.LoggingDriver}}' 2>/dev/null)"; then
      want="$(jq -r '."log-driver" // "json-file"' "$conf")"
      [[ "$running" == "$want" ]] && v=ok || v=FAIL
      verdict "$v" "docker running log driver" "expected $want as configured, read $running"
    else
      needs_root "docker running log driver" && verdict FAIL "docker running log driver" "docker info failed"
    fi
  fi
fi

section "unattended upgrades"
pkg="$(dpkg-query -W -f='${Status}' unattended-upgrades 2>/dev/null)"
[[ "$pkg" == "install ok installed" ]] && v=ok || v=FAIL
verdict "$v" "unattended-upgrades package" "expected installed, read ${pkg:-not installed}"
periodic="$(apt_value APT::Periodic::Update-Package-Lists) $(apt_value APT::Periodic::Unattended-Upgrade)"
[[ "$periodic" == "1 1" ]] && v=ok || v=FAIL
verdict "$v" "APT::Periodic" "expected Update-Package-Lists and Unattended-Upgrade 1 1, read $periodic"
reboot="$(apt_value Unattended-Upgrade::Automatic-Reboot)"
if [[ -z "$reboot" || "$reboot" == false ]]; then
  verdict ok "Automatic-Reboot" "expected unset or false (reboots stay manual), read ${reboot:-unset}"
else
  verdict FAIL "Automatic-Reboot" "expected unset or false (reboots stay manual), read $reboot"
fi
origins="$(apt-config dump 2>/dev/null | grep -E '^Unattended-Upgrade::(Origins-Pattern|Allowed-Origins):: ')"
if grep -qi security <<<"$origins"; then
  verdict ok "upgrade origins" "expected a security origin, read one"
else
  verdict FAIL "upgrade origins" "expected a security origin, read none"
  [[ -n "$origins" ]] && raw <<<"$origins"
fi
timers="$(systemctl is-active apt-daily.timer apt-daily-upgrade.timer 2>/dev/null | paste -sd ' ')"
[[ "$timers" == "active active" ]] && v=ok || v=FAIL
verdict "$v" "apt-daily timers" "expected apt-daily and apt-daily-upgrade active active, read $timers"
if command -v needrestart >/dev/null || [[ -x /usr/sbin/needrestart ]]; then
  verdict note "needrestart" "installed"
else
  verdict note "needrestart" "not installed; setup-server.sh does not install it"
fi

section "memory"
swaps="$(awk 'NR > 1 { printf "%s %d MB\n", $1, $3 / 1024 }' /proc/swaps)"
if [[ "$SWAP_SIZE_GB" == 0 ]]; then
  if [[ -z "$swaps" ]]; then verdict ok "swap" "expected none (SWAP_SIZE_GB=0), read none"
  else verdict note "swap" "expected none (SWAP_SIZE_GB=0), read $(paste -sd ',' <<<"$swaps")"; fi
elif [[ -z "$swaps" ]]; then
  verdict FAIL "swap" "expected one swap row, read none: the OOM killer is the only reclaim path"
else
  verdict ok "swap" "expected one swap row, read $(paste -sd ',' <<<"$swaps")"
fi
if grep -q '^/swapfile ' /proc/swaps; then
  grep -qs '^/swapfile ' /etc/fstab && v=ok || v=FAIL
  verdict "$v" "swap in fstab" "expected /swapfile in /etc/fstab, $([[ $v == ok ]] && echo found || echo 'read none: swap is gone after a reboot')"
fi
if [[ "$(findmnt -no FSTYPE /tmp 2>/dev/null)" == tmpfs ]]; then
  verdict note "/tmp" "tmpfs: everything written there is RAM; for build or agent workloads mask tmp.mount"
fi

section "locales"
lang="$(awk -F= '$1 == "LANG" { gsub(/"/, "", $2); print $2 }' /etc/default/locale 2>/dev/null)"
[[ "$lang" == "$SYSTEM_LOCALE" ]] && v=ok || v=FAIL
verdict "$v" "system LANG" "expected $SYSTEM_LOCALE in /etc/default/locale, read ${lang:-none}"
generated="$(locale -a 2>/dev/null)"
for loc in $SYSTEM_LOCALE $EXTRA_LOCALES; do
  grep -qxF "${loc%%.*}.utf8" <<<"$generated" && v=ok || v=FAIL
  verdict "$v" "locale $loc" "expected generated, $([[ $v == ok ]] && echo found || echo 'read none: perl tools warn when a client forwards it')"
done

section "health ping"
[[ -x /usr/local/bin/report-health ]] && v=ok || v=FAIL
verdict "$v" "report-health script" "expected /usr/local/bin/report-health executable, $([[ $v == ok ]] && echo found || echo 'read none')"
cron_line="0 * * * * root /usr/local/bin/report-health"
grep -qsxF "$cron_line" /etc/cron.d/report-health && v=ok || v=FAIL
verdict "$v" "report-health cron" "expected '$cron_line' in /etc/cron.d/report-health, $([[ $v == ok ]] && echo found || echo 'read none')"
state="$(systemctl is-active cron 2>/dev/null)"
[[ "$state" == active ]] && v=ok || v=FAIL
verdict "$v" "cron" "expected active, read ${state:-unknown}"
defaults=/etc/default/report-health
if [[ ! -f "$defaults" ]]; then
  verdict note "health ping URL" "no $defaults: the hourly check runs, nothing pings"
else
  mode="$(stat -c '%a %U' "$defaults")"
  if [[ "$mode" != "600 root" ]]; then
    verdict FAIL "health ping URL" "expected $defaults 600 root (the URL is a secret), read $mode"
  elif needs_root "health ping URL"; then
    if grep -q '^HEALTH_PING_URL="[^"]' "$defaults"; then
      verdict ok "health ping URL" "expected set in a 600 root file, read set (value not printed)"
    else
      verdict note "health ping URL" "$defaults holds no HEALTH_PING_URL: nothing pings"
    fi
  fi
fi

section "lingering"
[[ -f "/var/lib/systemd/linger/$USERNAME" ]] && v=ok || v=FAIL
verdict "$v" "linger for $USERNAME" "expected Linger=yes, read $([[ $v == ok ]] && echo yes || echo no)"

section "summary"
if (( fails > 0 )); then
  echo "$fails FAIL"
  exit 1
fi
echo "no FAIL"
