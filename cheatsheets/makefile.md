# Makefile

## Escaping

```makefile
# In a recipe, $$ escapes the $ so the shell expands it, not make.
release:
	@BRANCH=$$(git rev-parse --abbrev-ref HEAD); echo "on $$BRANCH"

# Capturing shell output into a make variable needs $(shell ...).
# `VAR := $$(cmd)` stores the literal text instead, so ifeq and $(filter ...)
# never see the output.
VERSION := $(shell git describe --tags --always)
```

See [templates/Makefile](../templates/Makefile) for a full-stack project template.
