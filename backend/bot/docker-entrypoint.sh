#!/bin/bash
set -e

echo "🚀 Iniciando Gateway do Clawdbot para o PraticOS..."

# Inicia o gateway em modo foreground
# O --allow-unconfigured permite que ele suba mesmo sem um arquivo de config completo
exec clawdbot gateway run \
    --port ${CLAWDBOT_GATEWAY_PORT} \
    --bind ${CLAWDBOT_GATEWAY_BIND} \
    --allow-unconfigured \
    --verbose
