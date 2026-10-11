# Valores e cobrança opcionais por empresa

**Data:** 2026-10-11 · **Status:** proposta · **Protótipo:** canvas https://claude.ai/artifact/NfHsv1Ge52LXGdpd9ZYihz, prancha "Mais · sua empresa" (`app-sua-empresa`), seção "Como você trabalha".

## Problema

Algumas empresas fazem só serviço terceirizado: a OS registra o que foi feito (fotos, checklist, assinatura), mas o dinheiro é tratado fora do app. Hoje todas veem preços, totais, "Receber", cobrança e a aba Financeiro, que para elas só poluem a tela.

## Proposta

Uma opção na empresa, ao lado de Agenda e Atendimento fora da oficina:

- **"Valores e cobrança"** · "Preços na OS, receber e aba Financeiro". Ligado por padrão.

Desligada, para todas as pessoas da empresa (inclusive o dono):

| Onde | O que some |
|---|---|
| Abas | Aba Financeiro |
| OS | Preço dos itens, total, "Falta receber", próximo passo "Receber R$ X", "Mandar link para pagar" |
| Catálogo | Campo de preço (serviço e produto) e o preço na lista |
| Seletor "O que vai na OS?" | Preços nas linhas |
| Link e PDF para o cliente | Valores e total (a OS vira um relatório do serviço) |
| Assistente (IA) | Não pergunta nem propõe valores; "item sem valor" deixa de ser pendência |
| Início | Nada de "a receber" no próximo passo |

Nada é apagado: os valores já salvos continuam no banco e voltam a aparecer se a opção for religada.

## Como funciona (segue o padrão de `fieldService`, `useScheduling`, `useDeviceManagement`)

- **Campo novo:** `Company.useFinancial` (`bool?`), chave Firestore `useFinancial`.
- **Resolução** em `auth_wrapper.dart` (bloco "Resolve feature toggles", hoje ~l. 433): empresa > padrão do ramo > `true`.
  `final useFinancial = companyData?['useFinancial'] as bool? ?? segmentProvider.segmentUseFinancialDefault;`
  e entra em `segmentProvider.setCompanyConfig(...)` como os outros.
- **Padrão por ramo (bootstrap):** campo `useFinancial` no documento do segmento, lido em `SegmentConfigService` como o `fieldService` (`data['useFinancial'] as bool? ?? true`) e semeado em `firebase/scripts/seed_segments.js`. Todos os ramos atuais ficam `true`; um ramo de serviço terceirizado (ou um "Outro" futuro) pode vir `false`.
- **Primeiro acesso:** a tela que confirma o bootstrap (`confirm_bootstrap_screen.dart`) já grava `fieldService`/`useScheduling`; passa a gravar `useFinancial` com o padrão do ramo. Não vira uma pergunta nova no primeiro acesso (menos telas); quem precisa muda em Mais › Sua empresa.
- **Esconder:** reaproveitar as permissões que já escondem preço e financeiro. Com `useFinancial == false`, `AuthorizationService` responde `false` para `viewPrices`, `viewFinancialReports` e as de pagamento/cobrança, para qualquer papel. Assim as telas que já respeitam essas permissões (`order_form`, `home`, `service_list_screen`, `product_list_screen`, `order_service_screen`, `order_product_screen`) mudam sem lógica nova; a aba Financeiro já some sem `viewFinancialReports` (spec `2026-10-09-telas-mapa-design.md`).
- **Fora do app:** o link/PDF do cliente (`firebase/web`, Functions do PDF) lê `useFinancial` da empresa para esconder valores. O painel admin (`firebase/web/pages/admin/companies/[id].vue`) mostra o campo junto dos outros.
- **i18n:** título e subtítulo da opção nos 3 `.arb`.

## Regras

1. Padrão `true`: nenhuma empresa existente perde nada.
2. Desligar não apaga valores, cobranças nem pagamentos.
3. Se houver cobrança Asaas em aberto, desligar pede confirmação: "Há 2 links de pagamento abertos. Eles continuam valendo." (sem cancelar sozinho).
4. A opção só aparece para quem pode editar a empresa.

## Ordem de implementação

1. Modelo + resolução + `SegmentConfigService` + seed dos segmentos (`risk:high`: modelo compartilhado).
2. `AuthorizationService` respeitando a opção + teste por papel (`risk:high`: permissões).
3. Linha em Mais › Sua empresa (ou `company_form_screen` atual) + i18n (`risk:low`).
4. Link/PDF do cliente sem valores (`risk:high`: Functions de produção).
5. Admin web mostra o campo (`risk:low`).

## Em aberto

- Nome do ramo/segmento que nasce com `useFinancial: false` (ex.: "Serviços terceirizados"), se for criado.
