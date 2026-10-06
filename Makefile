.PHONY: check links lint readme language skills compose prose history contracts test-agent-bus test-plan-run-guard test-git-guard test-report-health test-dockerfiles help

## check: run the full repo self-check (links, shellcheck, README index, language, skills, compose, prose, history words, contracts)
check:
	@scripts/check-repo.sh all

## links: verify every relative Markdown link resolves on disk, #anchors included (GitHub heading slugs)
links:
	@scripts/check-repo.sh links

## lint: run shellcheck on every tracked shell script
lint:
	@scripts/check-repo.sh lint

## readme: verify README.md indexes every content file and vice-versa, and every top-level folder is indexed or excluded
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

## prose: verify Markdown meets the prose caps (sentence ≤ 20 words, paragraph ≤ 3 lines)
prose:
	@scripts/check-repo.sh prose

## history: verify Markdown prose holds no history words (previously, formerly, deprecated, no longer, used to)
history:
	@scripts/check-repo.sh history

## contracts: verify handbook raw URLs name tracked paths, install-dotfiles.sh --check passes, and settings script paths exist
contracts:
	@scripts/check-repo.sh contracts

## test-agent-bus: run the fixture test for scripts/agent-bus.sh
test-agent-bus:
	@scripts/test-agent-bus.sh

## test-plan-run-guard: run the fixture test for scripts/plan-run-guard.sh
test-plan-run-guard:
	@scripts/test-plan-run-guard.sh

## test-git-guard: run the fixture test for scripts/git-guard.sh
test-git-guard:
	@scripts/test-git-guard.sh

## test-report-health: run the fixture test for scripts/report-health.sh
test-report-health:
	@scripts/test-report-health.sh

## test-dockerfiles: build the three Dockerfile templates against stub apps and wait for healthy (needs Docker and network)
test-dockerfiles:
	@scripts/test-dockerfiles.sh

## help: list available targets
help:
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/^## //'
