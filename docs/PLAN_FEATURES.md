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
| `teamRoles` | Pro | Servidor: convite (`POST /v1/app/invites`) e troca de papel (`PATCH /v1/app/team/members/:id`, `PATCH /v1/company/members/:id`) para gerente, supervisor, consultor ou técnico. App/web: escolha do papel |
| `perPersonAgenda` | Pro | App/web: filtro "de quem" da agenda e escolha do responsável |
| `workStages` | Pro | Web: criar etapas (`StagesForm.vue`) |
| `tvMode` | Pro | Web: Modo TV |
| `contracts` | Pro | App: ligar contratos. Web: criar contrato |
| `aiFinance` | Pro | Servidor: `getAiSettings` desliga `financeActions` sem o recurso |
| `spreadsheetExport` | Pro | Web: relatório em planilha |
| `bulkActions` | Business | Web: ações em lote |
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
3. Enquanto o plano vale, a linha vem da versão da tabela da assinatura
   (`tableVersion`, #726). Uma versão sem nenhum recurso listado (a 1) não
   trava nada.
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
