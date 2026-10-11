# VALUES_AND_BILLING_TOGGLE.md

## Visão Geral

Opção por empresa **"Valores e cobrança"** (Mais › Sua empresa › Como você trabalha).
Desligada, a empresa usa o app só para registrar o serviço (fotos, checklist,
assinatura): preços, totais, "Receber", cobrança e a aba Financeiro somem para
todas as pessoas da empresa, inclusive o dono. Nada é apagado.

Spec: `docs/superpowers/specs/2026-10-11-financeiro-opcional-design.md`.

## Arquitetura

- **Campo:** `Company.useFinancial` (`bool?`), chave Firestore `useFinancial`.
  `null`/ausente = `true` (comportamento de sempre).
- **Resolução** (`auth_wrapper.dart`, bloco "Resolve feature toggles"):
  empresa > padrão do segmento (`segments/{id}.useFinancial`, ausente = `true`) > `true`.
  Não há backfill: ausente continua ausente.
- **Estado em runtime:** `SegmentConfigService.useFinancial` /
  `SegmentConfigProvider.useFinancial` (`setCompanyConfig(useFinancial:)`;
  `setUseFinancial()` notifica os ouvintes).
- **Permissões:** `RolePermissions.financialPermissions`
  (`viewPrices`, `viewBilling`, `viewFinancialReports`, `editPrices`, `chargeOrder`).
  Com a opção desligada, `AuthorizationService.hasPermission` e
  `currentPermissions` negam essas permissões para qualquer papel
  (`RolePermissions.hasPermissionInCompany`).
- **Abas:** `visibleAppTabs(useFinancial:)` esconde Financeiro.
- **Escrita:** `MyCompanySettings` (`more/my_company_screen.dart`) faz
  `update({'useFinancial': bool})` em `/companies/{companyId}`. Regras do
  Firestore não mudam (owner/admin já podem atualizar a empresa).
- **Seed:** `firebase/scripts/seed_segments.js` grava `useFinancial: true` nos
  segmentos que não definem o campo.

## Fluxo de Dados

```
Mais › Sua empresa (switch)
  → confirmação ao desligar
  → SegmentConfigProvider.setUseFinancial (efeito imediato; volta se falhar)
  → Firestore companies/{id}.useFinancial
Próxima abertura: auth_wrapper resolve o campo → setCompanyConfig
  → AuthorizationService nega permissões financeiras → telas escondem valores
```

## Regras de Negócio

1. Padrão `true`: nenhuma empresa existente perde nada.
2. Desligar não apaga valores, cobranças nem pagamentos; religar mostra tudo de novo.
3. Desligar pede confirmação (links de pagamento já enviados continuam valendo).
4. A linha só aparece para quem vê "Sua empresa" (`manageCompany`).

## O que some com a opção desligada (no app)

| Onde | Como |
|---|---|
| Aba Financeiro | `visibleAppTabs` + `viewFinancialReports` |
| OS (nova e antiga) | Preço dos itens, total, "Falta receber", "Receber R$ X" (`viewPrices`), cobrança Asaas (`chargeOrder`); o PDF continua no menu, sem valores |
| Catálogo | Preço na lista e campo de preço no formulário (valor salvo é mantido) |
| Seletor "O que vai na OS?" | Preços nas linhas |
| Início | Valor nas linhas de OS |
| Cliente / Veículo | Total das OS e "Total gasto" |

## Fora do app

| Onde | Como |
|---|---|
| Link do cliente `/q/{token}` | Functions (`routes/public/orders.routes.ts`) não envia preços, totais, pagamentos nem cobrança; `showValues: false` na resposta. Ver `docs/SHARE_LINK.md` |
| PDF da OS | Variante sem valores (`OsPdfData.showValues`). Ver `docs/PDF_GENERATION.md` |

## Pendente (fora deste passo)

- Painel admin (`firebase/web`) ainda não mostra o campo.
- Assistente (IA): não perguntar/propor valores.
