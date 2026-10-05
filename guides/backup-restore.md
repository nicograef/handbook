# PostgreSQL Backup and Restore

Set up the verified daily backup of a deployed stack, restore a dump, and prove the backups quarterly.

## Prerequisites

- The stack passes [deploy.md#verify](deploy.md#verify): a clone under `/opt/<project>`, owned by the deploy user.
- Its `.env` sets `COMPOSE_FILE`, so plain `docker compose` targets the production stack.
- The backup heartbeat `BACKUP_PING_URL` is set in `.env`, as [monitoring.md](monitoring.md) describes.
- Every command runs as the deploy user in the clone:

```bash
cd /opt/<project>
```

## Daily backup

[backup-postgres.sh](../templates/backup-postgres.sh) takes, verifies and prunes the dumps; its header lists each step and setting.

1. **Create the backup directory**, owned by the deploy user:

   ```bash
   sudo install -d -o "$USER" -g "$USER" -m 0700 /opt/backups/postgres
   ```

   Expected: `ls -ld /opt/backups/postgres` shows `drwx------` and the deploy user as owner.

2. **Take one backup by hand:**

   ```bash
   scripts/backup-postgres.sh
   ```

   Expected: `Verified backup written: /opt/backups/postgres/backup-<timestamp>.dump`, then `Backup complete`.

3. **Schedule it daily at 03:00.** Open the deploy user's crontab with `crontab -e`, not root's, and add:

   ```bash
   0 3 * * * /opt/<project>/scripts/backup-postgres.sh >> /opt/backups/postgres/backup.log 2>&1
   ```

   Expected: `crontab -l` prints the line.

The dumps sit on the disk they protect, so losing the server loses them too.
The daily verified dump and the quarterly drill cover the common failures: bad migration, dropped table, corruption.

## Restore

A restore replaces the live database with a dump. Use it after data loss or for a [roll back](deploy.md#roll-back).
A netcup snapshot is no backup ([why](../reference/netcup.md#snapshots-are-not-backups)). Take one from your laptop with `scripts/netcup.sh snapshot-create` as the step back right before risky host work.

1. **Pick the dump:** the newest one taken before the loss, or the pre-update dump a failed deploy printed.

   ```bash
   ls -t /opt/backups/postgres/backup-*.dump | head
   DUMP=/opt/backups/postgres/backup-<timestamp>.dump
   ```

   Expected: `ls -l "$DUMP"` shows the file.

2. **Stop the backend**, so no session holds the database open:

   ```bash
   docker compose stop backend
   ```

   Expected: `Container <project>-backend-1  Stopped`.

3. **Recreate the database and restore the dump.** The drop also removes tables a failed migration added:

   ```bash
   docker compose exec postgres sh -c 'dropdb -U "$POSTGRES_USER" --force "$POSTGRES_DB" && createdb -U "$POSTGRES_USER" "$POSTGRES_DB"'
   docker compose exec -T postgres sh -c 'pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" --single-transaction --exit-on-error' < "$DUMP"
   ```

   Expected: no output, exit 0. An error leaves the database empty; rerun this step from the same dump.

4. **Rebuild the planner statistics**, which `pg_restore` does not restore:

   ```bash
   docker compose exec postgres sh -c 'vacuumdb -U "$POSTGRES_USER" -d "$POSTGRES_DB" --analyze-in-stages'
   ```

   Expected: three `Generating ... optimizer statistics` lines.

5. **Start the backend:**

   ```bash
   docker compose start backend
   ```

   Expected: `docker compose ps backend` shows `(healthy)` within a minute.

## Restore drill

Run the drill quarterly. It restores the newest dump into a throwaway database and never touches the live one.
CI's `upgrade-path` job in [templates/ci.yml](../templates/ci.yml) proves the migrations; this drill proves the real dumps.

1. **Pick the newest dump:**

   ```bash
   DUMP="$(ls -t /opt/backups/postgres/backup-*.dump | head -1)"; echo "$DUMP"
   ```

   Expected: a dump from the last 24 hours.

2. **Restore it into a throwaway database:**

   ```bash
   docker compose exec postgres sh -c 'createdb -U "$POSTGRES_USER" restore_drill'
   docker compose exec -T postgres sh -c 'pg_restore -U "$POSTGRES_USER" -d restore_drill --exit-on-error' < "$DUMP"
   ```

   Expected: no output, exit 0.

3. **Count the rows of a table you know**, in the drill and in the live database:

   ```bash
   docker compose exec -T postgres sh -c 'for db in restore_drill "$POSTGRES_DB"; do
     psql -U "$POSTGRES_USER" -d "$db" -At -c "SELECT count(*) FROM <table>;"; done'
   ```

   Expected: two non-zero counts; the live one differs only by a day of writes.

4. **Record the outcome** next to the backups:

   ```bash
   echo "$(date +%F) restore drill OK, <table>=<count> from $(basename "$DUMP")" >> /opt/backups/postgres/restore-drills.log
   ```

   Expected: `tail -n 1 /opt/backups/postgres/restore-drills.log` prints the line.

5. **Drop the throwaway database:**

   ```bash
   docker compose exec postgres sh -c 'dropdb -U "$POSTGRES_USER" restore_drill'
   ```

   Expected: no output, exit 0.

## Verify

```bash
crontab -l | grep backup-postgres
find /opt/backups/postgres -name 'backup-*.dump' -mtime -1
tail -n 1 /opt/backups/postgres/restore-drills.log
```

Expected: the cron line, at least one dump younger than a day, and a drill line from this quarter.
