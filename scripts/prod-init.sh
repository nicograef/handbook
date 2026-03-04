#!/usr/bin/env bash
# prod-init.sh — First-time production deployment
#
# Automates: prerequisite checks → certificate request → full stack start.
#
# Usage:
#   make prod-init                          (uses defaults, prompts for email)
#   DOMAIN=example.com EMAIL=you@example.com make prod-init
#
# Prerequisites:
#   1. DNS A record pointing to this server's IP
#   2. .env file with POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB
#   3. Docker + Compose installed
set -euo pipefail

# ── Configuration ──
DOMAIN="${DOMAIN:-example.com}"
EMAIL="${EMAIL:-}"
PROJECT="${PROJECT:-myapp}"   # Docker Compose project name (for volume prefixes)
COMPOSE_CERT="docker compose -f docker-compose.initial-cert.yml"
COMPOSE_PROD="docker compose -f docker-compose.prod.yml"

# ── Colors ──
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ── Prerequisite Checks ──
info "Checking prerequisites…"

[[ -f .env ]] || error ".env file not found. Copy .env.example and fill in your credentials."

source .env
[[ -n "${POSTGRES_USER:-}" ]]     || error "POSTGRES_USER not set in .env"
[[ -n "${POSTGRES_PASSWORD:-}" ]] || error "POSTGRES_PASSWORD not set in .env"
[[ -n "${POSTGRES_DB:-}" ]]       || error "POSTGRES_DB not set in .env"

command -v docker >/dev/null 2>&1      || error "docker is not installed."
docker compose version >/dev/null 2>&1 || error "docker compose plugin is not installed."

if [[ -z "$EMAIL" ]]; then
  read -rp "$(echo -e "${YELLOW}Enter email for Let's Encrypt notifications:${NC} ")" EMAIL
  [[ -n "$EMAIL" ]] || error "Email is required for Let's Encrypt registration."
fi

info "Domain:  $DOMAIN"
info "Email:   $EMAIL"
info "Project: $PROJECT"
echo ""

# ── Check if certificate already exists ──
CERT_VOLUME="${PROJECT}_letsencrypt"
if docker volume inspect "$CERT_VOLUME" >/dev/null 2>&1; then
  if docker run --rm -v "$CERT_VOLUME":/letsencrypt alpine \
    test -f "/letsencrypt/live/$DOMAIN/fullchain.pem" 2>/dev/null; then
    warn "Certificate for $DOMAIN already exists."
    read -rp "Skip certificate step and start the stack? [Y/n] " SKIP
    if [[ "${SKIP,,}" != "n" ]]; then
      info "Starting full production stack…"
      $COMPOSE_PROD up --build -d
      info "Production stack is running."
      exit 0
    fi
  fi
fi

# ── Step 1: Start minimal nginx for ACME challenges ──
info "Step 1/3 — Starting nginx for ACME challenge…"
$COMPOSE_CERT up -d reverse-proxy
sleep 2

for i in {1..15}; do
  if docker exec "${PROJECT}-reverse-proxy" nginx -t >/dev/null 2>&1; then
    break
  fi
  if [[ $i -eq 15 ]]; then
    $COMPOSE_CERT down
    error "Nginx did not become ready in time."
  fi
  sleep 1
done
info "Nginx is ready."

# ── Step 2: Request certificate via certbot ──
info "Step 2/3 — Requesting Let's Encrypt certificate…"
docker run --rm \
  -v "${PROJECT}_certbot-challenges:/var/www/certbot" \
  -v "${PROJECT}_letsencrypt:/etc/letsencrypt" \
  certbot/certbot:v2.11.0 \
  certonly \
    --webroot -w /var/www/certbot \
    -d "$DOMAIN" -d "www.$DOMAIN" \
    --email "$EMAIL" \
    --agree-tos \
    --non-interactive

if [[ $? -ne 0 ]]; then
  $COMPOSE_CERT down
  error "Certbot failed. Check that DNS for $DOMAIN points to this server."
fi
info "Certificate obtained successfully."

# ── Step 3: Tear down cert stack, start full production stack ──
info "Step 3/3 — Starting full production stack…"
$COMPOSE_CERT down
$COMPOSE_PROD up --build -d

echo ""
info "=========================================="
info "  Production deployment complete!"
info "  https://$DOMAIN"
info "=========================================="
info ""
info "Useful commands:"
info "  make prod-logs   — follow logs"
info "  make prod-down   — stop the stack"
