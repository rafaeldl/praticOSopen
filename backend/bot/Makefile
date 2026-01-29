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
	docker run -it --rm \
		-v $(PWD)/credentials:/root/.clawdbot/credentials \
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

deploy: push
	gcloud compute instances update-container praticos-bot \
		--zone=$(ZONE) \
		--container-image=$(IMAGE):latest

# ===== SETUP INICIAL (rodar 1x) =====
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
		--container-mount-host-path=mount-path=/root/.clawdbot/credentials,host-path=/var/clawdbot/credentials,mode=rw \
		--container-restart-policy=always

setup-credentials:
	gcloud compute ssh praticos-bot --zone=$(ZONE) -- 'sudo mkdir -p /var/clawdbot/credentials && sudo chmod 777 /var/clawdbot'

# ===== DOCKER COMPOSE (local) =====
up:
	docker compose up --build

down:
	docker compose down

logs-local:
	docker compose logs -f

# ===== UTILITÁRIOS GCE =====
logs:
	gcloud compute ssh praticos-bot --zone=$(ZONE) -- 'docker logs -f $$(docker ps -q)'

ssh:
	gcloud compute ssh praticos-bot --zone=$(ZONE)

status:
	gcloud compute instances list --filter="name=praticos-bot"

restart:
	gcloud compute instances reset praticos-bot --zone=$(ZONE)

.PHONY: dev build-dev run-dev build push deploy setup-vm setup-credentials up down logs-local logs ssh status restart
