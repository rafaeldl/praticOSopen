# WEB_CHECKOUT.md — Assinar plano pela web (Asaas da Rafsoft)

Issue #664, épico de planos #721. **Tudo desligado** até `config/webCheckout.enabled = true`, e a chave só liga depois que a Apple aprovar a versão nova do iPhone (ver "Ordem para ligar").

## Visão Geral

Quem usa o app web (`praticos.app/web`) pode assinar Starter, Pro ou Business sem instalar o app:

1. O dono/admin abre **Ajustes → Plano → Assinar um plano**, escolhe plano, mensal ou anual, forma de pagamento (cartão, Pix ou boleto) e os dados da nota.
2. O servidor cria o cliente e a **assinatura no Asaas da Rafsoft** (não a conta Asaas do técnico, que cobra a OS) e devolve a página de pagamento do Asaas.
3. Quando o Asaas confirma o pagamento, o webhook dá à empresa um **entitlement promocional no RevenueCat** (`appUserID` = `companyId`, entitlement = plano) até o próximo vencimento + 5 dias de folga.
4. O RevenueCat continua a **única fonte do plano**: `syncCompanySubscription` grava `companies/{id}.subscription` como sempre, agora com `store: 'web'`.

O Asaas emite a NFS-e da Rafsoft a cada pagamento (configuração da conta, passo manual).

## Arquitetura

### Functions (`firebase/functions/src`)

| Arquivo | O quê |
|---|---|
| `services/web-billing/web-billing-rules.ts` | Regras puras: preços, chave, datas, bloqueio de compra dupla, evento → ação, garantia de 7 dias, origem `web` |
| `services/web-billing/web-billing.service.ts` | Checkout, cancelamento/reembolso e webhook (Firestore + Asaas + RevenueCat por injeção) |
| `services/web-billing/web-origin.ts` | Gancho do `syncCompanySubscription`: promocional com registro web vira `store: 'web'`; compra na loja com web ativo para a recorrência do Asaas |
| `services/web-billing/revenuecat-promotional.ts` | `POST /v1/subscribers/{id}/entitlements/{plano}/promotional` (`end_time_ms`) e `.../revoke_promotionals` |
| `services/web-billing/billing-env.ts`, `default-deps.ts` | Segredos e montagem de produção |
| `services/asaas/asaas-client.ts` | Ganhou `createSubscription`, `getSubscription`, `listSubscriptionPayments`, `deleteSubscription`, `refundPayment` |
| `routes/v1/billing.routes.ts` | `/v1/app/billing` (dono/admin) |
| `routes/webhooks/asaas-billing.routes.ts` | `/webhooks/asaas-billing` (separado de `/webhooks/asaas/:companyId`) |

Mudança em código existente (mínima):
- `models/types.ts`: `SubscriptionStore` ganhou `'web'`.
- `services/subscription.service.ts`: `syncCompanySubscription` e `expireSubscriptions` passam o estado do RevenueCat por `webOriginFor` (uma leitura de `private/webBilling` por sincronização; falha nunca derruba a sincronização).
- `index.ts`: duas rotas e dois segredos no `api`.

### App web (`firebase/webapp/src`)

| Arquivo | O quê |
|---|---|
| `views/settings/SubscribeView.vue` | Rota `/settings/plan/subscribe` (dono/admin): formulário, assinatura atual, pagar pendente, cancelar, reembolso |
| `components/settings/WebBillingEntry.vue` | Na tela Plano: botão "Assinar um plano", linha "Sua assinatura" ou aviso "use o app" para quem assina na loja; nada com a chave desligada |
| `lib/settings/billing.ts` | Chamadas da API e regras de exibição (testes em `tests/web-billing.test.ts`) |

Textos `web.billing.*` e `web.error.*` em `src/i18n/web_{pt,en,es}.json`.

### App Flutter (`lib/`)

- `BillingStore.web` (`'web'`) em `lib/models/subscription.dart`, igual ao TS; `Subscription.hasWebSubscription(now)`.
- `PaywallLauncher.showPaywall`: com plano da web, mostra só "Seu plano Pro está ativo." (`planActiveMessage`), sem paywall e sem citar o site.
- `PlanScreen`: com plano da web, sem "Ver planos", "Gerenciar assinatura", "Restaurar compras" nem "peça ao administrador".
- Nenhum link, botão, texto ou push sobre comprar na web (App Store 3.1.1 / 3.1.3(b)).

### Firestore (só servidor; `firestore.rules` já nega `companies/{id}/private/**` e coleções raiz sem regra)

```
config/webCheckout                      { enabled, yearlyEnabled, billingTypes: { monthly: [...], yearly: [...] } }
companies/{cid}/private/webBilling      WebBillingRecord (status, plan, cycle, billingType, value, ids do Asaas,
                                        checkoutUrl, firstPaidAt, paidUntil, nextDueDate, cancelledAt, payments{...})
webBillingSubscriptions/{asaasSubId}    { companyId }      (o webhook acha a empresa)
webBillingEvents/{eventId}              { event, receivedAt } (idempotência)
companies/{cid}.subscription            store: 'web', source: 'store' (escrito pelo sync, como antes)
```

## Fluxo de Dados

```
Web (Assinar) ─POST /v1/app/billing/checkout─▶ Functions ─▶ Asaas Rafsoft: cliente + /v3/subscriptions
     ◀──────────────── invoiceUrl da 1ª cobrança ◀──────────┘
Cliente paga na página do Asaas (cartão / Pix / boleto)
Asaas ─PAYMENT_CONFIRMED─▶ /webhooks/asaas-billing ─▶ RevenueCat grant promocional (até vencimento + 5 dias)
                                                    └▶ syncCompanySubscription ─▶ companies/{cid}.subscription (store 'web')
App e web leem subscription como sempre (limites, recursos, tela Plano).
```

## Regras de Negócio

- **Chave:** `config/webCheckout.enabled` (falta ou diferente de `true` = desligado). Desligada: `GET /v1/app/billing` não traz oferta, checkout responde 403 `WEB_CHECKOUT_DISABLED`, a tela Plano não mostra nada. Quem já assinou continua vendo a própria assinatura (para cancelar ou pedir reembolso).
- **Preços** (iguais às lojas): Starter R$ 59,90/mês ou R$ 599/ano; Pro R$ 119 ou R$ 1.190; Business R$ 249 ou R$ 2.490. Ficam em `WEB_PRICES` (`web-billing-rules.ts`).
- **Anual só com paridade:** `config/webCheckout.yearlyEnabled` (padrão desligado). Ligar só depois que `praticos_*_annual` existir na App Store e no Google Play (3.1.3(b)).
- **Formas de pagamento** (padrão, mudam em `billingTypes`): mensal só cartão (renova sem o cliente agir); anual Pix, boleto ou cartão.
- **Sem teste grátis.** Garantia de 7 dias: até 7 dias depois do primeiro pagamento, "Cancelar e receber o dinheiro de volta" estorna tudo pelo Asaas (`POST /payments/{id}/refund`), revoga o promocional e o plano cai para Free na hora.
- **Cancelar** (depois dos 7 dias ou sem pedir dinheiro): apaga a assinatura no Asaas (sem cobrança nova); o plano vale até `paidUntil`; `subscription.status` vira `cancelled` ("válido até").
- **Compra dupla:**
  - checkout bloqueado (409 `STORE_SUBSCRIPTION_ACTIVE`) com assinatura de loja em vigor: "Você já assina pela App Store ou pelo Google Play. Para mudar de plano, use o app.";
  - checkout bloqueado (409 `WEB_SUBSCRIPTION_ACTIVE`) com assinatura web renovando; para trocar de plano, cancelar e assinar de novo;
  - o app esconde a compra de quem assinou pela web;
  - se mesmo assim a empresa comprar na loja com a web renovando, o sync para a recorrência do Asaas (`cancelReason: 'store'`) e vale o maior plano (ranking do RevenueCat).
- **Webhook** (`asaas-access-token` = `ASAAS_BILLING_WEBHOOK_TOKEN`, idempotente pelo id do evento):
  - `PAYMENT_CONFIRMED` / `PAYMENT_RECEIVED` → grant até `addCycle(dueDate) + 5 dias` (fim do dia em São Paulo); nunca de novo para pagamento já estornado;
  - `PAYMENT_REFUNDED`, `PAYMENT_CHARGEBACK_REQUESTED`, `PAYMENT_CHARGEBACK_DISPUTE` → revoga na hora e para a recorrência;
  - `SUBSCRIPTION_DELETED` / `SUBSCRIPTION_INACTIVATED` → cancelada, plano até `paidUntil`;
  - `PAYMENT_OVERDUE` e o resto → nada (o promocional vence sozinho);
  - evento de outra venda da Rafsoft, de assinatura desconhecida ou substituída → ignorado (200);
  - erro no processamento → 500 e o marcador do evento é apagado, para o Asaas reenviar.
- **Origem `web`:** só vira `store: 'web'` o promocional do **mesmo plano** de um registro web `active` ou `cancelled`. Promocional dado à mão continua `store: null`.
- **Job diário** (`scheduledExpireSubscriptions`) não derruba plano web válido: o promocional ainda está ativo no RevenueCat e a origem é mantida.

## Exemplos de Uso

```bash
# Ligar no emulador/sandbox (nunca em produção antes da aprovação da Apple)
# Firestore: config/webCheckout = { enabled: true, yearlyEnabled: false }

curl -H "Authorization: Bearer $ID_TOKEN" -H "X-Company-Id: $CID" \
  https://<api>/v1/app/billing
curl -X POST -H "Authorization: Bearer $ID_TOKEN" -H "X-Company-Id: $CID" -H 'Content-Type: application/json' \
  -d '{"plan":"pro","cycle":"monthly","billingType":"CREDIT_CARD","name":"Oficina","taxId":"11222333000181","email":"x@example.com"}' \
  https://<api>/v1/app/billing/checkout
curl -X POST ... -d '{"refund":true}' https://<api>/v1/app/billing/cancel
```

## Teste ponta a ponta no sandbox

As chaves ficam em `~/.praticos-sandbox.env`, **fora do repositório** e com permissão 600. Quem roda o teste lê o arquivo só para a memória do processo; nada é gravado nem impresso:

```bash
cat > ~/.praticos-sandbox.env <<'EOF2'
ASAAS_BILLING_API_KEY=$aact_hmlg_...   # conta de TESTE (sandbox) da Rafsoft
REVENUECAT_SECRET_KEY=sk_...           # chave secreta do RevenueCat (REVENUECAT_SECRET_API_KEY também vale)
EOF2
chmod 600 ~/.praticos-sandbox.env
```

Os dois testes recusam chave que não seja de sandbox (`$aact_hmlg`) ou que não seja `sk_`. No RevenueCat eles só mexem num appUserID de teste. Esse id nunca é de uma empresa real, e o teste recusa um id que tenha compra de loja. No fim, mesmo depois de uma falha, os promocionais de `starter`, `pro` e `business` desse id são revogados.

**Pela tela (o completo)**, com as Functions no emulador e a chave `config/webCheckout` ligada só no emulador:

```bash
cd firebase/webapp && E2E_BILLING_SANDBOX=1 PW_ARGS=e2e/billing-sandbox.spec.ts npm run e2e
```

O `e2e/billing-sandbox.spec.ts` faz isto, na empresa `e2e-web-checkout-sandbox`, que é o appUserID do teste:

1. Assina o Pro mensal com Pix pela tela e chega na fatura do sandbox. A assinatura existe no Asaas com valor, ciclo e referência certos.
2. Paga a fatura no sandbox (`/sandbox/payment/{id}/confirm`). O Asaas não alcança o emulador, então o teste manda ao `/webhooks/asaas-billing` local o evento que ele mandaria, montado com o pagamento real lido do sandbox. O webhook dá o Pro promocional no RevenueCat e a sincronização grava `plan pro`, `store web`. O mesmo evento repetido não estraga nada.
3. Renova: o sandbox só cria a próxima cobrança perto do vencimento, então o evento do mês seguinte é montado com a data seguinte. O vencimento no RevenueCat anda junto.
4. Bloqueia a compra dupla: a tela mostra a assinatura em vez do formulário, e a API recusa um segundo checkout (409 `WEB_SUBSCRIPTION_ACTIVE`).
5. Pede o dinheiro de volta pela tela, dentro dos 7 dias. O Asaas estorna e apaga a assinatura, o promocional é revogado e o plano volta ao Free. Os eventos de estorno e de assinatura apagada que chegam depois não mudam nada.

`BILLING_SHOTS=<pasta>` salva os prints. Precisa de Java 21 ou mais novo para o emulador.

**Só a API (rápido, sem Firestore):**

```bash
cd firebase/functions && npm run e2e:web-checkout
```

O `scripts/web-checkout-sandbox-e2e.ts` cria o cliente e a assinatura, paga no sandbox e aplica a regra do webhook. Depois dá e confere o promocional (`pro` com origem `web`), estorna, revoga e cancela. O appUserID padrão é `e2e-web-checkout-script`; dá para trocar com `RC_TEST_APP_USER_ID`.

**O que o sandbox não testa:** a entrega real do webhook pelo Asaas, que precisa das Functions publicadas (passo 3 abaixo), e o cartão salvo para as próximas cobranças.

## Passos manuais do dono (antes de ligar)

1. **Segredos (antes do merge, senão o deploy das Functions falha):** `firebase functions:secrets:set ASAAS_BILLING_API_KEY` (chave da conta Asaas da Rafsoft; `$aact_hmlg_` testa no sandbox, `$aact_prod_` é produção) e `ASAAS_BILLING_WEBHOOK_TOKEN` (texto aleatório, o mesmo do passo 4). `REVENUECAT_SECRET_API_KEY` já existe; conferir que a chave `sk_` tem permissão de escrita de entitlements (grant/revoke promocional).
2. **Estorno pela API no Asaas:** no sandbox, o estorno pedido pela API ficou em `AWAITING_CRITICAL_ACTION_AUTHORIZATION`, porque a conta exige autorização de ação crítica. Até alguém aprovar no painel, o dinheiro não volta e o `PAYMENT_REFUNDED` não chega, mas o plano já caiu para o Free na hora. Em produção, decidir entre aprovar cada estorno no painel ou liberar estornos pela API nas configurações de segurança/integrações do Asaas (por exemplo, com IP fixo). Isso vale para a garantia de 7 dias.
3. **Conta Asaas da Rafsoft:** conferir taxas; ligar a emissão automática de NFS-e ao receber (serviço, alíquota do ISS, código municipal); e-mails de cobrança ao cliente ligados.
4. **Webhook no Asaas da Rafsoft:** URL `https://<api do southamerica-east1>/webhooks/asaas-billing`, token do passo 1, eventos `PAYMENT_CONFIRMED`, `PAYMENT_RECEIVED`, `PAYMENT_OVERDUE`, `PAYMENT_REFUNDED`, `PAYMENT_CHARGEBACK_REQUESTED`, `PAYMENT_CHARGEBACK_DISPUTE`, `SUBSCRIPTION_DELETED`, `SUBSCRIPTION_INACTIVATED`.
5. **Produtos anuais nas lojas:** o código mapeia `praticos_{starter,pro,business}_annual`, mas `docs/REVENUECAT_SETUP.md` só lista os mensais em produção. Criar os anuais (App Store + Play + offering do RevenueCat) antes de ligar `yearlyEnabled`.
6. **Notas de revisão da Apple** (só no dia de ligar): em `ios/fastlane/metadata/review_information/notes.txt` e `ios/fastlane/Deliverfile`, trocar "Paid plans cannot be bought anywhere else…" por "All paid plans are available as In-App Purchase; the app has no external purchase links or calls to action." Revogar em `docs/SUBSCRIPTION.md` as regras "Never add another way to pay for a plan" e "The website shows no prices".
7. **Ligar:** depois da aprovação da Apple, `config/webCheckout.enabled = true` (e `yearlyEnabled` só com o passo 5).

## Pontos em aberto

- A fatura do Asaas mostra no topo os dados cadastrais da conta da Rafsoft: e-mail, telefone e endereço. Antes de ligar, conferir em Minha Conta do Asaas de produção se esses dados são os que o cliente deve ver.
- Página de pagamento: é a fatura do Asaas (`invoiceUrl`). Com cartão sem dados no checkout, o Asaas guarda o cartão pago na fatura para as próximas cobranças; confirmar no sandbox ponta a ponta (a doc do Asaas não diz explicitamente).
- O RevenueCat não documenta webhook para grant promocional pela API; por isso o webhook do Asaas chama `syncCompanySubscription` logo depois do grant.
- Aviso por e-mail quando a compra na loja para a recorrência web: ainda não enviado (fica no log `[WebBilling]`).
