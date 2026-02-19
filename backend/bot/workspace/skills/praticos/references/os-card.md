# CARD DE OS (OBRIGATORIO)

Quando precisar mostrar uma OS, seguir TODOS os passos abaixo.

## Passo 1 — Buscar dados
exec: GET /bot/orders/{NUM}/details
→ retorna `order` com `mainPhotoUrl`, `photosCount`, `shareUrl`

## Passo 2 — Link
Se `shareUrl` veio no passo 1, usar. Se nao: POST /bot/orders/{NUM}/share → retorna `url`.

## Passo 3 — Formatar card

Montar o texto a partir dos campos do `order`:
```
📋 *O.S. #{number}* - {createdAt} - {STATUS}

👤 *Cliente:* {customer.name}
🔧 *{DEVICE_LABEL}:* {device.name} ({device.serial})

🛠️ *Serviços:*
• {service.name} - R$ {value}

📦 *Produtos:*
• {product.name} (x{qty}) - R$ {value}

💰 *Total:* R$ {total}
🏷️ *Desconto:* R$ {discount}
✅ *Pago:* R$ {paidAmount}
⏳ *A receber:* R$ {remaining}
🗓️ *Agendado:* {scheduledDate}
📅 *Previsão:* {dueDate}

🔗 *Link:* {shareUrl}
```
**Status:** quote=Orçamento | approved=Aprovado | progress=Em andamento | done=Concluído | canceled=Cancelado
**Omitir:** campos null, vazio ou com valor 0. Ex: paidAmount=0 → nao mostrar "Pago". discount=0 → nao mostrar "Desconto".
**Valores R$:** SEMPRE formato BR com virgula decimal e ponto milhar. Ex: R$ 1.234,56 — NUNCA R$ 1234.56.
**Datas:** formato BR dia/mes/ano + hora. Ex: 20/02/2026 09:00 — NUNCA ISO 8601 no card. Se hora for 00:00, mostrar so data.
**remaining** = total - discount - paidAmount.

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
