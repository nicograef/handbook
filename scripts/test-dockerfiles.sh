#!/usr/bin/env bash
# test-dockerfiles.sh – build and health-check the three Dockerfile templates
#
# Usage:
#   scripts/test-dockerfiles.sh        # or: make test-dockerfiles
#   PREFIX=<name> scripts/test-dockerfiles.sh   # prefix for every image and container
#
# What it does:
#   1. Writes a minimal stub app per template into a temp dir:
#      go      standard library only, answers GET /api/health on port 8080
#      python  `uv init --package` output plus a bare ASGI factory on uvicorn,
#              the only dependency, same endpoint
#      spa     no dependencies; its build script writes dist/index.html
#   2. Resolves each stub's lockfile inside the template's own build image.
#   3. Fills the placeholders, copies .dockerignore (and nginx-spa.conf for the
#      SPA) beside the Dockerfile, and builds the image.
#   4. Runs each image and waits until `docker inspect` reports it healthy.
#   5. Removes every container and image it created; exits 1 on any failure.
#
# Needs only Docker. It pulls base images and resolves lockfiles over the
# network, so it stays out of `make check`. Run it after every base-image bump.

set -euo pipefail

PREFIX="${PREFIX:-test-dockerfiles}"
HEALTH_TIMEOUT="${HEALTH_TIMEOUT:-90}" # seconds per image

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATES="$ROOT/templates"
TMP="$(mktemp -d)"
STACKS=(go python spa)

log() { printf '\033[1;34m▸ %s\033[0m\n' "$*"; }
fail() { printf '\033[1;31mFAIL: %s\033[0m\n' "$*" >&2; }

cleanup() {
  local s
  for s in "${STACKS[@]}"; do
    docker rm -f "$PREFIX-$s" >/dev/null 2>&1 || true
    docker rmi -f "$PREFIX-$s:test" >/dev/null 2>&1 || true
  done
  rm -rf "$TMP"
}
trap cleanup EXIT

command -v docker >/dev/null || { fail "docker not found"; exit 1; }
docker info >/dev/null 2>&1 || { fail "docker daemon not reachable"; exit 1; }

# fill copies template $1 to $2 with the stub's placeholder values, and fails
# if any <angle-bracket> placeholder is left outside a comment.
fill() {
  sed -e 's/<name>/stub/g' -e 's/<package>/stub/g' "$1" >"$2"
  if grep -vE '^[[:space:]]*#' "$2" | grep -E '<[a-z][a-z-]*>'; then
    fail "unfilled placeholder in $(basename "$1")"
    return 1
  fi
}

# lock runs $3 in image $2 against a copy of stub dir $1 and writes the lockfile
# named $4 back into it. The file passes through stdout, so none ends up owned by
# root, and through a temp file, so the stub never holds an empty lockfile.
lock() {
  docker run --rm --name "$PREFIX-lock" -v "$1:/stub:ro" "$2" \
    sh -c "cp -r /stub /tmp/w && cd /tmp/w && { $3; } >&2 && cat $4" >"$TMP/$4"
  mv "$TMP/$4" "$1/$4"
}

stub_go() {
  local d="$TMP/go"
  mkdir -p "$d/cmd/stub"
  printf 'module stub\n\ngo 1.26\n' >"$d/go.mod"
  : >"$d/go.sum" # a real module with dependencies commits one
  cat >"$d/cmd/stub/main.go" <<'GO'
package main

import (
	"log"
	"net/http"
)

func main() {
	http.HandleFunc("GET /api/health", func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte("ok"))
	})
	log.Fatal(http.ListenAndServe(":8080", nil))
}
GO
}

# stub_python scaffolds with `uv init --package`, as the new-project runbook does, so
# the stub carries every file the scaffold writes (README.md among them).
stub_python() {
  local d="$TMP/python"
  mkdir -p "$d"
  docker run --rm --name "$PREFIX-scaffold" ghcr.io/astral-sh/uv:0.12.18-python3.12-trixie-slim \
    sh -c 'cd /tmp && uv init -q --package --python 3.12 stub >&2 && cd stub && uv add -q --no-sync uvicorn >&2 && tar -cf - .' |
    tar -xf - -C "$d"
  cat >"$d/src/stub/api.py" <<'PY'
def app():
    async def asgi(scope, receive, send):
        if scope["type"] != "http":
            return
        status = 200 if scope["path"] == "/api/health" else 404
        await send({"type": "http.response.start", "status": status, "headers": []})
        await send({"type": "http.response.body", "body": b"ok"})

    return asgi
PY
}

stub_spa() {
  local d="$TMP/spa"
  mkdir -p "$d"
  cat >"$d/package.json" <<'JSON'
{
  "name": "stub",
  "private": true,
  "scripts": {
    "build": "mkdir -p dist && echo '<!doctype html><title>stub</title>' > dist/index.html"
  }
}
JSON
  lock "$d" node:26-alpine "npm install -g pnpm@12 && pnpm install --lockfile-only" pnpm-lock.yaml
  cp "$TEMPLATES/nginx-spa.conf" "$d/nginx.conf"
}

# health waits until container $1 reports healthy; fails on unhealthy, exit or timeout.
health() {
  local status i
  for ((i = 0; i < HEALTH_TIMEOUT; i++)); do
    status="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$1")"
    case "$status" in
      healthy) return 0 ;;
      unhealthy | none) break ;;
    esac
    [[ "$(docker inspect -f '{{.State.Running}}' "$1")" == true ]] || break
    sleep 1
  done
  fail "$1 is ${status:-unknown} after ${i}s"
  docker logs --tail 20 "$1" >&2 || true
  return 1
}

# check_stack builds, runs and health-checks one template.
check_stack() {
  local s="$1" d="$TMP/$1"
  log "$s: stub"
  "stub_$s"
  fill "$TEMPLATES/Dockerfile.$s" "$d/Dockerfile"
  cp "$TEMPLATES/.dockerignore" "$d/.dockerignore"
  log "$s: build"
  docker build --pull --progress=plain -t "$PREFIX-$s:test" "$d"
  log "$s: run"
  docker run -d --name "$PREFIX-$s" "$PREFIX-$s:test" >/dev/null
  health "$PREFIX-$s"
}

# Each stack runs in a subshell outside any condition, so errexit stops it at the
# first failing step while the next stack still runs.
FAILED=()
for s in "${STACKS[@]}"; do
  set +e
  (
    set -e
    check_stack "$s"
  )
  rc=$?
  set -e
  if ((rc == 0)); then
    log "$s: healthy"
  else
    fail "$s"
    FAILED+=("$s")
  fi
done

if ((${#FAILED[@]})); then
  fail "${#FAILED[@]} of ${#STACKS[@]} images not healthy: ${FAILED[*]}"
  exit 1
fi
log "all ${#STACKS[@]} images healthy: ${STACKS[*]}"
