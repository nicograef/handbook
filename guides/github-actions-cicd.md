# GitHub Actions CI/CD

Reusable workflow patterns for full-stack projects.

## Java + Maven CI

```yaml
backend-ci:
  runs-on: ubuntu-latest
  defaults:
    run:
      working-directory: ./backend
  steps:
    - uses: actions/checkout@v5

    - uses: actions/setup-java@v4
      with:
        distribution: temurin
        java-version: 21
        cache: maven

    - name: Build and test
      run: ./mvnw verify -B
```

`./mvnw verify` runs compile + Spotless + Checkstyle + tests in one step.

## Node.js + pnpm CI

```yaml
frontend-ci:
  runs-on: ubuntu-latest
  defaults:
    run:
      working-directory: ./frontend
  steps:
    - uses: actions/checkout@v5

    - uses: pnpm/action-setup@v4
      with:
        version: 10
        run_install: false

    - uses: actions/setup-node@v6
      with:
        node-version: 24
        cache: pnpm
        cache-dependency-path: frontend/pnpm-lock.yaml

    - run: pnpm install --frozen-lockfile
    - run: pnpm run lint
    - run: pnpm run build
    - run: pnpm run test
```

## AWS CDK Deploy via OIDC

Uses short-lived credentials via GitHub's OIDC provider — no long-lived secrets needed.

```yaml
deploy:
  needs: [backend-ci, frontend-ci]
  runs-on: ubuntu-latest
  permissions:
    id-token: write   # required for OIDC
    contents: read
  steps:
    - uses: actions/checkout@v5

    - uses: aws-actions/configure-aws-credentials@v4
      with:
        role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
        aws-region: eu-central-1

    # build artifacts...

    - run: cd infra && npm ci && npx cdk deploy --all -c stage=dev --require-approval never
```

Prerequisites:
1. Create an IAM OIDC identity provider for `token.actions.githubusercontent.com`
2. Create an IAM role that trusts the GitHub OIDC provider
3. Store the role ARN as `AWS_ROLE_ARN` in GitHub repo secrets

## Tag-Based Production Deploy

Trigger production deploys by pushing a tag:

```yaml
name: Deploy Prod

on:
  push:
    tags:
      - "prod-*"

jobs:
  deploy:
    # same steps as dev, but with -c stage=prod
```

Release from the command line:

```bash
# Makefile target
prod-release:
	@BRANCH=$$(git rev-parse --abbrev-ref HEAD); \
	if [ "$$BRANCH" != "main" ]; then echo "Error: must be on main"; exit 1; fi
	@TAG=prod-$$(date +%Y%m%d-%H%M) && \
	git tag $$TAG && git push origin $$TAG && \
	echo "Pushed tag $$TAG — prod deploy triggered"
```

## CI on Pull Requests + Push

```yaml
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
```

## Parallel Jobs

Run backend and frontend CI in parallel, then deploy only if both pass:

```yaml
jobs:
  backend-ci:  # ...
  frontend-ci: # ...
  deploy:
    needs: [backend-ci, frontend-ci]
```

## Caching

| Tool | Cache Config |
| ---- | ----------- |
| Maven | `cache: maven` in `actions/setup-java` |
| pnpm | `cache: pnpm` + `cache-dependency-path` in `actions/setup-node` |
| npm | `cache: npm` in `actions/setup-node` |
