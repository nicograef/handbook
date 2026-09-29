# PostgreSQL Major Upgrade

Move a Compose stack's database to a new PostgreSQL major version on a fresh volume.

A new major version cannot read the old data directory, so the data moves by dump and restore.
The old volume stays untouched as the fallback until the new version has proven itself.

## Prerequisites

- The stack passes [deploy.md#verify](deploy.md#verify): a clone under `/opt/<project>`, owned by the deploy user.
- The [Daily backup](backup-restore.md#daily-backup) runs, so `scripts/backup-postgres.sh` and `/opt/backups/postgres` exist.
- A maintenance window: the backend is down from the dump until the final deploy.

## Change the version in git

1. **Bump every image pin** from `postgres:<old-major>` to `postgres:<new-major>`: the Compose files and both jobs in `ci.yml`.

   ```bash
   git grep -n 'postgres:<old-major>'
   ```

   Expected: after the edit, the same command prints nothing.

2. **Give the data volume a new name** in `docker-compose.prod.yml`. The service keeps its `postgres-data` key:

   ```diff
    volumes:
   -  postgres-data:
   +  postgres-data:
   +    name: <project>_postgres-<new-major>-data
   ```

   Expected: `docker compose config --volumes` still lists `postgres-data`.

3. **Commit and push.** The dev stack's volume holds old-format data too; recreate it with `docker compose down --volumes`.

## Upgrade on the server

Run each step as the deploy user in `/opt/<project>`.

1. **Stop the backend and take a verified dump:**

   ```bash
   docker compose stop backend
   scripts/backup-postgres.sh
   ```

   Expected: `Verified backup written: /opt/backups/postgres/backup-<timestamp>.dump`.

2. **Save a row-count query and record the counts:**

   ```bash
   cat > ~/count-rows.sql <<'SQL'
   SELECT table_name, (xpath('/row/c/text()', query_to_xml(format('SELECT count(*) AS c FROM public.%I', table_name), false, true, '')))[1]
   FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE' ORDER BY 1;
   SQL
   docker compose exec -T postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -At' < ~/count-rows.sql > ~/rows-before.txt
   ```

   Expected: `~/rows-before.txt` holds one `<table>|<count>` line per table.

3. **Stop the stack and pull the change:**

   ```bash
   docker compose down
   git pull --ff-only
   ```

   Expected: the pull lists `docker-compose.prod.yml`; `docker volume ls` still shows the old volume.

4. **Start only the database**, on the fresh volume:

   ```bash
   docker compose up -d --wait postgres
   ```

   Expected: `Container <project>-postgres-1  Healthy`, and `docker volume ls` lists `<project>_postgres-<new-major>-data`.

5. **Restore the dump** from step 1:

   ```bash
   DUMP="$(ls -t /opt/backups/postgres/backup-*.dump | head -1)"
   docker compose exec -T postgres sh -c \
     'pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" --single-transaction' < "$DUMP"
   ```

   Expected: no output, exit 0.

6. **Rebuild the planner statistics:**

   ```bash
   docker compose exec postgres sh -c 'vacuumdb -U "$POSTGRES_USER" -d "$POSTGRES_DB" --analyze-in-stages'
   ```

   Expected: three `Generating ... optimizer statistics` lines.

7. **Compare the row counts** with the ones from step 2:

   ```bash
   docker compose exec -T postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -At' < ~/count-rows.sql | diff ~/rows-before.txt -
   ```

   Expected: no output. Any line means a table lost rows: stop and [fall back](#fall-back-to-the-old-version).

8. **Deploy the stack** on the new database:

   ```bash
   DOMAIN=<domain> make prod-deploy
   ```

   Expected: the last lines read `Deployed v<X.Y.Z> — https://<domain>`, exit 0.

## Fall back to the old version

The old volume still holds the data as it was at the dump.
Rows written since the upgrade are lost on fallback.

1. **Revert the upgrade commit** in git and push it.
   Expected: `git grep -n 'postgres:<new-major>'` prints nothing.

2. **Pull the revert on the server and deploy:**

   ```bash
   docker compose down
   git pull --ff-only
   DOMAIN=<domain> make prod-deploy
   ```

   Expected: `Deployed v<X.Y.Z> — https://<domain>`, running on the old volume.

## Remove the old volume

Once the app has run correctly on the new version for a week, delete the old volume.
`docker volume ls` lists it as `<old-volume>`, for example `<project>_postgres-data`.

```bash
docker volume rm <old-volume>
```

Expected: the command prints the volume name. The deletion is irreversible.

## Verify

```bash
docker compose exec -T postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -At -c "SHOW server_version;"'
docker compose ps --format '{{.Service}} {{.Status}}'
```

Expected: `<new-major>.<minor>` and a Debian suffix, then every service `Up` and `(healthy)`.
