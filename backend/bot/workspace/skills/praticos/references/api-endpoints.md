# API Endpoints - Referência Completa

Todos os endpoints usam: -H "X-API-Key: $PRATICOS_API_KEY" -H "X-WhatsApp-Number: {NUMERO}" e base "$PRATICOS_API_URL". Retornam `formatContext` (ver SOUL.md > Dados da API).

## Busca Unificada (USAR SEMPRE)
POST /bot/search/unified
Parametros JSON (string OU array de strings): customer, customerPhone, device, deviceSerial, service, product
🔴 SEMPRE usar arrays para buscar multiplos termos de uma vez. NUNCA fazer chamadas separadas.
Exemplo com arrays: {"customer":"Joao","service":["tela","bateria"],"product":["película"]}
Resposta por entidade:
- customer/device: `{ exact, suggestions, available }` — `exact` = match exato (1 resultado ou null), `suggestions` = matches por nome
- service/product: `{ results, available }` — `results` = matches encontrados no catalogo
- `available` (todas): lista de itens cadastrados como fallback (retornado quando sem matches)
🔴 Se `available` tem match similar ao pedido → usar o ID dele + `description` customizada. NAO criar novo.
exec(command="curl -s -X POST -H \"X-API-Key: $PRATICOS_API_KEY\" -H \"X-WhatsApp-Number: {NUMERO}\" -H \"Content-Type: application/json\" -d '{\"customer\":\"Joao\",\"service\":[\"tela\",\"bateria\"]}' \"$PRATICOS_API_URL/bot/search/unified\"")

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
Resposta: retorna `order` atualizado (mesmo formato de /details) + `formatContext` + `previousStatus` + `newStatus`.
exec(command="curl -s -X PATCH -H \"X-API-Key: $PRATICOS_API_KEY\" -H \"X-WhatsApp-Number: {NUMERO}\" -H \"Content-Type: application/json\" -d '{\"status\":\"approved\"}' \"$PRATICOS_API_URL/bot/orders/42/status\"")

## OS - Criar
POST /bot/orders/full
Body: {customerId, deviceId?, deviceIds?:["id1","id2"], services:[{serviceId,value?,description?,deviceId?}], products:[{productId,quantity?,value?,description?,deviceId?}], dueDate?, scheduledDate?}
`deviceIds` para multi-device. Se passado, ignora `deviceId`. Cada service/product pode ter `deviceId` para vincular ao dispositivo.
Resposta: retorna `order` completo (mesmo formato de /details) + `formatContext` + `shareUrl` auto-criado. NAO precisa chamar GET /details apos criar.
exec(command="curl -s -X POST -H \"X-API-Key: $PRATICOS_API_KEY\" -H \"X-WhatsApp-Number: {NUMERO}\" -H \"Content-Type: application/json\" -d '{\"customerId\":\"abc\",\"services\":[{\"serviceId\":\"srv1\",\"value\":350}],\"scheduledDate\":\"2026-02-20T14:00:00.000Z\"}' \"$PRATICOS_API_URL/bot/orders/full\"")


## OS - Atualizar
PATCH /bot/orders/{NUM} `{"status":"approved","dueDate":"2026-02-20T18:00:00.000Z","scheduledDate":"2026-02-20T09:00:00.000Z","assignedTo":"userId"}`
Todos os campos opcionais. Passar `null` para limpar um campo (ex: `{"scheduledDate":null}`).
Resposta: retorna `order` atualizado (mesmo formato de /details) + `formatContext`.
exec(command="curl -s -X PATCH -H \"X-API-Key: $PRATICOS_API_KEY\" -H \"X-WhatsApp-Number: {NUMERO}\" -H \"Content-Type: application/json\" -d '{\"scheduledDate\":\"2026-02-20T09:00:00.000Z\"}' \"$PRATICOS_API_URL/bot/orders/42\"")

## OS - Itens
POST /bot/orders/{NUM}/services `{"serviceId":"ID","value":N,"description":"txt","deviceId":"ID"}`
POST /bot/orders/{NUM}/products `{"productId":"ID","quantity":N,"value":N,"description":"txt","deviceId":"ID"}`
`deviceId` opcional — vincula item a um dispositivo especifico da OS.
`description` opcional — texto livre para especificar detalhes. Ver exemplos em SKILL.md regra 5.
DELETE /bot/orders/{NUM}/services/{I} | DELETE /bot/orders/{NUM}/products/{I}
PATCH /bot/orders/{NUM}/customer `{"customerId":"ID"}` — corrigir cliente da OS
PATCH /bot/orders/{NUM}/device `{"deviceId":"ID"}` — corrigir dispositivo da OS
🔴 **TODOS os endpoints de mutacao** (POST /full, POST/DELETE /services, POST/DELETE /products, PATCH /status, PATCH /:number, PATCH /customer, PATCH /device, POST/DELETE /devices) retornam `{ order, formatContext }` no mesmo formato de /details. Usar dados do response para montar card. NAO re-fetch /details.

## OS - Dispositivos
POST /bot/orders/{NUM}/devices `{"deviceId":"ID"}` — adicionar dispositivo à OS (retorna order detail)
DELETE /bot/orders/{NUM}/devices/{DEVICE_ID} — remover dispositivo da OS (retorna order detail)
GET /bot/orders/{NUM}/details retorna `devices[]` (lista completa) e `deviceCount` (quantidade)

## OS - Fotos
POST /bot/orders/{NUM}/photos/upload - multipart com -F "file=@/path"
exec(command="curl -s -X POST -H \"X-API-Key: $PRATICOS_API_KEY\" -H \"X-WhatsApp-Number: {NUMERO}\" -F \"file=@/path/to/photo.jpg\" \"$PRATICOS_API_URL/bot/orders/{NUM}/photos/upload\"")
GET /bot/orders/{NUM}/photos - listar (retorna downloadUrl)
GET /bot/orders/{NUM}/photos/{ID} - download binario
DELETE /bot/orders/{NUM}/photos/{ID}

## Comentarios
POST /bot/orders/{NUM}/comments `{"text":"observacao aqui"}` (isInternal:true por padrao)
Para comentario visivel ao cliente: `{"text":"mensagem","isInternal":false}`
GET /bot/orders/{NUM}/comments - listar todos (internos + publicos)
exec(command="curl -s -X POST -H \"X-API-Key: $PRATICOS_API_KEY\" -H \"X-WhatsApp-Number: {NUMERO}\" -H \"Content-Type: application/json\" -d '{\"text\":\"Peca encomendada, chega amanha\"}' \"$PRATICOS_API_URL/bot/orders/42/comments\"")
exec(command="curl -s -H \"X-API-Key: $PRATICOS_API_KEY\" -H \"X-WhatsApp-Number: {NUMERO}\" \"$PRATICOS_API_URL/bot/orders/42/comments\"")

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
🔴 **NAO chamar POST /share.** shareUrl é auto-criado em TODOS os endpoints de mutacao.
GET /bot/orders/{NUM}/share | DELETE /bot/orders/{NUM}/share/{TOKEN} (consulta/remocao apenas)

## Checklists
Ver detalhes: `read(file_path="skills/praticos/references/checklists.md")`
