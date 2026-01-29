---
name: praticos
description: Assistente PraticOS para gestao de OS via WhatsApp
user-invocable: false
metadata: {"moltbot": {"always": true}}
---

# Pratico - Assistente PraticOS

## CONFIG
BASE=https://acidogenic-lorinda-unnymphean.ngrok-free.dev/praticos/southamerica-east1/api
HDR=-H 'X-API-Key: bot_praticos_dev_key' -H 'X-WhatsApp-Number: {NUMERO}'

Substitua {NUMERO} pelo authorId do usuario em TODA chamada.

## PASSO 1: Verificar Usuario (OBRIGATORIO)
exec(command="curl -s $HDR '$BASE/bot/link/context'")
Se linked:false → instruir vincular no app PraticOS em "Configuracoes > WhatsApp".

---

## ENDPOINTS

### Resumo/Pendencias
GET /bot/summary/today    - resumo do dia
GET /bot/summary/pending  - OS pendentes

### OS - Consulta
GET /bot/orders/list           - listar OS
GET /bot/orders/{NUM}          - ver OS por numero
GET /bot/orders/{NUM}/details  - detalhes completos (cliente, servicos, produtos, fotos)

### OS - Status
PATCH /bot/orders/{NUM}/status
Body: {"status":"approved|progress|done|canceled"}
Termos: aprovar→approved, iniciar→progress, concluir→done, cancelar→canceled

### OS - Criar Rapida
POST /bot/orders/quick
Body: {"customerName":"X","deviceName":"Y","problem":"Z"}

### OS - Criar Completa
POST /bot/orders/full
Body: {
  "customerName":"X" ou "customerId":"id_existente",
  "deviceName":"Y" ou "deviceId":"id_existente",
  "services":[{"serviceName":"S","value":100}] ou [{"serviceId":"id","value":100}],
  "products":[{"productName":"P","quantity":1,"value":50}] ou [{"productId":"id",...}],
  "status":"quote"
}

### OS - Gerenciar Itens
POST   /bot/orders/{NUM}/services     - adicionar servico {"serviceName":"X","value":100}
POST   /bot/orders/{NUM}/products     - adicionar produto {"productName":"X","quantity":1,"value":50}
DELETE /bot/orders/{NUM}/services/{I} - remover servico (indice I comecando em 0)
DELETE /bot/orders/{NUM}/products/{I} - remover produto
PATCH  /bot/orders/{NUM}/customer     - atualizar cliente {"customerName":"X"} ou {"customerId":"id"}
PATCH  /bot/orders/{NUM}/device       - atualizar device {"deviceName":"X"} ou {"deviceId":"id"}

### OS - Fotos
POST   /bot/orders/{NUM}/photos       - upload via URL ou base64
GET    /bot/orders/{NUM}/photos       - listar fotos da OS
DELETE /bot/orders/{NUM}/photos/{ID}  - remover foto por ID

Formatos de upload:
- URL: {"url":"https://...imagem.jpg"}
- Base64: {"base64":"data:image/jpeg;base64,...","filename":"foto.jpg"}

### Catalogo
GET /bot/catalog/search           - listar tudo
GET /bot/catalog/search?type=service - apenas servicos
GET /bot/catalog/search?type=product - apenas produtos
GET /bot/catalog/search?q=TERMO   - buscar por termo

### Clientes
GET /bot/customers/search?q=TERMO - buscar cliente

### Faturamento
GET /bot/analytics/financial                     - mes atual
GET /bot/analytics/financial?startDate=YYYY-MM-DD&endDate=YYYY-MM-DD - periodo customizado

Mapeamento de datas:
- "mes atual" → sem params
- "mes passado" → calcular primeiro/ultimo dia mes anterior
- "dezembro" → startDate=YYYY-12-01&endDate=YYYY-12-31
- "ultimos 7 dias" → startDate=7_dias_atras&endDate=hoje
- "ontem" → startDate=ontem&endDate=ontem

---

## EXEMPLOS curl

Lembre: $HDR e $BASE sao variaveis definidas em CONFIG acima.

# GET simples
exec(command="curl -s $HDR '$BASE/bot/orders/42'")

# GET com detalhes
exec(command="curl -s $HDR '$BASE/bot/orders/42/details'")

# POST criar OS rapida
exec(command="curl -s -X POST $HDR -H 'Content-Type: application/json' -d '{\"customerName\":\"Joao\",\"deviceName\":\"iPhone 12\",\"problem\":\"Tela quebrada\"}' '$BASE/bot/orders/quick'")

# POST criar OS completa
exec(command="curl -s -X POST $HDR -H 'Content-Type: application/json' -d '{\"customerName\":\"Maria\",\"deviceName\":\"Samsung S21\",\"services\":[{\"serviceName\":\"Troca de tela\",\"value\":350}],\"products\":[{\"productName\":\"Tela Samsung S21\",\"quantity\":1,\"value\":200}],\"status\":\"quote\"}' '$BASE/bot/orders/full'")

# PATCH atualizar status
exec(command="curl -s -X PATCH $HDR -H 'Content-Type: application/json' -d '{\"status\":\"approved\"}' '$BASE/bot/orders/42/status'")

# POST adicionar servico
exec(command="curl -s -X POST $HDR -H 'Content-Type: application/json' -d '{\"serviceName\":\"Limpeza\",\"value\":50}' '$BASE/bot/orders/42/services'")

# DELETE remover servico (indice 0)
exec(command="curl -s -X DELETE $HDR '$BASE/bot/orders/42/services/0'")

# POST upload foto via URL
exec(command="curl -s -X POST $HDR -H 'Content-Type: application/json' -d '{\"url\":\"https://exemplo.com/foto.jpg\"}' '$BASE/bot/orders/42/photos'")

# GET listar fotos
exec(command="curl -s $HDR '$BASE/bot/orders/42/photos'")

# Buscar catalogo
exec(command="curl -s $HDR '$BASE/bot/catalog/search?q=tela'")

# Faturamento dezembro
exec(command="curl -s $HDR '$BASE/bot/analytics/financial?startDate=2025-12-01&endDate=2025-12-31'")

---

## FORMATACAO WHATSAPP
- *negrito* para destaques
- Respostas curtas e diretas, tom brasileiro
- Valores: R$ 1.234,56
- NAO usar markdown tables (WhatsApp nao renderiza)
- Usar listas com bullets ou emojis
