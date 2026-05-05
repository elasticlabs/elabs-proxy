SHELL := /bin/bash

ifneq (,$(wildcard ./.env))
include .env
export
endif

BASE_DOMAIN ?= $(shell grep BASE_DOMAIN .env | cut -d '=' -f2)

AUTH_DOMAIN ?= auth.$(BASE_DOMAIN)
ADMIN_DOMAIN ?= admin.$(BASE_DOMAIN)
LABS_DOMAIN ?= labs.$(BASE_DOMAIN)

NETWORKS := $(REVPROXY_APPS_NETWORK) $(SWAG_NETWORK)

.PHONY: help cp-env docker-check networks init up down restart ps logs pull build config clean secrets-bootstrap stack-add stack-check stack-list

# ── Downstream stack helpers ───────────────────────────────────────────────
# STACK : container / service name (also used as subdomain or subfolder slug)
# PORT  : HTTP port exposed by the service
# MODE  : subdomain (default) | subfolder
STACK ?=
PORT  ?=
MODE  ?= subdomain

help:
	@echo ""
	@echo "Bootstrap"
	@echo "  make cp-env            -> create .env from .env.example if missing"
	@echo "  make secrets-bootstrap -> generate and inject secrets into .env where CHANGE_ME is present"
	@echo "  make init              -> validate docker + create networks + generate configs"
	@echo "  make htpasswd          -> flush and recreate .htpasswd with a single user"
	@echo "  make keycloak-realm    -> generate Keycloak realm file from template"
	@echo ""
	@echo "Lifecycle"
	@echo "  make build             -> build local images"
	@echo "  make up                -> start the stack"
	@echo "  make down              -> stop the stack"
	@echo "  make restart           -> restart the stack"
	@echo "  make ps                -> list containers"
	@echo "  make pull              -> pull base images"
	@echo "  make config            -> validate compose config"
	@echo ""
	@echo "Downstream stacks"
	@echo "  make stack-add   STACK=myapp PORT=8080 [MODE=subdomain|subfolder]"
	@echo "                         -> scaffold nginx conf + prometheus target for a new stack"
	@echo "  make stack-check STACK=myapp"
	@echo "                         -> verify network, nginx conf, and prometheus target"
	@echo "  make stack-list        -> list registered downstream stacks (stacks/REGISTRY.md)"
	@echo ""
	@echo "Derived domains"
	@echo "  AUTH_DOMAIN=$(AUTH_DOMAIN)"
	@echo "  ADMIN_DOMAIN=$(ADMIN_DOMAIN)"
	@echo "  LABS_DOMAIN=$(LABS_DOMAIN)"
	@echo ""

cp-env:
	@[ -f .env ] || cp .env-changeme .env
	@echo ".env ready."

env-check:
	@test -f .env || { echo ".env missing. Run: make cp-env"; exit 1; }
	@grep -q '^BASE_DOMAIN=' .env || { echo "BASE_DOMAIN missing"; exit 1; }
	@grep -q '^ADMIN_EMAIL=' .env || { echo "ADMIN_EMAIL missing"; exit 1; }
	@grep -q '^REVPROXY_APPS_NETWORK=' .env || { echo "REVPROXY_APPS_NETWORK missing"; exit 1; }
	@grep -q '^SWAG_NETWORK=' .env || { echo "SWAG_NETWORK missing"; exit 1; }
	@grep -q '^KEYCLOAK_DB_PASSWORD=' .env || { echo "KEYCLOAK_DB_PASSWORD missing"; exit 1; }
	@grep -q '^KEYCLOAK_ADMIN_PASSWORD=' .env || { echo "KEYCLOAK_ADMIN_PASSWORD missing"; exit 1; }
	@grep -q '^OAUTH2_PROXY_CLIENT_SECRET=' .env || { echo "OAUTH2_PROXY_CLIENT_SECRET missing"; exit 1; }
	@grep -q '^OAUTH2_PROXY_COOKIE_SECRET=' .env || { echo "OAUTH2_PROXY_COOKIE_SECRET missing"; exit 1; }
	@grep -q '^GRAFANA_ADMIN_USER=' .env || { echo "GRAFANA_ADMIN_USER missing"; exit 1; }
	@grep -q '^GRAFANA_ADMIN_PASSWORD=' .env || { echo "GRAFANA_ADMIN_PASSWORD missing"; exit 1; }
	@echo ".env OK."

secrets-bootstrap:
	@test -f .env || { echo ".env missing. Run: make cp-env"; exit 1; }
	@mkdir -p .tmp; \
	DB_PASS="$$(openssl rand -base64 24 | tr -d '\n')"; \
	KC_ADMIN_PASS="$$(openssl rand -base64 24 | tr -d '\n')"; \
	OAUTH_CLIENT_SECRET="$$(openssl rand -base64 32 | tr -d '\n')"; \
	OAUTH_COOKIE_SECRET="$$(openssl rand 32 | base64 | tr -d '\n' | tr '+/' '-_' | tr -d '=')"; \
	GRAFANA_ADMIN_PASS="$$(openssl rand -base64 24 | tr -d '\n')"; \
	changed=0; \
	set_secret() { \
		key="$$1"; value="$$2"; \
		if grep -Eq "^$${key}=CHANGE_ME$$" .env; then \
			sed -i "s|^$${key}=CHANGE_ME$$|$${key}=$${value}|" .env; \
			changed=1; \
		fi; \
	}; \
	set_secret KEYCLOAK_DB_PASSWORD "$$DB_PASS"; \
	set_secret KEYCLOAK_ADMIN_PASSWORD "$$KC_ADMIN_PASS"; \
	set_secret OAUTH2_PROXY_CLIENT_SECRET "$$OAUTH_CLIENT_SECRET"; \
	set_secret OAUTH2_PROXY_COOKIE_SECRET "$$OAUTH_COOKIE_SECRET"; \
	set_secret GRAFANA_ADMIN_PASSWORD "$$GRAFANA_ADMIN_PASS"; \
	{ \
		printf '%s\n' '# elabs-revproxy bootstrap secrets'; \
		printf '\n'; \
		printf '%s\n' '## KeepassXC entries to create'; \
		printf '\n'; \
		printf '%s\n' '### keycloak-db'; \
		printf '%s\n' "- username: $(KEYCLOAK_DB_USER)"; \
		printf '%s\n' "- password: $$DB_PASS"; \
		printf '\n'; \
		printf '%s\n' '### keycloak-admin'; \
		printf '%s\n' "- username: $(KEYCLOAK_ADMIN_USER)"; \
		printf '%s\n' "- password: $$KC_ADMIN_PASS"; \
		printf '\n'; \
		printf '%s\n' '### oauth2-proxy-client'; \
		printf '%s\n' "- username: $(OAUTH2_PROXY_CLIENT_ID)"; \
		printf '%s\n' "- password: $$OAUTH_CLIENT_SECRET"; \
		printf '\n'; \
		printf '%s\n' '### oauth2-proxy-cookie'; \
		printf '%s\n' '- username: cookie-secret'; \
		printf '%s\n' "- password: $$OAUTH_COOKIE_SECRET"; \
		printf '\n'; \
		printf '%s\n' '### grafana-admin'; \
		printf '%s\n' "- username: $(GRAFANA_ADMIN_USER)"; \
		printf '%s\n' "- password: $$GRAFANA_ADMIN_PASS"; \
		printf '\n'; \
		printf '%s\n' '## Injected .env values'; \
		printf '\n'; \
		printf '%s\n' "KEYCLOAK_DB_PASSWORD=$$DB_PASS"; \
		printf '%s\n' "KEYCLOAK_ADMIN_PASSWORD=$$KC_ADMIN_PASS"; \
		printf '%s\n' "OAUTH2_PROXY_CLIENT_SECRET=$$OAUTH_CLIENT_SECRET"; \
		printf '%s\n' "OAUTH2_PROXY_COOKIE_SECRET=$$OAUTH_COOKIE_SECRET"; \
		printf '%s\n' "GRAFANA_ADMIN_PASSWORD=$$GRAFANA_ADMIN_PASS"; \
	} > .tmp/secrets.bootstrap.md; \
	echo ""; \
	echo "Bootstrap secrets written to .tmp/secrets.bootstrap.md"; \
	if [ $$changed -eq 1 ]; then \
		echo "CHANGE_ME values were replaced directly in .env"; \
	else \
		echo "No CHANGE_ME placeholder found for auto-injection; .env left unchanged."; \
	fi

docker-check:
	@command -v docker >/dev/null 2>&1 || { echo "docker missing"; exit 1; }
	@docker info >/dev/null 2>&1 || { echo "docker daemon unavailable"; exit 1; }
	@docker compose version >/dev/null 2>&1 || { echo "docker compose plugin missing"; exit 1; }
	@echo "Docker OK."

networks: env-check
	@for net in $(NETWORKS); do \
		if ! docker network inspect $$net >/dev/null 2>&1; then \
			echo "Creating network $$net"; \
			docker network create $$net >/dev/null; \
		else \
			echo "Network already exists: $$net"; \
		fi; \
	done

init: docker-check env-check networks keycloak-realm
	@echo "Detected BASE_DOMAIN=$(BASE_DOMAIN)"
	@read -r -p "Use this domain? [Y/n] " confirm; \
	if [[ "$$confirm" =~ ^[Nn]$$ ]]; then \
		read -r -p "Enter new BASE_DOMAIN: " new_domain; \
		test -n "$$new_domain" || { echo "No domain provided"; exit 1; }; \
		sed -i "s|^BASE_DOMAIN=.*$$|BASE_DOMAIN=$$new_domain|" .env; \
		BASE_DOMAIN="$$new_domain"; \
	else \
		BASE_DOMAIN="$(BASE_DOMAIN)"; \
	fi; \
	echo "Using domain: $$BASE_DOMAIN"; \
	\
	echo "Creating .conf from .sample if missing..."; \
	find swag/config/nginx/site-confs -type f -name "*.conf.sample" | while read sample; do \
		target="$${sample%.sample}"; \
		if [ ! -f "$$target" ]; then \
			echo " -> creating $$target"; \
			cp "$$sample" "$$target"; \
		fi; \
	done; \
	\
	echo "Applying BASE_DOMAIN to .conf files..."; \
	find swag/config/nginx -type f -name "*.conf" -exec sed -i "s|__BASE_DOMAIN__|$$BASE_DOMAIN|g" {} +; \
	\
	echo "Generating homer/config.yml from template..."; \
	if [ ! -f homer/config.yml ]; then \
		sed "s|__BASE_DOMAIN__|$$BASE_DOMAIN|g" homer/config.yml.tpl > homer/config.yml; \
		echo " -> homer/config.yml created"; \
	else \
		echo " -> homer/config.yml already exists (skipped)"; \
	fi; \
	\
	echo "Ensuring prometheus downstream targets directory..."; \
	mkdir -p grafana/prometheus/targets/downstream; \
	\
	echo "Init OK."

build: init
	@docker compose build

up: init
	@docker compose up -d
	@echo ""
	@echo "Available URLs"
	@echo "  Admin       : https://$(ADMIN_DOMAIN)/"
	@echo "  Portainer   : https://$(ADMIN_DOMAIN)/portainer/"
	@echo "  Grafana     : https://$(ADMIN_DOMAIN)/grafana/"
	@echo "  Alertmanager: https://$(ADMIN_DOMAIN)/alertmanager/"
	@echo "  Prometheus  : https://$(ADMIN_DOMAIN)/prometheus/"
	@echo "  cAdvisor    : https://$(ADMIN_DOMAIN)/cadvisor/"
	@echo "  Files       : https://$(ADMIN_DOMAIN)/data/"
	@echo "  Logs        : https://$(ADMIN_DOMAIN)/logs/"
	@echo "  Labs        : https://$(LABS_DOMAIN)/"
	@echo "  IAM URLs"
	@echo "  Keycloak    : https://$(AUTH_DOMAIN)"


down:
	@docker compose down --remove-orphans

restart:
	@docker compose down
	@docker compose up -d
	@echo ""
	@echo "Available URLs"
	@echo "  Admin       : https://$(ADMIN_DOMAIN)/"
	@echo "  Portainer   : https://$(ADMIN_DOMAIN)/portainer/"
	@echo "  Grafana     : https://$(ADMIN_DOMAIN)/grafana/"
	@echo "  Alertmanager: https://$(ADMIN_DOMAIN)/alertmanager/"
	@echo "  Prometheus  : https://$(ADMIN_DOMAIN)/prometheus/"
	@echo "  cAdvisor    : https://$(ADMIN_DOMAIN)/cadvisor/"
	@echo "  Files       : https://$(ADMIN_DOMAIN)/data/"
	@echo "  Logs        : https://$(ADMIN_DOMAIN)/logs/"
	@echo "  Labs        : https://$(LABS_DOMAIN)/"
	@echo "  IAM URLs"
	@echo "  Keycloak    : https://$(AUTH_DOMAIN)"

ps:
	@docker compose ps

config: env-check
	@docker compose config

clean:
	@echo "Stopping stack and removing Docker volumes..."
	@docker compose down -v --remove-orphans
	@echo "Clean complete. ./tmp and TLS certs preserved."

.PHONY: keycloak-realm

keycloak-realm: env-check
	@mkdir -p keycloak/import
	@echo "Generating Keycloak realm from template..."
	@envsubst < keycloak/templates/elabs-realm.json.tpl > keycloak/import/elabs-realm.json
	@echo "✔ keycloak/import/elabs-realm.json generated"

htpasswd:
	@docker compose ps --status running swag | grep -q swag || { \
		echo "SWAG is not running."; \
		echo "Start the stack first with: make up"; \
		exit 1; \
	}
	@echo ""
	@echo "WARNING: this will flush and recreate ./swag/config/nginx/.htpasswd"
	@echo "with a single user."
	@echo ""
	@read -r -p "Continue? [y/N] " confirm; \
	if [[ ! "$$confirm" =~ ^[Yy]$$ ]]; then \
		echo "Aborted."; \
		exit 1; \
	fi; \
	echo ""; \
	read -r -p "Enter the username to create: " user; \
	if [ -z "$$user" ]; then \
		echo "Username cannot be empty."; \
		exit 1; \
	fi; \
	echo ""; \
	echo "Recreating .htpasswd with user '$$user'..."; \
	docker compose exec -it swag htpasswd -c /config/nginx/.htpasswd "$$user"
	@echo "User '$$user' created in .htpasswd."
	@echo "Reloading SWAG configuration..."
	@docker compose exec -it swag nginx -s reload
	@echo "Done."

backup-site-confs:
	@mkdir -p .tmp/backups/site-confs
	@cp -av swag/config/nginx/site-confs/admin.subdomain.conf .tmp/backups/site-confs/admin.subdomain.conf.$$(date +%Y%m%d-%H%M%S).bak 2>/dev/null || true
	@cp -av swag/config/nginx/site-confs/labs.subdomain.conf .tmp/backups/site-confs/labs.subdomain.conf.$$(date +%Y%m%d-%H%M%S).bak 2>/dev/null || true

pull: backup-site-confs
	git pull

# ──────────────────────────────────────────────────────────────────────────────
# Downstream stack helpers
# ──────────────────────────────────────────────────────────────────────────────

stack-add: env-check
	@test -n "$(STACK)" || { \
		echo ""; \
		echo "Usage: make stack-add STACK=<name> PORT=<port> [MODE=subdomain|subfolder]"; \
		echo ""; \
		echo "  STACK  container / service name (also used as subdomain or path slug)"; \
		echo "  PORT   HTTP port the container listens on"; \
		echo "  MODE   subdomain (default) or subfolder"; \
		echo ""; \
		exit 1; \
	}
	@test -n "$(PORT)" || { \
		echo ""; \
		echo "PORT is required."; \
		echo "Usage: make stack-add STACK=$(STACK) PORT=<port> [MODE=subdomain|subfolder]"; \
		echo ""; \
		exit 1; \
	}
	@echo ""
	@echo "=== Scaffolding downstream stack: $(STACK) (mode=$(MODE), port=$(PORT)) ==="
	@echo ""
	@\
	DOMAIN="$(BASE_DOMAIN)"; \
	\
	if [ "$(MODE)" = "subfolder" ]; then \
		nginx_tpl="stacks/templates/nginx-subfolder.conf.tpl"; \
		nginx_dest="swag/config/nginx/client-stacks/$(STACK).conf"; \
	else \
		nginx_tpl="stacks/templates/nginx-subdomain.conf.tpl"; \
		nginx_dest="swag/config/nginx/site-confs/$(STACK).subdomain.conf"; \
	fi; \
	\
	if [ -f "$$nginx_dest" ]; then \
		echo "⚠  $$nginx_dest already exists — skipping nginx conf"; \
	else \
		sed -e "s|__STACK__|$(STACK)|g" \
		    -e "s|__BASE_DOMAIN__|$$DOMAIN|g" \
		    -e "s|__PORT__|$(PORT)|g" \
		    "$$nginx_tpl" > "$$nginx_dest"; \
		echo "✔  Created: $$nginx_dest"; \
	fi; \
	\
	mkdir -p grafana/prometheus/targets/downstream; \
	prom_dest="grafana/prometheus/targets/downstream/$(STACK).yml"; \
	if [ -f "$$prom_dest" ]; then \
		echo "⚠  $$prom_dest already exists — skipping prometheus target"; \
	else \
		sed -e "s|__STACK__|$(STACK)|g" \
		    -e "s|__BASE_DOMAIN__|$$DOMAIN|g" \
		    -e "s|__PORT__|$(PORT)|g" \
		    -e "s|__METRICS_PORT__|9090|g" \
		    stacks/templates/prometheus-target.yml.tpl > "$$prom_dest"; \
		echo "✔  Created: $$prom_dest (update __METRICS_PORT__ if needed)"; \
	fi; \
	\
	echo ""; \
	echo "─── Next steps ────────────────────────────────────────────────────────────"; \
	echo ""; \
	echo "1. In your downstream docker-compose.yml, connect the service:"; \
	echo "   (see stacks/templates/docker-compose.fragment.yml for a full example)"; \
	echo ""; \
	echo "     networks:"; \
	echo "       - revproxy_apps"; \
	echo "     labels:"; \
	echo "       obs.stack: $(STACK)"; \
	echo "       obs.service: $(STACK)"; \
	echo "       obs.domain: labs"; \
	echo "       obs.role: <role>"; \
	echo "       obs.env: prod"; \
	echo ""; \
	echo "     # at file bottom:"; \
	echo "     networks:"; \
	echo "       revproxy_apps:"; \
	echo "         external: true"; \
	echo ""; \
	if [ "$(MODE)" = "subfolder" ]; then \
		echo "2. Nginx: $$nginx_dest auto-included under labs.$$DOMAIN"; \
	else \
		echo "2. Nginx: review $$nginx_dest"; \
		echo "   Add DNS A record: $(STACK).$$DOMAIN -> server IP"; \
	fi; \
	echo ""; \
	echo "3. If your service exposes /metrics, update the port in:"; \
	echo "   $$prom_dest"; \
	echo "   (or delete it if no metrics endpoint)"; \
	echo ""; \
	echo "4. Add a Homer entry in homer/config.yml under the relevant group"; \
	echo ""; \
	echo "5. Register: edit stacks/REGISTRY.md"; \
	echo ""; \
	echo "6. Validate: make stack-check STACK=$(STACK)"; \
	echo ""; \
	echo "7. Reload SWAG:"; \
	echo "   docker compose exec swag nginx -t && docker compose exec swag nginx -s reload"; \
	echo ""

stack-check: env-check
	@test -n "$(STACK)" || { \
		echo "Usage: make stack-check STACK=<name>"; \
		exit 1; \
	}
	@echo ""
	@echo "=== Checking downstream stack: $(STACK) ==="
	@echo ""
	@\
	ok=1; \
	\
	echo "── Docker network ($(REVPROXY_APPS_NETWORK)) ──────────────────────────"; \
	if docker network inspect $(REVPROXY_APPS_NETWORK) >/dev/null 2>&1; then \
		containers=$$(docker network inspect $(REVPROXY_APPS_NETWORK) --format '{{range .Containers}}{{.Name}} {{end}}'); \
		if echo "$$containers" | tr ' ' '\n' | grep -qi "$(STACK)"; then \
			echo "✔  Container matching '$(STACK)' found on $(REVPROXY_APPS_NETWORK)"; \
		else \
			echo "✗  No container matching '$(STACK)' on $(REVPROXY_APPS_NETWORK)"; \
			echo "   Running containers: $$containers"; \
			ok=0; \
		fi; \
	else \
		echo "✗  Network $(REVPROXY_APPS_NETWORK) not found"; \
		ok=0; \
	fi; \
	echo ""; \
	\
	echo "── Nginx configuration ────────────────────────────────────────────────"; \
	subdomain_conf="swag/config/nginx/site-confs/$(STACK).subdomain.conf"; \
	subfolder_conf="swag/config/nginx/client-stacks/$(STACK).conf"; \
	if [ -f "$$subdomain_conf" ]; then \
		echo "✔  Subdomain conf: $$subdomain_conf"; \
	elif [ -f "$$subfolder_conf" ]; then \
		echo "✔  Subfolder conf: $$subfolder_conf"; \
	else \
		echo "✗  No nginx conf found (run: make stack-add STACK=$(STACK) PORT=<port>)"; \
		ok=0; \
	fi; \
	echo ""; \
	\
	echo "── Prometheus target ──────────────────────────────────────────────────"; \
	prom_target="grafana/prometheus/targets/downstream/$(STACK).yml"; \
	if [ -f "$$prom_target" ]; then \
		if grep -q "__METRICS_PORT__" "$$prom_target"; then \
			echo "⚠  $$prom_target exists but __METRICS_PORT__ is not set yet"; \
		else \
			echo "✔  $$prom_target"; \
		fi; \
	else \
		echo "–  No prometheus target (optional — only needed if service exposes /metrics)"; \
	fi; \
	echo ""; \
	\
	echo "── Homer dashboard ────────────────────────────────────────────────────"; \
	if [ -f homer/config.yml ] && grep -q "$(STACK)" homer/config.yml; then \
		echo "✔  Homer entry found"; \
	else \
		echo "–  No Homer entry yet (add manually to homer/config.yml)"; \
	fi; \
	echo ""; \
	\
	echo "── Registry ───────────────────────────────────────────────────────────"; \
	if grep -q "$(STACK)" stacks/REGISTRY.md 2>/dev/null; then \
		echo "✔  Registered in stacks/REGISTRY.md"; \
	else \
		echo "–  Not registered yet (add a row to stacks/REGISTRY.md)"; \
	fi; \
	echo ""; \
	\
	if [ "$$ok" -eq 1 ]; then \
		echo "✅  Stack $(STACK) looks connected. Reload SWAG if you haven't yet:"; \
		echo "    docker compose exec swag nginx -t && docker compose exec swag nginx -s reload"; \
	else \
		echo "❌  One or more checks failed — review the items above."; \
	fi; \
	echo ""

stack-list:
	@echo ""
	@echo "=== Registered downstream stacks ==="
	@echo ""
	@if [ -f stacks/REGISTRY.md ]; then \
		cat stacks/REGISTRY.md; \
	else \
		echo "(stacks/REGISTRY.md not found)"; \
	fi
	@echo ""