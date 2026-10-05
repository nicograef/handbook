#!/usr/bin/env bash
# run.sh – run the skill evals for testing, decide and plan against a no-plugin baseline.
#
# Usage:
#   make eval
#   RUNS=3 MAX_COST_USD=10 .claude/evals/run.sh [claude plugin eval options, e.g. --case 'plan-*']
#
# What it does:
#   1. Builds a temporary plugin: symlinks to the three skills plus a copy of the cases here
#   2. Runs `claude plugin eval` on it from that temp dir, outside any repo, capped by MAX_COST_USD
#   3. Prints the pass rate per skill, with the plugin and without it
#
# Every run is a real model call on the user's plan. The cases are ours, so the run
# passes --trust-plugin and --scaffold. Results stay in RESULTS_DIR; the plugin is removed.

set -euo pipefail

MAX_COST_USD="${MAX_COST_USD:-10}"
RUNS="${RUNS:-2}"
MODEL="${MODEL:-}"
RESULTS_DIR="${RESULTS_DIR:-$(mktemp -d -t skill-evals-results.XXXXXX)}"
SKILLS=(testing decide plan)

EVALS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$(cd "$EVALS_DIR/../skills" && pwd)"

log() {
  printf 'eval: %s\n' "$*" >&2
}

for tool in claude jq; do
  command -v "$tool" >/dev/null 2>&1 || { log "$tool not found"; exit 1; }
done

WORK="$(mktemp -d -t skill-evals.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
PLUGIN="$WORK/handbook-skills"

mkdir -p "$PLUGIN/.claude-plugin" "$PLUGIN/skills" "$PLUGIN/evals"
printf '{"name": "handbook-skills", "version": "0.0.0", "description": "Handbook skills under eval"}\n' \
  > "$PLUGIN/.claude-plugin/plugin.json"
for skill in "${SKILLS[@]}"; do
  ln -s "$SKILLS_DIR/$skill" "$PLUGIN/skills/$skill"
done
for case_dir in "$EVALS_DIR"/*/; do
  cp -R "$case_dir" "$PLUGIN/evals/"
done

args=(
  "$PLUGIN"
  --trust-plugin --scaffold --no-publish
  --runs "$RUNS" --threshold 0 --max-cost-usd "$MAX_COST_USD"
  --output-dir "$RESULTS_DIR"
)
[[ -n "$MODEL" ]] && args+=(--model "$MODEL")
# --allow-tools takes a list, so it goes last before the caller's options.
args+=(--allow-tools Write Edit Bash)

log "runs per arm: $RUNS, cost cap: $MAX_COST_USD USD, results: $RESULTS_DIR"
cd "$WORK"
status=0
claude plugin eval "${args[@]}" "$@" || status=$?

RESULT="$RESULTS_DIR/aggregate-result.json"
if [[ ! -f "$RESULT" ]]; then
  log "no $RESULT; claude plugin eval exited $status"
  exit "${status/#0/1}"
fi

# A run passes when its score is 1.0. Cases are named <skill>-<slug>.
printf '\n%-8s %-10s %-10s %s\n' SKILL WITH W/OUT RUNS
jq -r '
  def rate(runs): if (runs | length) == 0 then "-"
    else "\((runs | map(select(.score >= 1)) | length) * 100 / (runs | length) | round)%" end;
  .cases | group_by(.name | split("-")[0])[]
  | (map(.arms.with // []) | add) as $with
  | (map(.arms.without // []) | add) as $without
  | [(.[0].name | split("-")[0]), rate($with), rate($without), "\($with | length)/\($without | length)"]
  | @tsv
' "$RESULT" | while IFS=$'\t' read -r skill with without runs; do
  printf '%-8s %-10s %-10s %s\n' "$skill" "$with" "$without" "$runs"
done

[[ "$(jq -r '.partial // false' "$RESULT")" == true ]] && log "partial result: $(jq -r '.partialReason' "$RESULT")"
exit "$status"
