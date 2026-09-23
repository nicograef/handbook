# Docker Multi-Stage Builds

## Java (Maven → JRE-only)

```dockerfile
FROM eclipse-temurin:25-jdk-alpine AS builder
WORKDIR /src

# Dependencies alone, keyed on pom.xml: a source edit rebuilds nothing here.
COPY pom.xml mvnw ./
COPY .mvn .mvn
RUN chmod +x mvnw && ./mvnw dependency:go-offline -B

COPY src ./src
RUN ./mvnw package -DskipTests -B

FROM eclipse-temurin:25-jre-alpine
RUN adduser -D -H -u 10001 app
COPY --from=builder /src/target/*.jar /app/app.jar
USER app
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
```

- `dependency:go-offline` fetches plugins too, so `package` needs no network for them.
- No cache mount for Maven: `package` reads `~/.m2` from the `go-offline` layer.
- `-DskipTests -B` → no tests inside the Docker build.
- `USER app` (uid 10001): the JVM never runs as root.

## Node.js (pnpm + Vite → Nginx)

```dockerfile
FROM node:26-alpine AS build
WORKDIR /app

COPY package.json pnpm-lock.yaml ./
RUN npm install -g pnpm@12
RUN --mount=type=cache,id=pnpm,target=/pnpm/store \
    pnpm install --frozen-lockfile --store-dir /pnpm/store

COPY . .
RUN pnpm build

FROM nginx:1.30-alpine
COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

- `npm install -g pnpm`, not Corepack: Node 25+ images no longer ship Corepack.
- The cache mount keeps the pnpm store across builds and out of the image.

- Copy [templates/.dockerignore](../templates/.dockerignore): the context is sent before any instruction runs.

## Python (uv, single stage)

One stage suffices here: the base image already carries the interpreter and the resolver.

```dockerfile
# Both versions literal: `latest` or `python3.12` alone would move under a frozen lockfile.
FROM ghcr.io/astral-sh/uv:0.12.18-python3.12-trixie-slim

# Compile bytecode once at build time; copy instead of hardlink across the cache boundary.
ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    PATH=/app/.venv/bin:$PATH

WORKDIR /app

# Dependencies alone, keyed on the two files that pin them: a source edit rebuilds nothing here.
COPY pyproject.toml uv.lock ./
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev --no-install-project

COPY src ./src
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev

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
