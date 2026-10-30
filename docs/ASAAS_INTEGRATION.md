# Integração Asaas

> Status: **etapa 1 (núcleo de cobrança) implementada, pronta para o piloto** (issue #303). Blocos A–E na `master` (Bloco E: botão "Pagar" no link da OS, PR #315, mergeado).
> Spec: [`docs/superpowers/specs/2026-10-04-asaas-cobranca-os-design.md`](superpowers/specs/2026-10-04-asaas-cobranca-os-design.md).
> Estratégia e parceria: [`business/PARCERIAS.md`](../business/PARCERIAS.md).

## Visão Geral

O técnico cobra o cliente da OS por Pix, boleto ou cartão (à vista, ou parcelado no cartão em 2–12x) pela conta Asaas da própria empresa. O cliente paga pelo link da OS (`/q/{token}`, botão "Pagar"). Quando o Asaas confirma o pagamento, um webhook lança o pagamento na OS e dá baixa automática.

Etapas seguintes (specs próprias): criar a empresa e importar clientes a partir da conta Asaas (etapa 2) e distribuição pela **Flapp Store**, a loja de apps dentro da conta Asaas (etapa 3). Fora do escopo atual: split para a Rafsoft, cliente escolher o número de parcelas.

**Nota fiscal de serviço (NFS-e)**: pronta atrás da flag `nfseEnabled` (desligada por padrão), ver [`NFSE_ASAAS.md`](NFSE_ASAAS.md).

## Ambientes

| Ambiente | Painel | API base | Fatura |
|----------|--------|----------|--------|
| Sandbox | https://sandbox.asaas.com | `https://api-sandbox.asaas.com/v3` | `https://sandbox.asaas.com/i/{id}` |
| Produção | https://www.asaas.com | `https://api.asaas.com/v3` | `https://www.asaas.com/i/{id}` (presumido; conferir na primeira cobrança real) |

- Autenticação: header `access_token: <chave>` + `User-Agent` identificando o PraticOS.
- Chaves de sandbox começam com `$aact_hmlg`; de produção, com `$aact_prod`. O ambiente da conexão é inferido desse prefixo (chave sem um dos dois prefixos é recusada). Em `.env`, usar aspas simples por causa do `$`.
- Chaves sem uso por 3 meses são desabilitadas pelo Asaas.
- Documentação oficial: https://docs.asaas.com (também via MCP `asaas` no Claude Code).

Confirmado no sandbox (E2E, 2026-10-04):

- O Asaas aceita cliente com **CNPJ alfanumérico** (`12ABC34501DE35`, exemplo oficial da Receita).
- O webhook chega com o token no header `asaas-access-token`.
- No parcelamento no cartão, cada parcela tem a própria `invoiceUrl`; a fatura da primeira mostra o plano inteiro (é a que a cobrança guarda).
- Cobrança recebida não pode ser apagada no sandbox: cada execução do E2E deixa uma cobrança paga de R$ 10 na conta de teste.

## Arquitetura

```
App ──► /v1/app/payments/asaas/*   ──► Asaas API (conta da empresa)
App ──► /v1/app/orders/:id/charges ─┘          │
                                               ▼
Firestore ◄── /webhooks/asaas/:companyId ◄── webhook (PAYMENT_*)
   │
   └── trigger onOrderUpdatedAsaas (orders onUpdate)
Link /q/{token} ◄── /public/orders/:token (cobrança aberta ou última paga + invoiceUrl)
```

Todas as chamadas ao Asaas saem das Cloud Functions (`api`). O app nunca guarda a chave: ela vai direto para o endpoint de conexão e fica só no backend, criptografada.

| Peça | Arquivo |
|------|---------|
| Tipos | `firebase/functions/src/models/asaas.types.ts` |
| Criptografia da credencial e hash de token | `firebase/functions/src/services/asaas/crypto.ts` |
| Cliente HTTP do Asaas | `firebase/functions/src/services/asaas/asaas-client.ts` |
| Credencial por empresa (`AsaasCredentialProvider`; hoje `ApiKeyCredentialProvider`) | `firebase/functions/src/services/asaas/credential-provider.ts` |
| Códigos de erro → HTTP | `firebase/functions/src/services/asaas/errors.ts` |
| Conectar/desconectar | `firebase/functions/src/services/asaas/connection.service.ts`, `src/routes/v1/asaas-connection.routes.ts` |
| Cobranças | `firebase/functions/src/services/asaas/charge.service.ts`, `src/routes/v1/charges.routes.ts` |
| Lançar/estornar pagamento na OS, reparo | `firebase/functions/src/services/asaas/order-payment.service.ts` |
| Webhook | `firebase/functions/src/services/asaas/webhook.service.ts`, `src/routes/webhooks/asaas.routes.ts` |
| Trigger de OS | `firebase/functions/src/services/asaas/order-trigger.service.ts` (`onOrderUpdatedAsaas` em `src/index.ts`) |
| App | `lib/services/asaas_api_service.dart`, `lib/models/order_charge.dart`, `lib/models/payment_settings.dart`, `lib/screens/integrations/`, `lib/screens/payments/` |
| Link público (Bloco E) | `firebase/functions/src/routes/public/orders.routes.ts`, `firebase/web/components/order/OrderChargeAction.vue`, `firebase/web/utils/charge.ts` |

Segredo e configuração das Functions:

- `ASAAS_CREDENTIALS_KEY`: chave mestra no Secret Manager, via `defineSecret`, ligada às functions que leem ou gravam `private/asaas` (`api` e `onOrderUpdatedAsaas`).
- `ASAAS_WEBHOOK_BASE_URL`: base da URL do webhook. Default no código: `https://southamerica-east1-praticos.cloudfunctions.net/api` (o deploy do CI não lê `.env` local). Sobrescrever só em dev.
- `ASAAS_SANDBOX_API_KEY`: só para o script E2E (`.env.local`).

## Endpoints

Rotas `/v1/app/*` usam `bearerAuth` + `resolveCompanyContext`; o app envia `X-Company-Id`. Respostas no formato `{ success, data }` ou `{ success: false, error: { code, message } }`.

| Método | Rota | Permissão | Comportamento |
|--------|------|-----------|---------------|
| GET | `/v1/app/payments/asaas/settings` | owner/admin | Devolve `settings/payments` |
| POST | `/v1/app/payments/asaas/connect` `{ apiKey }` | owner/admin + `asaasEnabled` | Infere o ambiente pelo prefixo, valida a chave no Asaas (`/myAccount/commercialInfo`), lê a carteira, cadastra o webhook, criptografa e salva em `private/asaas`, grava `settings/payments`. Reconectar troca a credencial e remove o webhook anterior. Chave inválida → `ASAAS_INVALID_API_KEY` sem gravar nada |
| DELETE | `/v1/app/payments/asaas/connect` | owner/admin | Remove o webhook no Asaas, apaga `private/asaas` com as subcoleções (mapa de clientes, eventos), `asaasConnected=false`. Cobranças abertas continuam no Asaas, sem baixa automática |
| POST | `/v1/app/orders/:orderId/charges` `{ value, mode, installmentCount?, dueDate?, customerTaxId? }` | `manage:payments` (owner/admin/manager) | Ver "Gerar cobrança". Resposta 201 com a cobrança |
| DELETE | `/v1/app/orders/:orderId/charges/:chargeId` | `manage:payments` | Cancela no Asaas (`DELETE /payments/{id}` ou `/installments/{id}`; 404 no Asaas conta como cancelada), `status=canceled` |
| POST | `/v1/app/customers/:customerId/charges` `{ orderIds, value, dueDate?, customerTaxId? }` | `manage:payments` | Uma cobrança para várias OS do cliente. Ver "Cobrança de várias OS" |
| DELETE | `/v1/app/customers/:customerId/charges/:chargeId` | `manage:payments` | Cancela a cobrança de várias OS (como a de uma OS) |
| GET | `/v1/app/customers/:customerId/open-orders` | quem recebe (owner/admin/manager/consultor, com `useFinancial`) | OS em aberto do cliente: só `id`, `number`, `open`, `createdAt`, `own`. Mais antiga primeiro |
| POST | `/v1/app/customers/:customerId/receipts` `{ receiptId, paidAt, allocations, receiptFile? }` | quem recebe | Recebimento em várias OS do cliente feito pelo servidor (consultor com OS de outra pessoa). Ver "Receber em OS de outra pessoa (consultor)" em `docs/FINANCEIRO.md` |
| POST | `/webhooks/asaas/:companyId` | header `asaas-access-token` | Ver "Webhook" |
| GET | `/public/orders/:token` | share token | Bloco E: inclui `charge` (ver "Link da OS") |

### Gerar cobrança

1. Conta conectada (`ASAAS_NOT_CONNECTED`), OS existe e não está cancelada (`ORDER_CANCELED`).
2. `0 < value <= total - paidAmount` (tolerância de meio centavo; o `total` já é líquido de desconto) → senão `INVALID_VALUE`. Cartão parcelado: 2–12 parcelas (`INVALID_INSTALLMENT_COUNT`). Vencimento `YYYY-MM-DD`, hoje ou depois no fuso de São Paulo, default hoje + 3 dias (`INVALID_DUE_DATE`).
3. Cliente da OS obrigatório (`CUSTOMER_REQUIRED`). CPF/CNPJ: o `customerTaxId` enviado é validado e gravado no cadastro do cliente; sem ele, usa o `taxId` do cadastro (`TAX_ID_REQUIRED` / `INVALID_TAX_ID`). Aceita CNPJ alfanumérico.
4. Se a OS tem parcelamento aberto com parcela já paga → `INSTALLMENTS_IN_PROGRESS` (uma nova cobrança poderia cobrar em dobro).
5. Find-or-create do cliente no Asaas (`externalReference` = id do cliente, `notificationDisabled: true`); o mapa fica em `private/asaas/customers` e só é reaproveitado na mesma conta/ambiente.
6. Cria a cobrança no Asaas: à vista com `billingType: UNDEFINED` (o cliente escolhe Pix, boleto ou cartão) ou `CREDIT_CARD` com `installmentCount` + `totalValue`. Descrição `OS #{número} - {empresa}`, `externalReference = {companyId}:{orderId}:{chargeId}`.
7. Grava o doc em `charges` (se falhar, cancela a cobrança órfã no Asaas). Só **depois** cancela a cobrança aberta anterior, para uma recusa do Asaas nunca matar um link já enviado; se a anterior não puder ser cancelada, desfaz a nova.

### Cobrança de várias OS

"Mandar cobrança" em "Receber de João" (`customer-charge.service.ts`). O Asaas não tem itens nem pagamento parcial de uma cobrança, então é **uma** cobrança do Asaas (valor = total) e a divisão fica no nosso lado:

1. Conta conectada, cliente existe, 1 a 50 OS, todas do cliente (`ORDER_NOT_OF_CUSTOMER`), nenhuma orçamento ou cancelada (`ORDER_NOT_PAYABLE`), nenhuma com parcelamento já pago (`INSTALLMENTS_IN_PROGRESS`). `0 < value <=` soma do que falta nas OS (`INVALID_VALUE`).
2. Repartição (`allocations`) da mais antiga para a mais nova, cada uma até o que falta na OS: a mesma regra do `allocatePayment` do app (`utils/payment-allocation.ts`).
3. CPF/CNPJ e cliente no Asaas como na cobrança de uma OS. Cobrança à vista (`billingType: UNDEFINED`), descrição `OS 182, 190, 201 - {empresa}` (até 500 caracteres; se passar, termina em "e mais N"), `externalReference = {companyId}:cc:{chargeId}` (um id curto nosso, nunca a lista de OS).
4. Grava `customerCharges/{chargeId}`. **Depois** lê de novo e cancela as cobranças abertas de uma OS só dessas OS e a cobrança de várias OS anterior do cliente, para o cliente nunca ter dois links que pagam a mesma dívida (`replaceRivals`). Ler de novo depois de gravar pega a criação ao mesmo tempo (ex.: o app repete o pedido depois de um erro de rede): **a mais nova vence** (`createdAt` mais recente, depois o id maior) e a mais velha é cancelada; se a nova perde, ela é desfeita e a API responde `CHARGE_SUPERSEDED` (409). Antes de cancelar qualquer uma, confere que todas ainda podem ser canceladas (parcelamento com parcela paga → desfaz a nova, `INSTALLMENTS_IN_PROGRESS`, nada cancelado). Se mesmo assim uma falhar depois de outra já ter sido cancelada, desfaz a nova e responde `PREVIOUS_LINK_CANCELED` (409): o app pede para mandar um link novo.
5. Enquanto uma OS está numa cobrança de várias OS aberta, gerar cobrança só dela é recusado (`CUSTOMER_CHARGE_OPEN`): cancele a de várias OS primeiro. A cobrança de uma OS faz a mesma varredura depois de gravar (cobranças abertas da OS e de várias OS que cobrem a OS; a mais nova vence).

O parsing do `externalReference` aceita os dois formatos: `{cid}:{oid}:{chargeId}` (uma OS) e `{cid}:cc:{chargeId}` (várias OS).

### Recebido por fora com link aberto ("dar baixa")

Quando entra um pagamento manual numa OS que está numa cobrança aberta (Receber da OS ou Receber de João), o servidor ajusta o link (`outside-payment.service.ts`):

| Situação | Ação no Asaas |
|----------|---------------|
| O que ainda falta pelo link é zero e entrou dinheiro nas OS desde que o link foi criado | `POST /v3/payments/{id}/receiveInCash` com o dinheiro que entrou (no máximo o valor da cobrança), `paymentDate` de hoje, `notifyCustomer: false`. Cobrança `paid` + `paidOutside: true` |
| Falta zero mas não entrou dinheiro (desconto, total baixou, OS cancelada) | Cancela o link: nada foi recebido em dinheiro |
| Falta uma parte | `PUT /v3/payments/{id}` com o que falta (só `PENDING`/`OVERDUE`); o link continua o mesmo; na de várias OS, a repartição é refeita. Se o Asaas recusar o valor (ex.: abaixo do mínimo), o link é cancelado, para o cliente nunca pagar mais do que deve |
| Falta tudo ainda | Nada |
| OS voltou a orçamento (mesmo com pagamento à mão) | Cancela o link, nunca dá baixa em dinheiro: orçamento não deve nada |
| Parcelamento no cartão sem parcela paga e a OS passou a dever menos que ele (pago à mão, total baixou, voltou a orçamento) | Antes, `GET /installments/{id}/payments`: se alguma parcela já está `CONFIRMED`/`RECEIVED` (cartão aprovado, webhook a caminho), não faz nada e o webhook lança. Senão cancela o parcelamento (não dá para baixar o valor nem dar baixa em dinheiro, e o cliente pagaria tudo de novo) marca a cobrança `autoCanceled` e deixa um comentário interno na OS: "Parcelamento no cartão de R$ X cancelado: a OS passou a dever R$ Y. Mande um link novo." Se ainda falta dinheiro, a tela Receber mostra "Parcelamento cancelado" com o botão do link novo. |

O que falta pelo link é recalculado das OS (cada parte limitada ao que falta na OS; orçamento e cancelada devem zero). Parcelamento com parcela já paga fica de fora. Cancelar um link só marca a cobrança `canceled` se ela ainda está aberta e sem pagamento lançado (um webhook que chegou no meio mantém o status dele).

O "entrou dinheiro desde que o link foi criado" compara o `createdAt` do pagamento com o do link. O app grava a hora local do celular sem fuso (`2026-10-29T17:39:47.433185`) e o servidor grava UTC (`…Z`): hora sem fuso é lida como horário de Brasília (UTC-3; data sem hora, como meia-noite de Brasília). Celular em outro fuso (Manaus, Acre) fica 1 a 2 h fora. Antes, um pagamento feito até 3 h depois do link contava como anterior e o link era cancelado em vez de receber a baixa em dinheiro.

**Sem lançar em dobro:** antes do `receiveInCash` a cobrança recebe `settlingOutsideAt` e `settlingOutsideValue`; o webhook `PAYMENT_RECEIVED` que o Asaas manda depois (status `RECEIVED_IN_CASH`) é reconhecido por `settlingOutsideAt`/`paidOutside`, não lança nada e limpa a marca. A marca só sai na hora quando o Asaas recusa com certeza (4xx). Timeout, erro de rede ou 5xx deixam o resultado desconhecido (o Asaas pode ter dado a baixa): a marca fica, o servidor faz `GET /v3/payments/{id}` na hora e, se o Asaas estiver fora, na próxima reconciliação, antes de decidir qualquer coisa. `RECEIVED_IN_CASH` → cobrança `paid` + `paidOutside`; `PENDING`/`OVERDUE` → tira a marca e decide de novo; outro status (pago pelo link, removido) → tira a marca e o webhook segue normal.

**Concorrência:** um lease curto (`adjustingUntil`) na cobrança; quem tem o lease recalcula até nada mudar. Quem encontra o lease tomado incrementa `dirtyCount`/`dirtyAt` e sai; antes de soltar o lease, quem o tem confere se `dirtyCount` mudou desde a última leitura e, se mudou, roda de novo (no máximo 5 rodadas). Assim um pagamento gravado depois da leitura de quem tem o lease nunca fica sem ajuste.

**Por que trigger e não chamada do app:** roda no `onOrderUpdatedAsaas` quando `transactions`, `total` ou `status` da OS mudam. Assim cobre também o pagamento registrado offline (chega ao servidor quando o celular sincroniza) e o "Receber de João" em lote, sem o app precisar de conexão no momento de receber e sem depender de versão nova do app.

### Códigos de erro

`errors.ts`: `ASAAS_NOT_ENABLED` (403), `ASAAS_INVALID_API_KEY` (400), `ASAAS_NOT_CONNECTED` (409), `ASAAS_VALIDATION_ERROR` (400, recusa do Asaas com a descrição dele), `ASAAS_UNAVAILABLE` (502, Asaas fora ou timeout), `ORDER_NOT_FOUND` (404), `ORDER_CANCELED` (409), `INVALID_VALUE`, `INVALID_INSTALLMENT_COUNT`, `INVALID_DUE_DATE`, `CUSTOMER_REQUIRED`, `TAX_ID_REQUIRED`, `INVALID_TAX_ID` (400), `CHARGE_NOT_FOUND` (404), `CHARGE_NOT_OPEN`, `INSTALLMENTS_IN_PROGRESS` (409). Várias OS e recebimento pelo servidor: `CUSTOMER_NOT_FOUND` (404), `ORDER_NOT_OF_CUSTOMER`, `INVALID_PAID_AT`, `INVALID_FILE` (400), `ORDER_NOT_PAYABLE`, `CUSTOMER_CHARGE_OPEN`, `VALUE_EXCEEDS_BALANCE`, `RECEIPT_EXISTS`, `CHARGE_SUPERSEDED` (outro link para a mesma dívida criado ao mesmo tempo ficou valendo), `PREVIOUS_LINK_CANCELED` (um link anterior foi cancelado e o novo foi desfeito: mandar um link novo) (409). `receiptId` começando com `asaas_` é recusado (`INVALID_VALUE`): o prefixo é dos recebimentos do Asaas. Validação do corpo → `VALIDATION_ERROR`; papel sem permissão → `FORBIDDEN`; erro inesperado → `INTERNAL_ERROR`.

## Modelo de dados (Firestore)

| Caminho | Acesso | Conteúdo |
|---------|--------|----------|
| `companies/{cid}/private/asaas` | só servidor | `mode` (`apiKey`\|`flapp`), `environment` (`sandbox`\|`production`), `encryptedApiKey` (criptografada), `accountName`, `walletId?`, `webhookId?`, `webhookTokenHash?` (hash), `status` (`active`\|`invalid`), `connectedBy`, `connectedAt` |
| `companies/{cid}/private/asaas/customers/{customerId}` | só servidor | `{ asaasCustomerId, environment?, walletId? }` |
| `companies/{cid}/private/asaas/events/{eventId}` | só servidor | `{ processedAt, expiresAt }`: idempotência do webhook, TTL de 30 dias em `expiresAt` |
| `companies/{cid}/settings/payments` | leitura membros, escrita servidor | `asaasEnabled` (piloto, só via script), `asaasConnected`, `asaasAccountName?`, `asaasEnvironment?` |
| `companies/{cid}/orders/{oid}/charges/{chargeId}` | leitura owner/admin/manager, escrita servidor | `asaasPaymentId`, `asaasInstallmentId?`, `mode` (`single`\|`cardInstallments`), `installmentCount?`, `value`, `dueDate` (YYYY-MM-DD), `status` (`pending`\|`paid`\|`overdue`\|`canceled`\|`refunded`), `invoiceUrl`, `paidAsaasPaymentIds`, `createdBy`, `createdAt`, `paidAt?`; só servidor: `appliedTransactions`, `refundedAsaasPaymentIds` |
| `companies/{cid}/customerCharges/{chargeId}` | leitura como `charges` (owner/admin/manager), escrita servidor | Cobrança de várias OS: `customer {id, name}`, `asaasPaymentId`, `value`, `dueDate`, `status`, `invoiceUrl`, `orderIds` (para `array-contains`), `allocations [{orderId, orderNumber, amount}]` (mais antiga primeiro, soma = `value`), `paidAsaasPaymentIds`, `createdBy`, `createdAt`, `paidAt?`, `receiptId?`, `paidOutside?`; só servidor: `appliedTransactions`, `refundedAsaasPaymentIds`, `settlingOutsideAt`, `settlingOutsideValue`, `adjustingUntil`, `dirtyCount`, `dirtyAt` |
| `companies/{cid}/receipts/asaas_{paymentId}` | como os recebimentos | Recebimento criado pelo webhook quando uma cobrança de várias OS é paga (`createdBy` = Asaas), para a tela "Recebimento" e o recibo funcionarem. O app e a API não criam recebimento com id `asaas_*` (regra de `receipts` e `customer-receipt.service.ts`); o app usa ids automáticos do Firestore |
| `Customer.taxId` / `CustomerAggr.taxId` | app | CPF/CNPJ normalizado: dígitos e, no CNPJ alfanumérico, letras maiúsculas |

Na OS, cada pagamento Asaas é uma `PaymentTransaction` com `id = asaas_{paymentId}` e `type: payment` (nunca um tipo novo: versões antigas do app quebram com valor desconhecido). Campos opcionais e aditivos (só em transações `asaas_*`, gravados pelo webhook): `billingType` (`PIX` | `BOLETO` | `CREDIT_CARD` | `DEBIT_CARD`...) e `receiptUrl` (o `transactionReceiptUrl` do Asaas; só é gravado se for `https` em `asaas.com` ou subdomínio). Versões antigas do app ignoram esses campos; transações antigas não os têm e o app cai na descrição ("Asaas • Pix"). O status de pagamento da OS continua `paid` | `unpaid` (o "parcial" é calculado no app).

**As cobranças são a fonte da verdade** dos pagamentos Asaas da OS: `paidAsaasPaymentIds` lista o que foi lançado e `appliedTransactions` guarda uma cópia de cada transação, usada pelo reparo.

Na cobrança de várias OS, cada OS recebe a sua parte como `asaas_{paymentId}_{n}` (`type: payment`, `receiptGroupId = asaas_{paymentId}`); o prefixo `asaas_` mantém a transação travada no app como qualquer pagamento Asaas.

As consultas novas (`customerCharges` por `customer.id` e por `orderIds array-contains`, OS por `customer.id`) usam um filtro só e não pedem índice composto.

Índices (`firebase/firestore.indexes.json`): `charges.asaasInstallmentId` com escopo de collection group (o webhook acha a cobrança pelo id do parcelamento quando falta `externalReference`) e TTL em `events.expiresAt`.

## Webhook e baixa na OS

- URL por empresa: `{ASAAS_WEBHOOK_BASE_URL}/webhooks/asaas/{companyId}`, cadastrada na conexão com `sendType: SEQUENTIALLY`, `apiVersion: 3`, um `authToken` aleatório próprio da empresa (guardado só como hash) e os eventos `PAYMENT_RECEIVED`, `PAYMENT_CONFIRMED`, `PAYMENT_OVERDUE`, `PAYMENT_REFUNDED`, `PAYMENT_DELETED`, `PAYMENT_RECEIVED_IN_CASH_UNDONE` e `PAYMENT_PARTIALLY_REFUNDED`, mais os eventos de nota fiscal `INVOICE_CREATED`, `INVOICE_UPDATED`, `INVOICE_SYNCHRONIZED`, `INVOICE_AUTHORIZED`, `INVOICE_PROCESSING_CANCELLATION`, `INVOICE_CANCELED`, `INVOICE_CANCELLATION_DENIED` e `INVOICE_ERROR` (tratados em `invoice.service.ts`, ver [`NFSE_ASAAS.md`](NFSE_ASAAS.md#webhook)). A lista assinada fica em `private/asaas.webhookEvents`. **Empresas conectadas antes desta versão** continuam com o webhook antigo (sem os eventos novos) até reconectar a conta; a nota fiscal responde `NFSE_RECONNECT_NEEDED` para elas.
- Autenticação pelo header `asaas-access-token`. Token ausente ou inválido → 401. Evento sem `id`/`event` → 400.
- Endpoint com limite de requisições por empresa + IP.
- Idempotência por `event.id` em `private/asaas/events`, gravado só depois do processamento dar certo. Erro interno → 500, o Asaas reenvia. Eventos que nunca vão dar certo (cobrança inexistente, `externalReference` de outra empresa, evento não tratado) são registrados e respondidos com 200 para não travar a fila `SEQUENTIALLY`.
- A cobrança é localizada pelo `externalReference`; sem ele, pelo `asaasInstallmentId` da parcela.
- O payload, a chave e o token nunca são logados (só ids e nome do evento).

| Evento | Efeito |
|--------|--------|
| `PAYMENT_RECEIVED` / `PAYMENT_CONFIRMED` | Em transação Firestore, lança `asaas_{payment.id}` (valor bruto pago pelo cliente) com descrição "Asaas • Pix" / "Asaas • Boleto" / "Asaas • Cartão 2/3", `billingType` e, quando o payload traz, `receiptUrl`; recalcula `paidAmount`, `paid` e `payment`. Se o pagamento já foi lançado (ex.: cartão chega como CONFIRMED sem comprovante e depois RECEIVED com ele), só completa `receiptUrl`/`billingType` que faltam na OS e na cópia da cobrança, sem mexer em valores nem em `updatedAt` e nunca trocando um valor já gravado. A cobrança vira `paid` quando todas as parcelas foram lançadas. Push "Pagamento recebido" para dono/admin/gerente. Pagamento que chega numa cobrança `canceled` é lançado mesmo assim (o dinheiro entrou) |
| `PAYMENT_OVERDUE` | `overdue` (se `pending`) |
| `PAYMENT_REFUNDED` | Remove `asaas_{payment.id}` da OS, recalcula, cobrança `refunded`, comentário interno no histórico da OS. O id vai para `refundedAsaasPaymentIds` e nunca é lançado de novo |
| `PAYMENT_DELETED` | `canceled` (se `pending`/`overdue` e sem parcela paga; parcelamento parcialmente pago mantém o status) |
| `PAYMENT_RECEIVED_IN_CASH_UNDONE` | Se a cobrança foi quitada pelo próprio servidor (`paidOutside`), volta a ficar aberta (`pending`, ou `overdue` se o vencimento passou). Se era um pagamento lançado (baixa em dinheiro marcada no painel do Asaas), fica como está e vai para o log com `ALERT`, para uma pessoa decidir |
| `PAYMENT_PARTIALLY_REFUNDED` | Nada muda nas OS (o Asaas não diz de qual OS sai o dinheiro); registrado no log para lançar à mão |

Cobrança de várias OS (`externalReference` `{cid}:cc:{id}`, `customer-charge-payment.service.ts`):

| Evento | Efeito |
|--------|--------|
| `PAYMENT_RECEIVED` / `PAYMENT_CONFIRMED` | Numa transação Firestore: reparte `payment.value` pelas OS da mais antiga para a mais nova, cada uma limitada ao que **falta nela agora** (a parte gravada em `allocations` primeiro, depois o que sobra para as OS que ainda devem; `allocations` pode estar velho se a gravação dela depois de um PUT se perdeu). O que passar do que as OS devem (juros, multa, pago a mais) vai para a última OS, com log. Contas em centavos. lança `asaas_{paymentId}_{n}` em cada OS com `receiptGroupId`, recalcula `paidAmount`/`paid`/`payment`, cria o recebimento `receipts/asaas_{paymentId}` e marca a cobrança `paid` com `receiptId`. Idempotente pelo evento e por `paidAsaasPaymentIds`. Cobrança quitada por fora (`paidOutside`/`settlingOutsideAt`) não lança nada |
| `PAYMENT_REFUNDED` | Tira de cada OS a sua parte, recalcula, recebimento `canceled`, cobrança `refunded` |
| `PAYMENT_OVERDUE` / `PAYMENT_DELETED` | Como na de uma OS |
| `PAYMENT_RECEIVED_IN_CASH_UNDONE` / `PAYMENT_PARTIALLY_REFUNDED` | Como na de uma OS |

OS em orçamento (`quote`) ou cancelada (`canceled`) fica sem status de pagamento (`payment: null`, `paid: false`), como no app; `paidAmount` e transações continuam sendo mantidos.

### Trigger `onOrderUpdatedAsaas`

Único trigger Asaas em `companies/{cid}/orders/{oid}` (onUpdate, lógica em `order-trigger.service.ts`):

- OS passou para `canceled` → cancela no Asaas as cobranças abertas sem parcela paga (só com `asaasConnected`).
- `transactions`, `total` ou `status` mudou → ajusta as cobranças abertas que cobrem a OS (ver "Recebido por fora com link aberto").
- `total` mudou (e `transactions` não) → `syncPaymentStatusWithTotal`, em **qualquer** empresa: `paid`/`payment` seguem o novo total. O salvamento da OS pelo app grava `total` mas nunca os campos de pagamento, então uma OS paga que ganhou um item continuava `paid` e sumia do "Falta receber" do Financeiro. Só grava `paid`/`payment` (sem `updatedAt`), e não mexe em OS antiga sem `paidAmount`.
- `transactions` mudou e a empresa tem `asaasConnected` → `repairAsaasTransactions`: reinsere transações Asaas apagadas por uma versão antiga do app que salvou a OS inteira, remove `asaas_*` estornadas que voltaram, devolve `receiptUrl`/`billingType` que uma versão antiga do app apagou ao salvar (copiando de `appliedTransactions`, sem mexer em `updatedBy`) e corrige `paidAmount`/`paid`/`payment` inconsistentes. Só grava quando algo muda (não entra em loop).

O app novo não envia `transactions`, `paidAmount`, `paid` nem `payment` ao salvar uma OS existente. Pagamento e desconto manuais usam transformações de campo (`arrayUnion`/`increment`, funcionam offline); remover transação, zerar e quitar tudo usam `runTransaction` (pedem conexão).

## Regras Firestore

`customerCharges`: leitura igual a `charges` (`canViewCharges`), escrita só servidor. O consultor continua sem poder escrever em OS de outra pessoa: o recebimento que inclui essas OS passa pelo endpoint do servidor.

- `companies/{cid}/private/**`: negado para o cliente (credencial, mapa de clientes e eventos do webhook).
- `companies/{cid}/settings/payments`: leitura para membros da empresa, escrita só pelo servidor.
- `companies/{cid}/orders/{oid}/charges/{chargeId}`: leitura para dono/admin/gerente (`canViewCharges`), escrita só pelo servidor.
- `companies/{cid}/invoices/{id}` e `companies/{cid}/settings/nfse` (nota fiscal): leitura `canViewCharges`, escrita só pelo servidor.
- Testes automatizados em `firebase/functions/src/__tests__/firestore.rules.test.ts` (`cd firebase/functions && npm run test:rules`, precisa de Java 21+).

## App

### Telas

- **Configurações > Integrações > Asaas** (`lib/screens/integrations/asaas_connection_screen.dart`): passo a passo para gerar a chave de API, campo da chave (oculto, sem sugestões) e botão Conectar. Conectada, mostra a conta e o ambiente (Teste/Produção) e permite desconectar (com confirmação). A chave vai direto para `POST /v1/app/payments/asaas/connect`; o app nunca a guarda.
- **Link para pagar na tela Receber** (`lib/screens/payment_management_screen.dart`, estado em `lib/screens/payments/widgets/order_charge_section.dart` (`OrderChargeController`) e blocos em `order_charge_card.dart`):
  - Sem link aberto: bloco "Falta receber" de sempre e, embaixo, o link "Mandar link para {cliente} pagar" (só com a conta conectada).
  - Link aberto: o bloco do topo vira "Link mandado em …" / "{cliente} ainda não pagou os R$ X. O link vale até …", com "Lembrar pelo WhatsApp também"; "Recebi de outro jeito" volta ao bloco de receber à mão. Embaixo, a linha "Link de pagamento" (ponto + "Esperando {cliente} pagar", vencido em vermelho).
  - OS mudou de valor (link cobra mais que o saldo): bloco âmbar "A OS mudou de valor" com o botão azul "Gerar link novo de R$ Y" e o link "Manter o link de R$ X".
  - Menu "…": "Copiar o link" e "Mandar de novo pelo WhatsApp"; "Cancelar o link" em vermelho no fim (some quando já há parcelas pagas).
- **Link para pagar (criar)** (`lib/screens/payments/create_charge_screen.dart`): sheet com X e ✓ (`FormSheet`). Valor (pré-preenchido com o saldo) e, quando preciso, CPF/CNPJ no primeiro cartão; "Vencimento" e "Parcelar no cartão" (tela de escolher: "Não" ou 2x a 12x) no segundo. O ✓ fica cinza com a frase do que falta. Chama `POST /v1/app/orders/{orderId}/charges`.
- Transações `asaas_*` não podem ser removidas no app (o estorno é feito no Asaas).
- **Receber** (`lib/screens/payment_management_screen.dart`): a forma de pagamento ("Pix pelo link", "Cartão pelo link") vem de `billingType`, com a descrição como reserva (`lib/utils/asaas_billing.dart`). Com `receiptUrl`, a linha diz "com comprovante" e o sheet do pagamento oferece "Ver comprovante", que abre o link no navegador (o app confere de novo que é `https` em `asaas.com`).
- **Financeiro > "Mandar cobrança"** (`lib/screens/payments/send_charge_flow.dart`): com permissão `chargeOrder`, `asaasEnabled` e `asaasConnected`, e a OS com saldo (não orçamento nem cancelada), primeiro garante a cobrança: se já há uma aberta, reaproveita; se não, abre "Nova cobrança" com o saldo (pede CPF/CNPJ se faltar). Depois de criada, abre o envio do link da OS (`ShareLinkSheet`, WhatsApp/compartilhar), onde o cliente paga por Pix, boleto ou cartão. Desistir da cobrança não manda nada. Sem Asaas, ou se não der para ler as configurações/cobranças (erro ou 8 s sem resposta), manda o link da OS como antes. Um segundo toque enquanto o fluxo roda é ignorado.

Valores da cobrança são sempre exibidos em reais (`FormatService().formatBrl`), qualquer que seja o idioma do app: o Asaas só cobra em BRL.

### Gate do piloto

A seção "Cobrança" aparece só quando:

1. o usuário tem a permissão `chargeOrder` (dono, admin e gerente);
2. `companies/{cid}/settings/payments.asaasEnabled` é `true` (liberado por empresa com o script do piloto);
3. a OS está salva e não é orçamento (`quote`) nem cancelada (`canceled`), mesma regra dos pagamentos manuais.

A entrada em Integrações também depende de `asaasEnabled`. Erro ao ler as configurações (ex.: `permission-denied`) esconde a seção.

### Recarga dos pagamentos

O `orderStream` não atualiza os campos de pagamento da OS, e o webhook grava a baixa no servidor. Por isso o app relê a OS do servidor (`OrderStore.reloadPayments()`, que espera a gravação local pendente antes de ler):

- **ao abrir** a tela de pagamentos, uma vez, quando a seção "Cobrança" aparece (evita saldo antigo e pagamento manual em dobro de uma cobrança já paga);
- **quando a cobrança muda** de status ou de parcelas pagas enquanto a tela está aberta (a primeira emissão do stream de cobranças é ignorada).

### Erros

Os códigos da API viram textos traduzidos (`lib/screens/payments/asaas_error_text.dart`): chave inválida, sem permissão, conta não conectada, valor acima do saldo, CPF/CNPJ obrigatório ou inválido, cliente obrigatório, parcelamento em andamento, link de várias OS aberto, link criado ao mesmo tempo, link anterior cancelado sem o novo ("Mande um link novo"), OS cancelada, vencimento ou parcelas inválidos, cobrança não está em aberto, validação do Asaas, Asaas indisponível e sem internet. Código desconhecido ou resposta inesperada (corpo malformado) mostra o texto genérico. A mensagem crua do servidor nunca é exibida.

### CPF/CNPJ

O Asaas exige o documento do cliente. O app usa o `taxId` do agregado do cliente na OS; se estiver vazio ou inválido, lê o cadastro do cliente. Se ainda assim não houver documento válido, a tela pede o CPF/CNPJ (aceita CNPJ alfanumérico), valida os dígitos verificadores e envia normalizado em `customerTaxId`.

## Link da OS (Bloco E, PR #315, mergeado)

`GET /public/orders/:token` passa a devolver `charge: { status, value, dueDate, mode, installmentCount?, invoiceUrl } | null`: a cobrança aberta (`pending`/`overdue`) mais recente ou, sem nenhuma, a última paga. Ids do Asaas e campos de auditoria nunca saem. Parcelamento com parcela já paga aparece como `paid`. Com o Asaas desconectado, cobrança aberta vira `null` (a paga continua). Erro ao ler a cobrança devolve `null` sem derrubar a página. Detalhes em [`SHARE_LINK.md`](SHARE_LINK.md).

Na página `/q/{token}` (`OrderChargeAction.vue`):

| `charge` | Exibição |
|----------|----------|
| `pending` | Botão "Pagar R$ x" (abre a fatura em nova aba) + "Pix, boleto ou cartão" ou "Em Nx no cartão" + vencimento |
| `overdue` | Botão "Pagar R$ X" com "Venceu em DD/MM/AAAA": a fatura vencida do Asaas ainda aceita Pix e boleto. Parcelamento no cartão ou sem link válido: "Cobrança vencida. Fale com a empresa" |
| `paid` | "Pago R$ x ✓" |
| `null` | nada |

- O botão só aparece para `invoiceUrl` `https` em `asaas.com` ou subdomínio (`www.asaas.com`, `sandbox.asaas.com`).
- Valor sempre em reais, qualquer que seja o idioma do link.
- Com cobrança `pending`/`overdue`, quando a aba volta a ficar visível a página refaz o GET (no máximo 1 vez a cada 10 s; a API pública permite 30 req/min por link). Com a cobrança paga, para de consultar.

## Configuração local (desenvolvimento)

`firebase/functions/.env.local` (gitignored):

```bash
ASAAS_SANDBOX_API_KEY='$aact_hmlg_...'
```

Nunca commitar chaves. Onde cada credencial está fica no inventário privado de acessos (fora deste repositório).

Teste rápido da chave:

```bash
curl -s https://api-sandbox.asaas.com/v3/myAccount -H "access_token: $ASAAS_SANDBOX_API_KEY" -H "User-Agent: praticos-dev"
```

O Asaas não alcança o emulador local. Para receber webhooks do sandbox em dev, expor a porta das Functions do emulador com um túnel e usar como `ASAAS_WEBHOOK_BASE_URL` a URL do túnel + `/{projectId}/southamerica-east1/api` antes de conectar a conta no app.

## E2E no sandbox

Script: `firebase/functions/scripts/asaas-sandbox-e2e.ts` (lê `.env.local` sozinho, aborta se a chave não for de sandbox; nunca imprime chave, ID token, share token nem corpos de requisição).

```bash
cd firebase/functions
npm run e2e:asaas                 # só Asaas: conta, cliente de teste, cobrança UNDEFINED, confirmação no sandbox,
                                  # parcelamento no cartão (invoiceUrls), CNPJ alfanumérico, leitura de webhooks
npm run e2e:asaas -- --with-api   # também cria a cobrança pela API do PraticOS e espera o webhook dar baixa
```

O modo `--with-api` **grava** uma cobrança no saldo total da OS e substitui qualquer cobrança aberta dessa OS: usar só OS de teste. Ele grava numa OS real: apontar só para o emulador (ou túnel para ele) ou para uma empresa de teste conectada ao sandbox com a **mesma** chave, nunca para empresa de cliente. A OS precisa de saldo e de link compartilhado. Variáveis (não commitar):

```bash
export PRATICOS_API_BASE=http://127.0.0.1:5001/<project>/southamerica-east1/api
export PRATICOS_E2E_ALLOW_BASE=127.0.0.1   # precisa ser igual ao host de PRATICOS_API_BASE (trava contra host errado)
export PRATICOS_ID_TOKEN=...               # Firebase ID token de dono/admin/gerente
export PRATICOS_COMPANY_ID=... PRATICOS_ORDER_ID=... PRATICOS_SHARE_TOKEN=...
npm run e2e:asaas -- --with-api
```

A cobrança é localizada no Asaas pelo `externalReference = {companyId}:{orderId}:{chargeId}`. Para simular vencimento no sandbox: `POST /v3/sandbox/payment/{id}/overdue`.

## Rollout

Situação em 2026-10-04: Blocos A–C (código de Functions/rules) publicados; D (app) entra no próximo release; E (link) publicado com o deploy do hosting web. O CI publica só as Functions; regras, índices e TTL são manuais.

1. **Secret da chave mestra**: `ASAAS_CREDENTIALS_KEY` já criado no Secret Manager (pré-requisito do Bloco B). Não trocar a chave mestra sem plano de reconexão (ver inventário privado).
2. **`ASAAS_WEBHOOK_BASE_URL`**: o valor de produção é o default do código (ver "Arquitetura"). Conferir:

   ```bash
   grep -rn "ASAAS_WEBHOOK_BASE_URL\|DEFAULT_WEBHOOK_BASE_URL" firebase/functions/src | grep -v __tests__
   ```

3. **Regras e índices** (antes do piloto). Antes, comparar as regras publicadas no console do Firebase com `firebase/firestore.rules`: as publicadas já divergiram da `master`, e o deploy sobrescreve tudo.

   ```bash
   cd firebase && firebase deploy --only firestore:rules,firestore:indexes --project praticos
   ```

4. **TTL dos eventos do webhook** (também declarado em `firestore.indexes.json`; o comando garante e confere):

   ```bash
   gcloud firestore fields ttls update expiresAt \
     --collection-group=events --enable-ttl --project=praticos
   gcloud firestore fields ttls list --project=praticos
   ```

   `events` só existe em `companies/{cid}/private/asaas/events`. A política leva alguns minutos para ficar `ACTIVE`; a exclusão acontece em até ~24 h depois de `expiresAt`.

5. **Trigger antigo**: `onOrderCanceledCancelAsaasCharges` (substituído por `onOrderUpdatedAsaas`) nunca foi publicado em produção; não há nada a apagar.
6. **App com o Bloco D publicado** (TestFlight/Internal → produção) antes de liberar qualquer empresa. Versões antigas não mostram "Cobrar"; o trigger de reparo cobre a sobrescrita de pagamentos por elas.
7. **Link da OS (Bloco E)**: PR #315 mergeado; o botão "Pagar" chega ao cliente com o deploy do hosting web.
8. **Checklist manual** (seção abaixo) feito no sandbox.
9. **Liberar empresas piloto** (só empresas com conta Asaas própria em produção). Sem `--yes` o script só mostra o plano:

   ```bash
   cd firebase/functions
   gcloud auth application-default login
   npm run asaas:pilot -- --company <companyId> --project praticos         # dry-run
   npm run asaas:pilot -- --company <companyId> --project praticos --yes
   ```

   O dono/admin conecta a chave `$aact_prod...` em Configurações > Integrações > Asaas.

10. **Primeira cobrança real** do piloto: valor baixo, pagar e estornar no painel do Asaas; conferir baixa, estorno e o host da fatura (`www.asaas.com`) no link da OS.

**Rollback de uma empresa:** desconectar no app (remove webhook e credencial) e `npm run asaas:pilot -- --company <companyId> --project praticos --disable --yes`. Cobranças abertas continuam no Asaas e podem ser canceladas no painel dele.

## Checklist manual antes do piloto

Itens que o E2E automático não cobre:

- [ ] **Parcelamento no cartão**: pagar uma vez pela fatura da primeira parcela no sandbox e confirmar que todas as parcelas ficam confirmadas (e que a cobrança na OS vira `paid` com N transações "Asaas • Cartão n/N").
- [x] **Fatura vencida**: o link da OS mantém o botão "Pagar", porque a fatura vencida do Asaas ainda aceita Pix e boleto. Falta confirmar no sandbox se o parcelamento no cartão vencido pode ser pago; até lá ele continua sem botão.
- [ ] **Retorno à aba (Bloco E)**: com a página `/q/{token}` aberta, pagar em outra aba, voltar e conferir "Pago R$ x ✓" sem recarregar; depois de pago, voltar à aba não faz novo GET.
- [ ] **Webhook ponta a ponta** com uma empresa sandbox conectada: `npm run e2e:asaas -- --with-api` contra o emulador (via túnel) ou a empresa de teste; conferir no app o card "Cobrança" pago e a transação na OS.
- [ ] **`req.ip`** (exige as Functions de produção com uma empresa de teste conectada ao sandbox, não o emulador) nas chamadas diretas a `cloudfunctions.net` (caminho do webhook, sem rewrite do Hosting): conferir nos logs que o rate limit usa o IP real do Asaas e não um IP de proxy compartilhado.

## Regras de Negócio

- Uma cobrança em aberto por OS; gerar outra cancela a anterior (exceto parcelamento com parcela paga, que bloqueia nova cobrança). Valor padrão = saldo restante (`total - paidAmount`), editável para menos (entrada).
- À vista (`billingType: UNDEFINED`, cliente escolhe Pix/boleto/cartão) ou parcelado no cartão (2–12x, definido pelo técnico). Vencimento padrão hoje + 3 dias.
- Notificações do Asaas desligadas no cliente (`notificationDisabled: true`): o cliente recebe a cobrança pelo link da OS.
- Cancelar a OS cancela as cobranças abertas no Asaas (trigger `onOrderUpdatedAsaas`).
- Estorno no Asaas remove o pagamento da OS. Transações `asaas_*` não podem ser removidas no app.
- Recursos de cobrança de serviço físico ficam fora do IAP da Apple; não amarrar recursos pagos do app iOS a planos vendidos fora da loja sem revisar a guideline 3.1.1.

## Limitações conhecidas

- **Chargeback e estorno parcial não são lançados.** `PAYMENT_CHARGEBACK_REQUESTED`/`PAYMENT_CHARGEBACK_DISPUTE` não são assinados; `PAYMENT_PARTIALLY_REFUNDED` só vai para o log. Um chargeback ou estorno parcial deixa a OS paga: corrigir manualmente no app.
- **Baixa em dinheiro desfeita no painel** de um pagamento já lançado fica como está (log com `ALERT`).
- **Valor mínimo do Asaas:** se o que falta ficar abaixo do mínimo de cobrança do Asaas, o `PUT` é recusado e o link é cancelado. Conferir no sandbox.
- **Parcelamento:** o estorno de uma única parcela marca a cobrança inteira como `refunded`. Apagar uma parcela de um parcelamento ainda não pago no painel do Asaas cancela a cobrança.
- **Depois de desconectar o Asaas**, o trigger de reparo para de rodar (só age em empresas com `asaasConnected`). Uma versão antiga do app que sobrescrever a OS pode então apagar transações Asaas já lançadas, e elas não são reinseridas. Pagamentos de cobranças que continuaram abertas no Asaas também não dão baixa.
- **Sandbox:** cobrança recebida não pode ser apagada; o E2E acumula uma cobrança paga de R$ 10 por execução na conta de teste.

## Recursos do Asaas usados

| Recurso | Doc |
|---------|-----|
| Cobranças | https://docs.asaas.com/reference/criar-nova-cobranca |
| Clientes | https://docs.asaas.com/reference/criar-novo-cliente |
| Webhooks de cobrança | https://docs.asaas.com/docs/webhook-para-cobrancas |
| Ações de sandbox | https://docs.asaas.com/reference/confirmar-pagamento |
| Split (futuro) | https://docs.asaas.com/docs/split-de-pagamentos |
| NFS-e ([`NFSE_ASAAS.md`](NFSE_ASAAS.md)) | https://docs.asaas.com/docs/notas-fiscais · https://docs.asaas.com/reference/agendar-nota-fiscal |
| Subcontas / BaaS (futuro) | https://docs.asaas.com/docs/criacao-de-subcontas · https://docs.asaas.com/docs/sobre-baas |
| Flapp Store (etapa 3) | https://docs.asaas.com/docs/flappstore |
