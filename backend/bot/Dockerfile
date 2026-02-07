# OpenClaw Docker Image for PraticOS
FROM node:22-slim

# Install system dependencies for OpenClaw and Puppeteer
RUN apt-get update && apt-get install -y \
    python3 \
    make \
    g++ \
    git \
    curl \
    ffmpeg \
    libnss3 \
    libatk-bridge2.0-0 \
    libxcomposite1 \
    libxdamage1 \
    libxrandr2 \
    libgbm1 \
    libasound2 \
    libpangocairo-1.0-0 \
    libxshmfence1 \
    && rm -rf /var/lib/apt/lists/*

# Install OpenClaw globally
RUN npm install -g openclaw@latest

# Select environment (default: prod)
ARG ENV=prod

# Copy workspace (skills, persona, cron)
COPY workspace/skills/ /root/.openclaw/skills/
COPY workspace/*.md /root/.openclaw/
COPY workspace/cron/jobs.json /root/.openclaw/cron/jobs.json

# Create agent directories (sessions are created at runtime)
RUN mkdir -p /root/.openclaw/agents/main/sessions

# Create memory directories (per-user memory files created at runtime)
RUN mkdir -p /root/.openclaw/memory/users

# Copy environment-specific config
COPY clawdbot.${ENV}.json /root/.openclaw/openclaw.json

# Create credentials directory (will be mounted as volume)
RUN mkdir -p /root/.openclaw/credentials /root/.openclaw/identity /root/.openclaw/devices

# Gateway configuration
EXPOSE 18789
ENV CLAWDBOT_GATEWAY_PORT=18789
ENV CLAWDBOT_GATEWAY_BIND=0.0.0.0

# Start OpenClaw directly
CMD ["openclaw", "gateway", "run", "--allow-unconfigured", "--verbose"]
