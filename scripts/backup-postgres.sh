#!/usr/bin/env bash
# backup-postgres.sh — verified, retained PostgreSQL backups for a Compose stack.
#
# Usage (as the deploy user, from the project clone under /opt/<project>):
#   scripts/backup-postgres.sh                        # defaults below
#   BACKUP_DIR=<dir> RETENTION_DAYS=<days> scripts/backup-postgres.sh
#
#   Cron runs the clone's own copy, so `git pull` keeps it current
#   (see guides/backup-restore.md, Daily backup):
#     0 3 * * * /opt/<project>/scripts/backup-postgres.sh >> /opt/backups/postgres/backup.log 2>&1
#
# What it does:
#   1. Reads BACKUP_PING_URL from the Compose .env in COMPOSE_DIR, without sourcing it.
#      Set but empty in the environment (prod-init.sh's pre-update backup), it skips the ping.
#   2. Dumps the DB (custom format) via `docker compose exec -T` to a TEMP file.
#   3. Verifies the fresh dump by restoring it to /dev/null with `pg_restore`
#      (run in the container — the host is not assumed to have postgresql-client).
#   4. Renames the temp file to the final timestamped name ONLY after verification,
#      so BACKUP_DIR never holds an unverified dump.
#   5. Prunes dumps older than RETENTION_DAYS.
#   6. Pings BACKUP_PING_URL (dead-man's switch) only after everything succeeds;
#      skips with a notice when unset. Any failure → non-zero exit, no ping.

set -euo pipefail
# Dumps hold every row of the database; keep them owner-only.
umask 077

# ── Configuration (env-var overridable) ──
BACKUP_DIR="${BACKUP_DIR:-/opt/backups/postgres}"
RETENTION_DAYS="${RETENTION_DAYS:-14}"
# The clone root: this script lives in its scripts/ directory.
COMPOSE_DIR="${COMPOSE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()   { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ── Read BACKUP_PING_URL from the Compose .env (cron runs with a bare environment) ──
# Only this one key is parsed; sourcing would execute the file as shell code.
[[ -d "$COMPOSE_DIR" ]] || error "COMPOSE_DIR not found: $COMPOSE_DIR"
[[ -f "$COMPOSE_DIR/.env" ]] || error ".env not found in COMPOSE_DIR: $COMPOSE_DIR/.env"
if [[ -z "${BACKUP_PING_URL+set}" ]]; then
  BACKUP_PING_URL="$(grep -E '^BACKUP_PING_URL=' "$COMPOSE_DIR/.env" | tail -n 1 | cut -d= -f2-)" || true
  BACKUP_PING_URL="${BACKUP_PING_URL%$'\r'}"
  BACKUP_PING_URL="${BACKUP_PING_URL#[\"\']}"
  BACKUP_PING_URL="${BACKUP_PING_URL%[\"\']}"
fi

command -v docker >/dev/null 2>&1      || error "docker is not installed."
docker compose version >/dev/null 2>&1 || error "docker compose plugin is not installed."

mkdir -p "$BACKUP_DIR"

# docker compose reads COMPOSE_FILE from COMPOSE_DIR/.env and the project from that
# file's `name:`, so `exec` reaches the production stack (see templates/.env.example).
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

# Restoring to /dev/null reads every data block, so a truncated or corrupt dump fails
# here. Run it in the container so the host needs no postgresql-client.
log "Verifying dump by restoring it to /dev/null…"
if ! docker compose exec -T postgres pg_restore -f /dev/null < "$temp_file" >/dev/null 2>&1; then
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
