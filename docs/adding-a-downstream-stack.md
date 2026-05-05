# Adding a downstream stack

This guide walks through the complete process of connecting a new application stack to the elabs-proxy platform.

Each downstream stack lives in its own Git repository (e.g. `../appli/myapp`) and is kept fully autonomous. This platform provides the shared layer: TLS termination, authentication, observability, and DNS routing.

---

## Prerequisites

Before starting, confirm:

- The elabs-proxy platform is running (`make up` completed successfully)
- The `revproxy_apps` network exists (`docker network ls | grep revproxy`)
- Your downstream repository starts independently (`docker compose up -d` in its own folder)
- You have identified the container name and HTTP port of the main entry point

---

## Quickstart

```bash
# From the elabs-proxy directory
make stack-add STACK=myapp PORT=8080 MODE=subdomain
```

This single command scaffolds:
- an nginx site conf at `swag/config/nginx/site-confs/myapp.subdomain.conf`
- a Prometheus target file at `grafana/prometheus/targets/downstream/myapp.yml`

Then follow the printed next-steps checklist.

Use `make stack-check STACK=myapp` at any point to verify the connection state.

---

## Step-by-step

### 1. Run `make stack-add`

```bash
make stack-add STACK=myapp PORT=8080 [MODE=subdomain|subfolder]
```

**MODE choices:**

| Mode | When to use | Result |
|------|-------------|--------|
| `subdomain` | Real application with its own identity | `https://myapp.YOUR_DOMAIN` |
| `subfolder` | Admin/support tool tightly coupled to the platform | `https://labs.YOUR_DOMAIN/myapp/` |

For most downstream applications, use `subdomain` (the default).

---

### 2. Connect the container to the shared network

In your downstream `docker-compose.yml`, add to each service that SWAG needs to reach:

```yaml
services:
  myapp:
    image: your-image:tag
    expose:
      - "8080"            # do NOT use `ports` — SWAG handles public ingress
    labels:
      obs.stack: myapp    # must match STACK value used in make stack-add
      obs.service: myapp
      obs.domain: labs    # labs | admin
      obs.role: api       # api | frontend | worker | db | ...
      obs.env: prod
    networks:
      - revproxy_apps

networks:
  revproxy_apps:
    external: true
```

See `stacks/templates/docker-compose.fragment.yml` for a complete annotated example.

Restart the downstream stack after editing:

```bash
docker compose up -d
```

---

### 3. Verify the DNS record (subdomain mode only)

Add an A record pointing the new subdomain to your server:

| Type | Name | Value |
|------|------|-------|
| A | `myapp` | server IP |

Validate: `dig myapp.YOUR_DOMAIN +short`

---

### 4. Review and activate the nginx conf

The scaffolded conf is ready to use but contains placeholders worth reviewing:

```bash
# Subdomain mode
cat swag/config/nginx/site-confs/myapp.subdomain.conf

# Subfolder mode (auto-included by labs.YOUR_DOMAIN)
cat swag/config/nginx/client-stacks/myapp.conf
```

By default the conf exposes the route without authentication. This is intentional — validate routing first before adding OIDC.

Reload SWAG to activate:

```bash
docker compose exec swag nginx -t
docker compose exec swag nginx -s reload
```

Confirm the route is reachable with a plain `curl` or browser request.

---

### 5. Configure metrics (optional)

If your service exposes a `/metrics` (Prometheus) endpoint, update the scaffolded target file:

```bash
# Edit the generated target file
vi grafana/prometheus/targets/downstream/myapp.yml
```

Replace the placeholder port with the real metrics port. Prometheus auto-discovers new files within 60 seconds — no restart needed.

If your service has no metrics endpoint, delete the file:

```bash
rm grafana/prometheus/targets/downstream/myapp.yml
```

---

### 6. Add traces (optional)

If your service is instrumented with OpenTelemetry, point it at the platform collector:

```
OTLP gRPC : alloy:4317
OTLP HTTP  : alloy:4318
```

Set these in your downstream stack's environment variables. No platform config change is needed — Alloy automatically enriches and forwards traces to Tempo.

---

### 7. Add a Homer dashboard entry

Edit `homer/config.yml` and add an entry under the appropriate group:

```yaml
  - name: "Applications"
    icon: "fas fa-cubes"
    items:
      - name: "My App"
        icon: "fa-solid fa-rocket"
        subtitle: "Short description"
        url: "https://myapp.YOUR_DOMAIN/"
```

Homer reloads the config automatically — no restart needed.

---

### 8. Security integration

**Phase 1 style (basic auth — rarely needed at this stage)**

If you need temporary basic auth before OIDC, uncomment in the nginx conf:

```nginx
include /config/nginx/custom/admin-auth.conf;
```

**Phase 2 style (OIDC via Keycloak)**

Follow the canary pattern: always validate OIDC on one route before protecting the whole subdomain.

In the nginx conf, uncomment:

```nginx
location @oauth2_start {
    return 302 /oauth2/start?rd=$scheme://$host$request_uri;
}
```

And in each `location` block you want to protect:

```nginx
include /config/nginx/custom/admin-auth-oidc.conf;
```

Then reload SWAG and test in a private browser window.

Add the new subdomain's callback to Keycloak's `oauth2-proxy` client:

```
https://myapp.YOUR_DOMAIN/oauth2/callback
```

---

### 9. Register the stack

Add a row to `stacks/REGISTRY.md`:

```markdown
| myapp | https://myapp.example.com | subdomain | ⏳ | ✅ | [repo](../appli/myapp) |
```

---

### 10. Full validation

Run the check command to confirm everything is in order:

```bash
make stack-check STACK=myapp
```

Expected output:
- ✔ Container on `revproxy_apps` network
- ✔ Nginx conf found
- ✔ Prometheus target (if metrics available)
- ✔ Homer entry
- ✔ Registered in REGISTRY.md

---

## Observability contract

Every downstream stack should follow this minimum contract so it integrates cleanly with the platform's observability layer.

**Logs** — write to stdout/stderr. Alloy discovers containers automatically via Docker labels and enriches logs with the `obs.*` label set.

**Labels** — the `obs.*` Docker labels are the source of truth for log and metric enrichment:

| Docker label | Observability dimension | Example |
|---|---|---|
| `obs.stack` | Stack name | `tennisme` |
| `obs.service` | Service within the stack | `api` |
| `obs.domain` | Subdomain area | `labs` |
| `obs.role` | Functional role | `api`, `frontend`, `worker` |
| `obs.env` | Environment | `prod` |

**Metrics** — expose a `/metrics` endpoint if possible. Drop a `.yml` file in `grafana/prometheus/targets/downstream/` and Prometheus picks it up within 60 seconds.

**Traces** — emit OTLP to `alloy:4317` (gRPC) or `alloy:4318` (HTTP). The platform handles enrichment and forwarding to Tempo.

---

## Troubleshooting

**502 Bad Gateway**
- Container not on `revproxy_apps` network
- Wrong upstream port in the nginx conf
- Service not running: `docker compose logs myapp`

**SWAG nginx config error**
- Validate first: `docker compose exec swag nginx -T`
- Check logs: `docker compose exec swag sh -c 'tail -30 /config/log/nginx/error.log'`

**OIDC redirect loop**
- Check oauth2-proxy logs: `docker compose logs oauth2-proxy`
- Verify Keycloak redirect URIs include `https://myapp.YOUR_DOMAIN/oauth2/callback`
- See `docs/oidc-and-security-rollout.md` for detailed debug steps

**Metrics not appearing in Grafana**
- Confirm the `.yml` file in `targets/downstream/` has no `.example` suffix
- Check the port is correct: `docker compose exec prometheus wget -qO- http://myapp:PORT/metrics | head`
- Prometheus reload is automatic (60s) — check Prometheus targets page

---

## Reference files

| File | Purpose |
|------|---------|
| `stacks/templates/docker-compose.fragment.yml` | Annotated compose fragment to copy into your stack |
| `stacks/templates/nginx-subdomain.conf.tpl` | Template used by `make stack-add MODE=subdomain` |
| `stacks/templates/nginx-subfolder.conf.tpl` | Template used by `make stack-add MODE=subfolder` |
| `stacks/templates/prometheus-target.yml.tpl` | Template used by `make stack-add` for metrics |
| `grafana/prometheus/targets/downstream/*.example` | Prometheus target format reference |
| `stacks/REGISTRY.md` | Registry of all connected stacks |
| `docs/oidc-and-security-rollout.md` | OIDC configuration and debug guide |
| `docs/observability-architecture.md` | Full observability pipeline documentation |
