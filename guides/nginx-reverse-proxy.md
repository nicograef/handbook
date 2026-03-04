# Nginx Reverse Proxy (HTTPS + SPA)

Production nginx config for TLS termination, API proxying, and SPA hosting.

## Full Config

See [templates/nginx-tls.conf](../templates/nginx-tls.conf) for the copy-paste-ready config.

## Key Patterns

### HTTP → HTTPS Redirect + ACME Challenges

```nginx
server {
  listen 80;
  server_name example.com www.example.com;

  # Let's Encrypt renewal
  location /.well-known/acme-challenge/ {
    root /var/www/certbot;
  }

  location / {
    return 301 https://$host$request_uri;
  }
}
```

### www → non-www Redirect

```nginx
server {
  listen 443 ssl;
  http2 on;
  server_name www.example.com;

  ssl_certificate     /etc/letsencrypt/live/example.com/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;

  return 301 https://example.com$request_uri;
}
```

### TLS Best Practices

```nginx
ssl_session_timeout 1d;
ssl_session_cache   shared:MozSSL:10m;
ssl_protocols       TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers off;
```

### Security Headers

```nginx
add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
add_header X-Content-Type-Options    nosniff always;
add_header X-Frame-Options           DENY always;
add_header Referrer-Policy           no-referrer-when-downgrade always;
```

### API Rate Limiting

```nginx
# top-level (outside server block)
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;

# inside location block
location /api/ {
  limit_req zone=api_limit burst=20 nodelay;
  limit_req_status 429;

  proxy_pass http://backend:8080/api/;
  proxy_set_header Host              $host;
  proxy_set_header X-Real-IP         $remote_addr;
  proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
  proxy_set_header X-Forwarded-Proto $scheme;
}
```

### SPA Client-Side Routing

When the frontend nginx serves a single-page app directly (no separate reverse proxy):

```nginx
location / {
  root /usr/share/nginx/html;
  try_files $uri $uri/ /index.html;
}
```

### Static Asset Caching

For Vite/Webpack builds with hashed filenames:

```nginx
location ~* \.(?:ico|css|js|gif|jpe?g|png|svg|woff2?)$ {
  expires 1y;
  add_header Cache-Control "public, immutable";
  try_files $uri $uri/ =404;
}
```

## Testing

```bash
# check config syntax inside container
docker exec <nginx-container> nginx -t

# test TLS grade
# https://www.ssllabs.com/ssltest/

# verify headers
curl -I https://example.com
```
