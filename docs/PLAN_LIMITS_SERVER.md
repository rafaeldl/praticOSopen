# PLAN_LIMITS_SERVER.md

## Visão Geral

Os limites do plano (fotos por mês, modelos de checklist ativos, pessoas na empresa) só eram barrados no app (`lib/services/feature_gate_service.dart`, `lib/models/subscription.dart`). O servidor agora tem a mesma conta e a aplica nas rotas de escrita da API, para o web não passar do plano.

Nenhum valor, preço ou plano mudou, e a compra pela web continua desligada. As regras do Firestore não mudaram: o app segue gravando direto, sem bloqueio do servidor.

## Arquitetura

- `firebase/functions/src/services/plan-limits.service.ts`: a conta (`checkPlanLimit`, `effectivePlan`, `effectiveLimits`, `shouldShowPdfWatermark`), a contagem de uso e a chave global.
- `firebase/functions/src/middleware/plan-limit.middleware.ts`: `requirePlanCapacity(recurso)`, depois das checagens de permissão.
- Valores: só em [`docs/plans/plans.json`](plans/plans.json) (#722). Ver "Tabela única" abaixo.
- Casos compartilhados: `docs/web-app/contract-cases/plan-limits.json`, rodando no Dart (`test/contract/plan_limits_cases_test.dart`, `FeatureGateService` real), em Functions (`plan-limits.cases.test.ts`) e na web (`firebase/webapp/tests/contract-cases.test.ts`, `src/lib/plan-limits.ts`).

### Tabela única

`docs/plans/plans.json` tem todas as versões da tabela (`versions`) e a que vale hoje (`currentVersion`). Cada plano tem `ordersPerMonth`, `users`, `photosPerMonth`, `formTemplates`, `ownChecklists`, `nfseCnpjs`, `pdfWatermark`, `aiPerMonth`, `aiPerDay` e `features`; -1 é sem limite.

Para mudar um número: editar o JSON e rodar `node scripts/plan-table.mjs`, que gera:

- `firebase/functions/src/services/plan-table.generated.ts` (servidor: `PLAN_LIMITS`, `AI_REQUESTS_PER_MONTH`, nota fiscal por plano);
- `lib/models/plan_table.dart` (app: `SubscriptionLimits.defaults`, `kAiRequestsPerMonth`);
- a web gera a sua cópia em `npm run gen` (`src/generated/plan-table.ts`, fora do git).

Os dois arquivos gerados ficam no git porque o deploy das Functions e o build do app não leem `docs/`. Um teste em cada lado compara com o JSON e falha se alguém esquecer de gerar (`plan-table.test.ts` nas Functions e na web, `test/models/plan_table_test.dart` no app); `node scripts/plan-table.mjs --check` faz a mesma conferência.

Firestore lido:

```
config/paidPlans                       enabled (chave global, padrão desligado)
companies/{id}.subscription            plan, expiresAt, limits
companies/{id}/memberships/*           pessoas
links/invites/tokens/*                 convites pendentes (company.id, status, expiresAt)
companies/{id}/forms/*                 modelos de checklist (isActive)
companies/{id}.subscription.usage     photosThisMonth (contador dos gatilhos da OS)
```

## Regras de Negócio

Iguais ao app, provadas pelos casos:

- Permitido se o limite é -1 (ilimitado) ou `uso + o que entra <= limite`.
- **Uma chave só** (#723): `config/paidPlans.enabled == true` no Firestore, desligada por padrão. O servidor, o app e o web leem o mesmo documento (as regras deixam qualquer pessoa logada ler; ninguém grava pelo cliente). Desligada, todo limite vale -1. O `PLAN_LIMITS_ENABLED` do ambiente das Functions e o `WEB_PLAN_LIMITS_ENFORCED` do web saíram. O app ainda precisa de uma build que venda (`SubscriptionService.paidPlansEnabled`, regra 3.1.1 da Apple): sem loja não há limite no app, mesmo com a chave ligada. O servidor guarda a chave por um minuto.
- **Plano ausente** (sem `subscription`, só `usage`, ou plano desconhecido) é Free.
- **Vencido** (`expiresAt` no passado, cortesia ou loja) é Free da tabela atual, mesmo com limites do Pro gravados. O `status` não conta: Pro com `status: expired` e sem data continua Pro.
- **Versão da tabela**: a assinatura segue `subscription.tableVersion` quando a tabela tem essa versão; sem ele (ou desconhecido) vale a atual. Ninguém grava `tableVersion` ainda: é o ponto de extensão do #726 (assinantes atuais e cortesia).
- **Limites gravados**: cada número fica com o mais generoso entre o gravado e a tabela (assinante nunca perde, e uma tabela melhor chega a ele); campo faltando é o da tabela; sem marca d'água ganha. `collaborators` é o nome antigo de `users`. O webhook do RevenueCat só regrava `limits` quando o plano muda: renovar o mesmo plano mantém o que estava gravado.
- **OS por mês** (limite suave): aviso a 80% e a 100% (`level`). No primeiro mês acima do limite ainda cria (`grace`); só trava quando o mês anterior também passou do limite. Nunca trava uma OS já aberta (editar, concluir, receber, mandar).
- **Business** (`overageAllowed`): acima de 500 OS ou de 20 pessoas não trava; a resposta diz `contactUs` (cobrança do excedente manual por enquanto).
- **Fotos**: sem limite em todos os planos (`photosPerMonth = -1`); `requirePlanCapacity('photo')` deixa de barrar.
- **Checklists**: `formTemplate` conta só os próprios ativos. Cópia de um pronto do ramo não conta: tem `sourceTemplateId` ("Usar", no app e no web) ou o mesmo id do pronto (cópias do primeiro acesso). Grátis não cria checklist próprio (limite 0); Starter em diante sem limite.
- **IA**: teto do mês e do dia do plano em vigor (`effectivePlan`, então plano vencido é Free) em `reserveAiRequest`. Starter e Pro param em 200 por dia; o dia é UTC, guardado em `aiUsage/{mês}.day/dayCount`. Recusa com `AI_QUOTA_EXCEEDED` e `period: 'month' | 'day'`. O `monthlyLimit` de piloto desliga o teto do dia.
- **Marca d'água no PDF**: só com a chave ligada e `pdfWatermark` do plano em vigor.
- **Nota fiscal (NFS-e direta)**: vem com o plano em vigor que tenha `nfseCnpjs` diferente de 0 (hoje: qualquer pago), no Brasil, sem depender da chave. O servidor liga e desliga `settings/payments.nfseDirectEnabled` pelo plano (ver "Quem tem a nota" em [`NFSE_DIRECT.md`](NFSE_DIRECT.md)). O número de CNPJs ainda não é aplicado.

### Uso contado no servidor

| Recurso | Conta |
|---|---|
| `order` | `subscription.usage.ordersThisMonth`, somado no gatilho de criação da OS (`firestoreUpdateTenantOSNumber` → `countNewOrder`), sempre (o app nunca gravou esse contador). O mês é o de São Paulo; o próprio gatilho vira o mês (`ordersMonth`, `ordersLastMonth`), sem job. OS de exemplo do primeiro acesso (`isSample: true`, no app e no servidor) não contam |
| `collaborator` | `memberships` + convites `pending` não vencidos da empresa, como o `CollaboratorStore` |
| `formTemplate` | Checklists próprios ativos em `companies/{id}/forms` (ver acima). O contador do app (`formTemplatesActive`) e o gatilho `onFormTemplateWrittenUsage` usam a mesma regra |
| `photo` | `subscription.usage.photosThisMonth`; sem limite desde a tabela 2 |

Com plano ilimitado no recurso, ou chave desligada, nada é contado.

## Onde barra

| Rota | Recurso |
|---|---|
| `POST /v1/app/orders` (web, MCP) | `order` (depois da validação: pedido inválido continua 400) |
| `POST /bot/orders/full` (criação) | `order` |
| `POST /v1/app/invites` (app e web) | `collaborator` |
| `POST /bot/invite/create` | `collaborator` |
| `POST /bot/orders/:number/photos` e `/photos/upload` | `photo` (sem limite hoje) |

O app cria OS, checklists e fotos direto no Firestore: ali quem confere é o próprio app (`FeatureGateService.canCreateOrder`, `canCreateFormTemplate`), com a mesma conta. A tela que avisa e pede plano é o #725.

Resposta no limite, HTTP 402, igual para app e web:

```json
{
  "success": false,
  "error": {
    "code": "PLAN_LIMIT",
    "message": "Plan limit reached for order (10/10)",
    "resource": "order",
    "limit": 10,
    "usage": 10,
    "adding": 1,
    "plan": "free"
  }
}
```

402 e não 403, para não se confundir com falta de permissão.

## Fluxo de Dados

```
rota → permissão → requirePlanCapacity / ensurePlanCapacity(recurso)
         → config/paidPlans.enabled? não → segue
         → companies/{id}.subscription → linha da tabela (plano em vigor, tableVersion) + limites gravados
         → limite -1? segue
         → conta o uso → cabe? segue · Business? segue (contactUs) · OS no 1º mês acima? segue (grace) · senão 402
```

Conferir e gravar não é atômico: duas OS criadas no mesmo instante no limite podem passar as duas.

## Pendente de decisão

- **Ligar** (decisão do dono): `config/paidPlans { enabled: true }` no Firestore. Para desligar, voltar para `false` (vale em até um minuto no servidor e no próximo login no app e no web).
- **Web sem compra** (#664): com a chave ligada, o web passa a barrar checklist próprio, convite e OS como o servidor, mas ainda não vende plano. Quem bater no limite no web precisa assinar pelo app.
- **Assinantes atuais** (#726): sem `tableVersion`, valem os números novos, com o mais generoso entre gravado e tabela. Starter atual mantém 3 pessoas e ganha fotos e checklists sem limite, mas passa a ter limite de OS (50) porque a tabela 1 não tinha esse número gravado. Gravar `tableVersion: "1"` mantém OS sem limite.
- **Fotos**: o contador continua sendo somado, só não barra mais.
- `isSample` é gravado pelo cliente: dá para marcar OS como exemplo e fugir da contagem. Aceito por enquanto.

## Exemplos de Uso

```ts
import { checkCompanyPlanLimit, planLimitError } from '../services/plan-limits.service';

const check = await checkCompanyPlanLimit(companyId, 'order');
if (!check.allowed) return res.status(402).json(planLimitError(check));
if (check.grace || check.contactUs || check.level === 'near') {
  // avisar (tela no #725)
}
```

```ts
router.post('/x', requireAppPermission('manageMembers'), requirePlanCapacity('collaborator'), handler);

// Dentro da rota, depois da validação
if (!(await ensurePlanCapacity(res, companyId, 'order'))) return;

// Teste: injeta a chave e a conta, sem Firestore
requirePlanCapacity('collaborator', () => 1, { enabled: () => true, check: async () => ({ ...check }) });
```
