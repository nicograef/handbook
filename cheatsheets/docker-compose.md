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
