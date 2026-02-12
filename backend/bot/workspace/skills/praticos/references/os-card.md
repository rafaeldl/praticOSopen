# CARD DE OS (OBRIGATORIO)

## Passo a passo:
1. GET /bot/orders/{NUM}/details (retorna photosCount, NAO o array)
2. Montar texto do card conforme modelo abaixo
3. **Se photosCount > 0:** GET /bot/orders/{NUM}/photos para obter lista com downloadUrl
4. **Se tiver foto:** baixar 1a foto e enviar IMAGEM com card como `message`
5. **Se NAO houver foto:** enviar apenas o texto
6. GET /bot/orders/{NUM}/share para link ativo

## Modelo:
```
*OS #[number]* - [STATUS_TRADUZIDO]

*Cliente:* [customer.name]
*[DEVICE_LABEL]:* [device.name] - [device.serial]

*Servicos:*
• [service.name] - R$ [value]

*Produtos:*
• [product.name] (x[qty]) - R$ [value]

*Total:* R$ [total]
*A receber:* R$ [remaining]

*Avaliacao:* ⭐x[score] ([score]/5)
_"[rating.comment]"_

🔗 Link cliente: [URL]

_[Z] foto(s)_
```

**[DEVICE_LABEL]** = labels["device._entity"] ou "Dispositivo"
**Status:** pending=Pendente | approved=Aprovado | progress=Em andamento | done=Concluido | canceled=Cancelado
**Regras:** omitir device/servicos/produtos/fotos/rating/link se null/vazio. done+paid → "*Pago*" em vez de A receber. remaining = total - paidAmount.

## Envio da imagem (se photosCount > 0):
1. GET /bot/orders/{NUM}/photos → obter lista com downloadUrl
2. Baixar 1a foto: curl com "$PRATICOS_API_URL{downloadUrl}" --output foto.jpg
3. Enviar imagem com:
   - **filePath**: caminho da imagem baixada (ex: foto.jpg)
   - **message**: texto do card formatado (este e o campo que aparece no WhatsApp)
   - **NAO usar campo `caption`** — usar SEMPRE `message` para o texto
