# Stages are the check_<stage> functions in scripts/check-repo.sh; `make help` prints their ## lines.
STAGES := $(shell sed -n 's/^check_\([a-z]*\)() {$$/\1/p' scripts/check-repo.sh)
TESTS := $(filter-out test-dockerfiles,$(basename $(notdir $(wildcard scripts/test-*.sh))))

.PHONY: check test help $(STAGES)

## check: run every repo self-check stage listed below
check:
	@scripts/check-repo.sh all

$(STAGES):
	@scripts/check-repo.sh $@

## test: run every scripts/test-*.sh fixture test except test-dockerfiles
test: $(TESTS)

## test-<name>: run scripts/test-<name>.sh alone; test-dockerfiles builds the Dockerfile templates (needs Docker and network)
test-%:
	@scripts/$@.sh

## help: list available targets
help:
	@grep -hE '^## ' $(MAKEFILE_LIST) scripts/check-repo.sh | sed 's/^## //'
