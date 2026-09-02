# PostgreSQL

## Query & Index Management

```sql
-- kill a query
SELECT pg_cancel_backend(<pid>);    -- graceful
SELECT pg_terminate_backend(<pid>); -- force

-- create index concurrently (no table lock)
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
