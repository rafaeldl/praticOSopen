# Cobrança da OS via Asaas

**Data:** 2026-10-04
**Status:** Em revisão (aguardando aprovação do Rafael)
**Issue:** #303
**Contexto:** [`business/PARCERIAS.md`](../../../business/PARCERIAS.md), [`docs/ASAAS_INTEGRATION.md`](../../ASAAS_INTEGRATION.md)

## Visão Geral

O técnico cobra o cliente da OS por Pix, boleto ou cartão (à vista ou parcelado no cartão) pela conta Asaas da própria empresa. Quando o pagamento é confirmado, a OS dá baixa sozinha. O cliente paga pelo link da OS (`/q/{token}`).

## Público e etapas

**Público principal: empresas que já usam o Asaas** e passam a usar o PraticOS (canal: Flapp Store, a loja de apps dentro da conta Asaas, ~270 mil empresas). Elas já têm conta aberta e documentação aprovada, o passo mais difícil. Convencer a base atual do PraticOS a abrir conta no Asaas dá mais trabalho.

| Etapa | Entrega | Depende de |
|-------|---------|-----------|
| **1. Núcleo de cobrança** (esta spec) | Conectar conta Asaas, gerar cobrança na OS, webhook de pagamento, baixa na OS, botão "Pagar" no link | Nada; conexão por chave de API serve para desenvolvimento e piloto |
| 2. Do Asaas ao PraticOS pronto | Criar a empresa no PraticOS com os dados da conta Asaas (`/myAccount`) e importar os clientes do Asaas com CPF/CNPJ | Etapa 1. Spec própria |
| 3. Flapp Store | Autorização de acesso na contratação, provisionamento automático da conta, cobrança do plano do PraticOS pelo saldo Asaas | Resposta e homologação do Asaas. Spec própria |

A conexão fica atrás de uma interface única (`AsaasCredentialProvider`): a etapa 1 implementa o modo "chave de API"; a etapa 3 acrescenta o modo "Flapp Store" sem mudar cobrança, webhook nem telas.

Perguntas abertas que afetam as etapas 2 e 3: como a Flapp Store entrega a credencial ao app (OAuth/escopos?), como identificar a empresa contratante para criar a conta no PraticOS, quantos clientes do Asaas são prestadores de serviço.

## Decisões de produto

| Tema | Decisão |
|------|---------|
| Quem cobra | Dono, admin e gerente (nova permissão `chargeOrder`) |
| Quem conecta a conta Asaas | Dono e admin |
| Como o cliente recebe | Pelo link da OS (botão "Pagar"), compartilhado pelo técnico. Notificações do Asaas desligadas (`notificationDisabled: true`) |
| Cobranças por OS | Uma cobrança em aberto por vez. Valor padrão = saldo restante, editável para menos (entrada). Gerar nova cancela a anterior |
| Forma | À vista (`billingType: UNDEFINED`, cliente escolhe Pix/boleto/cartão) ou parcelado no cartão em 2–12x (`CREDIT_CARD` + `installmentCount` + `totalValue`). O número de parcelas é definido pelo técnico |
| Vencimento | Padrão hoje + 3 dias, editável |
| OS cancelada | Cobrança pendente é cancelada no Asaas |
| Total da OS mudou com cobrança aberta | App avisa e oferece regerar com o valor novo |
| Piloto | Liberado por empresa via script (`asaasEnabled`), nunca pelo usuário |

Exemplo suportado: entrada de R$ 300 no Pix (cobrança 1) e restante de R$ 700 em 3x no cartão (cobrança 2, depois que a 1 for paga).

## Arquitetura

```
App ──► /v1/app/payments/asaas/*  ──► Asaas API (conta da empresa)
App ──► /v1/app/orders/:id/charges ─┘          │
                                               ▼
Firestore ◄── /webhooks/asaas/:companyId ◄── webhook (PAYMENT_*)
   │
   └── trigger de reparo (orders onUpdate)
Link /q/{token} ◄── /public/orders/:token (cobrança aberta + invoiceUrl)
```

Todas as chamadas ao Asaas saem das Functions. O app nunca vê a chave.

### Dados

**`companies/{companyId}/private/asaas`** — server-only (regras negam leitura e escrita ao cliente)

| Campo | Descrição |
|-------|-----------|
| `mode` | `apiKey` (etapa 1) \| `flapp` (etapa 3) |
| `environment` | `sandbox` \| `production`, inferido do prefixo da chave (`$aact_hmlg` / `$aact_prod`) |
| `encryptedApiKey` | `{ iv, tag, ciphertext }` — AES-256-GCM, chave mestra no secret `ASAAS_CREDENTIALS_KEY` |
| `accountName`, `walletId` | Da `/v3/myAccount` e `/v3/wallets` |
| `webhookId` | Id do webhook cadastrado no Asaas |
| `webhookTokenHash` | SHA-256 do token do webhook |
| `status` | `active` \| `invalid` |
| `connectedBy` (UserAggr), `connectedAt` | Auditoria |

**`companies/{companyId}/private/asaas/customers/{customerId}`** — server-only: `{ asaasCustomerId }`.

**`companies/{companyId}/private/asaas/events/{eventId}`** — server-only: ids de eventos de webhook já processados (idempotência), com TTL de 30 dias.

**`companies/{companyId}/settings/payments`** — leitura para membros, escrita só servidor

| Campo | Descrição |
|-------|-----------|
| `asaasEnabled` | Flag do piloto (script) |
| `asaasConnected` | Conta conectada |
| `asaasAccountName`, `asaasEnvironment` | Para exibir no app |

**`companies/{cid}/orders/{oid}/charges/{chargeId}`** — leitura para dono/admin/gerente, escrita só servidor

| Campo | Descrição |
|-------|-----------|
| `asaasPaymentId` | Id da cobrança (à vista) ou da 1ª parcela |
| `asaasInstallmentId` | Id do parcelamento (cartão parcelado) |
| `mode` | `single` \| `cardInstallments` |
| `installmentCount` | 2–12 quando parcelado |
| `value`, `dueDate` | Valor total e vencimento |
| `status` | `pending` \| `paid` \| `overdue` \| `canceled` \| `refunded` |
| `invoiceUrl` | Link da fatura |
| `paidAsaasPaymentIds` | Ids de pagamentos Asaas já lançados na OS (parcelas) |
| `createdBy`, `createdAt`, `paidAt` | Auditoria (datas em ISO string) |

**`Customer`** ganha `taxId` (CPF/CNPJ, só dígitos), também em `CustomerAggr`.

### Endpoints

Todos em `/v1/app` usam `bearerAuth` + `resolveCompanyContext`. O app passa a enviar `X-Company-Id` (hoje não envia, e usuários em várias empresas caem sempre na primeira).

| Método | Rota | Permissão | Comportamento |
|--------|------|-----------|---------------|
| POST | `/v1/app/payments/asaas/connect` `{ apiKey }` | owner/admin + `asaasEnabled` | Valida (`GET /myAccount`), infere ambiente, criptografa e salva, cadastra webhook (`POST /v3/webhooks` com `name`, `url` = `{ASAAS_WEBHOOK_BASE_URL}/webhooks/asaas/{companyId}`, `email` de quem conectou, `enabled: true`, `interrupted: false`, `apiVersion: 3`, `sendType: SEQUENTIALLY`, `authToken` aleatório de 48 bytes, eventos `PAYMENT_RECEIVED`, `PAYMENT_CONFIRMED`, `PAYMENT_OVERDUE`, `PAYMENT_REFUNDED`, `PAYMENT_DELETED`), grava `settings/payments`. Chave inválida → 400 sem gravar nada |
| DELETE | `/v1/app/payments/asaas/connect` | owner/admin | Remove o webhook no Asaas, apaga a credencial, `asaasConnected=false`. Cobranças abertas continuam no Asaas |
| POST | `/v1/app/orders/:orderId/charges` `{ value, mode, installmentCount?, dueDate?, customerTaxId? }` | `chargeOrder` | Ver "Gerar cobrança" |
| DELETE | `/v1/app/orders/:orderId/charges/:chargeId` | `chargeOrder` | Cancela no Asaas (`DELETE /payments/{id}` ou `/installments/{id}`), `status=canceled` |
| POST | `/webhooks/asaas/:companyId` | header `asaas-access-token` | Ver "Webhook" |

### Gerar cobrança

1. Valida: conta conectada; OS existe e não está cancelada; `0 < value <= saldo restante`; `installmentCount` 2–12 quando `cardInstallments`; cliente da OS com `taxId` (ou `customerTaxId` no corpo, validado e salvo no cliente).
2. Se houver cobrança `pending`/`overdue` na OS, cancela no Asaas e marca `canceled`.
3. Find-or-create do cliente no Asaas (`externalReference` = customerId, `notificationDisabled: true`), mapeado em `private/asaas/customers`.
4. Cria a cobrança: `description` "OS #{number} - {empresa}", `externalReference` = `{companyId}:{orderId}:{chargeId}`.
5. Grava o documento em `charges` e devolve `{ chargeId, invoiceUrl, status }`.

Saldo restante = `total - paidAmount` (o `total` da OS já é líquido de desconto). Corrige `order.service.ts` e `analytics.service.ts`, que hoje subtraem o desconto duas vezes.

### Webhook

- Autentica comparando (timing-safe) o SHA-256 do header `asaas-access-token` com `webhookTokenHash` da empresa. Sem match → 401.
- Rate limit próprio. Responde 200 rápido; erros internos → 500 para o Asaas reenviar.
- Idempotência por `event.id` em `private/asaas/events`.
- Localiza a cobrança pelo `externalReference` (ou `installment`) do payment.

| Evento | Efeito |
|--------|--------|
| `PAYMENT_RECEIVED` / `PAYMENT_CONFIRMED` | Se `payment.id` ainda não está em `paidAsaasPaymentIds`: lança transação na OS e adiciona o id. Cobrança `paid` quando todos os pagamentos dela estiverem lançados. Push para dono/admin/gerente: "Pagamento recebido – OS #n – R$ x" |
| `PAYMENT_OVERDUE` | `status=overdue` |
| `PAYMENT_REFUNDED` | Remove a transação `asaas_{payment.id}` da OS, recalcula, `status=refunded`, registra no histórico da OS |
| `PAYMENT_DELETED` | `status=canceled` (se não pago) |

**Lançamento na OS** (transação Firestore): lê a OS, acrescenta `PaymentTransaction` com `id = asaas_{payment.id}`, `type = payment` (sem tipo novo: versões antigas do app usam `$enumDecode` e quebrariam), `amount = payment.value`, `description` "Asaas • Pix" / "Asaas • Boleto" / "Asaas • Cartão 2/3", `createdAt` ISO string, `createdBy` = `{ name: 'Asaas' }`. Recalcula `paidAmount`, `paid` e `payment` usando a convenção do app (`paid` \| `unpaid`).

### Proteção dos pagamentos contra sobrescrita

- **App novo:** salvar a OS deixa de enviar `transactions`, `paidAmount`, `paid` e `payment`. Adicionar/remover/zerar pagamento manual passa a ser `runTransaction` atualizando só esses campos.
- **Reparo (versões antigas):** trigger `onDocumentUpdated` em `companies/{cid}/orders/{oid}`, ativo só para empresas com `asaasConnected`: se `transactions` mudou e falta algum `asaas_{id}` listado em `paidAsaasPaymentIds` de cobranças da OS, reinsere e recalcula. As cobranças são a fonte da verdade.
- Transações `asaas_*` não podem ser removidas manualmente no app (mensagem: estorne no Asaas).

### App

- **Integrações** (`lib/screens/integrations/`): seção "Pagamentos" → "Asaas", visível para owner/admin com `asaasEnabled`. Desconectado: tela com instruções, link para o painel do Asaas e campo seguro para a chave. Conectado: nome da conta, ambiente (Teste/Produção), "Desconectar" com `CupertinoAlertDialog`.
- **OS**: botão "Cobrar com Asaas" na área de pagamentos (permissão `chargeOrder`, conta conectada, saldo > 0). Tela: valor (FormatService), segmented control À vista / Parcelado no cartão, picker 2–12 com valor da parcela, vencimento, CPF/CNPJ se faltar.
- **Card "Cobrança"** com listener em `charges`: dot de status (azul pendente, vermelho vencida, verde paga), valor, vencimento, ações "Compartilhar link da OS", "Copiar link da fatura", "Cancelar cobrança".
- Transações Asaas com ícone próprio na lista de pagamentos.
- **Cliente**: campo CPF/CNPJ com máscara e validação de dígitos.
- Serviço `AsaasApiService` seguindo `IntegrationApiService` (singleton + `withClient` para testes). Strings em pt/en/es; cores com `.resolveFrom(context)`.

### Link da OS (`firebase/web`)

- `GET /public/orders/:token` passa a devolver `charge: { status, value, dueDate, mode, installmentCount, invoiceUrl } | null` (só a cobrança aberta ou a última paga; nada da conta Asaas).
- `OrderTotalSection`: pendente → botão "Pagar R$ X" (abre `invoiceUrl`); vencida → "Cobrança vencida. Fale com a empresa"; paga → "Pago ✓".
- Ao voltar o foco para a aba (`visibilitychange`), refaz o fetch para refletir o pagamento.

## Segurança

- Chave do Asaas só no servidor, criptografada; chave mestra em Secret Manager (`defineSecret('ASAAS_CREDENTIALS_KEY')`).
- `ASAAS_WEBHOOK_BASE_URL` (env): URL pública das Functions. Em desenvolvimento, o webhook do sandbox precisa de uma URL pública (túnel, como o ngrok já usado no app em debug); o emulador local não é alcançável pelo Asaas.
- Webhook com token por empresa, guardado só como hash; comparação timing-safe.
- Nunca logar chave, token nem payload do webhook (seguir a redação de logs existente).
- Regras: `private/**` negado; `charges` e `settings/payments` sem escrita do cliente; leitura de `charges` só owner/admin/gerente.
- `invoiceUrl` exposto no link público apenas para a cobrança daquela OS (o link já é um segredo de posse).

## Testes

- **Functions (jest, Asaas mockado):** criptografia (ida e volta, tag adulterada falha); connect (chave válida/inválida, ambiente, webhook criado); charges (permissão, valor > saldo, cancela anterior, cliente sem taxId, parcelado); webhook (token errado, evento repetido, Pix, cartão CONFIRMED+RECEIVED sem duplicar, parcelas, estorno, vencida); trigger de reparo; correção do saldo.
- **Regras do Firestore** (emulador): cliente não lê `private/`, não escreve `charges/` nem `settings/payments`.
- **Flutter:** save da OS sem campos de pagamento; operações de pagamento transacionais; `AsaasApiService`; validação de CPF/CNPJ; widgets de Integrações e Cobrar.
- **E2E sandbox:** script que conecta a chave do sandbox, cria cobrança, simula o pagamento com `POST /v3/sandbox/payment/{id}/confirm` (e o vencimento com `/v3/sandbox/payment/{id}/overdue`) e confere OS paga e link com "Pago".

## Entrega (PRs)

1. Base: OS sem sobrescrever pagamentos (app), saldo corrigido (server), `X-Company-Id`, permissão `chargeOrder`, `Customer.taxId`.
2. Server: crypto, `AsaasClient`, connect/disconnect, charges.
3. Server: webhook + trigger de reparo + regras.
4. App: Integrações, Cobrar, card de cobrança.
5. Web: botão "Pagar" e status.
6. Docs: `docs/ASAAS_INTEGRATION.md` atualizado e artigo público (pt/en/es).

## Rollout

1. Criar secret `ASAAS_CREDENTIALS_KEY` (produção) — passo do Rafael.
2. Testar com a conta sandbox da Rafsoft.
3. Ligar `asaasEnabled` para empresas piloto com conta Asaas própria em produção.
4. App novo publicado antes do piloto (versões antigas não mostram "Cobrar"; o trigger cobre sobrescrita).

## Fora do escopo

Split para a Rafsoft, NFS-e, conexão via Flapp Store (etapa 3), criação de empresa e importação de clientes do Asaas (etapa 2), cliente escolher o número de parcelas, cobrança pelo MCP.
