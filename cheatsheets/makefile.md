# Makefile

## Syntax

```makefile
target: prerequisites
	command              # ← must be a TAB, not spaces

.PHONY: target           # declare non-file targets
```

## Escaping

```makefile
# In a recipe, $$ escapes the $ so the shell expands it, not make.
release:
	@BRANCH=$$(git rev-parse --abbrev-ref HEAD); echo "on $$BRANCH"
	@echo "$$HOME"

# Capturing shell output into a make variable needs $(shell ...).
# `VAR := $$(cmd)` stores the literal text instead, so ifeq and $(filter ...)
# never see the output.
VERSION := $(shell git describe --tags --always)
```

See [templates/Makefile](../templates/Makefile) for a full-stack project template.
