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

### Compressed dump (recommended)

```bash
docker compose exec postgres pg_dump \
  -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc \
  > "backup-$(date +%Y%m%d-%H%M).dump"
```

### Plain SQL dump

```bash
docker compose exec postgres pg_dump \
  -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
  > "backup-$(date +%Y%m%d-%H%M).sql"
```

### Single table

```bash
docker compose exec postgres pg_dump \
  -U "$POSTGRES_USER" -d "$POSTGRES_DB" -t users -Fc \
  > "users-$(date +%Y%m%d-%H%M).dump"
```

## 2. Restore

### From compressed dump

```bash
docker compose exec -T postgres pg_restore \
  -U "$POSTGRES_USER" -d "$POSTGRES_DB" --clean --if-exists \
  < backup-20260101-1200.dump
```

### From SQL dump

```bash
docker compose exec -T postgres psql \
  -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
  < backup-20260101-1200.sql
```

### Into a fresh database

```bash
docker compose exec postgres createdb -U "$POSTGRES_USER" mydb_restored
docker compose exec -T postgres pg_restore \
  -U "$POSTGRES_USER" -d mydb_restored \
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

mkdir -p "$BACKUP_DIR"

docker compose -f "$COMPOSE_DIR/docker-compose.prod.yml" exec -T postgres \
  pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc \
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

```bash
# connection string
DB_URL="postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@localhost:5432/${POSTGRES_DB}?sslmode=disable"

# apply all pending
migrate -path database/migrations -database "$DB_URL" up

# apply next N
migrate -path database/migrations -database "$DB_URL" up 2

# rollback last batch
migrate -path database/migrations -database "$DB_URL" down 1

# rollback all
migrate -path database/migrations -database "$DB_URL" down -all

# check current version
migrate -path database/migrations -database "$DB_URL" version

# force version (after fixing a dirty migration)
migrate -path database/migrations -database "$DB_URL" force <version>
```

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
docker compose exec postgres createdb -U "$POSTGRES_USER" test_restore
docker compose exec -T postgres pg_restore \
  -U "$POSTGRES_USER" -d test_restore < backup-*.dump
docker compose exec postgres dropdb -U "$POSTGRES_USER" test_restore

# check migration version
migrate -path database/migrations -database "$DB_URL" version
```

## Troubleshooting

```bash
# "database is being accessed by other users" when restoring
# → terminate other connections first
docker compose exec postgres psql -U "$POSTGRES_USER" -c \
  "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'mydb' AND pid <> pg_backend_pid();"

# "dirty database version" after failed migration
# → check which version is dirty, fix the SQL, then force
migrate -path database/migrations -database "$DB_URL" version
migrate -path database/migrations -database "$DB_URL" force <last-good-version>

# connection refused — check if container is healthy
docker compose ps
docker compose logs postgres | tail -20
```

---

See also:
- [cheatsheets/postgresql.md](../cheatsheets/postgresql.md) — quick-reference psql commands
- [theory/postgresql.md](../theory/postgresql.md) — PostgreSQL concepts (German)
- [cheatsheets/docker-compose.md](../cheatsheets/docker-compose.md) — Compose commands
