# PostgreSQL

## psql Connection

```bash
psql -U admin -d mydb                            # local connection
psql -h host -p 5432 -U admin -d mydb            # remote connection
psql "postgres://admin:pass@host:5432/mydb?sslmode=require"  # connection string
PGPASSWORD=secret psql -U admin -d mydb          # password via env var
```

## psql Meta-Commands

```bash
\l                  # list databases
\c mydb             # connect to database
\dt                 # list tables
\dt+                # list tables with size
\d users            # describe table (columns, types, constraints)
\di                 # list indexes
\df                 # list functions
\dn                 # list schemas
\du                 # list roles
\x                  # toggle expanded output (vertical)
\timing             # toggle query timing
\q                  # quit
```

## Database & Role Management

```sql
CREATE DATABASE mydb;
DROP DATABASE mydb;

CREATE ROLE app_user WITH LOGIN PASSWORD 'secret';
GRANT ALL PRIVILEGES ON DATABASE mydb TO app_user;
GRANT ALL ON ALL TABLES IN SCHEMA public TO app_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO app_user;
```

## Common Queries

```sql
-- table sizes
SELECT relname, pg_size_pretty(pg_total_relation_size(relid))
FROM pg_catalog.pg_statio_user_tables ORDER BY pg_total_relation_size(relid) DESC;

-- database size
SELECT pg_size_pretty(pg_database_size('mydb'));

-- active connections
SELECT pid, usename, application_name, state, query_start, query
FROM pg_stat_activity WHERE datname = 'mydb';

-- kill a query
SELECT pg_cancel_backend(<pid>);    -- graceful
SELECT pg_terminate_backend(<pid>); -- force

-- long-running queries (> 5 min)
SELECT pid, now() - query_start AS duration, query
FROM pg_stat_activity
WHERE state = 'active' AND now() - query_start > interval '5 minutes';
```

## Index Management

```sql
-- list indexes with sizes
SELECT indexrelname, pg_size_pretty(pg_relation_size(indexrelid))
FROM pg_stat_user_indexes ORDER BY pg_relation_size(indexrelid) DESC;

-- unused indexes (candidates for removal)
SELECT indexrelname, idx_scan
FROM pg_stat_user_indexes WHERE idx_scan = 0;

-- create index concurrently (no table lock)
CREATE INDEX CONCURRENTLY idx_users_email ON users (email);

-- missing index hints (sequential scans on large tables)
SELECT relname, seq_scan, idx_scan
FROM pg_stat_user_tables WHERE seq_scan > 1000 ORDER BY seq_scan DESC;
```

## Backup & Restore

```bash
# full database dump (compressed)
pg_dump -U admin -d mydb -Fc -f mydb.dump

# plain SQL dump
pg_dump -U admin -d mydb > mydb.sql

# single table
pg_dump -U admin -d mydb -t users -Fc -f users.dump

# restore from custom format
pg_restore -U admin -d mydb --clean --if-exists mydb.dump

# restore from SQL
psql -U admin -d mydb < mydb.sql

# all databases
pg_dumpall -U admin > all.sql
```

For backup strategies and automation see [guides/postgresql-operations.md](../guides/postgresql-operations.md).

## Config & Tuning

```sql
SHOW work_mem;
SHOW shared_buffers;
SHOW max_connections;
SHOW config_file;                                -- location of postgresql.conf
```

```bash
# reload config without restart
sudo systemctl reload postgresql
# or from psql:
SELECT pg_reload_conf();
```

## Useful Shortcuts

```bash
# quick row count
SELECT count(*) FROM users;

# explain query plan
EXPLAIN ANALYZE SELECT * FROM users WHERE email = 'a@b.com';

# list table columns with types
SELECT column_name, data_type, is_nullable
FROM information_schema.columns WHERE table_name = 'users';

# current timestamp
SELECT now();
```
