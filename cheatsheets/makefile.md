# Makefile

## Syntax

```makefile
target: prerequisites
	command              # ← must be a TAB, not spaces

.PHONY: target           # declare non-file targets
```

## Escaping

```makefile
# dollar signs must be doubled in Makefiles
BRANCH := $$(git rev-parse --abbrev-ref HEAD)
echo "$$HOME"
```

See [templates/Makefile](../templates/Makefile) for a full-stack project template.
