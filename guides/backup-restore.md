# PostgreSQL Backup and Restore

Take a manual backup, restore a dump, run the verified daily backup, and prove it with the quarterly drill.

## Prerequisites

- Docker Compose stack with a `postgres` service (see [templates/docker-compose.prod.yml](../templates/docker-compose.prod.yml))
- `.env` file with `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`
- On the server, `.env` also sets `COMPOSE_FILE` (see [templates/.env.example](../templates/.env.example)).
  Plain `docker compose` then targets the production stack; its top-level `name:` sets the project.

## Manual backup

- The `postgres` container already holds `POSTGRES_USER` / `POSTGRES_DB` in its
  environment.

### Compressed dump (recommended)

```bash
docker compose exec -T postgres sh -c \
  'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc' \
  > "backup-$(date +%Y%m%d-%H%M).dump"
```

## Restore

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

## Daily backup

Use [scripts/backup-postgres.sh](../scripts/backup-postgres.sh); its header
documents each step. Set up the `BACKUP_PING_URL` heartbeat in
[monitoring.md](monitoring.md).

### Install on the server

```bash
sudo install -m 0755 scripts/backup-postgres.sh /opt/scripts/backup-postgres.sh
sudo install -d -o "$USER" -g "$USER" -m 0700 /opt/backups/postgres
```

Run this as the deploy user. It owns the directory, so its deploys and its cron job both write there.

### Cron line

Add it to the deploy user's crontab with `crontab -e`, not to root's.

```bash
# daily at 03:00
0 3 * * * BACKUP_DIR=/opt/backups/postgres COMPOSE_DIR=/opt/myapp /opt/scripts/backup-postgres.sh >> /opt/backups/postgres/backup.log 2>&1
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
> Backups then survive the loss of the server.

## Restore drill

- Run this drill **quarterly**.
- It proves the newest dump restores cleanly and that your row counts survive the
  round-trip.
- For the live disaster case, restore into the production database instead.
- Use the [full-restore commands](#restore), not the throwaway one below.
- The drill restores into a **throwaway database** and never touches the live one.
- Run it as the deploy user: it owns the backup directory and is in the `docker` group.
- CI runs a schema-only drill on every migration change: the `upgrade-path` job in
  [templates/ci.yml](../templates/ci.yml).
  It restores a dump into the stack's Postgres image; this drill proves the real dumps.

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

## Verify

```bash
# confirm backup file was created (BACKUP_DIR from the cron line)
ls -lh /opt/backups/postgres/backup-*.dump
```
