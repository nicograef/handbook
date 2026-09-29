# Deploy

First deploy of a web app with TLS and a reverse proxy on a provisioned VPS.

## Prerequisites

- The server passes [provision-server.md#verify](provision-server.md#verify).
- Point DNS at the VPS first.

## First deploy

1. **Deploy TLS + reverse proxy** (web app only).
   First deploy: [scripts/prod-init.sh](../scripts/prod-init.sh) with the production Compose template of the
   [chosen variant](letsencrypt-docker.md#pick-a-variant), copied to `docker-compose.prod.yml`.

## Verify

Then [letsencrypt-docker.md](letsencrypt-docker.md#verify) to verify and troubleshoot the certs.
