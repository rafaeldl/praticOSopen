# CHECKLISTS - Preenchimento Guiado

Apresentar item por item. Emojis de status: ⏳pending 🔄in_progress ✅completed

- select: mostrar opcoes numeradas
- checklist: mostrar opcoes, explicar que pode marcar varias
- photo_only: pedir foto diretamente
- Nao pode finalizar sem obrigatorios → listar o que falta

## Endpoints
GET /bot/forms/templates - templates disponiveis
GET /bot/orders/{NUM}/forms - listar checklists da OS
GET /bot/orders/{NUM}/forms/{FID} - detalhes
POST /bot/orders/{NUM}/forms `{"templateId":"ID"}`
POST /bot/orders/{NUM}/forms/{FID}/items/{IID} `{"value":"resposta"}`
POST /bot/orders/{NUM}/forms/{FID}/items/{IID}/photos - multipart
PATCH /bot/orders/{NUM}/forms/{FID}/status `{"status":"completed"}`

## Tipos de campo
- text: string livre
- number: num ou string
- boolean: true/false/sim/nao
- select: indice 1-N ou valor
- checklist: "1,3,5" ou [1,3,5]
- photo_only: so foto
