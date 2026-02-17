# API Endpoints - Referência Completa

Todos os endpoints usam: -H "X-API-Key: $PRATICOS_API_KEY" -H "X-WhatsApp-Number: {NUMERO}" e base "$PRATICOS_API_URL"

## Busca Unificada (USAR SEMPRE)
POST /bot/search/unified
Parametros JSON (string OU array de strings): customer, customerPhone, device, deviceSerial, service, product
Exemplo com arrays: {"service":["tela","bateria"],"product":["película"]}
Resposta: {exact, suggestions, available}
exec(command="curl -s -X POST -H \"X-API-Key: $PRATICOS_API_KEY\" -H \"X-WhatsApp-Number: {NUMERO}\" -H \"Content-Type: application/json\" -d '{\"customer\":\"Joao\",\"service\":\"tela\"}' \"$PRATICOS_API_URL/bot/search/unified\"")

## Resumo
GET /bot/summary/today - resumo do dia
GET /bot/summary/pending - OS pendentes
exec(command="curl -s -H \"X-API-Key: $PRATICOS_API_KEY\" -H \"X-WhatsApp-Number: {NUMERO}\" \"$PRATICOS_API_URL/bot/summary/pending\"")

## OS - Consulta
GET /bot/orders/list - listar OS
GET /bot/orders/{NUM}/details - detalhes completos (USAR PARA CARD)
exec(command="curl -s -H \"X-API-Key: $PRATICOS_API_KEY\" -H \"X-WhatsApp-Number: {NUMERO}\" \"$PRATICOS_API_URL/bot/orders/42/details\"")

## OS - Status
PATCH /bot/orders/{NUM}/status `{"status":"approved|progress|done|canceled"}` (→ se "done": sugerir notificar cliente via link)
exec(command="curl -s -X PATCH -H \"X-API-Key: $PRATICOS_API_KEY\" -H \"X-WhatsApp-Number: {NUMERO}\" -H \"Content-Type: application/json\" -d '{\"status\":\"approved\"}' \"$PRATICOS_API_URL/bot/orders/42/status\"")

## OS - Criar
POST /bot/orders/full
Body: {customerId, deviceId?, services:[{serviceId,value?,description?}], products:[{productId,quantity?,value?,description?}], dueDate?, scheduledDate?}
exec(command="curl -s -X POST -H \"X-API-Key: $PRATICOS_API_KEY\" -H \"X-WhatsApp-Number: {NUMERO}\" -H \"Content-Type: application/json\" -d '{\"customerId\":\"abc\",\"services\":[{\"serviceId\":\"srv1\",\"value\":350}]}' \"$PRATICOS_API_URL/bot/orders/full\"")

## OS - Atualizar
PATCH /bot/orders/{NUM} `{"status":"approved","dueDate":"2026-02-20T18:00:00.000Z","scheduledDate":"2026-02-20T09:00:00.000Z","assignedTo":"userId"}`
Todos os campos opcionais. Passar `null` para limpar um campo (ex: `{"scheduledDate":null}`).
exec(command="curl -s -X PATCH -H \"X-API-Key: $PRATICOS_API_KEY\" -H \"X-WhatsApp-Number: {NUMERO}\" -H \"Content-Type: application/json\" -d '{\"scheduledDate\":\"2026-02-20T09:00:00.000Z\"}' \"$PRATICOS_API_URL/bot/orders/42\"")

## OS - Itens
POST /bot/orders/{NUM}/services `{"serviceId":"ID","value":N,"description":"txt"}`
POST /bot/orders/{NUM}/products `{"productId":"ID","quantity":N,"value":N,"description":"txt"}`
DELETE /bot/orders/{NUM}/services/{I} | DELETE /bot/orders/{NUM}/products/{I}
PATCH /bot/orders/{NUM}/customer | PATCH /bot/orders/{NUM}/device

## OS - Fotos
POST /bot/orders/{NUM}/photos/upload - multipart com -F "file=@/path"
GET /bot/orders/{NUM}/photos - listar (retorna downloadUrl)
GET /bot/orders/{NUM}/photos/{ID} - download binario
DELETE /bot/orders/{NUM}/photos/{ID}

## Entidades CRUD
Base: /bot/entities/{TIPO} (customers|devices|services|products)
GET ?q=filtro&limit=20 | GET /{id} | POST | PATCH /{id} | DELETE /{id}
Campos: customers(name,phone?,email?,address?) | devices(name,serial*,manufacturer?) | services(name,value) | products(name,value)
exec(command="curl -s -H \"X-API-Key: $PRATICOS_API_KEY\" -H \"X-WhatsApp-Number: {NUMERO}\" \"$PRATICOS_API_URL/bot/entities/customers?q=joao&limit=10\"")

## Faturamento
GET /bot/analytics/financial[?startDate=YYYY-MM-DD&endDate=YYYY-MM-DD]
exec(command="curl -s -H \"X-API-Key: $PRATICOS_API_KEY\" -H \"X-WhatsApp-Number: {NUMERO}\" \"$PRATICOS_API_URL/bot/analytics/financial\"")

## Convites (INV_)
POST /bot/invite/create `{"collaboratorName":"Nome","role":"technician|admin|supervisor|manager","phone":"+55..."}`
GET /bot/invite/list | DELETE /bot/invite/{CODE}

## Magic Link
POST /bot/orders/{NUM}/share `{"permissions":["view","approve","comment"],"expiresInDays":7}`
GET /bot/orders/{NUM}/share | DELETE /bot/orders/{NUM}/share/{TOKEN}

## Checklists
GET /bot/forms/templates - templates disponiveis
GET /bot/orders/{NUM}/forms - listar checklists da OS
GET /bot/orders/{NUM}/forms/{FID} - detalhes
POST /bot/orders/{NUM}/forms `{"templateId":"ID"}`
POST /bot/orders/{NUM}/forms/{FID}/items/{IID} `{"value":"resposta"}`
POST /bot/orders/{NUM}/forms/{FID}/items/{IID}/photos - multipart
PATCH /bot/orders/{NUM}/forms/{FID}/status `{"status":"completed"}`

Tipos: text(string) | number(num/string) | boolean(true/false/sim/nao) | select(indice 1-N ou valor) | checklist("1,3,5" ou [1,3,5]) | photo_only(so foto)
Status: pending → in_progress → completed (completed requer obrigatorios preenchidos)
