# Integração Asaas

> Status: **em preparação** (2026-10-04). Implementação na issue #303.
> Estratégia e parceria: [`business/PARCERIAS.md`](../business/PARCERIAS.md).

## Visão Geral

O técnico cobra o cliente da OS (Pix, boleto ou cartão) pela conta Asaas dele, e o pagamento confirmado dá baixa na OS automaticamente. Depois: NFS-e e split para a Rafsoft. Caminho de distribuição: publicar o PraticOS na **Flapp Store** (loja de apps dentro da conta Asaas).

## Ambientes

| Ambiente | Painel | API base |
|----------|--------|----------|
| Sandbox | https://sandbox.asaas.com | `https://api-sandbox.asaas.com/v3` |
| Produção | https://www.asaas.com | `https://api.asaas.com/v3` |

- Autenticação: header `access_token: <chave>`. Enviar também `User-Agent` identificando o PraticOS.
- Chaves de sandbox começam com `$aact_hmlg`; de produção, com `$aact_prod`. Ao gravar em `.env`, usar aspas simples por causa do `$`.
- Chaves sem uso por 3 meses são desabilitadas pelo Asaas.
- Documentação oficial: https://docs.asaas.com (também disponível via MCP `asaas` no Claude Code).

## Configuração local (desenvolvimento)

`firebase/functions/.env.local` (gitignored):

```bash
ASAAS_SANDBOX_API_KEY='$aact_hmlg_...'
```

Nunca commitar chaves. Produção usará Secret Manager. Onde cada credencial está fica no inventário privado de acessos (fora deste repositório).

Teste rápido da chave:

```bash
curl -s https://api-sandbox.asaas.com/v3/myAccount -H "access_token: $ASAAS_SANDBOX_API_KEY" -H "User-Agent: praticos-dev"
```

## Arquitetura planejada

```
App (OS) ──► Functions /api ──► Asaas API (conta do técnico)
                 ▲                      │
                 └──── webhook ◄────────┘  PAYMENT_RECEIVED / PAYMENT_CONFIRMED
```

- **Conexão da conta do técnico**, dois modos atrás da mesma interface:
  1. chave de API colada pelo técnico (sandbox e piloto);
  2. permissões concedidas na contratação pela Flapp Store (quando homologado).
- Credencial do técnico guardada só no backend (Secret Manager ou criptografada), nunca no app nem em texto puro no Firestore.
- Cobrança criada com `billingType: UNDEFINED` (cliente escolhe Pix, boleto ou cartão), valor em aberto da OS e cliente da OS (find-or-create no Asaas).
- Link da OS (`/q/{token}`) mostra "Pagar" com a URL da fatura.
- Webhook autenticado por token registra a transação na OS (mesmo modelo de pagamentos parciais) e atualiza o status de pagamento.
- Feature flag por empresa para o piloto.

## Recursos do Asaas que vamos usar

| Recurso | Doc |
|---------|-----|
| Cobranças | https://docs.asaas.com/reference/criar-nova-cobranca |
| Clientes | https://docs.asaas.com/reference/criar-novo-cliente |
| Webhooks de cobrança | https://docs.asaas.com/docs/webhook-para-cobrancas |
| Split (fase 2) | https://docs.asaas.com/docs/split-de-pagamentos |
| NFS-e (fase 3) | https://docs.asaas.com/docs/notas-fiscais |
| Subcontas / BaaS (futuro) | https://docs.asaas.com/docs/criacao-de-subcontas · https://docs.asaas.com/docs/sobre-baas |
| Flapp Store | https://docs.asaas.com/docs/flappstore |

## Regras de Negócio

- Uma OS pode ter várias cobranças (pagamentos parciais); cada pagamento confirmado vira uma transação na OS.
- Cancelar a OS cancela as cobranças abertas no Asaas (trigger `onOrderUpdatedAsaas`).
- Estorno no Asaas deve estornar a transação na OS.
- Recursos de cobrança de serviço físico ficam fora do IAP da Apple; não amarrar recursos pagos do app iOS a planos vendidos fora da loja sem revisar a guideline 3.1.1.

## Webhook e baixa na OS

- Endpoint: `POST /webhooks/asaas/{companyId}` (função `api`), autenticado por um token próprio de cada empresa, gerado na conexão da conta. Requisição sem token válido → 401. Rate limit por empresa e IP. Erro interno → 500 (o Asaas reenvia). Eventos sem cobrança correspondente são registrados e respondidos com 200 para não travar a fila `SEQUENTIALLY`.
- Idempotência: `companies/{cid}/private/asaas/events/{eventId}` = `{ processedAt, expiresAt }` (TTL de 30 dias em `expiresAt`).
- `PAYMENT_RECEIVED`/`PAYMENT_CONFIRMED`: transação `asaas_{paymentId}` (`type: payment`) na OS, `paidAmount`/`paid`/`payment` recalculados, push "Pagamento recebido" para dono/admin/gerente. `PAYMENT_OVERDUE`: cobrança `overdue` (se `pending`). `PAYMENT_REFUNDED`: remove a transação, cobrança `refunded`, comentário interno no histórico da OS. `PAYMENT_DELETED`: cobrança `canceled` (se não paga).
- OS em orçamento (`quote`) ou cancelada (`canceled`) fica sem status de pagamento (`payment: null`, `paid: false`), como no app; o `paidAmount` e as transações continuam sendo mantidos.
- A cobrança é a fonte da verdade (`paidAsaasPaymentIds` + `appliedTransactions`). O trigger `onOrderUpdatedAsaas` (orders onUpdate) cancela cobranças abertas quando a OS é cancelada e reinsere transações Asaas apagadas por versões antigas do app, só para empresas com `asaasConnected`.
- O payload e o token do webhook nunca são logados.

## Regras Firestore

- `companies/{cid}/private/**`: negado para o cliente (credencial, mapa de clientes e eventos do webhook).
- `companies/{cid}/settings/payments`: leitura para membros da empresa, escrita só pelo servidor.
- `companies/{cid}/orders/{oid}/charges/{chargeId}`: leitura para dono/admin/gerente, escrita só pelo servidor.
- Testes automatizados em `firebase/functions/src/__tests__/firestore.rules.test.ts` (`cd firebase/functions && npm run test:rules`, precisa de Java 21+).

## Rollout do webhook (Bloco C)

O CI publica só as functions; regras, índices e TTL são manuais. Fazer nesta ordem.

**Os passos 1 a 3 precisam estar feitos ANTES de mergear o PR.** O merge na `master` dispara `.github/workflows/firebase-functions-deploy.yml`, que publica as functions sem `--force`: se ainda existir `onOrderCanceledCancelAsaasCharges` no projeto, o deploy aborta por causa da exclusão.

1. **Regras e índices** (antes do app que lê `charges`). Antes, comparar as regras publicadas no console do Firebase com `firebase/firestore.rules`: as publicadas já divergiram da `master`, e o deploy sobrescreve tudo.
   ```bash
   cd firebase && firebase deploy --only firestore:rules,firestore:indexes --project praticos
   ```
2. **TTL dos eventos do webhook** (também declarado em `firestore.indexes.json`; o comando garante e confere):
   ```bash
   gcloud firestore fields ttls update expiresAt \
     --collection-group=events --enable-ttl --project=praticos
   gcloud firestore fields ttls list --project=praticos
   ```
   A política leva alguns minutos para ficar `ACTIVE`; a exclusão acontece em até ~24 h depois de `expiresAt`.
3. **Remover o trigger antigo**, logo antes do merge. `onOrderCanceledCancelAsaasCharges` foi substituído por `onOrderUpdatedAsaas`, e o deploy do CI não usa `--force`, então não apaga funções sozinho (e aborta se houver função a apagar). Entre este passo e o deploy, cancelar uma OS não cancela as cobranças abertas:
   ```bash
   cd firebase && firebase functions:delete onOrderCanceledCancelAsaasCharges --project praticos --force
   ```
4. **Deploy das functions** (mergear o PR dispara o CI, ou manual):
   ```bash
   cd firebase && firebase deploy --only functions --project praticos
   ```
   O CLI pode pedir para habilitar Eventarc/Pub/Sub para o trigger v2; aceitar.

## App

### Telas

- **Configurações > Integrações > Asaas** (`lib/screens/integrations/asaas_connection_screen.dart`): passo a passo para gerar a chave de API, campo da chave (oculto, sem sugestões) e botão Conectar. Conectada, mostra a conta e o ambiente (Teste/Produção) e permite desconectar (com confirmação). A chave vai direto para `POST /v1/app/payments/asaas/connect`; o app nunca a guarda.
- **Seção "Cobrança" na tela de pagamentos da OS** (`lib/screens/payments/widgets/order_charge_section.dart` + `order_charge_card.dart`): mostra a cobrança atual (valor, status, vencimento, parcelas, link da fatura) e o botão Cobrar. Sem a conta conectada, o botão some, mas uma cobrança já existente continua visível.
- **Nova cobrança** (`lib/screens/payments/create_charge_screen.dart`): valor (pré-preenchido com o saldo em aberto), modo (à vista ou cartão parcelado de 2x a 12x), vencimento e, quando preciso, CPF/CNPJ do cliente. Chama `POST /v1/app/orders/{orderId}/charges`.

Valores da cobrança são sempre exibidos em reais (`FormatService().formatBrl`), qualquer que seja o idioma do app: o Asaas só cobra em BRL.

### Gate do piloto

A seção "Cobrança" aparece só quando:

1. o usuário tem a permissão `chargeOrder` (dono, admin e gerente);
2. `companies/{cid}/settings/payments.asaasEnabled` é `true` (liberado pelo servidor por empresa);
3. a OS está salva e não é orçamento (`quote`) nem cancelada (`canceled`), mesma regra dos pagamentos manuais.

A entrada em Integrações também depende de `asaasEnabled`. Erro ao ler as configurações (ex.: `permission-denied`) esconde a seção.

### Recarga dos pagamentos

O `orderStream` não atualiza os campos de pagamento da OS, e o webhook grava a baixa no servidor. Por isso o app relê a OS do servidor (`OrderStore.reloadPayments()`, que espera a gravação local pendente antes de ler):

- **ao abrir** a tela de pagamentos, uma vez, quando a seção "Cobrança" aparece (evita saldo antigo e pagamento manual em dobro de uma cobrança já paga);
- **quando a cobrança muda** de status ou de parcelas pagas enquanto a tela está aberta (a primeira emissão do stream de cobranças é ignorada).

### Erros

Os erros da API viram textos traduzidos por código (`lib/screens/payments/asaas_error_text.dart`): chave inválida, sem permissão, conta não conectada, valor acima do saldo, CPF/CNPJ obrigatório ou inválido, cliente obrigatório, parcelamento em andamento, OS cancelada, vencimento ou parcelas inválidos, cobrança não está em aberto, validação do Asaas, Asaas indisponível e sem internet. Código desconhecido ou resposta inesperada (corpo malformado) mostra o texto genérico. A mensagem crua do servidor nunca é exibida.

### CPF/CNPJ

O Asaas exige o documento do cliente. O app usa o `taxId` do agregado do cliente na OS; se estiver vazio ou inválido, lê o cadastro do cliente. Se ainda assim não houver documento válido, a tela pede o CPF/CNPJ (aceita CNPJ alfanumérico), valida os dígitos verificadores e envia normalizado em `customerTaxId`.

## Limitações conhecidas

- **Chargeback e estorno parcial não são tratados.** Os eventos `PAYMENT_CHARGEBACK_REQUESTED`/`PAYMENT_CHARGEBACK_DISPUTE`, `PAYMENT_RECEIVED_IN_CASH_UNDONE` e `PAYMENT_PARTIALLY_REFUNDED` não são assinados: um chargeback de cartão ou um estorno parcial deixa a OS paga. Até serem tratados, corrigir manualmente no app.
- **Parcelamento:** o estorno de uma única parcela marca a cobrança inteira como `refunded`. Apagar uma parcela de um parcelamento ainda não pago no painel do Asaas cancela a cobrança.
- **Depois de desconectar o Asaas**, o trigger de reparo para de rodar (só age em empresas com `asaasConnected`). Uma versão antiga do app que sobrescrever a OS pode então apagar transações Asaas já lançadas, e elas não são reinseridas.
