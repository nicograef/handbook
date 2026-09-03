# PostgreSQL Operations

## Prerequisites

- Docker Compose stack with a `postgres` service (see [templates/docker-compose.prod.yml](../templates/docker-compose.prod.yml))
- `.env` file with `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`

## 1. Manual Backup

- The `postgres` container already holds `POSTGRES_USER` / `POSTGRES_DB` in its
  environment.
- Run `pg_dump` through `sh -c` with those vars **single-quoted**.
- Single quotes expand them inside the container, not by your host shell.
- `-T` disables the pseudo-TTY, so CR/LF translation cannot corrupt binary dumps.

### Compressed dump (recommended)

```bash
docker compose exec -T postgres sh -c \
  'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc' \
  > "backup-$(date +%Y%m%d-%H%M).dump"
```

## 2. Restore

### From compressed dump

```bash
docker compose exec -T postgres sh -c \
  'pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" --clean --if-exists' \
  < backup-20260101-1200.dump
```

### Into a fresh database

```bash
docker compose exec postgres sh -c 'createdb -U "$POSTGRES_USER" mydb_restored'
docker compose exec -T postgres sh -c \
  'pg_restore -U "$POSTGRES_USER" -d mydb_restored' \
  < backup-20260101-1200.dump
```

## 3. Automated Backup (cron)

Use [scripts/backup-postgres.sh](../scripts/backup-postgres.sh); its header
documents each step. Set up the `BACKUP_PING_URL` heartbeat in
[monitoring.md](monitoring.md).

### Install on the server

```bash
sudo install -m 0755 scripts/backup-postgres.sh /opt/scripts/backup-postgres.sh
sudo mkdir -p /opt/backups/postgres
```

### Cron line

```bash
# daily at 03:00
0 3 * * * BACKUP_DIR=/opt/backups/postgres COMPOSE_DIR=/opt/myapp /opt/scripts/backup-postgres.sh >> /var/log/pg-backup.log 2>&1
```

> **Accepted risk — backups are on the same disk they protect.**
> `BACKUP_DIR` lives on the server being backed up.
> Losing the server loses the backups with it: disk failure, provider incident,
> accidental deletion.
> The daily verified dump plus the quarterly restore drill covers the failure modes that
> actually happen.
> Those are bad migration, dropped table, and corruption.
> **Upgrade path when this stops being acceptable:** push the verified dumps offsite with
> [restic](https://restic.net/).
> Target object storage, e.g. a Hetzner Storage Box.
> Backup survival then no longer depends on the server surviving.

## 4. Restore drill

- Run this drill **quarterly**.
- It proves the newest dump restores cleanly and that your row counts survive the
  round-trip.
- For the live disaster case, restore into the production database instead.
- Use the [full-restore commands](#2-restore), not the throwaway one below.
- The drill restores into a **throwaway database** and never touches the live one.

Set the two env vars to your server's values (same as the backup script):

```bash
export BACKUP_DIR=/opt/backups/postgres    # where scripts/backup-postgres.sh writes
export COMPOSE_DIR=/opt/myapp              # Compose project dir (its .env is used)
cd "$COMPOSE_DIR"
```

1. **Pick the newest verified dump.**

   ```bash
   DUMP="$(ls -t "$BACKUP_DIR"/backup-*.dump | head -1)"
   echo "$DUMP"
   ```

2. **Create a throwaway database and restore into it** (the live DB is left
   alone):

   ```bash
   docker compose exec postgres sh -c 'createdb -U "$POSTGRES_USER" restore_drill'
   docker compose exec -T postgres sh -c \
     'pg_restore -U "$POSTGRES_USER" -d restore_drill' < "$DUMP"
   ```

3. **Spot-check** that known tables came back with the expected row counts.
   Replace `users` / `orders` with two tables you know:

   ```bash
   docker compose exec -T postgres sh -c \
     'psql -U "$POSTGRES_USER" -d restore_drill -c "SELECT count(*) FROM users;" -c "SELECT count(*) FROM orders;"'
   ```

   Each `-c` prints its own one-row result block; expect a plausible,
   non-zero count per table.

4. **Record the outcome** — one line is enough. Append to a `restore-drills.log` next
   to the backups, or note it in your ops journal:

   ```bash
   echo "$(date +%F)  restore drill OK — users=42 orders=100 from $(basename "$DUMP")" \
     >> "$BACKUP_DIR/restore-drills.log"
   ```

5. **Drop the throwaway database.**

   ```bash
   docker compose exec postgres sh -c 'dropdb -U "$POSTGRES_USER" restore_drill'
   ```

## 5. Migrations with golang-migrate

### Install

```bash
curl -fsSL "https://github.com/golang-migrate/migrate/releases/download/v4.19.1/migrate.linux-amd64.tar.gz" \
  | tar -xz -C /usr/local/bin
```

### Create a migration

```bash
migrate create -ext sql -dir database/migrations -seq add_users_table
```

### Run migrations

- The wrapper below shadows the binary installed above; that install serves the
  published-port form at the end of this section.
- Run `migrate` as a throwaway container **on the compose network**.
- It then reaches the database by its service name (`postgres`), no published port
  required.
- Replace `<project>` with your Compose project name (the volume/network prefix).
- The network is `<project>_db-network`.

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
```

> **Published-port form.** If the `postgres` service publishes `5432` to the host, you
> can instead point a locally installed `migrate` binary at `@localhost:5432`.
> Replace `@postgres:5432` with `@localhost:5432` in `DB_URL`, and drop the
> `docker run` wrapper.

## Verify

```bash
# confirm backup file was created (BACKUP_DIR from the cron line)
ls -lh /opt/backups/postgres/backup-*.dump

# check migration version (uses the migrate wrapper from section 5)
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
```
