# Downstream Stack Registry

This file lists all application stacks connected to the elabs-proxy platform.

Update it each time you add, modify, or remove a stack using `make stack-add`.

---

## Connected stacks

| Stack | URL | Mode | OIDC | Metrics | Notes |
|-------|-----|------|------|---------|-------|
| *(none yet)* | — | — | — | — | Add your first stack with `make stack-add` |

---

## Usage

```bash
# Register a new stack interactively
make stack-add STACK=myapp PORT=8080 MODE=subdomain

# Check a stack's connection status
make stack-check STACK=myapp

# View this registry
make stack-list
```

---

## Column guide

| Column | Values | Meaning |
|--------|--------|---------|
| Stack | name | Container / service name used in Docker and nginx |
| URL | `https://…` | Public entry point after SWAG routing |
| Mode | `subdomain` / `subfolder` | How the stack is exposed |
| OIDC | ✅ / ⏳ / ❌ | Authentication status: protected / pending / none |
| Metrics | ✅ / ❌ | Whether a Prometheus target is active |
| Notes | free text | Repo link, deployment notes, caveats |

---

## Example entry

```markdown
| geostack | https://tennisme.example.com | subdomain | ✅ | ✅ | [repo](../appli/geostack) — geospatial stack |
```
