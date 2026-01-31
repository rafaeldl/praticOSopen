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
		-v $(PWD)/workspace/IDENTITY.md:/root/.clawdbot/IDENTITY.md \
		-v $(PWD)/workspace/SOUL.md:/root/.clawdbot/SOUL.md \
		-e GEMINI_API_KEY \
		-e PRATICOS_API_URL \
		-e PRATICOS_API_KEY \
		-p 18789:18789 \
		clawdbot:dev

# ===== PRODUÇÃO =====
build:
	gcloud builds submit --tag $(IMAGE):latest --region=southamerica-east1 .

push: build
	@echo "Image already pushed by Cloud Build"

# SSH key file (override with SSH_KEY_FILE env var, leave empty for OS Login)
SSH_KEY_FILE ?= ~/.ssh/id_ed25519
SSH_KEY_FLAG = $(if $(SSH_KEY_FILE),--ssh-key-file=$(SSH_KEY_FILE),)

# Build, push and deploy to GCE
deploy: push
	gcloud compute instances update-container praticos-bot \
		--zone=$(ZONE) \
		--container-image=$(IMAGE):latest
	@echo "Waiting for container to start..."
	@sleep 10
	@echo "Checking logs..."
	gcloud compute ssh praticos-bot --zone=$(ZONE) $(SSH_KEY_FLAG) -- \
		'sudo docker logs --tail 20 $$(sudo docker ps -q)'

# ===== SETUP INICIAL (rodar 1x) =====
# Estrutura de persistência:
#   /var/clawdbot/.openclaw/credentials  → sessão WhatsApp (persistente)
#   /var/clawdbot/.openclaw/agents       → histórico de sessões (persistente)
#   Config e skills                      → embarcados na imagem Docker
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

# Sincroniza configs e skills para dentro do container (sem rebuild)
sync:
	@echo "Copiando configs para a VM..."
	gcloud compute scp clawdbot.prod.json praticos-bot:/tmp/clawdbot.json --zone=$(ZONE) $(SSH_KEY_FLAG)
	gcloud compute scp workspace/IDENTITY.md workspace/SOUL.md workspace/HEARTBEAT.md workspace/USER.md workspace/AGENTS.md workspace/TOOLS.md praticos-bot:/tmp/ --zone=$(ZONE) $(SSH_KEY_FLAG)
	gcloud compute scp --recurse workspace/skills praticos-bot:/tmp/skills --zone=$(ZONE) $(SSH_KEY_FLAG)
	@echo "Copiando para dentro do container..."
	gcloud compute ssh praticos-bot --zone=$(ZONE) $(SSH_KEY_FLAG) -- \
		'CONTAINER=$$(sudo docker ps -q) && \
		sudo docker cp /tmp/clawdbot.json $$CONTAINER:/root/.clawdbot/clawdbot.json && \
		sudo docker cp /tmp/IDENTITY.md $$CONTAINER:/root/.clawdbot/IDENTITY.md && \
		sudo docker cp /tmp/SOUL.md $$CONTAINER:/root/.clawdbot/SOUL.md && \
		sudo docker cp /tmp/HEARTBEAT.md $$CONTAINER:/root/.clawdbot/HEARTBEAT.md && \
		sudo docker cp /tmp/USER.md $$CONTAINER:/root/.clawdbot/USER.md && \
		sudo docker cp /tmp/AGENTS.md $$CONTAINER:/root/.clawdbot/AGENTS.md && \
		sudo docker cp /tmp/TOOLS.md $$CONTAINER:/root/.clawdbot/TOOLS.md && \
		sudo docker cp /tmp/skills $$CONTAINER:/root/.clawdbot/ && \
		sudo rm -rf /tmp/clawdbot.json /tmp/*.md /tmp/skills'
	@echo "✅ Sincronização concluída. Reiniciando container..."
	gcloud compute ssh praticos-bot --zone=$(ZONE) $(SSH_KEY_FLAG) -- 'sudo docker restart $$(sudo docker ps -q)'

setup-directories:
	gcloud compute ssh praticos-bot --zone=$(ZONE) $(SSH_KEY_FLAG) -- \
		'sudo mkdir -p /var/clawdbot/.openclaw/{credentials,agents} && sudo chmod -R 777 /var/clawdbot'

# Legacy alias for backwards compatibility
setup-credentials: setup-directories

destroy-vm:
	gcloud compute instances delete praticos-bot --zone=$(ZONE) --quiet

# Recreate VM with updated mounts (backup credentials first!)
recreate-vm: destroy-vm setup-vm setup-directories
	@echo "VM recreated. Run 'make deploy' to deploy the latest image."

verify-mounts:
	gcloud compute ssh praticos-bot --zone=$(ZONE) $(SSH_KEY_FLAG) -- \
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
	gcloud compute ssh praticos-bot --zone=$(ZONE) $(SSH_KEY_FLAG) -- 'sudo docker logs -f $$(sudo docker ps -q)'

ssh:
	gcloud compute ssh praticos-bot --zone=$(ZONE) $(SSH_KEY_FLAG)

status:
	gcloud compute instances list --filter="name=praticos-bot"

restart:
	gcloud compute instances reset praticos-bot --zone=$(ZONE)

# Limpar sessões e reiniciar container (produção)
clear-sessions:
	@echo "Limpando sessões na produção..."
	gcloud compute ssh praticos-bot --zone=$(ZONE) $(SSH_KEY_FLAG) -- \
		'sudo rm -rf /var/clawdbot/.openclaw/agents/main/sessions/* && sudo docker restart $$(sudo docker ps -q)'
	@echo "✅ Sessões limpas e container reiniciado"

# Limpar sessões locais
clear-sessions-local:
	@echo "Limpando sessões locais..."
	rm -rf data/.openclaw/agents/main/sessions/*
	docker compose restart
	@echo "✅ Sessões locais limpas e container reiniciado"

.PHONY: dev build-dev run-dev build push deploy setup-vm sync setup-directories setup-credentials destroy-vm recreate-vm verify-mounts up down logs-local logs ssh status restart clear-sessions clear-sessions-local
