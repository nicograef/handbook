# Dockerfile.go — Go backend image: static binary on Alpine
# Copy to <backend-dir>/Dockerfile, the name release.yml builds, and copy .dockerignore beside it.
# Fill <name>: the command directory under cmd/ that holds main.go.
# The app answers GET /api/health on port 8080; the production Compose files poll its healthcheck.

# ── Build ──
# The Go version repeats the minor of the `go` directive in go.mod.
FROM golang:1.26-alpine AS build
WORKDIR /src

# Dependencies alone, keyed on the two files that pin them: a source edit rebuilds nothing here.
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download

# CGO_ENABLED=0 links statically, so the binary needs no libc from the runtime image.
COPY . .
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/app ./cmd/<name>

# ── Runtime ──
# Alpine rather than distroless: its busybox wget probes the health endpoint, so the app needs no probe flag.
FROM alpine:3.24
RUN adduser -D -H -u 10001 app
COPY --from=build /out/app /usr/local/bin/app
USER app

EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=5 \
  CMD wget -qO- http://127.0.0.1:8080/api/health >/dev/null 2>&1 || exit 1
ENTRYPOINT ["/usr/local/bin/app"]
