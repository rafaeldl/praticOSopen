# PLAN_LIMITS_SERVER.md

## Visão Geral

Os limites do plano (fotos por mês, modelos de checklist ativos, pessoas na empresa) só eram barrados no app (`lib/services/feature_gate_service.dart`, `lib/models/subscription.dart`). O servidor agora tem a mesma conta e a aplica nas rotas de escrita da API, para o web não passar do plano.

Nenhum valor, preço ou plano mudou, e a compra pela web continua desligada. As regras do Firestore não mudaram: o app segue gravando direto, sem bloqueio do servidor.

## Tabela nova (aprovada em 12/11/2026)

O dono aprovou uma tabela nova no épico #721. Os valores abaixo **ainda não estão no código**: entram com #722 (uma tabela só para servidor, app e web) e #723 (limites novos no servidor). Até lá, vale o `PLAN_LIMITS` atual.

| | Grátis | Starter | Pro | Business |
|---|---|---|---|---|
| OS por mês | 10 | 50 | 150 | 500 incluídas, depois +R$ 99 a cada 100 |
| Pessoas | 1 | 2 | 5 | 20, depois +R$ 15 cada |
| CNPJs na nota | — | 1 | 2 | sem limite |
| Fotos | sem limite | sem limite | sem limite | sem limite |
| IA (teto interno, o cliente não vê) | 50/mês, 20/dia | 1.000/mês, 200/dia | 3.000/mês, 200/dia | 6.000/mês |
| PDF sem a marca PraticOS | — | ✓ | ✓ | ✓ |
| Checklists | só os do ramo | próprios | próprios | próprios |

Regras novas que mudam a conta deste documento:

- O plano é o maior entre OS por mês, pessoas e CNPJs.
- Limite suave: aviso ao chegar perto e ao passar, o primeiro mês acima do limite ainda cria OS, e a OS nova só espera a troca de plano quando o mês anterior também passou; nunca trava uma OS já aberta. Hoje a conta é dura (`uso + o que entra <= limite`, 402).
- IA incluída em todos os planos, inclusive no Grátis (decisão de 12/11, comentário na #729): sem contador na tela; o teto é interno e os termos falam em uso justo.
- Fotos deixam de ter limite; o contador `photosThisMonth` passa a servir só para custo.
- Abrir OS, mandar ao cliente, aprovação pelo link, agenda e importar ficam em todos os planos.

A tabela completa, com preços e recursos de cada plano, está em [`SUBSCRIPTION.md`](SUBSCRIPTION.md#approved-table-2026-11-12-epic-721).

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
companies/{id}.subscription.usage     photosThisMonth (contador dos gatilhos da OS)
```

## Regras de Negócio

Iguais ao app, provadas pelos casos:

- Permitido se o limite é -1 (ilimitado) ou `uso + o que entra <= limite`.
- **Chaves**: no app, `paidPlansEnabled` (build com chave da loja). No servidor são duas, ambas desligadas por padrão:
  - `PLAN_LIMITS_ENABLED=true` no ambiente das Functions (deploy). Desligada, o middleware deixa passar sem ler nada (nem Firestore, nem Storage). É ela que deixa as rotas funcionarem em teste sem credencial.
  - `config/paidPlans.enabled == true` (Firestore). Só é lida com a primeira ligada. Desligada, todo limite vale -1, como um build sem chave.
- **Plano ausente** (sem `subscription`, só `usage`, ou plano desconhecido) é Free.
- **Vencido** (`expiresAt` no passado, cortesia ou loja) é Free com os limites padrão do Free, mesmo com limites do Pro gravados. O `status` não conta: Pro com `status: expired` e sem data continua Pro.
- **Cortesia** em vigor é Pro (o que estiver gravado em `limits`).
- **Limites gravados** ganham do padrão do plano; campo faltando vira o padrão do Free (Pro com só `photosPerMonth` gravado fica com 1 checklist). `collaborators` é o nome antigo de `users`.
- **Marca d'água no PDF**: só com a chave ligada e `pdfWatermark` do plano em vigor.
- **Nota fiscal (NFS-e direta)**: vem com qualquer plano em vigor diferente do Free, no Brasil, sem depender das chaves acima. O servidor liga e desliga `settings/payments.nfseDirectEnabled` pelo plano (ver "Quem tem a nota" em [`NFSE_DIRECT.md`](NFSE_DIRECT.md)).

### Uso contado no servidor

Os contadores que o app grava (`subscription.usage.*`) não são lidos.

| Recurso | Conta | Diferença do app |
|---|---|---|
| `collaborator` | `memberships` + convites `pending` não vencidos da empresa | Igual ao `CollaboratorStore`. O app só atualiza o contador quando um admin mexe na equipe |
| `formTemplate` | `companies/{id}/forms` com `isActive != false` | O contador do app consulta `formTemplates`, coleção que não existe nas regras; a falha é engolida e o contador nunca sai do valor gravado. **No app o limite de checklist praticamente não barra** |
| `photo` | `subscription.usage.photosThisMonth`, o contador que os gatilhos da OS somam (`countNewOrderPhotos`, #514) e o job do dia 1 zera. Uma leitura só: o Storage nunca é listado | Os gatilhos só contam com `config/usageCounters.serverOnly` ligado. Desligado, quem grava é o app, e só quando sobe um admin (TODO #458). Foto apagada não desconta. Fotos de checklist não contam |

Com plano ilimitado no recurso, ou chave desligada, nada é contado.

## Onde barra

| Rota | Recurso | Quando conta |
|---|---|---|
| `POST /v1/app/invites` (app e web) | `collaborator` | Sempre |
| `POST /bot/invite/create` | `collaborator` | Sempre |
| `POST /bot/orders/:number/photos` e `/photos/upload` (usadas pelo MCP) | `photo` | Sempre |
Aceitar convite não conta (convite pendente vira membro).

As rotas `POST /v1/app/orders/:id/photos` e `/v1/app/forms/templates` saíram deste PR (revisão do #526, M1): nenhuma tela usa, porque o app e o web gravam fotos no Storage e checklists no Firestore direto. Ficam fora até uma tela precisar delas, e aí entram atrás de uma flag desligada. `src/__tests__/app-routes-mounted.test.ts` falha se alguma for montada. Enquanto isso, o limite de checklist (`formTemplate`) existe na conta, mas nenhuma rota o aplica.

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
         → PLAN_LIMITS_ENABLED == 'true'? não → segue (nada é lido)
         → config/paidPlans.enabled? não → segue
         → companies/{id}.subscription → limite do plano em vigor
         → limite -1? segue
         → conta o uso → uso + 1 > limite? 402 PLAN_LIMIT
```

Conferir e gravar não é atômico: duas fotos enviadas no mesmo instante no limite podem passar as duas.

## Pendente de decisão

- **Ligar** (decisão do dono): pôr `PLAN_LIMITS_ENABLED=true` no ambiente do deploy das Functions e publicar, depois `config/paidPlans { enabled: true }` no Firestore. O deploy do CI (`firebase-functions-deploy.yml`) não tem `.env` (o arquivo fica fora do repositório), então ligar pede um passo no workflow que escreva `firebase/functions/.env.praticos` com essa linha. Para desligar sem deploy, basta voltar `config/paidPlans.enabled` para `false`.
- **Efeito de ligar `config/paidPlans.enabled`.** Com a chave ligada, o convite pelo app (`POST /v1/app/invites`, que o app já usa) passa a ser barrado pelo uso real. Empresa Free com convite pendente ou com o contador do app desatualizado vai receber 402 onde hoje o app deixa. A cortesia Pro de lançamento vai até 07/12/2026; depois disso, empresas Free vão bater no limite.
- Checklist: o servidor conta os modelos de verdade e o app não. Ligar a chave faz o web barrar checklists que o app deixa criar. Corrigir o contador do app (`formTemplates` → `forms`) é outra tarefa.
- Fotos: o limite lê o contador `subscription.usage.photosThisMonth`. **Antes de ligar `PLAN_LIMITS_ENABLED`, ligue `config/usageCounters.serverOnly`**: sem ele, o contador é o do app, que só soma fotos de admin, e o limite de foto quase não barra. O contador não desconta foto apagada no mês.
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

// Teste: injeta a chave e a conta, sem Firestore
requirePlanCapacity('photo', () => 1, { enabled: () => true, check: async () => ({ ...check }) });
```
