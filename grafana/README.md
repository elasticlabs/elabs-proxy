This Docker Compose setup wires together all the key components for a solid monitoring stack:

- *Prometheus* handles time-series data collection and storage. It pulls metrics from exporters and other endpoints based on your configuration. The --web.enable-lifecycle flag lets you trigger config reloads without restarting the container.
- *Alloy* handles the OpenTelemetry collection 
- *Node Exporter* collects low-level system metrics from the host—like CPU usage, memory, and disk stats. We're mounting /proc and /sys read-only so Prometheus can scrape accurate host metrics without affecting the system.
- *cAdvisor* focuses on container-level metrics, offering insights into resource usage per container—handy when you’re running multiple services on the same host.

- *Loki* 
- *Tempo* 
- *Grafana* sits on top of Prometheus and provides a user-friendly interface to visualize your data. The provisioning folders (datasources and dashboards) ensure everything is set up automatically on first run.
- *Alertmanager* receives alerts from Prometheus and routes them to the right place—Slack, PagerDuty, email, etc. Mounting the config from your local folder keeps it easy to tweak as your alerting needs evolve.

The volumes ensure data persists across restarts, and the shared monitoring network lets all services communicate internally. 

This setup gives you full control and visibility over your Docker environment—with minimal manual steps.

Grafana supports automatic setup through provisioning.

In datasource.yml, we define Prometheus as the default data source using the internal Docker URL.
In dashboards.yml, we tell Grafana to load dashboards from a specific folder.
The grafana/dashboards directory is where you’ll store those dashboard JSON files.
With this setup, Grafana connects to Prometheus and loads dashboards automatically—no manual steps needed.

TODO : adjust retentino times!!