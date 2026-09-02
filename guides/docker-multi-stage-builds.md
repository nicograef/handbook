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

- `-DskipTests -B` → tests run in CI, not in Docker build

## Node.js (pnpm + Vite → Nginx)

```dockerfile
FROM node:24-alpine AS build
WORKDIR /app

COPY package.json pnpm-lock.yaml ./
RUN corepack enable \
  && corepack prepare pnpm@10 --activate \
  && pnpm install --frozen-lockfile

COPY . .
RUN pnpm build

FROM nginx:1.30-alpine
COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

- Use a `.dockerignore` to exclude `node_modules/`, `.git/`, etc.

## Troubleshooting

```bash
# Alpine: "not found" when running binary
# → Binary may be dynamically linked against glibc. Use CGO_ENABLED=0 for Go,
#   or switch to a glibc-based image (e.g. debian-slim)
```
