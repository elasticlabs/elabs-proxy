---
# Homepage configuration
# Template file — __BASE_DOMAIN__ is substituted by `make init` → homer/config.yml
# See https://fontawesome.com/search for icons options

title: "Admin welcome page"
subtitle: "Elabs internal services dashboard"

icon: "fa-solid fa-user-gear"

header: true

footer: '<p>Created with <span class="has-text-danger">❤️</span> in Paris, France.</p>'

columns: 3

connectivityCheck: true

defaults:
  layout: columns
  colorTheme: light

theme: default

links:
  - name: "Elasticlabs GitHub"
    icon: "fab fa-github"
    url: "https://github.com/elasticlabs/elabs-proxy#top"
    target: "_blank"

  - name: "JetPunk"
    icon: "fas fa-fish"
    url: "https://www.jetpunk.com/"
    target: "_blank"

# Services
# First level array represents a group.
# To add a downstream stack, append an item under the relevant group
# or create a new group following the same pattern.
# Run `make stack-add` to scaffold the nginx route, then add the entry here.
services:
  - name: "Admin"
    icon: "fas fa-shield-alt"
    items:
      - name: "Keycloak"
        icon: "fa-solid fa-id-card"
        subtitle: "IAM / SSO"
        url: "https://auth.__BASE_DOMAIN__"

      - name: "Portainer"
        icon: "fa-brands fa-docker"
        subtitle: "Container management"
        url: "https://admin.__BASE_DOMAIN__/portainer/"

      - name: "Files"
        icon: "fa-solid fa-folder-open"
        subtitle: "Named volumes browser"
        url: "https://admin.__BASE_DOMAIN__/data/"

      - name: "Dozzle (logs)"
        icon: "fa-solid fa-scroll"
        subtitle: "Container logs UI"
        url: "https://admin.__BASE_DOMAIN__/logs/"

  - name: "Observability"
    icon: "fas fa-chart-bar"
    items:
      - name: "Grafana"
        icon: "fa-solid fa-chart-line"
        subtitle: "Observability"
        url: "https://admin.__BASE_DOMAIN__/grafana/"

      - name: "Prometheus"
        type: "Prometheus"
        icon: "fa-solid fa-fire"
        url: "https://admin.__BASE_DOMAIN__/prometheus/"

      - name: "Alertmanager"
        icon: "fa-solid fa-bell"
        subtitle: "Alert routing & silences"
        url: "https://admin.__BASE_DOMAIN__/alertmanager/"

      - name: "cAdvisor"
        icon: "fa-solid fa-microchip"
        subtitle: "Container metrics UI"
        url: "https://admin.__BASE_DOMAIN__/cadvisor/"

  # ─── Downstream stacks ───────────────────────────────────────────────────
  # Add your downstream application stacks below.
  # Example:
  #
  # - name: "Applications"
  #   icon: "fas fa-cubes"
  #   items:
  #     - name: "My App"
  #       icon: "fa-solid fa-rocket"
  #       subtitle: "Short description"
  #       url: "https://myapp.__BASE_DOMAIN__/"
