#!/usr/bin/env bash
# test-dockerfiles.sh – build and health-check the three Dockerfile templates
#
# Usage:
#   scripts/test-dockerfiles.sh        # or: make test-dockerfiles
#   PREFIX=<name> scripts/test-dockerfiles.sh   # prefix for every image and container
#   NODE_MAJOR=<n> scripts/test-dockerfiles.sh   # test a version bump; also UV_VERSION, PYTHON_VERSION, GO_MINOR
#
# What it does:
#   1. Fills each template's placeholders with the versions below and the stub's names.
#   2. Writes a minimal stub app per template into a temp dir:
#      go      standard library only, answers GET /api/health on port 8080
#      python  `uv init --package` output plus a bare ASGI factory on uvicorn,
#              the only dependency, same endpoint
#      edge    a frontend/ SPA with no dependencies, pnpm pinned through
#              packageManager, whose build writes index.html, a hashed asset,
#              an icon and a manifest; beside it reverse-proxy/ with the
#              Caddyfile template, its site addresses swapped for http://localhost
#   3. Scaffolds and locks each stub inside the first FROM image of its filled
#      Dockerfile, the build image, with the Go and Python versions it names.
#   4. Copies the stack's dockerignore template beside the Dockerfile, and
#      builds the image with the stub as context.
#   5. Runs each image and waits until `docker inspect` reports it healthy.
#      The edge image must also answer with the SPA fallback, cache headers
#      and manifest type the Caddyfile sets.
#   6. Removes every container and image it created; exits 1 on any failure.
#
# Needs only Docker. It pulls base images and resolves lockfiles over the
# network, so it stays out of `make check`. Run it after every base-image bump.

set -euo pipefail

PREFIX="${PREFIX:-test-dockerfiles}"
HEALTH_TIMEOUT="${HEALTH_TIMEOUT:-90}" # seconds per image
# The tested values of the templates' version placeholders, as guides/new-project.md fills them.
UV_VERSION="${UV_VERSION:-0.13.0}"
PYTHON_VERSION="${PYTHON_VERSION:-3.12}"
GO_MINOR="${GO_MINOR:-1.27}"
NODE_MAJOR="${NODE_MAJOR:-26}"

# shellcheck source=scripts/lib/test-harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib/test-harness.sh"

TEMPLATES="$REPO_ROOT/templates"
STACKS=(go python edge)

cleanup() {
  local s
  for s in "${STACKS[@]}"; do
    docker rm -f "$PREFIX-$s" >/dev/null 2>&1 || true
    docker rmi -f "$PREFIX-$s:test" >/dev/null 2>&1 || true
  done
}

command -v docker >/dev/null || { fail "docker not found"; exit 1; }
docker info >/dev/null 2>&1 || { fail "docker daemon not reachable"; exit 1; }

# fill copies template $1 to $2 with the stub's placeholder values, and fails
# if any <angle-bracket> placeholder is left outside a comment.
fill() {
  sed -e 's/<name>/stub/g' -e 's/<package>/stub/g' -e "s/<uv-version>/$UV_VERSION/g" \
    -e "s/<project-python-version>/$PYTHON_VERSION/g" -e "s/<node-major>/$NODE_MAJOR/g" \
    -e "s/<go-minor>/$GO_MINOR/g" "$1" >"$2"
  if grep -vE '^[[:space:]]*#' "$2" | grep -E '<[a-z][a-z-]*>'; then
    fail "unfilled placeholder in $(basename "$1")"
    return 1
  fi
}

# dockerfile prints where stack $1's Dockerfile sits in its stub, the build context.
dockerfile() { if [[ "$1" == edge ]]; then echo reverse-proxy/Dockerfile; else echo Dockerfile; fi; }

# build_image prints the image of Dockerfile $1's first FROM, its build stage.
build_image() { awk '/^FROM / { print $2; exit }' "$1"; }

# lock runs $3 in image $2 against a copy of stub dir $1 and writes the files named
# by the remaining arguments back into it. They pass through stdout as a tar, so none
# ends up owned by root, and through a temp file, so the stub never holds a partial one.
lock() {
  local d="$1" image="$2" cmd="$3"
  shift 3
  docker run --rm --name "$PREFIX-lock" -v "$d:/stub:ro" "$image" \
    sh -c "cp -r /stub /tmp/w && cd /tmp/w && { $cmd; } >&2 && tar -cf - $*" >"$FIX/lock.tar"
  tar -xf "$FIX/lock.tar" -C "$d"
}

# stub_go writes the build image's own Go release as the go directive: the newest patch
# a `go get` can raise it to, which the image's GOTOOLCHAIN=local must still accept.
stub_go() {
  local d="$FIX/go" go
  go="$(docker run --rm --pull always --name "$PREFIX-scaffold" "$1" go env GOVERSION)"
  mkdir -p "$d/cmd/stub"
  printf 'module stub\n\ngo %s\n' "${go#go}" >"$d/go.mod"
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
  cp "$TEMPLATES/.dockerignore" "$d/"
}

# stub_python scaffolds with `uv init --package` and adds uvicorn and the api.py factory,
# as the new-project runbook does, so the stub carries every file the scaffold writes.
stub_python() {
  local d="$FIX/python"
  docker run --rm --name "$PREFIX-scaffold" "$1" \
    sh -c "cd /tmp && uv init -q --package --python $PYTHON_VERSION stub >&2 && cd stub && uv add -q --no-sync uvicorn >&2 && tar -cf - ." |
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
  cp "$TEMPLATES/.dockerignore" "$d/"
}

# stub_edge pins the newest pnpm through packageManager, as the new-project runbook pins the host's.
# The http:// site addresses keep Caddy off ACME, so the probes below speak plain HTTP.
stub_edge() {
  local d="$FIX/edge"
  mkdir -p "$d/frontend"
  cat >"$d/frontend/package.json" <<'JSON'
{
  "name": "stub",
  "private": true,
  "scripts": {
    "build": "mkdir -p dist/assets && echo '<!doctype html><title>stub</title>' > dist/index.html && echo 'x' > dist/assets/app-0123abcd.js && echo '<svg/>' > dist/icon.svg && echo '{}' > dist/manifest.webmanifest"
  }
}
JSON
  # shellcheck disable=SC2016 # $(pnpm --version) expands in the container
  lock "$d/frontend" "$1" 'npm install -g pnpm && npm pkg set packageManager="pnpm@$(pnpm --version)" && pnpm install --lockfile-only' \
    package.json pnpm-lock.yaml
  sed -e 's|^www\.example\.com {|http://www.localhost {|' -e 's|^example\.com {|http://localhost {|' \
    "$TEMPLATES/Caddyfile" >"$d/reverse-proxy/Caddyfile"
  cp "$TEMPLATES/edge.dockerignore" "$d/reverse-proxy/Dockerfile.dockerignore"
}

# expect fails unless GET path $2 in container $1 answers with status $3 and a header line
# matching ERE $4, and with no header line matching ERE $5 if given. Busybox nc shows the
# headers of an error response too, which busybox wget hides.
expect() {
  local head want="'$4'"
  [[ -z "${5:-}" ]] || want+=" without '$5'"
  head="$(docker exec "$1" sh -c "printf 'GET $2 HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n' | nc localhost 80" |
    tr -d '\r' | sed '/^$/q')"
  if ! grep -qE "^HTTP/1\.1 $3 " <<<"$head" || ! grep -qiE "^$4" <<<"$head" ||
    { [[ -n "${5:-}" ]] && grep -qiE "^$5" <<<"$head"; }; then
    fail "$2: want $3 with $want, got:"
    printf '%s\n' "$head" >&2
    return 1
  fi
}

# check_edge probes the SPA routing and caching the Caddyfile sets.
check_edge() {
  local c="$PREFIX-edge"
  expect "$c" /some/route 200 'Cache-Control: no-cache'
  expect "$c" /some/route 200 'Content-Type: text/html'
  expect "$c" /assets/app-0123abcd.js 200 'Cache-Control: public, max-age=31536000, immutable'
  expect "$c" /assets/missing.js 404 'Content-Length: 0' 'Cache-Control'
  expect "$c" /icon.svg 200 'Cache-Control: public, max-age=3600'
  expect "$c" /manifest.webmanifest 200 'Content-Type: application/manifest\+json'
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
  local s="$1" d="$FIX/$1" f
  f="$d/$(dockerfile "$s")"
  mkdir -p "$(dirname "$f")"
  fill "$TEMPLATES/Dockerfile.$s" "$f"
  log "$s: stub"
  "stub_$s" "$(build_image "$f")"
  log "$s: build"
  docker build --pull --progress=plain -f "$f" -t "$PREFIX-$s:test" "$d"
  log "$s: run"
  docker run -d --name "$PREFIX-$s" "$PREFIX-$s:test" >/dev/null
  health "$PREFIX-$s"
  if [[ "$s" == edge ]]; then check_edge; fi
}

# Each stack runs in a subshell outside any condition, so errexit stops it at the
# first failing step while the next stack still runs.
UNHEALTHY=()
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
    UNHEALTHY+=("$s")
  fi
done

if ((${#UNHEALTHY[@]})); then
  fail "${#UNHEALTHY[@]} of ${#STACKS[@]} images not healthy: ${UNHEALTHY[*]}"
else
  log "all ${#STACKS[@]} images healthy: ${STACKS[*]}"
fi
finish
