# CARD DE OS (OBRIGATORIO)

Quando precisar mostrar uma OS, seguir TODOS os passos abaixo.

## Passo 1 — Buscar dados
```
exec: GET /bot/orders/{NUM}/details
```
Retorna `order` (dados brutos) com:
- `photosCount` e `mainPhotoUrl` (URL da foto de capa, pronta p/ download)
- `shareUrl` (link de compartilhamento, se ja existir e nao expirado)

## Passo 2 — Link de compartilhamento
Se `shareUrl` ja veio no passo 1, usar direto. Se nao:
```
exec: POST /bot/orders/{NUM}/share
```
Retorna `url` do link.

## Passo 3 — Formatar o card

Montar o texto a partir dos campos do `order`:
```
📋 *O.S. #{number}* - {STATUS}

👤 *Cliente:* {customer.name}
📞 *Telefone:* {customer.phone}
🔧 *{DEVICE_LABEL}:* {device.name} ({device.serial})

🛠️ *Serviços:*
• {service.name} - R$ {value}

📦 *Produtos:*
• {product.name} (x{qty}) - R$ {value}

💰 *Total:* R$ {total}
🏷️ *Desconto:* R$ {discount}
✅ *Pago:* R$ {paidAmount}
⏳ *A receber:* R$ {remaining}
📅 *Previsão:* {dueDate}
🗓️ *Aberto em:* {createdAt}

⭐ *Avaliação:* {score}/5
_"{rating.comment}"_

🔗 *Link:* {url do share}
```

**Status:** quote=Orçamento | approved=Aprovado | progress=Em andamento | done=Concluído | canceled=Cancelado
**{DEVICE_LABEL}:** usar labels do segmento (memoria do usuario) ou "Dispositivo"
**Regras:** omitir campos null/vazio. done+paid → "Pago" em vez de A receber. remaining = total - discount - paidAmount.

## Passo 4 — Enviar (COM ou SEM foto)

O `/details` retorna `mainPhotoUrl` (URL da foto de capa) e `photosCount`.

🔴 **Se mainPhotoUrl existir → OBRIGATORIO enviar foto como IMAGEM com card de legenda:**
```
exec: curl -s -H "X-API-Key: $PRATICOS_API_KEY" -H "X-WhatsApp-Number: {NUMERO}" "$PRATICOS_API_URL{mainPhotoUrl}" --output /tmp/os-{NUM}.jpg
message(filePath="/tmp/os-{NUM}.jpg", message="{card formatado no passo 3}")
```

🔴 NUNCA apenas mencionar "possui X fotos". SEMPRE baixar e enviar a foto como imagem.
A foto de capa transforma o card — o texto vira legenda da imagem no WhatsApp.

**Se mainPhotoUrl for null → enviar apenas texto:**
```
message("{card formatado no passo 3}")
```

## Regras finais
- **NAO usar campo `caption`** — usar SEMPRE `message` para o texto do card.
- `mainPhotoUrl` ja vem no response do `/details`. Baixar com curl --output.
- Formatar valores com R$ e pontuacao BR (1.234,56).
- 🔴 `/list` NAO traz fotos. Para card com foto, SEMPRE usar `/details`.
