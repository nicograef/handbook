# PostgreSQL Operations

## Prerequisites

- Docker Compose stack with a `postgres` service (see [templates/docker-compose.prod.yml](../templates/docker-compose.prod.yml))
- `.env` file with `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`
- On the server, `.env` also sets `COMPOSE_FILE` and `COMPOSE_PROJECT_NAME` (see
  [templates/.env.example](../templates/.env.example)).
  Plain `docker compose` then targets the production stack.
  `COMPOSE_PROJECT_NAME` must equal `PROJECT` in the Makefile (default `myapp`).

## 1. Manual Backup

- The `postgres` container already holds `POSTGRES_USER` / `POSTGRES_DB` in its
  environment.

### Compressed dump (recommended)

```bash
docker compose exec -T postgres sh -c \
  'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc' \
  > "backup-$(date +%Y%m%d-%H%M).dump"
```

## 2. Restore

### From compressed dump

Stop the backend so no session holds the database open.
`--single-transaction` rolls the whole restore back on any error.

```bash
docker compose stop backend
docker compose exec -T postgres sh -c \
  'pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" --clean --if-exists --single-transaction' \
  < backup-20260101-1200.dump
docker compose exec postgres sh -c \
  'vacuumdb -U "$POSTGRES_USER" -d "$POSTGRES_DB" --analyze-in-stages'
docker compose start backend
```

`pg_restore` restores no planner statistics, so `vacuumdb` rebuilds them.

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
sudo install -d -m 0700 /opt/backups/postgres
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
> Target a Hetzner Storage Box over SFTP, or Object Storage over S3.
> Backup survival then no longer depends on the server surviving.

## 4. Restore drill

- Run this drill **quarterly**.
- It proves the newest dump restores cleanly and that your row counts survive the
  round-trip.
- For the live disaster case, restore into the production database instead.
- Use the [full-restore commands](#2-restore), not the throwaway one below.
- The drill restores into a **throwaway database** and never touches the live one.
- Run it as root: the backup directory is root-only.

Open a root shell and set the two env vars to your server's values (same as the backup
script):

```bash
sudo -i
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
     'pg_restore -U "$POSTGRES_USER" -d restore_drill --exit-on-error' < "$DUMP"
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

## 5. Major upgrade

- A new major version (18 → 19) cannot read the old data directory.
- Move the data with a dump and restore onto a fresh volume.
- Run the steps as root in the Compose directory, since the backup directory is root-only.

```bash
sudo -i
cd /opt/myapp
```

1. **Stop the backend and take a verified dump** with the
   [backup script](#3-automated-backup-cron):

   ```bash
   docker compose stop backend
   BACKUP_DIR=/opt/backups/postgres COMPOSE_DIR=/opt/myapp /opt/scripts/backup-postgres.sh
   ```

2. **Stop the stack**, then bump the `postgres` image tag in the Compose file.

   ```bash
   docker compose down
   ```

3. **Point the service at a fresh volume.** Rename the volume in the Compose file,
   e.g. `postgres-data` to `postgres19-data`, so the old one stays as a fallback.

4. **Start only the database** and restore the dump into it:

   ```bash
   docker compose up -d --wait postgres
   DUMP="$(ls -t /opt/backups/postgres/backup-*.dump | head -1)"
   docker compose exec -T postgres sh -c \
     'pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" --single-transaction' < "$DUMP"
   ```

5. **Rebuild planner statistics**, then start the rest of the stack:

   ```bash
   docker compose exec postgres sh -c \
     'vacuumdb -U "$POSTGRES_USER" -d "$POSTGRES_DB" --analyze-in-stages'
   docker compose up -d
   ```

6. **Remove the old volume** once the app runs correctly on the new version.

## 6. Migrations with golang-migrate

### Install

```bash
curl -fsSL "https://github.com/golang-migrate/migrate/releases/download/v4.20.1/migrate.linux-amd64.tar.gz" \
  | sudo tar -xz -C /usr/local/bin migrate
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
    migrate/migrate:v4.20.1 \
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

# check migration version (uses the migrate wrapper from section 6)
migrate version
```

## Troubleshooting

```bash
# "dirty database version" after failed migration
# → check which version is dirty, fix the SQL, then force
migrate version
migrate force <last-good-version>
```
