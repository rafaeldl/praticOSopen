# Integração Asaas

> Status: **etapa 1 (núcleo de cobrança) implementada, pronta para o piloto** (issue #303). Blocos A–D na `master`; Bloco E (botão "Pagar" no link da OS) no PR #315, ainda não mergeado.
> Spec: [`docs/superpowers/specs/2026-10-04-asaas-cobranca-os-design.md`](superpowers/specs/2026-10-04-asaas-cobranca-os-design.md).
> Estratégia e parceria: [`business/PARCERIAS.md`](../business/PARCERIAS.md).

## Visão Geral

O técnico cobra o cliente da OS por Pix, boleto ou cartão (à vista, ou parcelado no cartão em 2–12x) pela conta Asaas da própria empresa. O cliente paga pelo link da OS (`/q/{token}`, botão "Pagar"). Quando o Asaas confirma o pagamento, um webhook lança o pagamento na OS e dá baixa automática.

Etapas seguintes (specs próprias): criar a empresa e importar clientes a partir da conta Asaas (etapa 2) e distribuição pela **Flapp Store**, a loja de apps dentro da conta Asaas (etapa 3). Fora do escopo atual: split para a Rafsoft, NFS-e, cliente escolher o número de parcelas.

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
| Criptografia (AES-256-GCM, hash de token) | `firebase/functions/src/services/asaas/crypto.ts` |
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

- `ASAAS_CREDENTIALS_KEY`: chave mestra (base64 de 32 bytes) no Secret Manager, via `defineSecret`, ligada às functions que leem ou gravam `private/asaas` (`api` e `onOrderUpdatedAsaas`).
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

### Códigos de erro

`errors.ts`: `ASAAS_NOT_ENABLED` (403), `ASAAS_INVALID_API_KEY` (400), `ASAAS_NOT_CONNECTED` (409), `ASAAS_VALIDATION_ERROR` (400, recusa do Asaas com a descrição dele), `ASAAS_UNAVAILABLE` (502, Asaas fora ou timeout), `ORDER_NOT_FOUND` (404), `ORDER_CANCELED` (409), `INVALID_VALUE`, `INVALID_INSTALLMENT_COUNT`, `INVALID_DUE_DATE`, `CUSTOMER_REQUIRED`, `TAX_ID_REQUIRED`, `INVALID_TAX_ID` (400), `CHARGE_NOT_FOUND` (404), `CHARGE_NOT_OPEN`, `INSTALLMENTS_IN_PROGRESS` (409). Validação do corpo → `VALIDATION_ERROR`; papel sem permissão → `FORBIDDEN`; erro inesperado → `INTERNAL_ERROR`.

## Modelo de dados (Firestore)

| Caminho | Acesso | Conteúdo |
|---------|--------|----------|
| `companies/{cid}/private/asaas` | só servidor | `mode` (`apiKey`\|`flapp`), `environment` (`sandbox`\|`production`), `encryptedApiKey { iv, tag, ciphertext }`, `accountName`, `walletId?`, `webhookId?`, `webhookTokenHash?` (SHA-256), `status` (`active`\|`invalid`), `connectedBy`, `connectedAt` |
| `companies/{cid}/private/asaas/customers/{customerId}` | só servidor | `{ asaasCustomerId, environment?, walletId? }` |
| `companies/{cid}/private/asaas/events/{eventId}` | só servidor | `{ processedAt, expiresAt }`: idempotência do webhook, TTL de 30 dias em `expiresAt` |
| `companies/{cid}/settings/payments` | leitura membros, escrita servidor | `asaasEnabled` (piloto, só via script), `asaasConnected`, `asaasAccountName?`, `asaasEnvironment?` |
| `companies/{cid}/orders/{oid}/charges/{chargeId}` | leitura owner/admin/manager, escrita servidor | `asaasPaymentId`, `asaasInstallmentId?`, `mode` (`single`\|`cardInstallments`), `installmentCount?`, `value`, `dueDate` (YYYY-MM-DD), `status` (`pending`\|`paid`\|`overdue`\|`canceled`\|`refunded`), `invoiceUrl`, `paidAsaasPaymentIds`, `createdBy`, `createdAt`, `paidAt?`; só servidor: `appliedTransactions`, `refundedAsaasPaymentIds` |
| `Customer.taxId` / `CustomerAggr.taxId` | app | CPF/CNPJ normalizado: dígitos e, no CNPJ alfanumérico, letras maiúsculas |

Na OS, cada pagamento Asaas é uma `PaymentTransaction` com `id = asaas_{paymentId}` e `type: payment` (nunca um tipo novo: versões antigas do app quebram com valor desconhecido). O status de pagamento da OS continua `paid` | `unpaid` (o "parcial" é calculado no app).

**As cobranças são a fonte da verdade** dos pagamentos Asaas da OS: `paidAsaasPaymentIds` lista o que foi lançado e `appliedTransactions` guarda uma cópia de cada transação, usada pelo reparo.

Índices (`firebase/firestore.indexes.json`): `charges.asaasInstallmentId` com escopo de collection group (o webhook acha a cobrança pelo id do parcelamento quando falta `externalReference`) e TTL em `events.expiresAt`.

## Webhook e baixa na OS

- URL por empresa: `{ASAAS_WEBHOOK_BASE_URL}/webhooks/asaas/{companyId}`, cadastrada na conexão com `sendType: SEQUENTIALLY`, `apiVersion: 3`, um `authToken` aleatório próprio da empresa (guardado só como hash) e os eventos `PAYMENT_RECEIVED`, `PAYMENT_CONFIRMED`, `PAYMENT_OVERDUE`, `PAYMENT_REFUNDED`, `PAYMENT_DELETED`.
- Autenticação pelo header `asaas-access-token`. Token ausente ou inválido → 401 (mesma resposta para empresa inexistente, desconectada ou token errado). Evento sem `id`/`event` → 400.
- Rate limit de 300 req/min por empresa + IP.
- Idempotência por `event.id` em `private/asaas/events`, gravado só depois do processamento dar certo. Erro interno → 500, o Asaas reenvia. Eventos que nunca vão dar certo (cobrança inexistente, `externalReference` de outra empresa, evento não tratado) são registrados e respondidos com 200 para não travar a fila `SEQUENTIALLY`.
- A cobrança é localizada pelo `externalReference`; sem ele, pelo `asaasInstallmentId` da parcela.
- O payload, a chave e o token nunca são logados (só ids e nome do evento).

| Evento | Efeito |
|--------|--------|
| `PAYMENT_RECEIVED` / `PAYMENT_CONFIRMED` | Em transação Firestore, lança `asaas_{payment.id}` (valor bruto pago pelo cliente) com descrição "Asaas • Pix" / "Asaas • Boleto" / "Asaas • Cartão 2/3", recalcula `paidAmount`, `paid` e `payment`. A cobrança vira `paid` quando todas as parcelas foram lançadas. Push "Pagamento recebido" para dono/admin/gerente. Pagamento que chega numa cobrança `canceled` é lançado mesmo assim (o dinheiro entrou) |
| `PAYMENT_OVERDUE` | `overdue` (se `pending`) |
| `PAYMENT_REFUNDED` | Remove `asaas_{payment.id}` da OS, recalcula, cobrança `refunded`, comentário interno no histórico da OS. O id vai para `refundedAsaasPaymentIds` e nunca é lançado de novo |
| `PAYMENT_DELETED` | `canceled` (se `pending`/`overdue` e sem parcela paga; parcelamento parcialmente pago mantém o status) |

OS em orçamento (`quote`) ou cancelada (`canceled`) fica sem status de pagamento (`payment: null`, `paid: false`), como no app; `paidAmount` e transações continuam sendo mantidos.

### Trigger `onOrderUpdatedAsaas`

Único trigger Asaas em `companies/{cid}/orders/{oid}` (onUpdate, lógica em `order-trigger.service.ts`):

- OS passou para `canceled` → cancela no Asaas as cobranças abertas sem parcela paga (só com `asaasConnected`).
- `transactions` mudou e a empresa tem `asaasConnected` → `repairAsaasTransactions`: reinsere transações Asaas apagadas por uma versão antiga do app que salvou a OS inteira, remove `asaas_*` estornadas que voltaram e corrige `paidAmount`/`paid`/`payment` inconsistentes. Só grava quando algo muda (não entra em loop).

O app novo não envia `transactions`, `paidAmount`, `paid` nem `payment` ao salvar uma OS existente. Pagamento e desconto manuais usam transformações de campo (`arrayUnion`/`increment`, funcionam offline); remover transação, zerar e quitar tudo usam `runTransaction` (pedem conexão).

## Regras Firestore

- `companies/{cid}/private/**`: negado para o cliente (credencial, mapa de clientes e eventos do webhook).
- `companies/{cid}/settings/payments`: leitura para membros da empresa, escrita só pelo servidor.
- `companies/{cid}/orders/{oid}/charges/{chargeId}`: leitura para dono/admin/gerente (`canViewCharges`), escrita só pelo servidor.
- Testes automatizados em `firebase/functions/src/__tests__/firestore.rules.test.ts` (`cd firebase/functions && npm run test:rules`, precisa de Java 21+).

## App

### Telas

- **Configurações > Integrações > Asaas** (`lib/screens/integrations/asaas_connection_screen.dart`): passo a passo para gerar a chave de API, campo da chave (oculto, sem sugestões) e botão Conectar. Conectada, mostra a conta e o ambiente (Teste/Produção) e permite desconectar (com confirmação). A chave vai direto para `POST /v1/app/payments/asaas/connect`; o app nunca a guarda.
- **Seção "Cobrança" na tela de pagamentos da OS** (`lib/screens/payments/widgets/order_charge_section.dart` + `order_charge_card.dart`): mostra a cobrança atual (valor, status, vencimento, parcelas, link da fatura) e o botão Cobrar. Sem a conta conectada, o botão some, mas uma cobrança já existente continua visível.
- **Nova cobrança** (`lib/screens/payments/create_charge_screen.dart`): valor (pré-preenchido com o saldo em aberto), modo (à vista ou cartão parcelado de 2x a 12x), vencimento e, quando preciso, CPF/CNPJ do cliente. Chama `POST /v1/app/orders/{orderId}/charges`.
- Transações `asaas_*` não podem ser removidas no app (o estorno é feito no Asaas).

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

Os códigos da API viram textos traduzidos (`lib/screens/payments/asaas_error_text.dart`): chave inválida, sem permissão, conta não conectada, valor acima do saldo, CPF/CNPJ obrigatório ou inválido, cliente obrigatório, parcelamento em andamento, OS cancelada, vencimento ou parcelas inválidos, cobrança não está em aberto, validação do Asaas, Asaas indisponível e sem internet. Código desconhecido ou resposta inesperada (corpo malformado) mostra o texto genérico. A mensagem crua do servidor nunca é exibida.

### CPF/CNPJ

O Asaas exige o documento do cliente. O app usa o `taxId` do agregado do cliente na OS; se estiver vazio ou inválido, lê o cadastro do cliente. Se ainda assim não houver documento válido, a tela pede o CPF/CNPJ (aceita CNPJ alfanumérico), valida os dígitos verificadores e envia normalizado em `customerTaxId`.

## Link da OS (Bloco E, PR #315)

`GET /public/orders/:token` passa a devolver `charge: { status, value, dueDate, mode, installmentCount?, invoiceUrl } | null`: a cobrança aberta (`pending`/`overdue`) mais recente ou, sem nenhuma, a última paga. Ids do Asaas e campos de auditoria nunca saem. Parcelamento com parcela já paga aparece como `paid`. Com o Asaas desconectado, cobrança aberta vira `null` (a paga continua). Erro ao ler a cobrança devolve `null` sem derrubar a página. Detalhes em [`SHARE_LINK.md`](SHARE_LINK.md).

Na página `/q/{token}` (`OrderChargeAction.vue`):

| `charge` | Exibição |
|----------|----------|
| `pending` | Botão "Pagar R$ x" (abre a fatura em nova aba) + "Pix, boleto ou cartão" ou "Em Nx no cartão" + vencimento |
| `overdue` | "Cobrança vencida. Fale com a empresa" (sem botão) |
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

O modo `--with-api` **grava** uma cobrança numa OS real: apontar só para o emulador (ou túnel para ele) ou para uma empresa de teste conectada ao sandbox com a **mesma** chave, nunca para empresa de cliente. A OS precisa de saldo e de link compartilhado. Variáveis (não commitar):

```bash
export PRATICOS_API_BASE=http://127.0.0.1:5001/<project>/southamerica-east1/api
export PRATICOS_E2E_ALLOW_BASE=127.0.0.1   # precisa ser igual ao host de PRATICOS_API_BASE (trava contra host errado)
export PRATICOS_ID_TOKEN=...               # Firebase ID token de dono/admin/gerente
export PRATICOS_COMPANY_ID=... PRATICOS_ORDER_ID=... PRATICOS_SHARE_TOKEN=...
npm run e2e:asaas -- --with-api
```

A cobrança é localizada no Asaas pelo `externalReference = {companyId}:{orderId}:{chargeId}`. Para simular vencimento no sandbox: `POST /v3/sandbox/payment/{id}/overdue`.

## Rollout

Situação em 2026-10-04: Blocos A–C publicados (functions pelo CI). O CI publica só as Functions; regras, índices e TTL são manuais.

1. **Secret da chave mestra**: `ASAAS_CREDENTIALS_KEY` já criado no Secret Manager (pré-requisito do Bloco B). **Não trocar** essa chave depois que houver empresas conectadas: as credenciais gravadas deixam de abrir e todas precisam reconectar.
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
7. **Link da OS (Bloco E)**: mergear o PR #315 (o CI publica o web no Cloud Run e as Functions) para o cliente ter o botão "Pagar".
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
- [ ] **Fatura vencida**: verificar se uma cobrança `overdue` ainda pode ser paga pela fatura do Asaas. Hoje o link da OS mostra "Cobrança vencida" sem botão; se o Asaas aceitar pagamento após o vencimento, decidir se o botão deve continuar aparecendo.
- [ ] **Retorno à aba (Bloco E)**: com a página `/q/{token}` aberta, pagar em outra aba, voltar e conferir "Pago R$ x ✓" sem recarregar; depois de pago, voltar à aba não faz novo GET.
- [ ] **Webhook ponta a ponta** com uma empresa sandbox conectada: `npm run e2e:asaas -- --with-api` contra o emulador (via túnel) ou a empresa de teste; conferir no app o card "Cobrança" pago e a transação na OS.
- [ ] **`req.ip`** nas chamadas diretas a `cloudfunctions.net` (caminho do webhook, sem rewrite do Hosting): conferir nos logs que o rate limit usa o IP real do Asaas e não um IP de proxy compartilhado.

## Regras de Negócio

- Uma cobrança em aberto por OS; gerar outra cancela a anterior (exceto parcelamento com parcela paga, que bloqueia nova cobrança). Valor padrão = saldo restante (`total - paidAmount`), editável para menos (entrada).
- À vista (`billingType: UNDEFINED`, cliente escolhe Pix/boleto/cartão) ou parcelado no cartão (2–12x, definido pelo técnico). Vencimento padrão hoje + 3 dias.
- Notificações do Asaas desligadas no cliente (`notificationDisabled: true`): o cliente recebe a cobrança pelo link da OS.
- Cancelar a OS cancela as cobranças abertas no Asaas (trigger `onOrderUpdatedAsaas`).
- Estorno no Asaas remove o pagamento da OS. Transações `asaas_*` não podem ser removidas no app.
- Recursos de cobrança de serviço físico ficam fora do IAP da Apple; não amarrar recursos pagos do app iOS a planos vendidos fora da loja sem revisar a guideline 3.1.1.

## Limitações conhecidas

- **Chargeback e estorno parcial não são tratados.** Os eventos `PAYMENT_CHARGEBACK_REQUESTED`/`PAYMENT_CHARGEBACK_DISPUTE`, `PAYMENT_RECEIVED_IN_CASH_UNDONE` e `PAYMENT_PARTIALLY_REFUNDED` não são assinados: um chargeback de cartão ou um estorno parcial deixa a OS paga. Até serem tratados, corrigir manualmente no app.
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
| NFS-e (futuro) | https://docs.asaas.com/docs/notas-fiscais |
| Subcontas / BaaS (futuro) | https://docs.asaas.com/docs/criacao-de-subcontas · https://docs.asaas.com/docs/sobre-baas |
| Flapp Store (etapa 3) | https://docs.asaas.com/docs/flappstore |
