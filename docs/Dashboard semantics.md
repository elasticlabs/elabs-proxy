# Dashboard Semantics and Confidence Model

This chapter documents the semantic choices used in the **Zone Proxy Operations** dashboard.

## Goal

The layout of the dashboard is intentionally kept stable. The work in this iteration focuses on **meaning**, **signal quality**, and **operator trust**.

The dashboard should answer four questions quickly:

* Is the platform up?
* Is the host healthy?
* Is there an active incident?
* Is the absence of data expected, or is it a problem?

## Core Principle

A panel should never create avoidable doubt.

For that reason, the dashboard avoids misleading empty states and distinguishes between:

* **UP**
* **DOWN**
* **UNSTABLE**
* **NO DATA**

## Status Tile Semantics

Service tiles use a common pattern.

### Query pattern

For Prometheus-scraped targets:

```promql
(avg_over_time(up{job="<job>"}[2m])) OR on() vector(-1)
```

For container-presence targets:

```promql
max(((time() - container:last_seen:timestamp{name=~"<regex>"}) < 120)) OR on() vector(-1)
```

### Meaning of values

| Value         | Meaning                             |
| ------------- | ----------------------------------- |
| `1`           | Healthy and stable                  |
| `0 < x < 0.9` | Unstable, intermittent, or flapping |
| `0`           | Down                                |
| `-1`          | No data available                   |

### Visual mapping

| State    | Color  | Meaning                                        |
| -------- | ------ | ---------------------------------------------- |
| NO DATA  | Gray   | Missing telemetry, not automatically a failure |
| DOWN     | Red    | Explicit failure                               |
| UNSTABLE | Orange | Partial availability or flapping               |
| UP       | Green  | Healthy                                        |

This avoids false red panels when a metric is simply absent.

## Activity Panels

Panels such as **Zone logs / min**, **Critical path logs / min**, and **Service graph req/s** are forced to return a value even when no signal exists yet.

Examples:

```logql
sum(count_over_time({stack="$stack"}[1m])) or vector(0)
```

```promql
sum(rate(traces_service_graph_request_total[5m])) OR vector(0)
```

This ensures that:

* no panel appears empty,
* low activity is represented as `0`,
* the operator can distinguish inactivity from failure.

## Host Vitals

Host metrics also use a safe fallback:

```promql
node:cpu_usage:avg5m OR vector(0)
```

This is not meant to hide broken telemetry. It is meant to avoid distracting empty panels during transient startup or scrape delays.

## Why This Matters

A dashboard is trusted when it is semantically consistent.

A red panel should mean:

* something is broken,

not:

* a query returned nothing,
* a target has not been scraped yet,
* a trace feature is simply not enabled.

## Specific Choice for Traces

Tracing is prepared in Phase 1 but not fully active yet.

Because of that:

* the **Service graph request rate** panel is kept in place,
* but its query falls back to `0`,
* so the panel expresses **"no traces yet"** instead of presenting an alarming empty state.

This preserves the future structure of the dashboard while keeping the current meaning honest.

## Dashboard Design Rule

The dashboard layout is intentionally preserved.

Changes in this iteration should only improve:

* semantic clarity,
* resilience to missing data,
* operator confidence.

The visual structure should remain stable so that Phase 2 can build on the same operational habits.
