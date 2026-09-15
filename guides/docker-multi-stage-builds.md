# Docker Multi-Stage Builds

## Java (Maven → JRE-only)

```dockerfile
FROM eclipse-temurin:21-jdk-alpine AS builder
WORKDIR /src

# Cache dependencies (re-downloaded only when pom.xml changes)
COPY pom.xml ./
COPY .mvn .mvn
COPY mvnw ./
RUN chmod +x mvnw && ./mvnw dependency:resolve -B

COPY src ./src
RUN ./mvnw package -DskipTests -B

FROM eclipse-temurin:21-jre-alpine
COPY --from=builder /src/target/*.jar /app/app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
```

- `-DskipTests -B` → no tests inside the Docker build

## Node.js (pnpm + Vite → Nginx)

```dockerfile
FROM node:26-alpine AS build
WORKDIR /app

COPY package.json pnpm-lock.yaml ./
RUN npm install -g pnpm@12 \
  && pnpm install --frozen-lockfile

COPY . .
RUN pnpm build

FROM nginx:1.30-alpine
COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

- `npm install -g pnpm`, not Corepack: Node 25+ images no longer ship Corepack.

- Copy [templates/.dockerignore](../templates/.dockerignore): the context is sent before any instruction runs.

## Python (uv, single stage)

One stage suffices here: the base image already carries the interpreter and the resolver.

```dockerfile
# Both versions literal: `latest` or `python3.12` alone would move under a frozen lockfile.
FROM ghcr.io/astral-sh/uv:0.9.30-python3.12-bookworm-slim

# Compile bytecode once at build time; copy instead of hardlink across the cache boundary.
ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    PATH=/app/.venv/bin:$PATH

WORKDIR /app

# Dependencies alone, keyed on the two files that pin them: a source edit rebuilds nothing here.
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev --no-install-project

COPY src ./src
RUN uv sync --frozen --no-dev

# Created after the sync, so the venv is owned by root and only read by the service.
RUN useradd --create-home --uid 10001 app
USER app

EXPOSE 8080
CMD ["uvicorn", "--factory", "<package>.api:app", "--host", "0.0.0.0", "--port", "8080"]
```

- `--frozen` installs what `uv.lock` pins and never re-resolves; `--no-dev` leaves pytest, ruff and ty out.
- `0.0.0.0` inside the container; the `127.0.0.1:` in the Compose port mapping is what keeps it off the internet.

## Troubleshooting

```bash
# Alpine: "not found" when running binary
# → Binary may be dynamically linked against glibc. Use CGO_ENABLED=0 for Go,
#   or switch to a glibc-based image (e.g. debian-slim)
```
