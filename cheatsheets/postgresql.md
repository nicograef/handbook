# PostgreSQL

## psql Connection

```bash
psql -U admin -d mydb                            # local connection
psql -h host -p 5432 -U admin -d mydb            # remote connection
psql "postgres://admin:pass@host:5432/mydb?sslmode=require"  # connection string
PGPASSWORD=secret psql -U admin -d mydb          # password via env var
```

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
```

For backup strategies and automation see [guides/postgresql-operations.md](../guides/postgresql-operations.md).
