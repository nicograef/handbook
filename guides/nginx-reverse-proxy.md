# Nginx Reverse Proxy (HTTPS + SPA)

Production nginx config for TLS termination, API proxying, and SPA hosting.

## Prerequisites

- Docker + Compose installed, with a reverse-proxy service (see
  [templates/docker-compose.prod.yml](../templates/docker-compose.prod.yml)).
- A TLS certificate already issued (see [guides/letsencrypt-docker.md](letsencrypt-docker.md)).

## Full Config

See [templates/nginx-tls.conf](../templates/nginx-tls.conf) for the copy-paste-ready config. It
already covers the HTTP→HTTPS redirect + ACME challenge, the www→non-www redirect, TLS session
settings, security headers, and API rate limiting — adapt those there, not here.

## Key Patterns

These two patterns are not in the reverse-proxy template because they belong in the **frontend**
nginx that serves the SPA directly.

### SPA Client-Side Routing

When the frontend nginx serves a single-page app directly (no separate reverse proxy), fall back to
`index.html` so client-side routes resolve:

```nginx
location / {
  root /usr/share/nginx/html;
  try_files $uri $uri/ /index.html;
}
```

### Static Asset Caching

For Vite/Webpack builds with hashed filenames, cache aggressively:

```nginx
location ~* \.(?:ico|css|js|gif|jpe?g|png|svg|woff2?)$ {
  expires 1y;
  add_header Cache-Control "public, immutable";
  try_files $uri $uri/ =404;
}
```

## Verify

```bash
# check config syntax inside container
docker exec <nginx-container> nginx -t

# verify headers (expect Strict-Transport-Security + HTTP/2)
curl -I https://example.com

# test TLS grade
# https://www.ssllabs.com/ssltest/
```

## Troubleshooting

```bash
# 502 Bad Gateway — backend not reachable
# → Check if the backend container is running: docker compose ps
# → Verify the proxy_pass hostname matches the Compose service name
# → Ensure both containers share the same Docker network

# SSL certificate not found / nginx won't start
# → Check cert paths: ls /etc/letsencrypt/live/<domain>/
# → First-time setup? Run cert request first (see letsencrypt-docker.md)

# Mixed content warnings (HTTPS page loads HTTP resources)
# → Ensure proxy_set_header X-Forwarded-Proto $scheme; is set
# → Check app is reading the X-Forwarded-Proto header

# "too many redirects"
# → HTTP→HTTPS redirect loop. Check that the backend isn't also redirecting.
# → Verify listen 80 block only handles ACME + redirect, nothing else.
```

---

See also:
- [templates/nginx-tls.conf](../templates/nginx-tls.conf) — full nginx TLS config template
- [guides/letsencrypt-docker.md](letsencrypt-docker.md) — TLS certificate setup
- [templates/docker-compose.prod.yml](../templates/docker-compose.prod.yml) — production Compose with nginx
