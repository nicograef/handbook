# Makefile

## Syntax

```makefile
target: prerequisites
	command              # ← must be a TAB, not spaces

.PHONY: target           # declare non-file targets
```

## Variables

```makefile
APP_NAME := myapp                          # simple assignment
VERSION  ?= $(shell git describe --tags)   # ?= only if not already set
GO_FILES := $(shell find . -name '*.go')   # shell command

# use variables
build:
	go build -ldflags "-X main.version=$(VERSION)" -o $(APP_NAME)
```

## .env Loading

```makefile
include .env
export

db-shell:
	docker compose exec postgres psql -U $(POSTGRES_USER) -d $(POSTGRES_DB)
```

## Pattern Rules

```makefile
# build any .o from matching .c
%.o: %.c
	$(CC) -c $< -o $@

# $@ = target, $< = first prerequisite, $^ = all prerequisites
```

## Common Patterns

```makefile
.DEFAULT_GOAL := help

.PHONY: help
help:          ## Show this help
	@grep -hE '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) | \
	  awk 'BEGIN {FS = ":.*## "} {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
```

```makefile
# multi-line command (single shell)
deploy:
	@TAG=prod-$$(date +%Y%m%d-%H%M) && \
	git tag $$TAG && git push origin $$TAG
```

```makefile
# conditional
check:
ifdef CI
	go test -v ./...
else
	go test ./...
endif
```

## Useful Flags

```bash
make -n target         # dry-run (print commands, don't execute)
make -j4               # parallel execution (4 jobs)
make -B target         # force rebuild (ignore timestamps)
make VAR=value target  # override variable from CLI
make -f alt.mk target  # use alternate Makefile
```

## Escaping

```makefile
# dollar signs must be doubled in Makefiles
BRANCH := $$(git rev-parse --abbrev-ref HEAD)
echo "$$HOME"
```

See [templates/Makefile](../templates/Makefile) for a full-stack project template.
