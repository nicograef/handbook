# Docker Compose

## .env Integration

```yaml
# docker-compose.yml — variables from .env are auto-loaded
services:
  db:
    environment:
      POSTGRES_USER: ${POSTGRES_USER}     # reads from .env
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
```

```bash
# Makefile — load .env for make targets too
include .env
export
```

## Healthchecks + Dependency Ordering

```yaml
postgres:
  image: postgres:17
  healthcheck:
    test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
    interval: 5s
    timeout: 3s
    retries: 10

backend:
  depends_on:
    postgres:
      condition: service_healthy    # wait until healthcheck passes
```

## Internal Networks

```yaml
# database only reachable by backend, not from host or reverse-proxy
networks:
  app-network:
    driver: bridge
  db-network:
    driver: bridge
    internal: true    # no external access

services:
  backend:
    networks: [app-network, db-network]
  postgres:
    networks: [db-network]
  reverse-proxy:
    networks: [app-network]
```

## Port Binding

```yaml
# bind to localhost only (not exposed to the internet)
ports:
  - "127.0.0.1:5432:5432"

# bind to all interfaces (public)
ports:
  - "80:80"
```

## Named Volumes

```yaml
volumes:
  postgres-data:          # persistent across restarts
  letsencrypt:            # TLS certs
  certbot-challenges:     # ACME challenges

services:
  postgres:
    volumes:
      - postgres-data:/var/lib/postgresql/data
```

## Multiple Compose Files

```bash
docker compose -f docker-compose.prod.yml up --build -d
docker compose -f docker-compose.prod.yml down
docker compose -f docker-compose.prod.yml logs -f
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
