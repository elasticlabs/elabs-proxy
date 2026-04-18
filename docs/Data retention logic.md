# Retention Strategy for Grafana Stack (Prometheus, Loki, Tempo, Alloy)

## Overview

When running a full observability stack with **Grafana, Prometheus, Loki, Tempo, and Alloy**, storage usage can grow rapidly if retention policies are not explicitly configured.

This document explains how to **control data retention in a Docker Compose environment** to prevent uncontrolled disk usage.

---

## Key Principles

* **Always set retention limits explicitly** (time and/or size)
* Use **both time-based and size-based limits** when available
* Configure **log rotation at the Docker level**
* Keep retention **short unless you truly need long history**
* Reduce ingestion volume (cardinality, logs, traces) when possible

---

## 1. Prometheus (Metrics)

Prometheus stores time series data locally using its TSDB.

### Recommended settings

* Time retention: `7d` to `30d`
* Size retention: enforce a hard cap (e.g., `10GB–50GB`)

### Docker Compose example

```yaml
prometheus:
  image: prom/prometheus:latest
  command:
    - --config.file=/etc/prometheus/prometheus.yml
    - --storage.tsdb.path=/prometheus
    - --storage.tsdb.retention.time=15d
    - --storage.tsdb.retention.size=20GB
  volumes:
    - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
    - prometheus_data:/prometheus
```

### Notes

* Default retention is **15 days**
* Without `retention.size`, disk usage can still grow dangerously

---

## 2. Loki (Logs)

Loki **does NOT enforce retention by default**. You must explicitly enable it.

### Required configuration

```yaml
compactor:
  working_directory: /loki/compactor
  retention_enabled: true

limits_config:
  retention_period: 168h  # 7 days
```

### Docker Compose example

```yaml
loki:
  image: grafana/loki:latest
  command: -config.file=/etc/loki/loki-config.yml
  volumes:
    - ./loki/loki-config.yml:/etc/loki/loki-config.yml:ro
    - loki_data:/loki
```

### Recommendations

* Start with **7 days**
* Use per-stream retention if needed
* Logs are often the **biggest storage consumer**

---

## 3. Tempo (Traces)

Tempo stores traces in blocks and supports retention via the compactor.

### Configuration

```yaml
compactor:
  compaction:
    block_retention: 48h
```

### Docker Compose example

```yaml
tempo:
  image: grafana/tempo:latest
  command: ["-config.file=/etc/tempo/tempo.yml"]
  volumes:
    - ./tempo/tempo.yml:/etc/tempo/tempo.yml:ro
    - tempo_data:/var/tempo
```

### Recommendations

* Dev: `24h–72h`
* Production: `3d–7d`
* Traces grow fast → keep retention short

---

## 4. Docker Container Logs (Critical!)

Even if Loki is used, Docker still stores logs locally.

Without rotation, this can silently fill your disk.

### Recommended logging config

```yaml
x-logging: &default-logging
  driver: local
  options:
    max-size: "10m"
    max-file: "3"
```

Apply to all services:

```yaml
logging: *default-logging
```

### Why this matters

* Prevents `/var/lib/docker/containers` from growing indefinitely
* Often overlooked → common root cause of disk exhaustion

---

## 5. Grafana

Grafana stores:

* Dashboards
* Users
* Metadata

### Storage impact

* Typically **very small**
* No retention tuning required in most cases

---

## 6. Alloy (Telemetry Agent)

Alloy mainly forwards data and does not store much by default.

### Watch out for

* WAL (write-ahead log)
* File-based storage components

### Recommendation

* Avoid persistent storage unless necessary
* Monitor disk usage if using local buffering

---

## 7. Optional: Mimir (Long-term Metrics Storage)

If using Mimir instead of Prometheus TSDB:

### Retention setting

```yaml
limits:
  compactor_blocks_retention_period: 30d
```

### Important

* Retention is **not enforced unless configured**
* Required for long-term metric storage setups

---

## Suggested Baseline Configuration

| Component  | Retention       |
| ---------- | --------------- |
| Prometheus | 15d + 20GB cap  |
| Loki       | 7d              |
| Tempo      | 48h–72h         |
| Docker     | 10MB × 3 files  |
| Grafana    | Default         |
| Alloy      | Minimal storage |

---

## Example Compose Snippet

```yaml
version: "3.9"

x-logging: &default-logging
  driver: local
  options:
    max-size: "10m"
    max-file: "3"

services:
  prometheus:
    image: prom/prometheus:latest
    command:
      - --storage.tsdb.retention.time=15d
      - --storage.tsdb.retention.size=20GB
    volumes:
      - prometheus_data:/prometheus
    logging: *default-logging

  loki:
    image: grafana/loki:latest
    volumes:
      - loki_data:/loki
    logging: *default-logging

  tempo:
    image: grafana/tempo:latest
    volumes:
      - tempo_data:/var/tempo
    logging: *default-logging

  grafana:
    image: grafana/grafana:latest
    volumes:
      - grafana_data:/var/lib/grafana
    logging: *default-logging

volumes:
  prometheus_data:
  loki_data:
  tempo_data:
  grafana_data:
```

---

## Final Tips

* **Retention alone is not enough**

  * Reduce Prometheus cardinality
  * Limit log ingestion
  * Sample traces before sending to Tempo

* Monitor disk usage regularly:

  * `du -sh /var/lib/docker`
  * `docker system df`

* Always test retention behavior in a staging environment

---

## Conclusion

A properly configured retention strategy is **essential** for a stable observability stack.
Without it, storage usage will grow indefinitely and eventually cause system failures.
Start with conservative retention, monitor usage, and adjust as needed.
