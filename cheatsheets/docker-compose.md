# Docker Compose

## Port Binding

```yaml
# bind to localhost only (not exposed to the internet)
ports:
  - "127.0.0.1:5432:5432"

# bind to all interfaces (public)
ports:
  - "80:80"
```

## Common Commands

```bash
docker compose up -d                  # start detached
docker compose up --build -d          # rebuild + start
docker compose down                   # stop + remove containers
docker compose down -v                # stop + remove containers + volumes
docker compose logs -f                # follow all logs
docker compose logs -f backend        # follow one service
docker compose exec postgres psql -U $POSTGRES_USER -d $POSTGRES_DB   # DB shell
docker compose ps                     # list services
docker compose restart backend        # restart one service
docker compose pull                   # pull latest images
```

## Project Name

```yaml
# set in docker-compose.yml (affects volume/network prefixes)
name: myapp
# → volumes: myapp_postgres-data, myapp_letsencrypt, ...
```

```bash
# or via CLI
docker compose -p myapp up -d
```
