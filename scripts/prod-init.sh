#!/usr/bin/env bash
# prod-init.sh — First production deploy and every later update, both guarded
#
# Usage (DOMAIN is required; EMAIL is optional and only receives account notices):
#   DOMAIN=example.com make prod-deploy
#   DOMAIN=example.com EMAIL=you@example.com make prod-deploy
#   ROLLBACK=1 DOMAIN=example.com make prod-deploy   # only after restoring a backup
#
# What it does:
#   1. Checks prerequisites, and that every image carries a pinned tag (the app a vX.Y.Z one).
#   2. After an earlier deploy: refuses a downgrade unless ROLLBACK=1, then takes a verified backup.
#   3. nginx variant without a certificate: requests one through the initial-cert stack.
#   4. Pulls the pinned images, starts the stack and polls every healthcheck.
#   5. Polls https://DOMAIN, then records the tag as deployed; on a failure, prints the rollback path.
#
# Not checked below: the DNS records for DOMAIN (A and AAAA on dual-stack, AAAA only on
# IPv6-only) must already point at this server, or the ACME challenge fails
# (see guides/deploy.md, Prerequisites).
set -euo pipefail

# ── Configuration ──
DOMAIN="${DOMAIN:-}"
EMAIL="${EMAIL:-}"
ROLLBACK="${ROLLBACK:-}"                    # 1: the operator restored a backup that fits the older tag
APP_SERVICE="${APP_SERVICE:-backend}"       # its image tag is the release version
HEALTH_TIMEOUT="${HEALTH_TIMEOUT:-180}"     # seconds `up --wait` polls the healthchecks
BACKUP_DIR="${BACKUP_DIR:-/opt/backups/postgres}"

# Either variant is copied to docker-compose.prod.yml, so this name holds for both.
PROD_FILE="docker-compose.prod.yml"
CERT_FILE="docker-compose.initial-cert.yml"
# Last healthy tag and the tag of an unfinished attempt. Written by this script only; gitignore it.
STATE_FILE=".deploy-state"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Both files carry the same top-level `name:`, so they address one Compose project.
COMPOSE_PROD=(docker compose -f "$PROD_FILE")
COMPOSE_CERT=(docker compose -f "$CERT_FILE")

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()   { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

is_release_tag() { [[ "$1" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; }

# True when $1 is a strictly older release tag than $2.
is_downgrade() {
  [[ "$1" != "$2" ]] && [[ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n1)" == "$1" ]]
}

read_state() {
  [[ -f "$STATE_FILE" ]] || return 0
  grep -E "^$1=" "$STATE_FILE" | tail -n1 | cut -d= -f2- || true
}

# write_state DEPLOYED ATTEMPTED — the rename keeps the record whole if the script dies mid-write.
write_state() {
  printf 'deployed=%s\nattempted=%s\n' "$1" "$2" > "$STATE_FILE.tmp"
  mv "$STATE_FILE.tmp" "$STATE_FILE"
}

# ── Prerequisite Checks ──
log "Checking prerequisites…"

[[ -f .env ]] || error ".env file not found. Copy .env.example and fill in your credentials."

# Verify required keys without sourcing .env (Compose reads it directly; never exec it here).
# Each must appear as a KEY=value line with a non-empty value.
for key in POSTGRES_USER POSTGRES_PASSWORD POSTGRES_DB; do
  grep -Eq "^${key}=.+" .env || error "$key not set in .env"
done

command -v docker >/dev/null 2>&1      || error "docker is not installed."
docker compose version >/dev/null 2>&1 || error "docker compose plugin is not installed."
command -v curl >/dev/null 2>&1        || error "curl is not installed."
command -v jq >/dev/null 2>&1          || error "jq is not installed (setup-server.sh installs it)."
[[ -f "$PROD_FILE" ]]                  || error "$PROD_FILE not found. Copy one production Compose template to it."

[[ -n "$DOMAIN" ]] || error "DOMAIN is required. Set it via 'DOMAIN=example.com make prod-deploy'."

CONFIG="$("${COMPOSE_PROD[@]}" config --format json)"

# The certbot service marks the nginx variant; the Caddy variant issues certificates itself.
# A missing bind source becomes an empty directory inside the container, and the proxy fails.
if jq -e '.services | has("certbot")' <<<"$CONFIG" >/dev/null; then
  USES_CERTBOT=true
  [[ -f "$CERT_FILE" ]] || error "$CERT_FILE not found. Copy the docker-compose.initial-cert.yml template."
  [[ -f reverse-proxy/nginx.initial-cert.conf ]] || \
    error "reverse-proxy/nginx.initial-cert.conf not found. Copy the nginx-initial-cert.conf template there."
  [[ -f reverse-proxy/nginx.conf ]] || \
    error "reverse-proxy/nginx.conf not found. Copy the nginx-tls.conf template there and set your domain."
else
  USES_CERTBOT=false
  [[ -f reverse-proxy/Caddyfile ]] || \
    error "reverse-proxy/Caddyfile not found. Copy the Caddyfile template there and set your domain."
fi

# A `build:`, a missing tag or `latest` lets the stack change under an unchanged Compose file.
BUILT="$(jq -r '.services | to_entries[] | select(.value.build) | .key' <<<"$CONFIG")"
[[ -z "$BUILT" ]] || error "The server builds nothing; pin a registry image for: $BUILT"
while IFS= read -r image; do
  [[ "$image" != *@sha256:* ]] || continue
  last="${image##*/}"
  if [[ "$last" != *:* || "${last##*:}" == latest ]]; then
    error "Image '$image' in $PROD_FILE is not pinned to a tag."
  fi
done < <(jq -r '.services[].image // empty' <<<"$CONFIG")

# The app tag orders releases; the downgrade guard compares it.
TARGET_IMAGE="$(jq -r --arg s "$APP_SERVICE" '.services[$s].image' <<<"$CONFIG")"
TARGET_TAG="${TARGET_IMAGE##*:}"
is_release_tag "$TARGET_TAG" || \
  error "$APP_SERVICE image '$TARGET_IMAGE' is not pinned to a vX.Y.Z tag in $PROD_FILE."

# Without --email, certbot registers the ACME account with no contact address.
EMAIL_ARGS=()
[[ -z "$EMAIL" ]] || EMAIL_ARGS=(--email "$EMAIL")

log "Domain:  $DOMAIN"
log "Email:   ${EMAIL:-none}"
log "Target:  $TARGET_TAG"
echo ""

# ── Downgrade guard and pre-update backup ──
# The record, not the running containers, says what has touched the schema: a stopped
# stack or a failed update still counts.
DEPLOYED_TAG="$(read_state deployed)"
ATTEMPTED_TAG="$(read_state attempted)"
DATA_VOLUME="$(jq -r '.volumes["postgres-data"].name // empty' <<<"$CONFIG")"
PRE_UPDATE_DUMP=""

if [[ ! -f "$STATE_FILE" ]]; then
  if [[ -n "$DATA_VOLUME" ]] && docker volume inspect "$DATA_VOLUME" >/dev/null 2>&1; then
    error "Volume $DATA_VOLUME exists but $STATE_FILE does not. Write 'deployed=<running tag>' to $STATE_FILE, then rerun."
  fi
  log "First deploy: no deploy record and no database volume."
else
  FLOOR="$(printf '%s\n%s\n' "$DEPLOYED_TAG" "$ATTEMPTED_TAG" | sed '/^$/d' | sort -V | tail -n1)"
  [[ -n "$FLOOR" ]] || error "$STATE_FILE holds no tag. Write 'deployed=<running tag>' to it, then rerun."
  if is_downgrade "$TARGET_TAG" "$FLOOR"; then
    # Migrations are forward-only: an older release cannot start on a newer schema.
    [[ "$ROLLBACK" == 1 ]] || error "Downgrade refused: $TARGET_TAG is older than $FLOOR." \
      "Restore a backup taken on $TARGET_TAG or earlier, then rerun with ROLLBACK=1."
    warn "════════════════════════════════════════════════════════════════════"
    warn "ROLLBACK=1: deploying $TARGET_TAG below $FLOOR, with the downgrade guard off."
    warn "You assert the database was restored from a backup taken on $TARGET_TAG or earlier."
    warn "════════════════════════════════════════════════════════════════════"
  elif [[ "$ROLLBACK" == 1 ]]; then
    warn "ROLLBACK=1 ignored: $TARGET_TAG is not older than $FLOOR."
  fi
  log "Updating: $FLOOR -> $TARGET_TAG"

  if [[ -z "$("${COMPOSE_PROD[@]}" ps -q postgres)" ]]; then
    log "Starting postgres for the backup…"
    "${COMPOSE_PROD[@]}" up -d --no-recreate --wait postgres
  fi
  log "Taking a pre-update backup…"
  # The empty ping URL keeps the heartbeat for the cron run; a failed ping must not abort a deploy.
  BACKUP_PING_URL="" COMPOSE_FILE="$PROD_FILE" COMPOSE_DIR="$PWD" BACKUP_DIR="$BACKUP_DIR" \
    "$SCRIPT_DIR/backup-postgres.sh"
  PRE_UPDATE_DUMP="$(find "$BACKUP_DIR" -maxdepth 1 -name 'backup-*.dump' -printf '%f\n' | sort | tail -n1)"
  [[ -n "$PRE_UPDATE_DUMP" ]] || error "No backup found in $BACKUP_DIR. Nothing was changed."
  PRE_UPDATE_DUMP="$BACKUP_DIR/$PRE_UPDATE_DUMP"
  log "Pre-update backup: $PRE_UPDATE_DUMP"
fi

# ── Certificate (nginx variant, first time only) ──
request_certificate() {
  log "Starting nginx for the ACME challenge…"
  "${COMPOSE_CERT[@]}" up -d reverse-proxy

  for i in {1..15}; do
    if "${COMPOSE_CERT[@]}" exec -T reverse-proxy nginx -t >/dev/null 2>&1; then
      break
    fi
    if [[ $i -eq 15 ]]; then
      "${COMPOSE_CERT[@]}" down
      error "Nginx did not become ready in time."
    fi
    sleep 1
  done

  log "Requesting Let's Encrypt certificate…"
  # The prod certbot service supplies the image pin and volumes; --no-deps keeps its proxy down.
  if ! "${COMPOSE_PROD[@]}" run --rm --no-deps --entrypoint certbot certbot \
    certonly \
      --webroot -w /var/www/certbot \
      -d "$DOMAIN" -d "www.$DOMAIN" \
      "${EMAIL_ARGS[@]}" \
      --agree-tos \
      --non-interactive; then
    "${COMPOSE_CERT[@]}" down
    error "Certbot failed. Check that DNS for $DOMAIN points to this server."
  fi
  "${COMPOSE_CERT[@]}" down
  log "Certificate obtained."
}

if [[ "$USES_CERTBOT" == true ]]; then
  if "${COMPOSE_PROD[@]}" run --rm --no-deps --entrypoint test certbot \
    -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" 2>/dev/null; then
    log "Certificate for $DOMAIN exists."
  else
    request_certificate
  fi
fi

# ── Start and health polling ──
rollback_hint() {
  [[ -n "$PRE_UPDATE_DUMP" && -n "$DEPLOYED_TAG" ]] || return 0
  warn "Roll back to $DEPLOYED_TAG (guides/deploy.md, Roll back):"
  warn "  1. Set the app image tags in $PROD_FILE back to $DEPLOYED_TAG."
  warn "  2. Restore $PRE_UPDATE_DUMP (guides/backup-restore.md, Restore)."
  warn "  3. ROLLBACK=1 DOMAIN=$DOMAIN make prod-deploy"
}

log "Pulling the pinned images…"
"${COMPOSE_PROD[@]}" pull || error "Pull failed. Nothing was changed."

# From here on the new release may migrate the schema, so the attempt counts for the guard.
write_state "$DEPLOYED_TAG" "$TARGET_TAG"

log "Starting the stack and waiting up to ${HEALTH_TIMEOUT}s for every healthcheck…"
if ! "${COMPOSE_PROD[@]}" up -d --wait --wait-timeout "$HEALTH_TIMEOUT"; then
  "${COMPOSE_PROD[@]}" ps >&2
  rollback_hint
  error "The stack did not become healthy. Check: docker compose -f $PROD_FILE logs"
fi

log "Checking https://$DOMAIN…"
for i in {1..10}; do
  if curl -fsS -o /dev/null --max-time 5 "https://$DOMAIN/"; then
    break
  fi
  if [[ $i -eq 10 ]]; then
    rollback_hint
    error "https://$DOMAIN did not answer. Check: docker compose -f $PROD_FILE logs reverse-proxy"
  fi
  sleep 3
done

write_state "$TARGET_TAG" ""

echo ""
log "Deployed $TARGET_TAG — https://$DOMAIN"
log "Useful commands:"
log "  make prod-logs   — follow logs"
log "  make prod-down   — stop the stack"
