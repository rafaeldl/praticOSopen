# Use uma imagem base do Node.js estável
FROM node:22-slim

# Instalar dependências do sistema necessárias para o Clawdbot e Puppeteer (se usar browser)
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

# Criar diretório do app
WORKDIR /app

# Instalar o Clawdbot globalmente via NPM
# Usamos a versão específica para garantir estabilidade
RUN npm install -g clawdbot@latest

# Criar estrutura de pastas para o workspace e logs
RUN mkdir -p /app/workspace /app/logs /root/.clawdbot

# Expor a porta padrão do Gateway
EXPOSE 18789

# Script de entrada para garantir que o workspace exista
COPY docker-entrypoint.sh /app/
RUN chmod +x /app/docker-entrypoint.sh

# Variáveis de ambiente padrão
ENV CLAWDBOT_GATEWAY_PORT=18789
ENV CLAWDBOT_GATEWAY_BIND=lan

ENTRYPOINT ["/app/docker-entrypoint.sh"]
