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
#      spa     no dependencies, pnpm pinned through packageManager; its build
#              script writes dist/index.html
#   3. Scaffolds and locks each stub inside the first FROM image of its filled
#      Dockerfile, the build image, with the Go and Python versions it names.
#   4. Copies .dockerignore (and nginx-spa.conf for the SPA) beside the
#      Dockerfile, and builds the image.
#   5. Runs each image and waits until `docker inspect` reports it healthy.
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
STACKS=(go python spa)

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
}

# stub_spa pins the newest pnpm through packageManager, as the new-project runbook pins the host's.
stub_spa() {
  local d="$FIX/spa"
  cat >"$d/package.json" <<'JSON'
{
  "name": "stub",
  "private": true,
  "scripts": {
    "build": "mkdir -p dist && echo '<!doctype html><title>stub</title>' > dist/index.html"
  }
}
JSON
  # shellcheck disable=SC2016 # $(pnpm --version) expands in the container
  lock "$d" "$1" 'npm install -g pnpm && npm pkg set packageManager="pnpm@$(pnpm --version)" && pnpm install --lockfile-only' \
    package.json pnpm-lock.yaml
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
  local s="$1" d="$FIX/$1"
  mkdir -p "$d"
  fill "$TEMPLATES/Dockerfile.$s" "$d/Dockerfile"
  log "$s: stub"
  "stub_$s" "$(build_image "$d/Dockerfile")"
  cp "$TEMPLATES/.dockerignore" "$d/.dockerignore"
  log "$s: build"
  docker build --pull --progress=plain -t "$PREFIX-$s:test" "$d"
  log "$s: run"
  docker run -d --name "$PREFIX-$s" "$PREFIX-$s:test" >/dev/null
  health "$PREFIX-$s"
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
