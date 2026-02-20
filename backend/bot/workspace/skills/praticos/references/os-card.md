# CARD DE OS (OBRIGATORIO)

Quando precisar mostrar uma OS, seguir TODOS os passos abaixo.

## Passo 1 — Buscar dados
exec: GET /bot/orders/{NUM}/details
→ retorna `order` com `mainPhotoUrl`, `photosCount`, `shareUrl`

## Passo 2 — Link
Se `shareUrl` veio no passo 1, usar. Se nao: POST /bot/orders/{NUM}/share → retorna `url`.

## Passo 3 — Formatar card

🌐 **REGRA MULTILÍNGUE:** Traduzir TODOS os labels e status do card para o idioma do usuário (do memory/preferredLanguage). Os exemplos abaixo são em pt-BR como referência.

Montar o texto a partir dos campos do `order`:
```
📋 *O.S. #{number}* - {createdAt} - {STATUS}

👤 *Cliente:* {customer.name}
🔧 *{DEVICE_LABEL}:* {device.name} ({device.serial})

🛠️ *Serviços:*
• {service.name} - {VALOR_FORMATADO}

📦 *Produtos:*
• {product.name} (x{qty}) - {VALOR_FORMATADO}

💰 *Total:* {VALOR_FORMATADO}
🏷️ *Desconto:* {VALOR_FORMATADO}
✅ *Pago:* {VALOR_FORMATADO}
⏳ *A receber:* {VALOR_FORMATADO}
📅 *Previsão:* {dueDate}

🔗 *Link:* {shareUrl}
```
**Labels:** Traduzir no idioma do usuario. Referência pt-BR: Cliente, Serviços, Produtos, Total, Desconto, Pago, A receber, Previsão, Link. Ex en: Customer, Services, Products, Total, Discount, Paid, Balance, Due date, Link.
**Status:** Traduzir no idioma do usuario. Valores internos e referência pt-BR: quote=Orçamento | approved=Aprovado | progress=Em andamento | done=Concluído | canceled=Cancelado. Ex en: Quote | Approved | In progress | Completed | Canceled.
**Omitir:** campos null, vazio ou com valor 0. Ex: paidAmount=0 → nao mostrar "Pago". discount=0 → nao mostrar "Desconto".
**Moeda/Valores:** Usar `formatContext` retornado pelo endpoint `/bot/orders/{NUM}/details`. O `currency` define o simbolo (BRL=R$, EUR=€, USD=$) e o `locale` define o formato numerico: pt-BR → R$ 1.234,56 | en-US → $1,234.56 | fr-FR → 1 234,56 €. A API retorna valores raw (numeros).
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
