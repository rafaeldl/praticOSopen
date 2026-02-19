# CARD DE OS (OBRIGATORIO)

Quando precisar mostrar uma OS, seguir TODOS os passos abaixo.

## Passo 1 — Buscar dados
Se os dados da OS ja estao no contexto (ex: acabou de criar/modificar via POST /full, POST /services, PATCH, etc), usar diretamente.
So chamar GET /bot/orders/{NUM}/details se NAO tem os dados (ex: usuario pediu "mostra OS 42").
→ retorna `order` com `mainPhotoUrl`, `photosCount`, `shareUrl`

## Passo 2 — Link
`shareUrl` ja vem em TODOS os responses da API (criado automaticamente). Usar direto no card. NAO chamar POST /share.

## Passo 3 — Formatar card

🌐 **REGRA MULTILÍNGUE:** Traduzir TODOS os labels e status do card para o idioma do usuário (do memory/preferredLanguage). Os exemplos abaixo são em pt-BR como referência.

Montar o texto a partir dos campos do `order`:
```
📋 *O.S. #{number}* - {createdAt} - {STATUS}

👤 *Cliente:* {customer.name}
📍 *{ADDRESS_LABEL}:* {address}

**Dispositivo (single ou sem devices):**
🔧 *{DEVICE_LABEL}:* {device.name} ({device.serial})

**Multi-device (deviceCount > 1):**
🔧 *{DEVICE_LABEL_PLURAL} ({deviceCount}):*
1. {devices[0].name} ({devices[0].serial})
2. {devices[1].name} ({devices[1].serial})
3. {devices[2].name} ({devices[2].serial})

🛠️ *Serviços:*
**Se deviceCount <= 1:** lista plana
• {service.name} - {VALOR_FORMATADO}
**Se deviceCount > 1:** agrupar por dispositivo
  *{device.name}:*
  • {service.name} - {VALOR_FORMATADO}
  *Geral:*
  • {service.name} - {VALOR_FORMATADO}

📦 *Produtos:*
**Se deviceCount <= 1:** lista plana
• {product.name} (x{qty}) - {VALOR_FORMATADO}
**Se deviceCount > 1:** agrupar por dispositivo (mesmo formato dos serviços)

💰 *Total:* {VALOR_FORMATADO}
🏷️ *Desconto:* {VALOR_FORMATADO}
✅ *Pago:* {VALOR_FORMATADO}
⏳ *A receber:* {VALOR_FORMATADO}
🗓️ *Agendado:* {scheduledDate}
📅 *Previsão:* {dueDate}

🔗 *Link:* {shareUrl}
```
**Labels:** Traduzir no idioma do usuario. Referência pt-BR: Cliente, Endereço, Serviços, Produtos, Total, Desconto, Pago, A receber, Agendado, Previsão, Link. Ex en: Customer, Address, Services, Products, Total, Discount, Paid, Balance, Scheduled, Due date, Link.
**Status:** Traduzir no idioma do usuario. Valores internos e referência pt-BR: quote=Orçamento | approved=Aprovado | progress=Em andamento | done=Concluído | canceled=Cancelado. Ex en: Quote | Approved | In progress | Completed | Canceled.
**Omitir:** campos null, vazio ou com valor 0. Ex: paidAmount=0 → nao mostrar "Pago". discount=0 → nao mostrar "Desconto". address=null → nao mostrar "Endereço". scheduledDate=null → nao mostrar "Agendado".
**Moeda/Valores:** Usar `formatContext` retornado pelo endpoint. O `currency` define o simbolo (BRL=R$, EUR=€, USD=$) e o `locale` define o formato numerico: pt-BR → R$ 1.234,56 | en-US → $1,234.56 | fr-FR → 1 234,56 €. A API retorna valores raw (numeros).
**Datas:** formato BR dia/mes/ano + hora. Ex: 20/02/2026 09:00 — NUNCA ISO 8601 no card. Se hora for 00:00, mostrar so data.
**remaining** = total - discount - paidAmount.
**Multi-device:** Usar `deviceCount` da resposta de /details. Se `deviceCount > 1`, listar todos os devices numerados e agrupar serviços/produtos por `deviceId`. Itens sem `deviceId` ficam em "Geral" (traduzir). O label plural do device vem de `segment.labels` (ex: "Veículos", "Aparelhos"). Se nao houver, usar "Dispositivos"/"Devices"/etc.

### Exemplo multi-device (pt-BR)
```
📋 *O.S. #42* - 25/02/2026 - EM ANDAMENTO

👤 *Cliente:* João Silva
🔧 *Veículos (3):*
1. Fiat Uno 2015 (ABC-1234)
2. VW Gol 2018 (DEF-5678)
3. Chevrolet Onix 2020 (GHI-9012)

🛠️ *Serviços:*
  *Fiat Uno 2015:*
  • Troca de óleo - R$ 150,00
  *VW Gol 2018:*
  • Alinhamento - R$ 80,00
  • Balanceamento - R$ 60,00
  *Geral:*
  • Diagnóstico - R$ 50,00

💰 *Total:* R$ 340,00
🔗 *Link:* https://praticos.web.app/q/abc123
```

## Passo 4 — Enviar

🔴 Se `mainPhotoUrl` existir → BAIXAR foto e enviar como IMAGEM com card de legenda:
```
exec: curl -s -H "X-API-Key: $PRATICOS_API_KEY" -H "X-WhatsApp-Number: {NUMERO}" "$PRATICOS_API_URL{mainPhotoUrl}" --output /tmp/os-{NUM}.jpg
message(filePath="/tmp/os-{NUM}.jpg", message="{card}")
```

Se `mainPhotoUrl` for null → enviar apenas texto:
```
message("{card}")
```

🔴 NUNCA mencionar "possui X fotos" sem enviar. SEMPRE baixar e enviar a foto.
