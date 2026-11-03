# PLAN_LIMITS_SERVER.md

## Visão Geral

Os limites do plano (fotos por mês, modelos de checklist ativos, pessoas na empresa) só eram barrados no app (`lib/services/feature_gate_service.dart`, `lib/models/subscription.dart`). O servidor agora tem a mesma conta e a aplica nas rotas de escrita da API, para o web não passar do plano.

Nenhum valor, preço ou plano mudou, e a compra pela web continua desligada. As regras do Firestore não mudaram: o app segue gravando direto, sem bloqueio do servidor.

## Arquitetura

- `firebase/functions/src/services/plan-limits.service.ts`: a conta (`checkPlanLimit`, `effectivePlan`, `effectiveLimits`, `shouldShowPdfWatermark`), a contagem de uso e a chave global.
- `firebase/functions/src/middleware/plan-limit.middleware.ts`: `requirePlanCapacity(recurso)`, depois das checagens de permissão.
- Valores: `PLAN_LIMITS` em `subscription-plans.ts` (iguais a `SubscriptionLimits.defaults`).
- Casos compartilhados: `docs/web-app/contract-cases/plan-limits.json`, rodando no Dart (`test/contract/plan_limits_cases_test.dart`, `FeatureGateService` real) e em Functions (`plan-limits.cases.test.ts`).

Firestore lido:

```
config/paidPlans                       enabled (chave global, padrão desligado)
companies/{id}.subscription            plan, expiresAt, limits
companies/{id}/memberships/*           pessoas
links/invites/tokens/*                 convites pendentes (company.id, status, expiresAt)
companies/{id}/forms/*                 modelos de checklist (isActive)
Storage tenants/{id}/orders/*/photos/* fotos de OS (timeCreated)
```

## Regras de Negócio

Iguais ao app, provadas pelos casos:

- Permitido se o limite é -1 (ilimitado) ou `uso + o que entra <= limite`.
- **Chave**: no app, `paidPlansEnabled` (build com chave da loja). No servidor, `config/paidPlans.enabled`. Desligada, todo limite vale -1, como um build sem chave. Padrão: desligada.
- **Plano ausente** (sem `subscription`, só `usage`, ou plano desconhecido) é Free.
- **Vencido** (`expiresAt` no passado, cortesia ou loja) é Free com os limites padrão do Free, mesmo com limites do Pro gravados. O `status` não conta: Pro com `status: expired` e sem data continua Pro.
- **Cortesia** em vigor é Pro (o que estiver gravado em `limits`).
- **Limites gravados** ganham do padrão do plano; campo faltando vira o padrão do Free (Pro com só `photosPerMonth` gravado fica com 1 checklist). `collaborators` é o nome antigo de `users`.
- **Marca d'água no PDF**: só com a chave ligada e `pdfWatermark` do plano em vigor.

### Uso contado no servidor

Os contadores que o app grava (`subscription.usage.*`) não são lidos.

| Recurso | Conta | Diferença do app |
|---|---|---|
| `collaborator` | `memberships` + convites `pending` não vencidos da empresa | Igual ao `CollaboratorStore`. O app só atualiza o contador quando um admin mexe na equipe |
| `formTemplate` | `companies/{id}/forms` com `isActive != false` | O contador do app consulta `formTemplates`, coleção que não existe nas regras; a falha é engolida e o contador nunca sai do valor gravado. **No app o limite de checklist praticamente não barra** |
| `photo` | Objetos em `tenants/{id}/orders/{os}/photos/` criados desde a meia-noite do dia 1 (Brasília), pela data do Storage | O app só soma quando quem sobe é admin (TODO #458) e nunca desconta. Aqui conta todo perfil e todo cliente, e foto apagada no mês deixa de contar. Fotos de checklist não contam (o app também não barra nem conta) |

Com plano ilimitado no recurso, ou chave desligada, nada é contado.

## Onde barra

| Rota | Recurso | Quando conta |
|---|---|---|
| `POST /v1/app/invites` (app e web) | `collaborator` | Sempre |
| `POST /bot/invite/create` | `collaborator` | Sempre |
| `POST /v1/app/orders/:id/photos` (nova) | `photo` | Sempre |
| `POST /bot/orders/:number/photos` e `/photos/upload` (usadas pelo MCP) | `photo` | Sempre |
| `POST /v1/app/forms/templates` (nova) | `formTemplate` | Sempre, mesmo salvo inativo (como `saveTemplate`) |
| `POST /v1/app/forms/templates/import` (nova) | `formTemplate` | Sempre (como `importGlobalTemplate`) |
| `PATCH /v1/app/forms/templates/:id` (nova) | `formTemplate` | Só ao ligar um modelo desligado (como `toggleTemplateStatus`) |

`DELETE /v1/app/forms/templates/:id` não conta. Aceitar convite não conta (convite pendente vira membro).

Resposta no limite, HTTP 402:

```json
{
  "success": false,
  "error": {
    "code": "PLAN_LIMIT",
    "message": "Plan limit reached for photo (30/30)",
    "resource": "photo",
    "limit": 30,
    "usage": 30,
    "adding": 1,
    "plan": "free"
  }
}
```

402 e não 403, para não se confundir com falta de permissão. O app atual mostra "Failed to create invite: 402" se receber isso no convite.

## Fluxo de Dados

```
rota → requireAppPermission → requirePlanCapacity(recurso)
         → config/paidPlans.enabled? não → segue
         → companies/{id}.subscription → limite do plano em vigor
         → limite -1? segue
         → conta o uso → uso + 1 > limite? 402 PLAN_LIMIT
```

Conferir e gravar não é atômico: duas fotos enviadas no mesmo instante no limite podem passar as duas.

## Pendente de decisão

- **Ligar `config/paidPlans.enabled`.** Com a chave ligada, o convite pelo app (`POST /v1/app/invites`, que o app já usa) passa a ser barrado pelo uso real. Empresa Free com convite pendente ou com o contador do app desatualizado vai receber 402 onde hoje o app deixa. A cortesia Pro de lançamento vai até 07/12/2026; depois disso, empresas Free vão bater no limite.
- Checklist: o servidor conta os modelos de verdade e o app não. Ligar a chave faz o web barrar checklists que o app deixa criar. Corrigir o contador do app (`formTemplates` → `forms`) é outra tarefa.
- Fotos: a contagem pelo Storage lista todos os arquivos das OS da empresa a cada envio (paginado de mil em mil). Para empresa Free com histórico grande, uma alternativa é um contador mantido por gatilho do Storage.
- O app continua sem gravar os contadores certos. Gravar o uso contado pelo servidor em `subscription.usage` faria o app barrar com o número real; isso muda o app e ficou de fora.
- Plano no web: sem compra pela web, o usuário do web no limite precisa assinar pelo app.

## Exemplos de Uso

```ts
import { checkCompanyPlanLimit, planLimitError } from '../services/plan-limits.service';

const check = await checkCompanyPlanLimit(companyId, 'photo', 3);
if (!check.allowed) return res.status(402).json(planLimitError(check));
```

```ts
router.post('/x', requireAppPermission('attachPhotos'), requirePlanCapacity('photo'), handler);
```
