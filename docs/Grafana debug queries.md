# Grafana Debug Queries (Loki / Prometheus)

This document provides a curated set of **production-ready queries** to debug:

- Reverse proxy (NGINX / SWAG)
- Authentication flows (OAuth2 Proxy + Keycloak)
- Header propagation issues
- Service health & observability gaps

It updates the earlier query set to match the **actual labels present in the stack**:
- `stack="zone-proxy"`
- `service="..."`

---

# Quick validation checklist

Before using the dashboard or advanced drilldowns, validate Loki ingestion with these queries.

## 1. Check that Loki receives logs from the stack
```logql
{stack="zone-proxy"}
```

## 2. Check log distribution by service
```logql
sum by (service) (count_over_time({stack="zone-proxy"}[5m]))
```

## 3. Check SWAG logs
```logql
{stack="zone-proxy", service="swag"}
```

## 4. Check oauth2-proxy logs
```logql
{stack="zone-proxy", service="oauth2-proxy"}
```

## 5. Check Keycloak logs
```logql
{stack="zone-proxy", service="keycloak"}
```

## 6. Check the full critical access chain
```logql
{stack="zone-proxy", service=~"swag|oauth2-proxy|keycloak|keycloak-postgresql"}
```

---

# 1. SWAG / Reverse Proxy Debug

## SWAG — auth / headers / upstream
```logql
{stack="zone-proxy", service="swag"} |~ "(auth request|upstream|invalid host|header)"
```

## SWAG — 4xx / 5xx responses
```logql
{stack="zone-proxy", service="swag"} |~ " [45][0-9]{2} "
```

## SWAG — OIDC canary flow
```logql
{stack="zone-proxy", service="swag"} |= "/oidc-canary/"
```

## SWAG — oauth2 endpoints
```logql
{stack="zone-proxy", service="swag"} |= "/oauth2/"
```

## SWAG — all recent errors
```logql
{stack="zone-proxy", service="swag"} |= "error"
```

## SWAG — upstream incidents only
```logql
{stack="zone-proxy", service="swag"} |= "upstream"
```

## SWAG — auth request failures
```logql
{stack="zone-proxy", service="swag"} |= "auth request"
```

---

# 2. OAuth2 Proxy Debug

## All oauth2-proxy logs
```logql
{stack="zone-proxy", service="oauth2-proxy"}
```

## oauth2-proxy — errors
```logql
{stack="zone-proxy", service="oauth2-proxy"} |= "error"
```

## oauth2-proxy — sessions / callbacks / redirects
```logql
{stack="zone-proxy", service="oauth2-proxy"} |~ "(session|cookie|redirect|callback)"
```

## oauth2-proxy — startup / configuration issues
```logql
{stack="zone-proxy", service="oauth2-proxy"} |~ "(invalid configuration|cookie_secret|configuration)"
```

## oauth2-proxy — header-related issues
```logql
{stack="zone-proxy", service="oauth2-proxy"} |~ "(header|X-Forwarded)"
```

---

# 3. Keycloak Debug

## All Keycloak logs
```logql
{stack="zone-proxy", service="keycloak"}
```

## Keycloak — authentication flow issues
```logql
{stack="zone-proxy", service="keycloak"} |= "authentication"
```

## Keycloak — Google identity provider issues
```logql
{stack="zone-proxy", service="keycloak"} |= "identity_provider"
```

## Keycloak — federated login errors
```logql
{stack="zone-proxy", service="keycloak"} |= "FEDERATED_IDENTITY"
```

## Keycloak — required actions / TOTP / verify email
```logql
{stack="zone-proxy", service="keycloak"} |~ "(required action|CONFIGURE_TOTP|VERIFY_EMAIL)"
```

## Keycloak — OAuth callback failures
```logql
{stack="zone-proxy", service="keycloak"} |= "oauth"
```

---

# 4. Full OIDC Flow Correlation

## Step 1 — user hits protected resource
```logql
{stack="zone-proxy", service="swag"} |= "/oidc-canary/"
```

## Step 2 — redirect to oauth2
```logql
{stack="zone-proxy", service="swag"} |= "/oauth2/start"
```

## Step 3 — oauth2-proxy activity
```logql
{stack="zone-proxy", service="oauth2-proxy"}
```

## Step 4 — Keycloak authentication
```logql
{stack="zone-proxy", service="keycloak"}
```

Use the **same narrow timestamp window** to correlate the three services.

---

# 5. Header Debugging

## SWAG — forwarded headers / header-related incidents
```logql
{stack="zone-proxy", service="swag"} |~ "(X-Forwarded|header|invalid host)"
```

## oauth2-proxy — forwarded header issues
```logql
{stack="zone-proxy", service="oauth2-proxy"} |~ "(header|X-Forwarded)"
```

---

# 6. Useful Time Series Queries

## SWAG — 401 trend
```logql
sum(count_over_time({stack="zone-proxy", service="swag"} |= " 401 " [5m]))
```

## SWAG — 5xx trend
```logql
sum(count_over_time({stack="zone-proxy", service="swag"} |~ " 5[0-9]{2} " [5m]))
```

## SWAG — oauth2 hit rate
```logql
sum(count_over_time({stack="zone-proxy", service="swag"} |= "/oauth2/" [5m]))
```

## SWAG — canary hit rate
```logql
sum(count_over_time({stack="zone-proxy", service="swag"} |= "/oidc-canary/" [5m]))
```

## Full access chain volume
```logql
sum by (service) (count_over_time({stack="zone-proxy", service=~"swag|oauth2-proxy|keycloak|keycloak-postgresql"}[5m]))
```

---

# 7. Prometheus Health Queries

## All targets status
```promql
up
```

## Failing targets only
```promql
up == 0
```

## Prometheus self health
```promql
up{job="prometheus"}
```

## Loki health
```promql
up{job=~"loki|loki.*"}
```

## Alloy health
```promql
up{job="alloy"}
```

---

# 8. Live Debug Workflow

Recommended order when debugging:

1. Start with:
```logql
{stack="zone-proxy", service="swag"}
```

2. Narrow by endpoint:
```logql
|= "/oauth2/"
```
or
```logql
|= "/oidc-canary/"
```

3. Correlate with:
- oauth2-proxy logs
- Keycloak logs

4. Narrow down further by:
- timestamp
- endpoint
- HTTP status
- auth flow event

---

# 9. Bonus: Known oauth2-proxy configuration pitfall

If you see logs like:

```text
invalid configuration:
cookie_secret must be 16, 24, or 32 bytes to create an AES cipher, but is 44 bytes
```

The cookie secret is invalid for AES.

Use a cookie secret that decodes to a valid AES key length:
- 16 bytes
- 24 bytes
- 32 bytes

Typical fix:
- generate a proper secret
- update the environment variable
- restart oauth2-proxy

---

# 10. Observability Best Practices

- Always correlate:
  - SWAG → oauth2-proxy → Keycloak
- Use **short time windows (5–15 min)** while debugging
- Prefer **focused selectors by `stack` + `service`**
- Build dashboards around:
  - auth failures
  - upstream incidents
  - callback / redirect activity
  - critical service log volume

---

# Summary

These queries cover:

- Reverse proxy debugging
- OIDC authentication chain
- Header propagation issues
- Service health monitoring
- Known oauth2-proxy startup misconfiguration

They are designed to be:

- Minimal
- Readable
- Production-ready
- Aligned with the actual labels used by the stack