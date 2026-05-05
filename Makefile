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
	docker/media/audiobookshelf \
	docker/media/epub-to-audiobook \
	docker/media/immich \
	docker/monitoring/prometheus \
	docker/monitoring/grafana \
	docker/nextcloud \
	docker/stirling-pdf \
	docker/frigate \
	docker/reverse-proxy \
	docker/filebrowser \
	docker/portainer \
	docker/tsdproxy \
	docker/ollama-openwebui \
	docker/homepage \
# 	docker/caddy

# Extracts the last path component as the service name, e.g. "docker/media/immich" -> "immich"
define service_name
$(notdir $(1))
endef

.PHONY: all up down logs restart network-setup $(foreach dir,$(SERVICE_DIRS),$(call service_name,$(dir))-up $(call service_name,$(dir))-down)

network-setup:
	@echo "Setting up Docker networks..."
	@bash ./docker/shared/network-setup.sh

# Bring up all services
all: up

# Runs a docker compose command across all SERVICE_DIRS in sequence.
# Env file resolution: uses a local .env in the service dir if present,
# otherwise falls back to the root .env.
define dc_all
	@for dir in $(SERVICE_DIRS); do \
		echo "$(1) $$dir..."; \
		(cd $$dir && docker compose --env-file $$([ -f $$dir/.env ] && echo $$dir/.env || echo $(ROOT_DIR)/.env) $(2)); \
	done
endef

up: network-setup
	$(call dc_all,Bringing up,up -d)

down:
	$(call dc_all,Bringing down,down)

logs:
	$(call dc_all,Logs for,logs --tail 50 -f)

restart: down up

# Generic docker compose command dispatcher
#
# Generates targets for each service dir, e.g. for a dir named "navidrome":
#   make navidrome-up          # start containers in background
#   make navidrome-up-force    # recreate containers from scratch
#   make navidrome-down        # stop and remove containers
#   make navidrome-down-vol    # stop and remove containers + volumes
#   make navidrome-logs        # tail last 50 log lines and follow
#   make navidrome-pull        # pull latest images
#
# Env file resolution: prefer a local .env in the service dir if it exists,
# otherwise fall back to the root .env.
#   $(wildcard ...)            -> expands to the path if the file exists, "" if not
#   $(if <cond>,<then>,<else>) -> picks local or root path based on the above
define dc_cmd
$(call service_name,$(1))-$(2): ; @cd $(1) && docker compose --env-file $(if $(wildcard $(ROOT_DIR)/$(1)/.env),$(ROOT_DIR)/$(1)/.env,$(ROOT_DIR)/.env) $(3)
endef

$(foreach dir,$(SERVICE_DIRS),$(eval $(call dc_cmd,$(dir),up,        up -d)))
$(foreach dir,$(SERVICE_DIRS),$(eval $(call dc_cmd,$(dir),up-force,  up -d --force-recreate)))
$(foreach dir,$(SERVICE_DIRS),$(eval $(call dc_cmd,$(dir),down,      down)))
$(foreach dir,$(SERVICE_DIRS),$(eval $(call dc_cmd,$(dir),down-vol,  down -v)))
$(foreach dir,$(SERVICE_DIRS),$(eval $(call dc_cmd,$(dir),logs,      logs --tail 50 -f)))
$(foreach dir,$(SERVICE_DIRS),$(eval $(call dc_cmd,$(dir),pull,      pull)))

include .env # for DATA_ROOT used below

# Reverse-proxy target with automatic certbot-init
reverse-proxy-up: network-setup
	@echo "ROOT_DIR is $(ROOT_DIR)"
	@echo "DATA_ROOT is $(DATA_ROOT)"
	@echo "Checking if Certbot has run..."
	@if [ ! -f "$(DATA_ROOT)/certbot/conf/.certbot-done" ]; then \
		echo "Initial certificate not found. Running certbot-init..."; \
		docker compose --env-file $(ROOT_DIR)/.env -f docker/reverse-proxy/docker-compose.yml --profile init up -d nginx-init; \
		docker compose --env-file $(ROOT_DIR)/.env -f docker/reverse-proxy/docker-compose.yml --profile init run --rm certbot-init; \
		docker compose --env-file $(ROOT_DIR)/.env -f docker/reverse-proxy/docker-compose.yml --profile init down; \
	else \
		echo "Certificate already exists. Skipping certbot-init."; \
	fi
	@echo "Starting Nginx and Certbot services..."
	@docker compose --env-file $(ROOT_DIR)/.env -f docker/reverse-proxy/docker-compose.yml up -d nginx certbot modsecurity
