#!/usr/bin/env bash
# backup-postgres.sh — verified, retained PostgreSQL backups for a Compose stack.
#
# Usage:
#   scripts/backup-postgres.sh              # uses the defaults / env-var overrides below
#   BACKUP_DIR=/opt/backups/postgres COMPOSE_DIR=/opt/myapp scripts/backup-postgres.sh
#
#   Intended for cron — see guides/postgresql-operations.md §3:
#     0 3 * * * /opt/scripts/backup-postgres.sh >> /var/log/pg-backup.log 2>&1
#
# What it does:
#   1. Loads the Compose .env from COMPOSE_DIR.
#   2. Dumps the DB (custom format) via `docker compose exec -T` to a TEMP file.
#   3. Verifies the fresh dump with `pg_restore --list` (run in the container —
#      the host is not assumed to have postgresql-client installed).
#   4. Renames the temp file to the final timestamped name ONLY after verification,
#      so BACKUP_DIR never holds an unverified dump.
#   5. Prunes dumps older than RETENTION_DAYS.
#   6. Pings BACKUP_PING_URL (dead-man's switch) only after everything succeeds;
#      skips with a notice when unset. Any failure → non-zero exit, no ping.

set -euo pipefail

# ── Configuration (env-var overridable) ──
BACKUP_DIR="${BACKUP_DIR:-/opt/backups/postgres}"
RETENTION_DAYS="${RETENTION_DAYS:-14}"
COMPOSE_DIR="${COMPOSE_DIR:-/opt/myapp}"
BACKUP_PING_URL="${BACKUP_PING_URL:-}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()   { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ── Load the Compose .env (cron runs with a bare environment) ──
# Sets the container's POSTGRES_* vars and lets `docker compose` find the project.
[[ -d "$COMPOSE_DIR" ]] || error "COMPOSE_DIR not found: $COMPOSE_DIR"
[[ -f "$COMPOSE_DIR/.env" ]] || error ".env not found in COMPOSE_DIR: $COMPOSE_DIR/.env"
set -a
# shellcheck disable=SC1091
. "$COMPOSE_DIR/.env"
set +a

command -v docker >/dev/null 2>&1      || error "docker is not installed."
docker compose version >/dev/null 2>&1 || error "docker compose plugin is not installed."

mkdir -p "$BACKUP_DIR"

# Run compose from COMPOSE_DIR so it picks up the project's compose file and .env.
cd "$COMPOSE_DIR"

timestamp="$(date +%Y%m%d-%H%M)"
final_file="$BACKUP_DIR/backup-$timestamp.dump"
temp_file="$BACKUP_DIR/.backup-$timestamp.dump.tmp"

# Never leave a stray temp file behind, whatever happens.
cleanup() { rm -f "$temp_file"; }
trap cleanup EXIT

# Single-quote the inner command so POSTGRES_* expand inside the container, not on
# the host. -T disables the pseudo-TTY so the binary dump is not CR/LF-corrupted.
log "Dumping database to temporary file…"
docker compose exec -T postgres sh -c \
  'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc' \
  > "$temp_file"

# pg_restore --list parses the archive's table of contents; a truncated or corrupt
# dump fails here. Run it in the container so the host needs no postgresql-client.
log "Verifying dump with pg_restore --list…"
if ! docker compose exec -T postgres pg_restore --list < "$temp_file" >/dev/null 2>&1; then
  error "Dump verification failed — corrupt or truncated archive. Not keeping it."
fi

# ── Promote to the final name (only now is the dump trustworthy) ──
mv "$temp_file" "$final_file"
log "Verified backup written: $final_file"

log "Pruning backups older than $RETENTION_DAYS days…"
find "$BACKUP_DIR" -maxdepth 1 -name 'backup-*.dump' -mtime +"$RETENTION_DAYS" -delete

if [[ -z "$BACKUP_PING_URL" ]]; then
  warn "BACKUP_PING_URL unset — skipping success ping."
else
  log "Pinging BACKUP_PING_URL…"
  curl -fsS --max-time 10 "$BACKUP_PING_URL" >/dev/null \
    || error "Backup succeeded but the ping to BACKUP_PING_URL failed."
fi

log "Backup complete. Remaining backups:"
ls -lh "$BACKUP_DIR"
