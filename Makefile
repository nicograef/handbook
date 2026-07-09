# Handbook dev interface. `make check` is the full repo self-check.

.PHONY: check links lint readme language help

## check: run the full repo self-check (links, shellcheck, README index, language)
check:
	@scripts/check-repo.sh all

## links: verify every relative Markdown link resolves on disk
links:
	@scripts/check-repo.sh links

## lint: run shellcheck on scripts/*.sh and install.sh
lint:
	@scripts/check-repo.sh lint

## readme: verify README.md indexes every content file and vice-versa
readme:
	@scripts/check-repo.sh readme

## language: verify no German prose outside the allow-listed files
language:
	@scripts/check-repo.sh language

## help: list available targets
help:
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/^## //'
