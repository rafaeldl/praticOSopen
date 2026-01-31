#!/bin/bash
set -e

echo "🚀 Iniciando Gateway do Clawdbot para o PraticOS..."

# Limpar locks de sessões órfãs (evita erro após restart da VM)
echo "🧹 Limpando locks de sessões..."
rm -f /root/.clawdbot/agents/main/sessions/*.lock 2>/dev/null || true

# Usar o caminho completo do executável do npm global
exec /usr/local/bin/clawdbot gateway run \
    --port ${CLAWDBOT_GATEWAY_PORT} \
    --bind ${CLAWDBOT_GATEWAY_BIND} \
    --allow-unconfigured \
    --verbose
