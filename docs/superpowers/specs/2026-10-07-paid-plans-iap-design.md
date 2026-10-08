# Planos pagos com In-App Purchase (iOS) e Play Billing (Android)

**Data:** 2026-10-07
**Status:** Proposta, aguardando revisão
**Risco:** `risk:high` (billing, IAP, `firestore.rules`, Functions com escrita)

## 1. Por que

A Apple rejeitou o app cinco vezes desde 11/09/2026, quatro delas pela guideline 3.1.1:

| Data | Build | Motivo |
|---|---|---|
| 12/09 | 1.49.3 (147) | 2.1: alerta de ATT não encontrado (resolvido) |
| 14/09 | 1.51.0 (150) | 3.1.1: assinatura comprável sem IAP |
| 17/09 | 1.52.0 (151) | 3.1.1: acessa conteúdo pago comprado fora do app |
| 18/09 | 1.52.2 (153) | 3.1.1: conteúdo pago precisa estar à venda via IAP |
| 05/10 e 07/10 | 1.53.0 (155) | 3.1.1: cadastro de empresa conta como mecanismo externo de compra |

A última rejeição pede para remover o cadastro de empresas do app. A outra saída é vender os planos dentro do app via In-App Purchase. Com o IAP, o cadastro aberto deixa de ser um problema: o que é pago passa a ser comprável no próprio app. Escolhemos esse caminho, que também serve ao modelo de negócio.

## 2. Decisões

| Tema | Decisão |
|---|---|
| Modelo | Freemium com os planos atuais: Free, Starter, Pro, Business, com os limites que já estão no código |
| Períodos | Só mensal. Plano anual e teste grátis ficam para depois |
| Empresas existentes | 60 dias de Pro grátis (carência). Depois, Free ou assinatura |
| Intermediário | RevenueCat (SDK único para as duas lojas, validação de recibo, webhook único) |
| Tela de planos | Paywall do RevenueCat. "Gerenciar assinatura" pelo Customer Center do RevenueCat. A `PlansScreen` atual é removida |
| Quem compra | Só dono (`owner`) e `admin` da empresa |
| Plataformas | iOS e Android com a mesma regra. A web não vende nada |

## 3. Fora do escopo

- Plano anual, teste grátis, oferta promocional.
- Paywall com visual próprio (Cupertino).
- Limites aplicados no servidor (por exemplo, bloquear convite acima do limite de usuários). Os limites continuam no app.
- Venda pela web (Asaas, Stripe). Enquanto houver IAP no iOS, o site não mostra preços (regra de `docs/SUBSCRIPTION.md`).

## 4. Estado atual (levantamento de 07/10)

O código tem a estrutura, mas nada funciona de ponta a ponta:

- `SubscriptionService.revenueCatEnabled = false`. `purchaseUiEnabled` e `planLimitsEnforced` estão desligados no iOS.
- `SubscriptionStore` é criado em `main.dart`, mas `initialize`/`logIn` nunca são chamados. As ofertas nunca carregam.
- `Global.subscription` nunca é preenchido. Todos os limites usam o Free, mesmo para quem pagasse.
- O modelo do cliente (`lib/models/subscription.dart`) e o do servidor (`firebase/functions/src/models/types.ts`) divergem:
  - campos `formTemplates`/`collaborators` contra `formTemplatesActive`/`usersActive`;
  - status `canceled` contra `cancelled` e `past_due`;
  - `fromJson` quebra com valores do servidor.
- O webhook (`routes/webhooks/revenuecat.routes.ts`) valida `x-revenuecat-signature`, um header que o RevenueCat não envia. Sem segredo configurado, aceita qualquer requisição.
- `CANCELLATION` rebaixa para Free na hora. O correto é manter o acesso até o fim do período pago.
- `firestore.rules` deixa dono e admin gravarem `subscription` no documento da empresa: dá para virar Business sem pagar.
- `photo_service.dart` grava o contador de fotos em `tenants/`, coleção errada. A gravação falha em silêncio.
- A `PlansScreen` tem:
  - preços fixos no código;
  - links de Termos e Privacidade vazios;
  - FAQ prometendo teste de 7 dias e cobrança proporcional.
- O "Restaurar" de Ajustes e da `ManageSubscriptionScreen` é falso: espera um pouco e mostra sucesso.
- O site diz "gratuito no iOS e no Android, sem cartão".
- Não há testes do webhook, do serviço de assinatura nem das regras.

## 5. Arquitetura

```
App (iOS/Android)
  RevenueCat SDK ── compra / restaurar ──▶ App Store / Google Play
        │                                        │
        │ appUserID = companyId                  ▼
        │                                   RevenueCat
        │                                        │ webhook (Authorization)
        ▼                                        ▼
  Firestore companies/{id}.subscription ◀── Function revenuecatWebhook
        │   (somente o servidor grava plano/status)   └─ consulta GET /v1/subscribers/{companyId}
        ▼
  SubscriptionStore (MobX, listener ao vivo) → Global.subscription → FeatureGateService → UI
```

### 5.1 Identidade

- O `appUserID` no RevenueCat é o `companyId`: a assinatura pertence à empresa, não ao usuário.
- Ao trocar de empresa, o app chama `Purchases.logIn(novoCompanyId)`. No logout, chama `Purchases.logOut()`.

### 5.2 Produtos e entitlements

| Plano | Produto (App Store e Play) | Entitlement |
|---|---|---|
| Starter | `praticos_starter_monthly` | `starter` |
| Pro | `praticos_pro_monthly` | `pro` |
| Business | `praticos_business_monthly` | `business` |

- Na App Store, os três ficam no mesmo grupo de assinatura (`PraticOS`), em ordem: Business > Pro > Starter. Assim, upgrade e downgrade são tratados pela Apple.
- O RevenueCat tem uma offering `default` com os três pacotes.
- O mapeamento produto → plano continua em `subscription.service.ts`. As entradas `_annual` ficam para quando o anual existir.
- O entitlement de teste `Rafsoft Pro` sai do código de release.

### 5.3 Servidor (Functions)

**Webhook `POST /webhooks/revenuecat`**

- **Autenticação:** compara o header `Authorization` com o segredo `REVENUECAT_WEBHOOK_AUTH`, em tempo constante e checando o tamanho antes. Sem segredo configurado, responde 500 e não processa.
- **Estado autoritativo:** em vez de confiar na ordem dos eventos, cada evento dispara `GET https://api.revenuecat.com/v1/subscribers/{companyId}`, com a chave secreta `REVENUECAT_SECRET_API_KEY`. O servidor grava o estado atual. Isso torna o processamento idempotente e imune a eventos fora de ordem ou repetidos.
- **Plano efetivo:** o entitlement ativo de maior nível (`business` > `pro` > `starter`). Sem entitlement ativo, o plano é `free`.
- **Status:**

| Situação no RevenueCat | `status` gravado |
|---|---|
| Ativo, renovação ligada | `active` |
| Ativo, renovação desligada (cancelou) | `cancelled`. Acesso mantido até `expiresAt` |
| Em billing retry ou grace period | `past_due`. Acesso mantido |
| Sem entitlement ativo | `expired`, e `plan` vira `free` |

- **Escrita:** atualiza só os campos de plano (`plan`, `status`, `limits`, `expiresAt`, `store`, `rcSubscriberId`, `updatedAt`). Nunca sobrescreve `subscription.usage`.
- **Carência:** se a empresa está em carência (`subscription.source == 'grace'`, `expiresAt` no futuro) e o RevenueCat não tem entitlement ativo, o webhook não mexe.
- **Resposta:** responde 200 para eventos tratados e ignorados. Responde 5xx para falhas transitórias, assim o RevenueCat tenta de novo.

**Job diário `expireSubscriptions`** (agendado)
- Rebaixa para `free` as empresas com `expiresAt` vencido, `status != active` e nenhum entitlement ativo no RevenueCat. Cobre o fim da carência e eventos perdidos.

**Job mensal `scheduledResetMonthlyUsage`** (já existe)
- Passa a zerar `photosThisMonth` de todas as empresas com `subscription`, não só das que têm `usageResetAt`.

**Script de carência** (`firebase/functions/scripts/grant-grace-period.ts`, roda uma vez)
- Para cada empresa sem assinatura paga, grava:

```json
{ "plan": "pro", "status": "active", "source": "grace", "expiresAt": "<data do lançamento + 60 dias>" }
```

  Também grava os limites do Pro e preserva `usage`.
- Tem `--dry-run` e imprime só totais agregados (nada de nomes de empresas no repositório nem no log).

### 5.4 Firestore rules

- O cliente pode criar a empresa com `subscription` ausente ou exatamente igual ao Free padrão.
- Em `update`, se `subscription` mudar, a única chave alterada dentro dela pode ser `usage`:

```
request.resource.data.subscription.diff(resource.data.subscription).affectedKeys().hasOnly(['usage'])
```

- Vale também para o `match` legado das linhas ~267-272.
- Testes de regras com o emulador cobrem:
  - dono não consegue mudar `plan`;
  - dono consegue incrementar `usage`;
  - membro sem papel não consegue nada.

**Limitação aceita:** quem tem acesso de escrita consegue diminuir o próprio contador de uso. O ganho é pequeno (algumas fotos a mais) e mover os contadores para o servidor está fora do escopo.

### 5.5 Modelo único de assinatura

O schema canônico é o do servidor, porque é ele que grava.

| Campo | Tipo | Observação |
|---|---|---|
| `plan` | `free \| starter \| pro \| business` | |
| `status` | `active \| cancelled \| past_due \| expired` | Valor desconhecido vira `active` no cliente (`unknownEnumValue`) |
| `source` | `store \| grace` | |
| `store` | `app_store \| play_store \| null` | |
| `expiresAt` | ISO string | |
| `limits` | `{ photosPerMonth, formTemplates, users, pdfWatermark }` | |
| `usage` | `{ photosThisMonth, formTemplatesActive, usersActive, usageResetAt }` | |

- O cliente renomeia os campos de `usage` e ajusta os enums.
- Documentos antigos com campos no formato do cliente são lidos com fallback (`formTemplates` → `formTemplatesActive`). Nenhuma migração de dados é necessária, porque os contadores do cliente nunca funcionaram de fato.

**Plano efetivo no cliente:** `plan` quando `expiresAt` é nulo ou futuro; caso contrário, `free`. O app não depende do job diário para cortar o acesso.

### 5.6 App (Flutter)

**`SubscriptionStore`**
- `initialize(companyId)` depois do login, `logIn` na troca de empresa, `logOut` no logout.
- Mantém um listener do documento da empresa e expõe `effectivePlan`/`limits`.
- Preenche `Global.subscription`, consumido pelo `FeatureGateService` e pelo `order_store`. As chamadas que hoje passam `null` passam a usar o valor real.

**Chaves de plataforma**
- `revenueCatEnabled`, `purchaseUiEnabled` e `planLimitsEnforced` são ligados juntos para iOS e Android, por uma única constante `SubscriptionService.paidPlansEnabled`. Ela só fica `true` se o SDK estiver configurado com chave real (`appl_`/`goog_`).
- Se a chave faltar no build, o app fica ilimitado e sem compra nas duas plataformas, como o iOS hoje. Isso evita impor limite sem ter como comprar.

**Paywall**
- `RevenueCatUI.presentPaywallIfNeeded` (ou `presentPaywall`), com a offering `default`, configurado no painel do RevenueCat com:
  - preço e período vindos da loja;
  - texto de renovação automática;
  - links de Termos de uso (EULA padrão da Apple ou `https://praticos.web.app/terms.html`) e Política de privacidade (`https://praticos.web.app/privacy.html`);
  - botão Restaurar.
- Pontos de entrada:
  - Ajustes > Assinatura;
  - diálogo de limite de fotos (`photo_limit_dialog.dart`);
  - limite de formulários e de colaboradores;
  - deep link `upgrade`/`plans`.

**Gerenciar assinatura e restaurar**
- O Customer Center do RevenueCat (`RevenueCatUI.presentCustomerCenter`) substitui a `ManageSubscriptionScreen`.
- O "Restaurar" de Ajustes chama `Purchases.restorePurchases()` de verdade e mostra o resultado real.

**Quem compra**
- Os pontos de entrada só mostram o botão de assinar para `owner`/`admin`.
- Os outros membros veem "Peça ao administrador da empresa para mudar de plano".

**Remoções**
- `PlansScreen`, `SubscriptionSuccessScreen`, `ManageSubscriptionScreen` e suas rotas.
- Os textos de FAQ do paywall antigo.
- A duplicata de `FeatureGateLimitException`.
- O `photo_service.dart` passa a gravar em `companies/`.

**Exclusão de conta**
- O diálogo de excluir conta avisa que a assinatura da loja precisa ser cancelada nos ajustes da loja.
- Inclui o link para gerenciar a assinatura.

**i18n**
- Todas as strings novas nos 3 `.arb`.
- O paywall do RevenueCat é configurado em pt, en e es no painel.

### 5.7 Site, notas da App Review e Android

- **Site:** trocar "gratuito, sem cartão" por "comece grátis; planos pagos dentro do app" (FAQ, home, segmentos). Continua sem tabela de preços.
- **Notas da App Review** (`Deliverfile` e `notes.txt`):
  - o app é freemium;
  - os planos são vendidos via In-App Purchase;
  - a conta demo mostra o paywall em Ajustes > Assinatura;
  - o cadastro de empresa é grátis e os limites do Free são liberados pela assinatura IAP.
- **Resposta no Resolution Center**, junto com o envio: "implementamos In-App Purchase para todos os planos pagos; o cadastro dá acesso ao plano Free, e os planos pagos estão à venda no app via In-App Purchase".
- **Android:** mesma regra. Google Play Billing via RevenueCat, chave `goog_`.

## 6. Pré-requisitos manuais (Rafael)

Rodam em paralelo com o código. Sem eles, o app não pode ser enviado.

1. **App Store Connect:**
   - Paid Apps Agreement assinado, dados bancários e fiscais.
   - Grupo de assinatura `PraticOS` com os 3 produtos mensais e preços em BRL. As outras regiões seguem por equivalência.
   - Localizações dos produtos e screenshot de revisão.
   - Chave In-App Purchase (.p8) para o RevenueCat.
2. **Google Play Console:**
   - Os 3 produtos de assinatura, cada um com base plan mensal.
   - Service account com acesso para o RevenueCat.
3. **RevenueCat:**
   - Projeto com os apps iOS e Android, os entitlements e a offering `default`.
   - Paywall configurado e Customer Center ligado.
   - Webhook apontando para a Function, com header `Authorization`.
4. **Secrets:**
   - GitHub: `REVENUECAT_IOS_API_KEY` e `REVENUECAT_ANDROID_API_KEY` com as chaves reais.
   - Functions: `REVENUECAT_WEBHOOK_AUTH` e `REVENUECAT_SECRET_API_KEY`.
5. **Sandbox:** testar a compra com uma conta Sandbox no iPhone e com um license tester no Play antes do envio.

## 7. Entrega em PRs

Dois PRs, para respeitar o limite de 2 PRs de agente abertos:

| PR | Conteúdo | Risco |
|---|---|---|
| A (backend) | Webhook (auth, estado autoritativo, status), job `expireSubscriptions`, reset mensal, rules (`subscription` só com `usage` editável), script de carência, testes | high |
| B (app) | Modelo unificado, store ao vivo, `Global.subscription`, contador de fotos em `companies/`, paywall e Customer Center, restaurar real, só owner/admin, remoção das telas antigas, `paidPlansEnabled`, i18n, aviso na exclusão de conta, site, notas da App Review, docs | high |

O PR B é seguro sem o A: sem chave real do RevenueCat, `paidPlansEnabled` fica `false`.

**Ordem de lançamento:**
1. Deploy do servidor e das rules.
2. Script de carência em produção.
3. Build com as chaves reais vai para o TestFlight e para o internal track.
4. Teste no sandbox.
5. Envio à Apple com os produtos anexados à versão.
6. Resposta no Resolution Center.

## 8. Testes

- **Functions (`npm test`):**
  - autenticação do webhook (sem header, header errado, tamanho diferente, sem segredo);
  - mapeamento entitlement → plano;
  - os quatro status;
  - carência não sobrescrita;
  - `usage` preservado;
  - job de expiração.
  - A API do RevenueCat entra mockada.
- **Rules (emulador):** os casos da seção 5.4.
- **Flutter (`fvm flutter test`):**
  - `fromJson` com documentos do servidor e com o formato antigo;
  - plano efetivo com `expiresAt` vencido;
  - `FeatureGateService` com `paidPlansEnabled` ligado e desligado;
  - visibilidade do botão de assinar por papel.
- **Manual, antes do envio:**
  - comprar, cancelar, restaurar em outro aparelho e trocar de plano no sandbox iOS e no Play;
  - conferir o Firestore depois de cada evento.

## 9. Riscos

| Risco | Mitigação |
|---|---|
| A Apple rejeita os produtos ou o paywall | Paywall do RevenueCat com os elementos da 3.1.2; screenshot de revisão de cada produto; notas explicando onde fica o paywall |
| Empresa existente perde acesso de repente | Carência de 60 dias gravada antes do lançamento; plano efetivo calculado com `expiresAt` |
| Webhook perdido ou fora de ordem | Consulta ao RevenueCat a cada evento e job diário de expiração |
| Build sai sem chave real | `paidPlansEnabled` exige chave `appl_`/`goog_`; sem ela, o app volta a ser ilimitado e sem compra |
| Fraude escrevendo `plan` no Firestore | Rules bloqueiam qualquer chave de `subscription` além de `usage` |
