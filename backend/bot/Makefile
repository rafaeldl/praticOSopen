# ClawdBot Makefile - Comandos para dev e produção
# Uso: make dev, make build, make deploy

PROJECT=praticos
ZONE=southamerica-east1-b
IMAGE=gcr.io/$(PROJECT)/clawdbot

# Load .env file if exists
ifneq (,$(wildcard ./.env))
    include .env
    export
endif

# ===== DESENVOLVIMENTO =====
dev: build-dev run-dev

build-dev:
	docker build --build-arg ENV=dev -t clawdbot:dev .

run-dev:
	@mkdir -p data/.openclaw/credentials data/.openclaw/agents
	docker run -it --rm \
		-v $(PWD)/data/.openclaw/credentials:/root/.clawdbot/credentials \
		-v $(PWD)/data/.openclaw/agents:/root/.clawdbot/agents \
		-v $(PWD)/workspace/skills:/root/.clawdbot/skills \
		-v $(PWD)/workspace/AGENTS.md:/root/.clawdbot/AGENTS.md \
		-v $(PWD)/workspace/PERSONA.md:/root/.clawdbot/PERSONA.md \
		-e GEMINI_API_KEY \
		-e PRATICOS_API_URL \
		-e PRATICOS_API_KEY \
		-p 18789:18789 \
		clawdbot:dev

# ===== PRODUÇÃO =====
build:
	docker build -t $(IMAGE):latest .

push: build
	docker push $(IMAGE):latest

# SSH key file (override with SSH_KEY_FILE env var)
SSH_KEY_FILE ?= ~/.ssh/id_rsa

# Build, push and deploy to GCE
deploy: push
	gcloud compute instances update-container praticos-bot \
		--zone=$(ZONE) \
		--container-image=$(IMAGE):latest
	@echo "Waiting for container to start..."
	@sleep 10
	@echo "Checking logs..."
	gcloud compute ssh praticos-bot --zone=$(ZONE) --ssh-key-file=$(SSH_KEY_FILE) -- \
		'sudo docker logs --tail 20 $$(sudo docker ps -q)'

# ===== SETUP INICIAL (rodar 1x) =====
# Estrutura de persistência:
#   /var/clawdbot/.openclaw/credentials  → sessão WhatsApp (persistente)
#   /var/clawdbot/.openclaw/agents       → histórico de sessões (persistente)
#   Workspace (SKILL.md, etc.)           → copiado no Docker image
setup-vm:
	gcloud compute instances create-with-container praticos-bot \
		--project=$(PROJECT) \
		--zone=$(ZONE) \
		--machine-type=e2-small \
		--image-family=cos-stable \
		--image-project=cos-cloud \
		--boot-disk-size=20GB \
		--container-image=$(IMAGE):latest \
		--container-env-file=.env.prod \
		--container-mount-host-path=mount-path=/root/.clawdbot/credentials,host-path=/var/clawdbot/.openclaw/credentials,mode=rw \
		--container-mount-host-path=mount-path=/root/.clawdbot/agents,host-path=/var/clawdbot/.openclaw/agents,mode=rw \
		--container-restart-policy=always

setup-directories:
	gcloud compute ssh praticos-bot --zone=$(ZONE) --ssh-key-file=$(SSH_KEY_FILE) -- \
		'sudo mkdir -p /var/clawdbot/.openclaw/{credentials,agents} && sudo chmod -R 777 /var/clawdbot'

# Legacy alias for backwards compatibility
setup-credentials: setup-directories

destroy-vm:
	gcloud compute instances delete praticos-bot --zone=$(ZONE) --quiet

# Recreate VM with updated mounts (backup credentials first!)
recreate-vm: destroy-vm setup-vm setup-directories
	@echo "VM recreated. Run 'make deploy' to deploy the latest image."

verify-mounts:
	gcloud compute ssh praticos-bot --zone=$(ZONE) --ssh-key-file=$(SSH_KEY_FILE) -- \
		'sudo docker inspect $$(sudo docker ps -q) | grep -A20 Mounts'

# ===== DOCKER COMPOSE (local) =====
up:
	docker compose up --build

down:
	docker compose down

logs-local:
	docker compose logs -f

# ===== UTILITÁRIOS GCE =====
logs:
	gcloud compute ssh praticos-bot --zone=$(ZONE) --ssh-key-file=$(SSH_KEY_FILE) -- 'sudo docker logs -f $$(sudo docker ps -q)'

ssh:
	gcloud compute ssh praticos-bot --zone=$(ZONE) --ssh-key-file=$(SSH_KEY_FILE)

status:
	gcloud compute instances list --filter="name=praticos-bot"

restart:
	gcloud compute instances reset praticos-bot --zone=$(ZONE)

.PHONY: dev build-dev run-dev build push deploy setup-vm setup-directories setup-credentials destroy-vm recreate-vm verify-mounts up down logs-local logs ssh status restart
