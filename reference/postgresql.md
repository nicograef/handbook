# PostgreSQL

Backup, restore and the restore drill: [backup-restore.md](../guides/backup-restore.md). Major upgrades: [postgres-upgrade.md](../guides/postgres-upgrade.md).

## Connect

The host has no `psql`; PostgreSQL and its client tools live only in the `postgres`
container. Run every query through it:

```bash
docker compose exec -T postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT 1;"'
```

Single quotes keep `$POSTGRES_*` for the container's shell; `-T` avoids a pseudo-TTY.

## Query & Index Management

```sql
-- kill a query
SELECT pg_cancel_backend(<pid>);    -- graceful
SELECT pg_terminate_backend(<pid>); -- force

-- does not block writes; not inside a transaction; on failure DROP the INVALID index and retry
CREATE INDEX CONCURRENTLY idx_users_email ON users (email);

-- missing index hints (sequential scans on large tables)
SELECT relname, seq_scan, idx_scan
FROM pg_stat_user_tables WHERE seq_scan > 1000 ORDER BY seq_scan DESC;

-- should be > 99%
SELECT
  sum(heap_blks_hit) / nullif(sum(heap_blks_hit) + sum(heap_blks_read), 0) AS ratio
FROM pg_statio_user_tables;
```

## Migrations with golang-migrate

### Install

```bash
curl -fsSL "https://github.com/golang-migrate/migrate/releases/download/v4.20.1/migrate.linux-amd64.tar.gz" \
  | sudo tar -xz -C /usr/local/bin migrate
```

### Forward-only

- Write only `.up.sql` files. The rollback restores the backup taken before the deploy: [Roll back](../guides/deploy.md#roll-back).
- A down migration that drops a column destroys data; the restore keeps it.
- Make each change additive, so the running release still works against the new schema.
- Never edit a migration that a release already shipped.
- The `upgrade-path` job in [templates/ci.yml](../templates/ci.yml) applies the latest
  tag's migrations, then the current ones.

### Create a migration

`migrate create` writes an up and a down file; delete the down file.

```bash
migrate create -ext sql -dir database/migrations -seq add_users_table
rm database/migrations/*_add_users_table.down.sql
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

### Check the version

```bash
migrate version
```

### Recover a dirty database

```bash
# "dirty database version" after failed migration
# → check which version is dirty, fix the SQL, then force
migrate version
migrate force <last-good-version>
```
