# ClawdBot Docker Image for PraticOS
FROM node:22-slim

# Install system dependencies for Clawdbot and Puppeteer
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

# Install Clawdbot globally
RUN npm install -g clawdbot@latest

# Select environment (default: prod)
ARG ENV=prod

# Copy workspace (skills, persona, cron)
COPY workspace/skills/ /root/.clawdbot/skills/
COPY workspace/*.md /root/.clawdbot/
COPY workspace/cron/jobs.json /root/.clawdbot/cron/jobs.json

# Create agent directories (sessions are created at runtime)
RUN mkdir -p /root/.clawdbot/agents/main/sessions

# Copy environment-specific config
COPY clawdbot.${ENV}.json /root/.clawdbot/clawdbot.json

# Create credentials directory (will be mounted as volume)
RUN mkdir -p /root/.clawdbot/credentials /root/.clawdbot/identity /root/.clawdbot/devices

# Gateway configuration
EXPOSE 18789
ENV CLAWDBOT_GATEWAY_PORT=18789
ENV CLAWDBOT_GATEWAY_BIND=lan

# Entrypoint script
COPY docker-entrypoint.sh /app/
RUN chmod +x /app/docker-entrypoint.sh

ENTRYPOINT ["/app/docker-entrypoint.sh"]
