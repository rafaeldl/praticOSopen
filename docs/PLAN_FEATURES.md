# PLAN_FEATURES.md

## Visão Geral

Cada plano libera recursos próprios além dos limites (#724). A lista vem de
`features` em `docs/plans/plans.json` (cumulativa: cada plano inclui os do
anterior). Servidor, app e web fazem a mesma checagem, com os mesmos casos de
contrato (`docs/web-app/contract-cases/plan-features.json`).

Tudo fica atrás da chave única dos limites, `config/paidPlans.enabled`
(desligada por padrão; no app também exige build com loja). Com ela desligada
nada muda para ninguém.

| Recurso (`features`) | Plano | Onde trava |
|---|---|---|
| `charges` | Starter | Servidor: `POST /v1/app/orders/:id/charges`, `POST /v1/app/payments/asaas/connect`. App: abrir "Mandar cobrança", conectar Asaas. Web: idem |
| `reviewRequest` | Starter | Ainda sem checagem: a avaliação chega pelo link da OS, que é do básico. Fica na tabela para a tela Plano e as lojas |
| `teamRoles` | Pro | Servidor: convite (`POST /v1/app/invites`) e troca de papel (`PATCH /v1/app/team/members/:id`, `PATCH /v1/company/members/:id`) para gerente, supervisor, consultor ou técnico. App/web: escolha do papel |
| `perPersonAgenda` | Pro | App/web: filtro "de quem" da agenda e escolha do responsável |
| `workStages` | Pro | Web: criar etapas (`StagesForm.vue`). App: não cria etapas (só usa as que existem). Servidor: sem rota; a lista grava direto em `companies/{id}` (travar lá pede regra no `firestore.rules`) |
| `tvMode` | Pro | Web: Modo TV. App: não tem. Servidor: só lê, nada grava |
| `contracts` | Pro | App: ligar contratos. Web: criar contrato |
| `aiFinance` | Pro | Servidor: `getAiSettings` desliga `financeActions` sem o recurso |
| `spreadsheetExport` | Pro | Web: CSV/Excel do relatório (gerado no navegador a partir de `GET /v1/app/finance/report`, que também serve o relatório impresso de todo plano). App: não tem |
| `bulkActions` | Business | Web: ações em lote. App: não tem. Servidor: o lote chama a rota de cada OS, igual a uma OS sozinha, então não há o que travar lá |
| `mcp` | Business | Servidor: `POST /v1/app/integrations/tokens`. App/web: nova conexão ChatGPT/Claude |
| `nfse`, `brandedPdf`, `ownChecklists` | Starter | Já seguem os limites da tabela (`nfseCnpjs`, `pdfWatermark`, `ownChecklists`) |
| `api` | Business | Ainda sem checagem: as chaves de API são criadas à mão |

O básico (o que o Free tem: OS, clientes, catálogo, agenda, orçamento, aprovação
pelo link, financeiro básico, importar, app web) e a IA (`ai`) nunca travam. A
IA tem só os tetos de uso.

## Arquitetura

- Servidor: `firebase/functions/src/services/plan-features.service.ts`
  (`checkPlanFeature`, `requiredPlanFor`, `featureForRole`,
  `checkCompanyPlanFeature`, `planFeatureError`) e
  `middleware/plan-limit.middleware.ts` (`requirePlanFeature`,
  `ensurePlanFeature`).
- App: `FeatureGateService.checkFeature` / `checkFeatureKey` /
  `featureForRole` (`lib/services/feature_gate_service.dart`) e
  `lib/widgets/plan_feature_notice.dart` (`ensurePlanFeature`,
  `showPlanFeatureNotice`).
- Web: `firebase/webapp/src/lib/plan-features.ts` e o aviso
  `PlanFeatureNotice.vue`.

## Regras de Negócio

1. Chave desligada: tudo liberado.
2. Plano ausente ou desconhecido é Free; plano com `expiresAt` vencido é Free
   da tabela atual.
3. A linha é a do plano em vigor (`planInForce`, a mesma dos limites, nos três
   lados): `tableVersion` gravado; sem ele, plano pago (assinante de antes da
   tabela atual e cortesia) segue a versão antiga (#726). A versão 1 não lista
   recursos, então o assinante atual e a cortesia mantêm tudo.
4. `requiredPlan` é o primeiro plano da tabela atual com o recurso: o plano
   para onde mudar.
5. Só trava criar ou ligar algo novo. O que a empresa já tem (contratos,
   etapas, membros com papel Pro, conexões) continua funcionando depois de
   cair de plano.
6. Resposta do servidor: `402 { error: { code: 'PLAN_FEATURE', feature, plan, requiredPlan } }`.

## Aviso ao usuário

Mesmo texto no app e na web:

- Título: "Recurso do plano {plano}" (`planFeatureTitle`).
- Texto: "{recurso}. Para usar, mude para o plano {plano}. O que você já tem
  continua." (`planFeatureBody`); quem não é dono nem admin lê "Peça ao dono da
  empresa para mudar para o plano {plano}." (`planFeatureAskOwner`).
- Dono e admin: "Ver planos" (app: paywall; web: tela Plano).

## Fora do servidor por enquanto

Escritas diretas no Firestore (ligar contratos, etapas, responsável da OS)
não passam por rota: a checagem é só no app e na web. Fechar no servidor
pediria regra no `firestore.rules`.

## Tela Plano (#725)

App (`plan_screen.dart`) e web (`PlanView.vue`) mostram o mesmo, pela mesma
regra: `planOverview` em `lib/services/plan_overview.dart` e
`firebase/webapp/src/lib/plan-overview.ts`, com os casos de
`docs/web-app/contract-cases/plan-overview.json`.

- Linhas: OS este mês, pessoas na equipe e CNPJs na nota fiscal (só quando o
  plano tem nota; contados em `companies/{id}/fiscalEmitters`). Sem contador
  de IA.
- Nível: quase no limite a partir de 80%, no limite, acima. Pessoas com limite
  1 nunca avisam (empresa nova no Free não vê aviso).
- Um aviso só, OS antes de pessoas: 80%; 100%; passou neste mês (mês de
  folga); passou de novo (a OS nova espera mudar de plano); Business acima
  ("fale com a gente").
- "O que o {próximo plano} dá a mais": os recursos do plano seguinte que o
  atual não tem.
- Chave desligada: os números aparecem sem limite e sem aviso.
- Compra: no app, "Ver planos" abre o paywall (RevenueCat, oferta `default`).
  Na web, por enquanto, a tela diz para mudar de plano pelo app (#664).
