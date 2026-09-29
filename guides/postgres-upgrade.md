# PostgreSQL Major Upgrade

Move a Compose stack's database to a new PostgreSQL major version.

## Prerequisites

- A new major version (18 → 19) cannot read the old data directory.
- Move the data with a dump and restore onto a fresh volume.
- Run the steps as the deploy user in the Compose directory.

```bash
cd /opt/myapp
```

## Upgrade

1. **Stop the backend and take a verified dump** with the
   [backup script](backup-restore.md#daily-backup):

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
