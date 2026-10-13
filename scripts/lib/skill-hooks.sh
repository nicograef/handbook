# shellcheck shell=bash
# skill-hooks.sh – reads the hook commands a plugin SKILL.md declares in its frontmatter
#
# Usage (sourced, never run):
#   # shellcheck source=scripts/lib/skill-hooks.sh
#   . "$(dirname "${BASH_SOURCE[0]}")/lib/skill-hooks.sh"
#   skill_hook_commands plugin/skills/<name>/SKILL.md
#
# What it does:
#   1. skill_hook_commands prints every `command:` value of the file's frontmatter, one per line.
#   2. Unwraps a YAML single-quoted value and unescapes its doubled quotes, as YAML reads it.

skill_hook_commands() {
  awk 'NR == 1 && /^---/ { fm = 1; next } fm && /^---/ { exit }
    fm && sub(/^[ \t]*command:[ \t]*/, "") { print }' "$1" | sed -E "s/^'(.*)'$/\1/; s/''/'/g"
}
