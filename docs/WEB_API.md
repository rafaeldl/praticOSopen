# WEB_API.md

## Visão Geral

O app web (SPA em `/app`) grava dinheiro, situação e itens da OS pela API `/v1/app`, para existir uma única versão das regras: a do servidor, igual à do app Flutter (`lib/mobx/order_store.dart`, `lib/utils/order_payment_math.dart`, `lib/services/authorization_service.dart`). Os casos em `docs/web-app/contract-cases/` provam que servidor, app e web decidem igual.

O app Flutter não chama estas rotas de OS (só `share` e `charges`, montadas no mesmo caminho). Por isso elas podem mudar sem quebrar versões instaladas. Bot e MCP continuam usando `POST /:id/services` e `/:id/products`, que passam pela mesma lógica.

Especificação completa dos corpos e respostas: `docs/api-spec.yaml` (tag `App Orders`).

## Arquitetura

| Parte | Onde |
|---|---|
| Rotas de OS | `firebase/functions/src/routes/v1/orders.routes.ts` |
| Rotas de recibo | `firebase/functions/src/routes/v1/customer-payments.routes.ts` |
| Itens, situação, pagamento | `services/order.service.ts` |
| Regras puras de itens e totais | `services/order-items.ts` |
| Tirar pagamento, zerar, marcar pago, comprovante | `services/order-finance.service.ts` |
| Apagar OS | `services/order-delete.service.ts` |
| OS parada | `services/order-hold.service.ts` |
| Recibos | `services/customer-receipt.service.ts` |
| O que sai do servidor | `services/order-projection.ts` |
| Quem pode | `middleware/app-permission.middleware.ts` |
| Limite de taxa e CORS | `utils/app-rate-limit.utils.ts` |

### Chamada

```
Authorization: Bearer <Firebase ID token>
X-Company-Id: <companyId>
Content-Type: application/json
```

O servidor confere se o usuário é membro da empresa (`resolveCompanyContext`). O papel vem do servidor, nunca do cliente.

Limite de taxa: 300 pedidos por minuto por usuário, contados depois de conferir o token (um escritório divide o mesmo IP), e 1.500 por minuto por IP antes do token.

## Regras de cada escrita

1. **Transação.** Toda escrita que lê a OS roda numa transação do Firestore e confere a permissão de novo na OS fresca (`guard`). Duas pessoas salvando ao mesmo tempo não perdem item uma da outra.
2. **`expectedUpdatedAt` (opcional).** O `updatedAt` que o cliente viu. Se a OS mudou desde então, a resposta é `409 ORDER_CHANGED` e nada é gravado: o cliente recarrega e mostra a versão nova. Vale em `PATCH /:id` e nas rotas de itens. No `DELETE`, vai na query string.
3. **Total do servidor.** O cliente nunca manda o total da OS. Total = soma dos itens com preço − desconto, arredondado ao centavo, nunca abaixo de 0. Produto vale o `total` da linha quando existe, senão `value × quantity`.
4. **Item sem preço.** `value: null` fica "sem valor" e fora do total. Nunca vira 0.
5. **Pago / a pagar.** Segue o total novo. Orçamento e cancelada não têm situação de pagamento (`payment: null`). Quando a situação muda só porque o total mudou, o servidor marca `paymentSyncedAt`, e o gatilho da OS não emite nota "na hora em que for pago" (não entrou dinheiro).
6. **Pagamento até o que falta.** `POST /:id/payments` recusa valor acima do que falta receber, comparando em centavos dentro da transação: `409 PAYMENT_EXCEEDS_BALANCE`, com `error.remainingBalance` (o saldo atual). Assim, web e app recebendo ao mesmo tempo não passam do total. OS de valor 0 não recebe pagamento solto: use `mark-paid`. `mark-paid` lança só o que falta e o recibo do cliente já recusa acima do aberto (`VALUE_EXCEEDS_BALANCE`). Pagamento que chega do Asaas é sempre gravado.
7. **Repetir sem gravar em dobro (`clientTransactionId`).** `POST /:id/payments` e `POST /:id/discounts` aceitam um `clientTransactionId` opcional: um uuid gerado pelo cliente (letras, números e hífen, 8 a 64). Ele vira o `id` da transação. Se a OS já tem uma transação com esse id, nada é gravado e a resposta traz o estado atual com o mesmo `transactionId` (duplo clique, nova tentativa depois de queda de rede). Mesmo id com outro tipo ou valor → `409 TRANSACTION_ID_CONFLICT`. O cliente gera um id novo para cada pagamento que o usuário pede, e reusa o mesmo só ao repetir o envio.
8. **Data e comprovante.** `paidAt` não pode estar no futuro (folga de 5 minutos de relógio) nem antes do dia em que a OS foi criada (folga de 24 h pelo fuso). O comprovante (`receiptFile`) fica na pasta da OS (`tenants/{companyId}/orders/{orderId}/`, ou do recibo), e a `url` tem de ser a URL de download desse mesmo arquivo no bucket do projeto (`firebasestorage.googleapis.com/v0/b/{bucket}/o/…` ou `storage.googleapis.com/{bucket}/…`).
9. **Arquivo apagado só da pasta do pagamento.** Ao tirar pagamento, zerar ou trocar comprovante, o servidor só apaga do Storage o comprovante dentro da pasta daquele pagamento (`tenants/{companyId}/orders/{orderId}/payments/{transactionId}/`). Outro caminho em `documents` é mantido e registrado em log.
10. **Valores escondidos.** Sem `viewPrices` (técnico, supervisor, ou "Valores e cobrança" desligado) nenhum valor sai do servidor: total, valor e total da linha, preço de catálogo dentro da linha, pagamentos, situação de pagamento, comprovantes. Vale para lista, detalhe e respostas de escrita.

### Identificador de item e de pagamento

Cada linha da resposta tem `id`. Linhas gravadas pela API guardam um `id` próprio. O app não guarda esse campo, então linhas sem ele recebem um id derivado do que a linha é (serviço/produto, item do catálogo, descrição, valores, aparelho) e da posição entre linhas iguais. Ele não muda quando outras linhas entram ou saem; quando a própria linha muda, o id antigo deixa de achar a linha (`404 ITEM_NOT_FOUND`) e o cliente recarrega. Pagamentos antigos sem `id` seguem a mesma ideia (`legacy_…`).

## Rotas

Base: `/v1/app/orders` (OS) e `/v1/app/customers` (recibos).

| Rota | Quem | Observação |
|---|---|---|
| `GET /orders` | todos | Quem tem `viewAllOrders` vê todas; consultor e técnico, as que criaram; o técnico com `assignedTo=<o próprio uid>` recebe as atribuídas a ele, criadas por qualquer um (como `isOrderAssignee` nas regras). Cursor, filtros e ordem abaixo |
| `GET /orders/:id` | quem vê a OS | O técnico também vê a OS atribuída a ele |
| `POST /orders` | `createOrder` | Situação inicial por papel; valor próprio exige `editPrices`; grava `deviceIds`. `clientOrderId` opcional (uuid do cliente, mesmo formato do `clientTransactionId`) vira o id da OS: repetir devolve a OS já criada (200, sem criar outra); se outra pessoa criou com esse id → `409 ORDER_ID_CONFLICT` |
| `PATCH /orders/:id` | `editOrder` | Situação: fluxo por papel. Datas: `canEditOrderMainFields` (supervisor e técnico só em orçamento). Responsável: `assignOrder`, nome lido do membro. `null` limpa |
| `DELETE /orders/:id` | `canDeleteOrder` | Mesma regra de `order-delete.json`. Ver "Apagar" |
| `POST /orders/:id/items` | main fields | `{kind, catalogId?, value?, quantity?, total?, description?, deviceId?}`. Valor ou total próprio exige `editPrices`. Sem `catalogId` é item avulso: `description` obrigatória, `service`/`product` gravado como `null` (como o app), sem valor fica "sem valor" |
| `PATCH /orders/:id/items/:itemId` | main fields; só `description`: quem vê a OS | Supervisor e técnico mudam a observação depois de aprovada |
| `DELETE /orders/:id/items/:itemId` | main fields | |
| `POST /orders/:id/services`, `/products` | main fields | Para bot, MCP e integrações; respondem `{success, newTotal}` |
| `POST /orders/:id/payments` | `canReceiveOnOrder` | `{amount, paidAt?, paymentMethod?, receiptFile?, description?, clientTransactionId?}`. Desconto aqui → 400 |
| `DELETE /orders/:id/payments/:transactionId` | `canReceiveOnOrder` | Pagamento do Asaas → `409 ASAAS_LOCKED`; parte de recibo → `409 RECEIPT_SHARE` |
| `POST /orders/:id/payments/mark-paid` | `canReceiveOnOrder` | Lança o que falta e marca paga (OS de valor 0 também) |
| `POST /orders/:id/payments/reset` | financeiro | Tira pagamentos e descontos feitos à mão; os do Asaas ficam |
| `PUT`/`DELETE /orders/:id/payments/:transactionId/receipt` | `canReceiveOnOrder` | Comprovante em `tenants/{companyId}/orders/{orderId}/…` |
| `POST /orders/:id/discounts` | financeiro | `{amount, description?, clientTransactionId?}`. Nunca acima do que falta |
| `DELETE /orders/:id/discounts/:transactionId` | financeiro | |
| `DELETE /orders/:id/discounts` | financeiro | Tira todo o desconto, também o que não tem transação |
| `POST /orders/:id/hold` | não consultor | `{reason, note?}`; só aprovada ou em andamento (`409 HOLD_NOT_ALLOWED`) |
| `DELETE /orders/:id/hold` | não consultor | Em qualquer situação; sem marca, nada muda |
| `GET /customers/:id/receipts` | quem recebe | Financeiro vê todos; consultor, os que registrou |
| `POST /customers/:id/receipts/:receiptId/cancel` | financeiro ou quem registrou | Desfaz: tira a parte de cada OS e marca `canceled`. Parte antiga sem id de transação (ou que não está mais na OS) → `409 RECEIPT_LEGACY_SHARE`, nada muda |
| `PUT`/`DELETE /customers/:id/receipts/:receiptId/file` | financeiro ou quem registrou | Comprovante em todas as OS do recibo |

**Quem recebe (`canReceiveOnOrder`)**: dono, admin e gerente em qualquer OS; consultor nas OS que criou, com "Valores e cobrança" ligado. Supervisor e técnico nunca. Igual a `canReceiveOnOrderFor` no app e a `canReceiveOnOrder` nas regras do Firestore.

**Financeiro**: `viewFinancialReports` (dono, admin, gerente), com "Valores e cobrança" ligado.

### Lista

`GET /orders?limit=20&cursor=<id>&status=approved,progress&sort=createdAt&direction=desc`

- `limit` até 100; `cursor` é o `pagination.nextCursor` da página anterior.
- `status`: uma ou várias situações separadas por vírgula.
- `sort`: `createdAt` (padrão, mais nova primeiro), `updatedAt`, `number`, `dueDate`, `scheduledDate` (estas duas, mais próxima primeiro). OS sem o campo da ordem ficam fora.
- Filtros: `customerId`, `deviceId`, `assignedTo`, `startDate`/`endDate` (em `createdAt`, só com `sort=createdAt`).
- Combinação sem índice no Firestore → `400 UNSUPPORTED_QUERY`.
- `pagination.total` só na primeira página.

### Apagar

1. Papel: `canDeleteOrder` (admin sempre; gerente e supervisor em orçamento sem dinheiro; consultor e técnico no orçamento sem dinheiro que criaram).
2. Nota fiscal ativa → `409 ORDER_HAS_INVOICE`.
3. Cobrança de várias OS aberta → `409 CUSTOMER_CHARGE_OPEN` (ela cobre outras OS: quem decide é o usuário).
4. Parcelamento com parcela paga → `409 INSTALLMENTS_IN_PROGRESS`.
5. Com cobrança aberta só desta OS, o papel é conferido de novo na OS fresca antes de cancelar qualquer coisa (se entrou dinheiro e o papel não pode mais apagar, recusa e a cobrança fica). Depois a cobrança é cancelada no Asaas. Se não cancelar, a OS fica (`502 ASAAS_UNAVAILABLE`).
6. A OS sai numa transação (o papel é conferido mais uma vez), depois comentários, formulários, fotos, cobranças, arquivos e links do cliente.

## Erros

`{ "success": false, "error": { "code": "…", "message": "…" } }`

| Código | HTTP | Quando |
|---|---|---|
| `VALIDATION_ERROR` | 400 | Corpo inválido |
| `INVALID_DEVICE` | 400 | Aparelho do item não está na OS |
| `INVALID_ASSIGNEE` | 400 | Responsável não é da empresa |
| `INVALID_CURSOR`, `UNSUPPORTED_QUERY` | 400 | Lista |
| `INVALID_FILE`, `INVALID_PAID_AT` | 400 | Comprovante fora da pasta, de outro bucket ou tipo errado; data inválida, no futuro ou antes da OS |
| `INSUFFICIENT_PERMISSIONS`, `FORBIDDEN` | 403 | Papel |
| `NOT_FOUND`, `ITEM_NOT_FOUND`, `TRANSACTION_NOT_FOUND`, `RECEIPT_NOT_FOUND` | 404 | |
| `ORDER_CHANGED` | 409 | `expectedUpdatedAt` diferente |
| `ASAAS_LOCKED`, `RECEIPT_SHARE`, `RECEIPT_CANCELED`, `RECEIPT_LEGACY_SHARE`, `HOLD_NOT_ALLOWED` | 409 | Ver rotas |
| `TRANSACTION_ID_CONFLICT` | 409 | `clientTransactionId` já usado com outro tipo ou valor |
| `PAYMENT_EXCEEDS_BALANCE` | 409 | Pagamento acima do que falta; `error.remainingBalance` traz o saldo |
| `ORDER_ID_CONFLICT` | 409 | `clientOrderId` de OS criada por outra pessoa |
| `ORDER_HAS_INVOICE`, `CUSTOMER_CHARGE_OPEN`, `INSTALLMENTS_IN_PROGRESS` | 409 | Apagar |
| `ASAAS_UNAVAILABLE` | 502 | Não deu para cancelar a cobrança aberta |
| `RATE_LIMIT_EXCEEDED` | 429 | |

## Regras de Negócio (decisões)

- `done` não é mais gravado: o app não grava e ninguém lê; `status` é a fonte.
- Mudar a situação de OS antiga paga antes de existir `paidAmount` mantém a situação de pagamento (igual a `syncPaymentStatusWithTotal`).
- Pagamento e desconto acima do que falta são recusados em `POST /payments` e `POST /discounts`. O app ainda aceita pagamento a mais (`divergesIn.dart` em `payment-transactions.json`).
- Marcar e retomar OS parada deixam o mesmo comentário interno do app.
- Desfazer recibo não apaga o arquivo do comprovante, que é do recibo.
- Quantidade de produto é inteira (o app lê como inteiro).

## Exemplos de Uso

```bash
# Adicionar um serviço e não sobrescrever quem salvou antes
curl -X POST "$API/v1/app/orders/$ORDER/items" \
  -H "Authorization: Bearer $TOKEN" -H "X-Company-Id: $COMPANY" \
  -H "Content-Type: application/json" \
  -d '{"kind":"service","catalogId":"s1","expectedUpdatedAt":"2026-11-03T10:00:00.000Z"}'

# Receber R$ 50 em Pix com comprovante
curl -X POST "$API/v1/app/orders/$ORDER/payments" \
  -H "Authorization: Bearer $TOKEN" -H "X-Company-Id: $COMPANY" \
  -H "Content-Type: application/json" \
  -d '{"amount":50,"paymentMethod":"pix","paidAt":"2026-11-03T12:00:00.000Z","clientTransactionId":"'$(uuidgen)'",
       "receiptFile":{"url":"https://firebasestorage.googleapis.com/v0/b/<bucket>/o/<storagePath codificado>?alt=media&token=…","storagePath":"tenants/'$COMPANY'/orders/'$ORDER'/payments/x/comprovante.jpg","contentType":"image/jpeg"}}'
```

## Testes

| Arquivo | Cobre |
|---|---|
| `firebase/functions/src/routes/v1/__tests__/orders.routes.test.ts` | Rotas, transações concorrentes, `expectedUpdatedAt`, projeção, outra empresa |
| `firebase/functions/src/__tests__/rbac/api-matrix.ts` + `rbac-api.test.ts` | Papel × rota |
| `firebase/functions/src/__tests__/contract-cases.test.ts` | `docs/web-app/contract-cases/*.json` no servidor |
| `firebase/functions/src/utils/app-rate-limit.utils.test.ts` | Limite por usuário e CORS |
| `firebase/functions/src/services/asaas/__tests__/order-trigger.service.test.ts`, `invoice.service.test.ts` | Nota automática uma vez só |
