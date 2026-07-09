# PostgreSQL Operations

Practical runbook for PostgreSQL backup, restore, migrations, and monitoring
in a Docker Compose stack.

## Prerequisites

- Docker Compose stack with a `postgres` service (see [templates/docker-compose.prod.yml](../templates/docker-compose.prod.yml))
- `.env` file with `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`
- `pg_dump` / `pg_restore` available (installed with `postgresql-client`)

```bash
sudo apt install -y postgresql-client
```

## 1. Manual Backup

The `postgres` container already holds `POSTGRES_USER` / `POSTGRES_DB` in its
environment, so run `pg_dump` through `sh -c` with those vars **single-quoted**
(expanded inside the container, not by your host shell). `-T` disables the
pseudo-TTY so binary dumps are not corrupted by CR/LF translation.

### Compressed dump (recommended)

```bash
docker compose exec -T postgres sh -c \
  'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc' \
  > "backup-$(date +%Y%m%d-%H%M).dump"
```

### Plain SQL dump

```bash
docker compose exec -T postgres sh -c \
  'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB"' \
  > "backup-$(date +%Y%m%d-%H%M).sql"
```

### Single table

```bash
docker compose exec -T postgres sh -c \
  'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -t users -Fc' \
  > "users-$(date +%Y%m%d-%H%M).dump"
```

## 2. Restore

### From compressed dump

```bash
docker compose exec -T postgres sh -c \
  'pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" --clean --if-exists' \
  < backup-20260101-1200.dump
```

### From SQL dump

```bash
docker compose exec -T postgres sh -c \
  'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"' \
  < backup-20260101-1200.sql
```

### Into a fresh database

```bash
docker compose exec postgres sh -c 'createdb -U "$POSTGRES_USER" mydb_restored'
docker compose exec -T postgres sh -c \
  'pg_restore -U "$POSTGRES_USER" -d mydb_restored' \
  < backup-20260101-1200.dump
```

## 3. Automated Backup (cron)

Create a backup script on the host:

```bash
#!/usr/bin/env bash
# /opt/scripts/pg-backup.sh
set -euo pipefail

BACKUP_DIR="/opt/backups/postgres"
RETENTION_DAYS=14
COMPOSE_DIR="/opt/myapp"

# cron runs with a bare environment — load the compose .env so the container
# name resolves and any host-side vars are available.
set -a; . "$COMPOSE_DIR/.env"; set +a

mkdir -p "$BACKUP_DIR"

docker compose -f "$COMPOSE_DIR/docker-compose.prod.yml" exec -T postgres sh -c \
  'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc' \
  > "$BACKUP_DIR/backup-$(date +%Y%m%d-%H%M).dump"

# remove backups older than retention period
find "$BACKUP_DIR" -name 'backup-*.dump' -mtime +"$RETENTION_DAYS" -delete

echo "Backup complete. Remaining backups:"
ls -lh "$BACKUP_DIR"
```

Add to crontab:

```bash
# daily at 03:00
0 3 * * * /opt/scripts/pg-backup.sh >> /var/log/pg-backup.log 2>&1
```

## 4. Migrations with golang-migrate

### Install

```bash
curl -fsSL "https://github.com/golang-migrate/migrate/releases/download/v4.19.1/migrate.linux-amd64.tar.gz" \
  | tar -xz -C /usr/local/bin
```

### Create a migration

```bash
migrate create -ext sql -dir database/migrations -seq add_users_table
```

This creates two files:

```
database/migrations/000001_add_users_table.up.sql
database/migrations/000001_add_users_table.down.sql
```

### Run migrations

Run `migrate` as a throwaway container **on the compose network** so it reaches
the database by its service name (`postgres`), no published port required.
Replace `<project>` with your Compose project name (the volume/network prefix);
the network is `<project>_db-network`.

```bash
DB_URL="postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB}?sslmode=disable"

migrate() {
  docker run --rm \
    --network <project>_db-network \
    -v "$PWD/database/migrations:/migrations" \
    migrate/migrate \
    -path /migrations -database "$DB_URL" "$@"
}

migrate up                 # apply all pending
migrate up 2               # apply next N
migrate down 1             # rollback last batch
migrate down -all          # rollback all
migrate version            # check current version
migrate force <version>    # force version (after fixing a dirty migration)
```

> **Published-port form.** If the `postgres` service publishes `5432` to the
> host, you can instead point a locally installed `migrate` binary at
> `@localhost:5432` — replace `@postgres:5432` with `@localhost:5432` in
> `DB_URL` and drop the `docker run` wrapper.

### Migration file template

```sql
-- 000001_add_users_table.up.sql
CREATE TABLE IF NOT EXISTS users (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email      TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 000001_add_users_table.down.sql
DROP TABLE IF EXISTS users;
```

## 5. Monitoring Queries

### Active connections

```sql
SELECT pid, usename, application_name, state, query_start, query
FROM pg_stat_activity WHERE datname = current_database();
```

### Long-running queries (> 5 min)

```sql
SELECT pid, now() - query_start AS duration, query
FROM pg_stat_activity
WHERE state = 'active' AND now() - query_start > interval '5 minutes';
```

### Table sizes

```sql
SELECT relname, pg_size_pretty(pg_total_relation_size(relid))
FROM pg_catalog.pg_statio_user_tables
ORDER BY pg_total_relation_size(relid) DESC;
```

### Unused indexes

```sql
SELECT indexrelname, idx_scan
FROM pg_stat_user_indexes WHERE idx_scan = 0;
```

### Cache hit ratio (should be > 99%)

```sql
SELECT
  sum(heap_blks_hit) / nullif(sum(heap_blks_hit) + sum(heap_blks_read), 0) AS ratio
FROM pg_statio_user_tables;
```

## Verify

```bash
# confirm backup file was created
ls -lh backup-*.dump

# test restore into a throwaway database
docker compose exec postgres sh -c 'createdb -U "$POSTGRES_USER" test_restore'
docker compose exec -T postgres sh -c \
  'pg_restore -U "$POSTGRES_USER" -d test_restore' < backup-*.dump
docker compose exec postgres sh -c 'dropdb -U "$POSTGRES_USER" test_restore'

# check migration version (uses the migrate wrapper from section 4)
migrate version
```

## Troubleshooting

```bash
# "database is being accessed by other users" when restoring
# → terminate other connections first
docker compose exec postgres sh -c \
  'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = current_database() AND pid <> pg_backend_pid();"'

# "dirty database version" after failed migration
# → check which version is dirty, fix the SQL, then force
migrate version
migrate force <last-good-version>

# connection refused — check if container is healthy
docker compose ps
docker compose logs postgres | tail -20
```

---

See also:
- [cheatsheets/postgresql.md](../cheatsheets/postgresql.md) — quick-reference psql commands
- [cheatsheets/docker-compose.md](../cheatsheets/docker-compose.md) — Compose commands
