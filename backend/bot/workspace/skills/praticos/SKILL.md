---
name: praticos
description: Assistente PraticOS para gestao de OS via WhatsApp
user-invocable: false
metadata: {"moltbot": {"always": true}}
---

# Pratico - Assistente PraticOS

## CONFIG
BASE=$PRATICOS_API_URL
HDR=-H 'X-API-Key: $PRATICOS_API_KEY' -H 'X-WhatsApp-Number: {NUMERO}'

Substitua {NUMERO} pelo authorId do usuario em TODA chamada.

## PASSO 1: Verificar Usuario (OBRIGATORIO)
exec(command="curl -s $HDR '$BASE/bot/link/context'")
Se linked:false → instruir vincular no app PraticOS em "Configuracoes > WhatsApp".

## REGRAS

1. **IDs OBRIGATORIOS** - A API NAO aceita nomes, apenas IDs
   - Use POST /bot/search/unified para buscar TODOS os IDs de uma vez

2. **Fluxo para criar OS:**
   a) Buscar tudo de uma vez: POST /bot/search/unified
   b) Se exact != null, usar esse ID
   c) Se suggestions tem itens, confirmar com usuario: "Encontrei X. E esse?"
   d) Se available tem itens (fallback), mostrar opcoes disponiveis
   e) Se NAO encontrar, oferecer criar (ver regra 3)

3. **Gerenciamento de Entidades (CRUD completo):**
   a) **Listar:** GET /bot/entities/{tipo}?q=filtro - para ver opcoes disponiveis
   b) **Consultar:** GET /bot/entities/{tipo}/{id} - para ver detalhes completos
   c) **Criar:** POST /bot/entities/{tipo} - quando nao encontrar na busca
   d) **Editar:** PATCH /bot/entities/{tipo}/{id} - para corrigir dados
   e) **Excluir:** DELETE /bot/entities/{tipo}/{id} - SEMPRE pedir confirmacao!

   Fluxo recomendado:
   - Buscar primeiro via /bot/search/unified
   - Se nao encontrar, perguntar se quer criar
   - Para editar/excluir, sempre confirmar com usuario

4. **Upload de fotos** - SEMPRE usar multipart/form-data:
   - Usar `-F file=@/path/to/foto.jpg` (NAO base64)
   - Mais rapido e confiavel

5. **VALORES de servicos/produtos** - Incluir valor quando disponivel:
   - A busca unificada retorna `value` para servicos e produtos
   - Use esse valor ao criar OS: `{"serviceId":"ID","value":VALOR_DO_CATALOGO}`
   - Se valor NAO for enviado, o sistema usa automaticamente o valor do catalogo
   - Para brindes/cortesias, envie `"value":0` explicitamente

6. **EXIBIR OS** - SEMPRE usar formato CARD (ver secao CARD DE OS):
   - Ao consultar uma OS especifica, SEMPRE formatar como card
   - Se order.photos[0] existir, enviar IMAGEM com card como CAPTION
   - Nunca responder com JSON bruto ou texto nao-formatado

---

## ENDPOINTS

### Busca Unificada (USAR SEMPRE)
POST /bot/search/unified - buscar cliente/device/servico/produto em UMA chamada

Parametros (inclua apenas o que precisa):
- customer: buscar cliente por nome
- customerPhone: buscar cliente por telefone (match exato, prioritario)
- device: buscar device por nome
- deviceSerial: buscar device por serial/IMEI (match exato, prioritario)
- service: buscar servico por nome
- product: buscar produto por nome

Exemplo: {"customerPhone":"+5511999999999","deviceSerial":"IMEI123456789","service":"tela"}

Resposta:
- customer/device: {exact, suggestions, available}
- service/product: {results, available}

Se nao encontrar, available traz lista de disponiveis.

### Resumo/Pendencias
GET /bot/summary/today    - resumo do dia
GET /bot/summary/pending  - OS pendentes

### OS - Consulta
GET /bot/orders/list           - listar OS
GET /bot/orders/{NUM}          - ver OS por numero
GET /bot/orders/{NUM}/details  - detalhes completos (USAR PARA CARD)

**IMPORTANTE:** Ao mostrar OS para usuario, SEMPRE usar formato CARD (ver secao abaixo)

### OS - Status
PATCH /bot/orders/{NUM}/status
Body: {"status":"approved|progress|done|canceled"}

### OS - Criar
POST /bot/orders/full
Body: {"customerId":"ID","deviceId":"ID","services":[{"serviceId":"ID","value":100,"description":"detalhes"}],"products":[{"productId":"ID","quantity":1,"value":50,"description":"detalhes"}]}

Campos opcionais em services/products:
- value: valor (se omitido, usa valor do catalogo)
- description: detalhes adicionais do item nesta OS (max 500 chars)

### OS - Gerenciar Itens
POST   /bot/orders/{NUM}/services     - adicionar servico {"serviceId":"ID","value":100,"description":"detalhes"}
POST   /bot/orders/{NUM}/products     - adicionar produto {"productId":"ID","quantity":1,"value":50,"description":"detalhes"}
DELETE /bot/orders/{NUM}/services/{I} - remover servico (indice)
DELETE /bot/orders/{NUM}/products/{I} - remover produto
PATCH  /bot/orders/{NUM}/customer     - atualizar cliente
PATCH  /bot/orders/{NUM}/device       - atualizar device

### OS - Fotos
POST   /bot/orders/{NUM}/photos/upload - upload foto (multipart, RECOMENDADO)
GET    /bot/orders/{NUM}/photos        - listar fotos (retorna downloadUrl para cada)
GET    /bot/orders/{NUM}/photos/{ID}   - DOWNLOAD da foto (retorna imagem binaria)
DELETE /bot/orders/{NUM}/photos/{ID}   - remover foto

### Entidades - CRUD Generico
Base: /bot/entities/{TIPO} onde TIPO = customers | devices | services | products

GET    /{TIPO}?q=filtro&limit=20  - listar (limit max 50)
GET    /{TIPO}/{id}               - detalhes
POST   /{TIPO}                    - criar
PATCH  /{TIPO}/{id}               - editar (campos opcionais)
DELETE /{TIPO}/{id}               - excluir

**Campos por tipo:**
- customers: name, phone?, email?, address?
- devices: name, serial (obrigatorio), manufacturer?
- services: name, value
- products: name, value

### Faturamento
GET /bot/analytics/financial - mes atual
GET /bot/analytics/financial?startDate=YYYY-MM-DD&endDate=YYYY-MM-DD

---

## EXEMPLOS curl

# Busca unificada por nome
exec(command="curl -s -X POST $HDR -H 'Content-Type: application/json' -d '{\"customer\":\"Joao\",\"service\":\"tela\"}' '$BASE/bot/search/unified'")

# Busca unificada por telefone/serial (match exato)
exec(command="curl -s -X POST $HDR -H 'Content-Type: application/json' -d '{\"customerPhone\":\"+5511999999999\",\"deviceSerial\":\"IMEI123456789\"}' '$BASE/bot/search/unified'")

# Criar OS com IDs obtidos
exec(command="curl -s -X POST $HDR -H 'Content-Type: application/json' -d '{\"customerId\":\"abc123\",\"services\":[{\"serviceId\":\"srv789\",\"value\":350}]}' '$BASE/bot/orders/full'")

# Ver OS
exec(command="curl -s $HDR '$BASE/bot/orders/42/details'")

# Atualizar status
exec(command="curl -s -X PATCH $HDR -H 'Content-Type: application/json' -d '{\"status\":\"approved\"}' '$BASE/bot/orders/42/status'")

# Upload foto (usar -F, NAO base64)
exec(command="curl -s -X POST $HDR -F 'file=@/workspace/media/foto.jpg' '$BASE/bot/orders/42/photos/upload'")

# Upload foto com descricao
exec(command="curl -s -X POST $HDR -F 'file=@/workspace/media/foto.jpg' -F 'description=Foto do veiculo' '$BASE/bot/orders/42/photos/upload'")

# Entidades CRUD (substituir {TIPO} por customers|devices|services|products)
# Listar
exec(command="curl -s $HDR '$BASE/bot/entities/{TIPO}?q=filtro&limit=10'")
# Consultar
exec(command="curl -s $HDR '$BASE/bot/entities/{TIPO}/{id}'")
# Criar (customer)
exec(command="curl -s -X POST $HDR -H 'Content-Type: application/json' -d '{\"name\":\"X\",\"phone\":\"+55...\"}' '$BASE/bot/entities/customers'")
# Criar (device - serial obrigatorio)
exec(command="curl -s -X POST $HDR -H 'Content-Type: application/json' -d '{\"name\":\"X\",\"serial\":\"Y\"}' '$BASE/bot/entities/devices'")
# Criar (service/product)
exec(command="curl -s -X POST $HDR -H 'Content-Type: application/json' -d '{\"name\":\"X\",\"value\":100}' '$BASE/bot/entities/{services|products}'")
# Editar
exec(command="curl -s -X PATCH $HDR -H 'Content-Type: application/json' -d '{\"campo\":\"valor\"}' '$BASE/bot/entities/{TIPO}/{id}'")
# Excluir
exec(command="curl -s -X DELETE $HDR '$BASE/bot/entities/{TIPO}/{id}'")

# Faturamento
exec(command="curl -s $HDR '$BASE/bot/analytics/financial'")

---

## FORMATACAO WHATSAPP
- *negrito* para destaques
- Respostas curtas e diretas
- Valores: R$ 1.234,56
- NAO usar markdown tables

---

## CARD DE OS (OBRIGATORIO)

**SEMPRE** usar este formato ao mostrar uma OS individual ao usuario.

### Passo a passo:
1. Chamar GET /bot/orders/{NUM}/details (retorna photosCount, NAO o array)
2. Montar texto do card conforme modelo abaixo
3. **Se photosCount > 0:** chamar GET /bot/orders/{NUM}/photos para obter lista com downloadUrl
4. **Se tiver foto:** enviar IMAGEM usando URL completa: $BASE + downloadUrl (ex: $BASE/bot/orders/42/photos/ID)
5. **Se NAO houver foto:** enviar apenas o texto

**IMPORTANTE:** O endpoint de download retorna a imagem binaria diretamente (requer headers de autenticacao).

### Modelo do card (usar como caption se tiver foto):
```
*OS #[number]* - [STATUS_TRADUZIDO]

*Cliente:* [customer.name]
*Dispositivo:* [device.name]

*Total:* R$ [total]
*A receber:* R$ [remaining]

_[X] servico(s) | [Y] produto(s) | [Z] foto(s)_
```

### Traducao de status:
- pending → Pendente
- approved → Aprovado
- progress → Em andamento
- done → Concluido
- canceled → Cancelado

### Regras:
- Se `device` for null → omitir linha Dispositivo
- Se status=done e paid=true → mostrar "*Pago*" em vez de "A receber: R$..."
- `remaining` = total - paidAmount
- Contadores so se > 0 (omitir "0 foto(s)")
- Contar: services.length, products.length, photos.length

### Envio da imagem:
Se photosCount > 0:
1. Chamar GET /bot/orders/{NUM}/photos para obter lista de fotos com downloadUrl
2. Baixar a imagem: curl $HDR "$BASE{downloadUrl}" --output foto.jpg
3. Enviar imagem com caption:
   - Usar a imagem baixada (o endpoint retorna imagem binaria)
   - caption: texto do card formatado
