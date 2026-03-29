# Docker Multi-Stage Builds

Patterns for minimal production images using multi-stage builds.

## Java (Maven → JRE-only)

```dockerfile
# --- Build Stage ---
FROM eclipse-temurin:21-jdk-alpine AS builder
WORKDIR /src

# Cache dependencies (re-downloaded only when pom.xml changes)
COPY pom.xml ./
COPY .mvn .mvn
COPY mvnw ./
RUN chmod +x mvnw && ./mvnw dependency:resolve -B

# Build
COPY src ./src
RUN ./mvnw package -DskipTests -B

# --- Runtime Stage ---
FROM eclipse-temurin:21-jre-alpine
COPY --from=builder /src/target/*.jar /app/app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
```

Key points:
- `jdk-alpine` for build, `jre-alpine` for runtime (~half the size)
- `dependency:resolve` in a separate layer → cached until `pom.xml` changes
- `-DskipTests -B` → tests run in CI, not in Docker build

## Node.js (pnpm + Vite → Nginx)

```dockerfile
# --- Build Stage ---
FROM node:24-alpine AS build
WORKDIR /app

COPY package.json pnpm-lock.yaml ./
RUN corepack enable \
  && corepack prepare pnpm@latest --activate \
  && pnpm install --frozen-lockfile

COPY . .
RUN pnpm build

# --- Runtime Stage ---
FROM nginx:1.27-alpine
COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

Key points:
- `--frozen-lockfile` ensures reproducible installs
- Only `dist/` and nginx config are copied to the runtime image
- Use a `.dockerignore` to exclude `node_modules/`, `.git/`, etc.

## .dockerignore

Always add a `.dockerignore` to keep build context small:

```
node_modules
dist
.git
.env
*.log
.idea
.vscode
```

## Layer Caching Tips

```
# Good: dependency files first, then source (dependencies cached on unchanged lockfile)
COPY package.json pnpm-lock.yaml ./
RUN pnpm install
COPY . .

# Bad: COPY . . first (invalidates cache on every source change)
COPY . .
RUN pnpm install
```

## Image Size Comparison

| Approach | Typical Size |
| -------- | ------------ |
| `node:24` (full) | ~1 GB |
| `node:24-alpine` build + `nginx:alpine` runtime | ~50 MB |
| `temurin:21-jdk-alpine` (full) | ~350 MB |
| `temurin:21-jre-alpine` (runtime only) | ~180 MB |

## Troubleshooting

```bash
# "exec format error" when running image on different architecture
# → Build with --platform: docker build --platform linux/amd64 .

# "COPY --from=builder" fails: file not found
# → Check the build stage output path matches the COPY source
# → Verify the build command runs (check for skipped steps)

# Image still large after multi-stage
# → Check docker image ls — ensure you’re running the final stage, not the builder
# → Avoid copying unnecessary files: use .dockerignore

# Alpine: "not found" when running binary
# → Binary may be dynamically linked against glibc. Use CGO_ENABLED=0 for Go,
#   or switch to a glibc-based image (e.g. debian-slim)
```

---

See also:
- [guides/docker-setup.md](docker-setup.md) — Docker installation
- [cheatsheets/docker-compose.md](../cheatsheets/docker-compose.md) — Compose commands
- [templates/docker-compose.prod.yml](../templates/docker-compose.prod.yml) — production Compose template
