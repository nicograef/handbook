#!/usr/bin/env bash
# netcup.sh – netcup's server API (SCP REST) from the laptop: login, servers, firewall, snapshots
#
# Untested against a live account until the owner's first run. Paths and fields follow the
# public OpenAPI spec, version 2026.0923.125530; see reference/netcup.md.
#
# Usage (on the laptop, never on a server: the token controls every server on the account):
#   scripts/netcup.sh login                              # device flow, stores the refresh token
#   scripts/netcup.sh token                              # print a short-lived access token
#   scripts/netcup.sh claims                             # print the access token's claims
#   scripts/netcup.sh servers                            # list servers
#   scripts/netcup.sh server <server>                    # one server's detail
#   scripts/netcup.sh firewall-get <server>              # the interface's ServerFirewall JSON
#   scripts/netcup.sh policy-apply <policy.json>         # create or update a policy by name, print its id
#   scripts/netcup.sh firewall-attach <server> <policy-name>...   # attach user policies in order
#   scripts/netcup.sh snapshot-create <server> <name>    # online snapshot, waits for the task
#   scripts/netcup.sh snapshots <server>                 # list snapshots
#
#   <server> is the numeric server id, or a server's name, nickname or hostname.
#
# What it does:
#   1. login runs the OIDC device flow against the realm scp with the public client scp.
#      It prints the URL to open, polls the token endpoint and stores the refresh token
#      in NETCUP_CONFIG_DIR/refresh-token, mode 0600.
#   2. Every other command trades the refresh token for an access token and stores a
#      rotated refresh token when the response carries one. Any use keeps the 30-day window open.
#   3. /users/{userId} paths need the SCP userId: NETCUP_USER_ID, else the cached value,
#      else the executing user of one task, else the access token's id claim, checked against /users.
#   4. firewall-attach keeps the server's copied (netcup default) policies, replaces the user
#      policies with the named ones, sets the firewall active and waits for the task.
#   5. JSON goes to stdout, status to stderr; any HTTP error stops the script.

set -euo pipefail

# ── Configuration (env-var overridable) ──
NETCUP_CONFIG_DIR="${NETCUP_CONFIG_DIR:-$HOME/.config/netcup}"
SCP_URL="${SCP_URL:-https://www.servercontrolpanel.de}"
NETCUP_USER_ID="${NETCUP_USER_ID:-}"
# Seconds firewall-attach, policy-apply and snapshot-create wait for their task.
TASK_TIMEOUT="${TASK_TIMEOUT:-600}"

API="$SCP_URL/scp-core/api/v1"
OIDC="$SCP_URL/realms/scp/protocol/openid-connect"
CLIENT_ID="scp"
REFRESH_FILE="$NETCUP_CONFIG_DIR/refresh-token"
USER_ID_FILE="$NETCUP_CONFIG_DIR/user-id"

log()   { echo "[netcup] $*" >&2; }
error() { echo "[netcup] ERROR: $*" >&2; exit 1; }

usage() {
  sed -n '/^# Usage/,/^# What it does/p' "${BASH_SOURCE[0]}" | sed '$d; s/^# \{0,1\}//' >&2
  exit 2
}

for tool in curl jq base64; do
  command -v "$tool" >/dev/null 2>&1 || error "$tool is not installed."
done

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

# store <file> <value>: writes a secret owner-only, through a temp file in the same directory.
store() {
  (umask 077; mkdir -p "$NETCUP_CONFIG_DIR")
  chmod 700 "$NETCUP_CONFIG_DIR"
  (umask 077; printf '%s\n' "$2" > "$1.tmp")
  mv "$1.tmp" "$1"
}

# ── Auth ──

cmd_login() {
  local device code interval expires waited=0 token err rt
  device="$(curl -sS --fail-with-body "$OIDC/auth/device" \
    --data-urlencode "client_id=$CLIENT_ID" \
    --data-urlencode "scope=openid offline_access")" || error "device request failed: $device"
  code="$(jq -r '.device_code' <<<"$device")"
  interval="$(jq -r '.interval // 5' <<<"$device")"
  expires="$(jq -r '.expires_in // 600' <<<"$device")"
  log "Open: $(jq -r '.verification_uri_complete // .verification_uri' <<<"$device")"
  log "Code: $(jq -r '.user_code' <<<"$device")"
  while (( waited < expires )); do
    sleep "$interval"
    waited=$(( waited + interval ))
    token="$(curl -sS "$OIDC/token" \
      --data-urlencode "grant_type=urn:ietf:params:oauth:grant-type:device_code" \
      --data-urlencode "device_code=$code" \
      --data-urlencode "client_id=$CLIENT_ID")"
    err="$(jq -r '.error // empty' <<<"$token")"
    case "$err" in
      "")
        rt="$(jq -er '.refresh_token' <<<"$token")" || error "login answered no refresh token: $token"
        store "$REFRESH_FILE" "$rt"
        log "Refresh token stored in $REFRESH_FILE"
        return ;;
      authorization_pending) ;;
      slow_down) interval=$(( interval + 5 )) ;;
      *) error "login failed: $err $(jq -r '.error_description // empty' <<<"$token")" ;;
    esac
  done
  error "login timed out after ${expires}s"
}

ACCESS_TOKEN=""
# Epoch second the access token is treated as expired, 30 s before its expires_in.
ACCESS_EXPIRES=0

# access_token: refreshes when needed. Secrets go through stdin, never onto curl's command line.
access_token() {
  [[ -n "$ACCESS_TOKEN" ]] && (( $(date +%s) < ACCESS_EXPIRES )) && return
  [[ -f "$REFRESH_FILE" ]] || error "no refresh token in $REFRESH_FILE; run: $0 login"
  local response rotated
  response="$(printf '%s' "$(<"$REFRESH_FILE")" | curl -sS "$OIDC/token" \
    --data-urlencode "grant_type=refresh_token" \
    --data-urlencode "refresh_token@-" \
    --data-urlencode "client_id=$CLIENT_ID")"
  ACCESS_TOKEN="$(jq -r '.access_token // empty' <<<"$response")"
  [[ -n "$ACCESS_TOKEN" ]] || error "token refresh failed: $(jq -r '.error_description // .error // .' <<<"$response"); run: $0 login"
  ACCESS_EXPIRES=$(( $(date +%s) + $(jq -r '.expires_in // 300' <<<"$response") - 30 ))
  rotated="$(jq -r '.refresh_token // empty' <<<"$response")"
  if [[ -n "$rotated" && "$rotated" != "$(<"$REFRESH_FILE")" ]]; then
    store "$REFRESH_FILE" "$rotated"
  fi
}

# jwt_claims: decodes the access token's payload (base64url, padding restored).
jwt_claims() {
  access_token
  local payload
  payload="$(cut -d. -f2 <<<"$ACCESS_TOKEN" | tr '_-' '/+')"
  while (( ${#payload} % 4 )); do payload+="="; done
  base64 -d <<<"$payload" | jq .
}

# ── HTTP ──

# api <method> <path> [json-body]: prints the response body; an HTTP status >= 400 stops the script.
api() {
  access_token
  local status args=(-sS -o "$TMP" -w '%{http_code}' -X "$1" -H "Accept: application/json")
  [[ $# -ge 3 ]] && args+=(-H "Content-Type: application/json" --data-binary "$3")
  # The header file stays on the curl line: a process substitution in an assignment closes before curl reads it.
  status="$(curl "${args[@]}" -H @<(printf 'Authorization: Bearer %s\n' "$ACCESS_TOKEN") "$API$2")"
  if (( status >= 400 )); then
    cat "$TMP" >&2; echo >&2
    error "$1 $2 answered HTTP $status"
  fi
  cat "$TMP"
}

# wait_task <uuid>: polls a task until FINISHED; ERROR, CANCELED and ROLLBACK stop the script.
wait_task() {
  local task state="" waited=0
  while (( waited < TASK_TIMEOUT )); do
    # Refresh in this shell: api runs in a subshell, and a long task can outlive one access token.
    access_token
    task="$(api GET "/tasks/$1")"
    state="$(jq -r '.state' <<<"$task")"
    case "$state" in
      FINISHED) log "task $1 FINISHED"; return ;;
      ERROR|CANCELED|ROLLBACK)
        jq . <<<"$task" >&2
        error "task $1 ended $state: $(jq -r '.message // .responseError.message // empty' <<<"$task")" ;;
    esac
    sleep 3
    waited=$(( waited + 3 ))
  done
  error "task $1 still $state after ${TASK_TIMEOUT}s; check: $0 token, then GET /tasks/$1"
}

# ── Lookups ──

user_id() {
  if [[ -z "$NETCUP_USER_ID" && -f "$USER_ID_FILE" ]]; then
    NETCUP_USER_ID="$(<"$USER_ID_FILE")"
  fi
  [[ -n "$NETCUP_USER_ID" ]] && return
  local candidate
  candidate="$(api GET "/tasks?limit=1" | jq -r '.[0].executingUser.id // empty')"
  [[ -n "$candidate" ]] || candidate="$(jwt_claims | jq -r '.id // empty')"
  [[ "$candidate" =~ ^[0-9]+$ ]] || error "SCP userId not found; read it from: $0 claims, then set NETCUP_USER_ID"
  api GET "/users/$candidate" >/dev/null
  NETCUP_USER_ID="$candidate"
  store "$USER_ID_FILE" "$NETCUP_USER_ID"
  log "SCP userId $NETCUP_USER_ID cached in $USER_ID_FILE"
}

# server_id <server>: a numeric id passes through; a name, nickname or hostname must match one server.
server_id() {
  if [[ "$1" =~ ^[0-9]+$ ]]; then echo "$1"; return; fi
  local ids
  ids="$(api GET "/servers?limit=1000" \
    | jq -r --arg n "$1" '.[] | select(.name == $n or .nickname == $n or .hostname == $n) | .id')"
  [[ -n "$ids" && "$(wc -l <<<"$ids")" -eq 1 ]] || error "no single server matches '$1': ${ids:-none}"
  echo "$ids"
}

# server_mac <id>: the one non-VLAN interface of the server's live info.
server_mac() {
  local macs
  macs="$(api GET "/servers/$1" \
    | jq -r '.serverLiveInfo.interfaces // [] | map(select(.vlanInterface != true)) | .[].mac')"
  [[ -n "$macs" && "$(wc -l <<<"$macs")" -eq 1 ]] || error "server $1 has no single public interface: ${macs:-none}"
  echo "$macs"
}

# policy_ids <name>: ids of the user policies named exactly <name>.
policy_ids() {
  api GET "/users/$NETCUP_USER_ID/firewall-policies?limit=1000" \
    | jq -r --arg n "$1" '.[] | select(.name == $n) | .id'
}

# ── Commands ──

cmd_firewall_get() {
  local id mac
  id="$(server_id "$1")"
  mac="$(server_mac "$id")"
  api GET "/servers/$id/interfaces/$mac/firewall?consistencyCheck=true" | jq .
}

cmd_policy_apply() {
  local file="$1" name ids id result uuid
  [[ -f "$file" ]] || error "policy file not found: $file"
  name="$(jq -er '.name' "$file")" || error "$file has no name"
  user_id
  ids="$(policy_ids "$name")"
  case "$(grep -c . <<<"$ids" || true)" in
    0)
      id="$(api POST "/users/$NETCUP_USER_ID/firewall-policies" "$(jq -c . "$file")" | jq -r '.id')"
      log "created policy '$name'" ;;
    1)
      result="$(api PUT "/users/$NETCUP_USER_ID/firewall-policies/$ids" "$(jq -c . "$file")")"
      id="$(jq -r '.firewallPolicy.id' <<<"$result")"
      uuid="$(jq -r '.taskInfo.uuid // empty' <<<"$result")"
      log "updated policy '$name'; attached servers receive it"
      [[ -z "$uuid" ]] || wait_task "$uuid" ;;
    *) error "several policies are named '$name': $(tr '\n' ' ' <<<"$ids")" ;;
  esac
  echo "$id"
}

cmd_firewall_attach() {
  local id mac name ids user_policies="[]" body uuid
  id="$(server_id "$1")"
  shift
  user_id
  for name in "$@"; do
    ids="$(policy_ids "$name")"
    [[ -n "$ids" && "$(wc -l <<<"$ids")" -eq 1 ]] || error "no single policy named '$name'; run policy-apply first"
    user_policies="$(jq -c --argjson i "$ids" '. + [{id: $i}]' <<<"$user_policies")"
  done
  mac="$(server_mac "$id")"
  body="$(api GET "/servers/$id/interfaces/$mac/firewall" \
    | jq -c --argjson u "$user_policies" '{copiedPolicies: [(.copiedPolicies // [])[] | {id}], userPolicies: $u, active: true}')"
  log "PUT firewall of server $id ($mac): $body"
  uuid="$(api PUT "/servers/$id/interfaces/$mac/firewall" "$body" | jq -r '.uuid')"
  wait_task "$uuid"
  api GET "/servers/$id/interfaces/$mac/firewall?consistencyCheck=true" | jq .
}

cmd_snapshot_create() {
  local id body checks uuid
  id="$(server_id "$1")"
  body="$(jq -nc --arg n "$2" '{name: $n, onlineSnapshot: true}')"
  checks="$(api POST "/servers/$id/snapshots:dryrun" '{"onlineSnapshot":true}')"
  [[ "$(jq 'length' <<<"$checks")" -eq 0 ]] || error "snapshot not possible: $checks"
  uuid="$(api POST "/servers/$id/snapshots" "$body" | jq -r '.uuid')"
  log "snapshot '$2' of server $id: task $uuid"
  wait_task "$uuid"
}

[[ $# -ge 1 ]] || usage
command="$1"
shift
# Refresh up front: command substitutions are subshells and would each refresh again.
[[ "$command" == login ]] || access_token
case "$command" in
  login)           [[ $# -eq 0 ]] || usage; cmd_login ;;
  token)           [[ $# -eq 0 ]] || usage; access_token; echo "$ACCESS_TOKEN" ;;
  claims)          [[ $# -eq 0 ]] || usage; jwt_claims ;;
  servers)         [[ $# -eq 0 ]] || usage; api GET "/servers?limit=1000" | jq . ;;
  server)          [[ $# -eq 1 ]] || usage; id="$(server_id "$1")"; api GET "/servers/$id" | jq . ;;
  firewall-get)    [[ $# -eq 1 ]] || usage; cmd_firewall_get "$1" ;;
  policy-apply)    [[ $# -eq 1 ]] || usage; cmd_policy_apply "$1" ;;
  firewall-attach) [[ $# -ge 2 ]] || usage; cmd_firewall_attach "$@" ;;
  snapshot-create) [[ $# -eq 2 ]] || usage; cmd_snapshot_create "$1" "$2" ;;
  snapshots)       [[ $# -eq 1 ]] || usage; id="$(server_id "$1")"; api GET "/servers/$id/snapshots" | jq . ;;
  *)               usage ;;
esac
