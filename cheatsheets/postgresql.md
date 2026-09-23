# PostgreSQL

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

For backup strategies and automation see [guides/postgresql-operations.md](../guides/postgresql-operations.md).
