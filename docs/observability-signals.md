# Observability Signals & Query Model

## Goal

Unify logs, metrics, and traces across the stack to enable:
- fast debugging
- cross-signal correlation
- reliable dashboards

---

## Shared Labels (MANDATORY)

All signals must expose:

- stack: zone-proxy
- service: (swag, oauth2-proxy, keycloak, grafana, etc.)
- env: dev|prod
- level: info|warn|error

Optional:
- route
- status
- method
- trace_id

---

## Logs (Loki)

### Base query
{stack="zone-proxy"}

### Errors
{stack="zone-proxy"} |= "error"

### Auth issues
{service="oauth2-proxy"} |= "401"
{service="swag"} |= "auth request"

### Rate
sum(rate({stack="zone-proxy"}[1m]))

---

## Metrics (Prometheus)

### Service health
avg_over_time(up{job=~".*"}[2m]) OR vector(-1)

### Error rate
sum(rate(http_requests_total{status=~"5.."}[5m])) 
/
sum(rate(http_requests_total[5m]))

---

## Traces (Tempo)

### Throughput
sum(rate(traces_service_graph_request_total[5m])) OR vector(0)

### Errors
sum(rate(traces_spanmetrics_calls_total{status_code="STATUS_CODE_ERROR"}[5m]))

---

## Correlation

- Logs → traces via trace_id
- Metrics → logs via service label
- Traces → metrics via service graph

---

## Key Principle

NO DATA ≠ ERROR

Always fallback:
- logs: vector(0)
- metrics: OR vector(0)
