# Load top-level .env
# export $(shell sed 's/=.*//' .env)

# Load top-level .env with values
# export $(shell grep -v '^#' .env | xargs)

# Load top-level .env (ignore comments and empty lines)
# ifneq (,$(wildcard .env))
#     include .env
#     export $(shell sed '/^\s*#/d;/^\s*$$/d' .env | sed 's/=.*//')
# endif

ROOT_DIR := $(shell git rev-parse --show-toplevel)

# List of docker-compose directories
SERVICE_DIRS := \
	docker/media/jellyfin \
	docker/media/navidrome \
	docker/media/calibre-web-automated \
	docker/monitoring/prometheus \
	docker/monitoring/grafana \
	docker/nextcloud \
	docker/stirling-pdf \
	docker/frigate \
	docker/reverse-proxy \
	docker/filebrowser \
	docker/portainer \
# 	docker/caddy

# Helper function to get a friendly service name from path
define service_name
$(notdir $(shell echo $(1) | sed 's|.*/||'))
endef

.PHONY: all up down logs restart network-setup $(foreach dir,$(SERVICE_DIRS),$(call service_name,$(dir))-up $(call service_name,$(dir))-down)

network-setup:
	@echo "Setting up Docker networks..."
	@bash ./docker/shared/network-setup.sh

# Bring up all services
all: up

up: network-setup
	@for dir in $(SERVICE_DIRS); do \
		echo "Bringing up $$dir..."; \
		(cd $$dir && docker compose --env-file $(ROOT_DIR)/.env up -d); \
	done

down:
	@for dir in $(SERVICE_DIRS); do \
		echo "Bringing down $$dir..."; \
		(cd $$dir && docker compose --env-file $(ROOT_DIR)/.env down); \
	done

logs:
	@for dir in $(SERVICE_DIRS); do \
		echo "Logs for $$dir:"; \
		(cd $$dir && docker compose logs --tail 50 -f); \
	done

restart: down up

# Generate per-service targets like jellyfin-up, navidrome-up
$(foreach dir,$(SERVICE_DIRS),$(eval $(call service_name,$(dir))-up: ; @cd $(dir) && docker compose --env-file $(ROOT_DIR)/.env up -d))
$(foreach dir,$(SERVICE_DIRS),$(eval $(call service_name,$(dir))-up-force: ; @cd $(dir) && docker compose --env-file $(ROOT_DIR)/.env up -d --force-recreate))
$(foreach dir,$(SERVICE_DIRS),$(eval $(call service_name,$(dir))-down: ; @cd $(dir) && docker compose --env-file $(ROOT_DIR)/.env down))
$(foreach dir,$(SERVICE_DIRS),$(eval $(call service_name,$(dir))-down-vol: ; @cd $(dir) && docker compose --env-file $(ROOT_DIR)/.env down -v))
$(foreach dir,$(SERVICE_DIRS),$(eval $(call service_name,$(dir))-logs: ; @cd $(dir) && docker compose --env-file $(ROOT_DIR)/.env logs --tail 50 -f))
$(foreach dir,$(SERVICE_DIRS),$(eval $(call service_name,$(dir))-pull: ; @cd $(dir) && docker compose --env-file $(ROOT_DIR)/.env pull))

include .env # for DATA_ROOT used below

# Reverse-proxy target with automatic certbot-init
reverse-proxy-up: network-setup
	@echo "ROOT_DIR is $(ROOT_DIR)"
	@echo "DATA_ROOT is $(DATA_ROOT)"
	@echo "Checking if Certbot has run..."
	@if [ ! -f "$(DATA_ROOT)/certbot/conf/.certbot-done" ]; then \
		echo "Initial certificate not found. Running certbot-init..."; \
		docker compose -f docker/reverse-proxy/docker-compose.yml --env-file $(ROOT_DIR)/.env --profile init up -d nginx-init; \
		docker compose -f docker/reverse-proxy/docker-compose.yml --env-file $(ROOT_DIR)/.env --profile init run --rm certbot-init; \
		docker compose -f docker/reverse-proxy/docker-compose.yml --env-file $(ROOT_DIR)/.env --profile init down; \
	else \
		echo "Certificate already exists. Skipping certbot-init."; \
	fi
	@echo "Starting Nginx and Certbot services..."
	@docker compose -f docker/reverse-proxy/docker-compose.yml --env-file $(ROOT_DIR)/.env up -d nginx certbot modsecurity
