# Handbook dev interface. `make check` is the full repo self-check.

.PHONY: check links lint readme language skills compose plugin prose test-prune test-agent-bus help

## check: run the full repo self-check (links, shellcheck, README index, language, skills, compose, plugin, prose)
check:
	@scripts/check-repo.sh all

## links: verify every relative Markdown link resolves on disk
links:
	@scripts/check-repo.sh links

## lint: run shellcheck on scripts/*.sh, install.sh, and .claude/skills/*/*.sh
lint:
	@scripts/check-repo.sh lint

## readme: verify README.md indexes every content file and vice-versa
readme:
	@scripts/check-repo.sh readme

## language: verify no German prose outside the allow-listed files
language:
	@scripts/check-repo.sh language

## skills: verify .claude/skills/README.md indexes every SKILL.md directory and vice-versa
skills:
	@scripts/check-repo.sh skills

## compose: verify every templates/docker-compose*.yml passes `docker compose config -q`
compose:
	@scripts/check-repo.sh compose

## plugin: verify the plugin manifests pass `claude plugin validate .`
plugin:
	@scripts/check-repo.sh plugin

## prose: verify Markdown meets the output-style caps (paragraph length, sentence length)
prose:
	@scripts/check-repo.sh prose

## test-prune: run the fixture test for the prune skill's prune-state.sh
test-prune:
	@scripts/test-prune.sh

## test-agent-bus: run the fixture test for scripts/agent-bus.sh
test-agent-bus:
	@scripts/test-agent-bus.sh

## help: list available targets
help:
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/^## //'
