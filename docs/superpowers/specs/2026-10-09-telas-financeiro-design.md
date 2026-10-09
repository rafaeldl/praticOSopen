# Telas do app: Financeiro (aba, pagamentos da OS, cobrança, integrações)

Status: proposta · 2026-10-09 · base: `docs/APP_DESIGN_SYSTEM.md` · componentes: `2026-10-09-telas-componentes-design.md`

Protótipos: canvas https://claude.ai/artifact/NfHsv1Ge52LXGdpd9ZYihz, página "Telas do app". Pranchas deste grupo: "Financeiro · aba", "Financeiro · modo escuro".

## Telas do grupo

| Tela | Arquivo | Uso | O que muda |
|---|---|---|---|
| Aba Financeiro | `lib/screens/dashboard/financial_dashboard_simple.dart` (2.859 linhas, ~1.150 de PDF em `:1716-2859`) | semanal, dono/gerente | Redesenho completo: quem deve, botão de cobrar, 2 números |
| Pagamentos da OS | `lib/screens/payment_management_screen.dart` | diário | Achados + correções; desenho final com a sessão da OS |
| Cobrança na OS (Asaas) | `lib/screens/payments/widgets/order_charge_section.dart`, `order_charge_card.dart` | semanal (piloto) | Achados + correções; alinhar com a sessão da OS |
| Nova cobrança | `lib/screens/payments/create_charge_screen.dart` | semanal (piloto) | Achados + correções; alinhar com a sessão da OS |
| Integrações | `lib/screens/integrations/integration_list_screen.dart` | rara | Só achados |
| Conexão Asaas | `lib/screens/integrations/asaas_connection_screen.dart` | uma vez | Só achados |

## Problema atual (achados)

| Tela | Regra | Evidência | O que o usuário vê | Correção |
|---|---|---|---|---|
| Aba | R1 | 7 blocos de informação, nenhum próximo passo (`financial_dashboard_simple.dart:146-152`) | Painel de números que não diz quem deve nem o que fazer | `NextStepBlock` "Falta receber R$ X de N clientes" + "Mandar cobrança para ..." |
| Aba | R1/R4 | 2 barras e ~9 números antes da 1ª lista (`:491-575`, `:709-819`); 5 opções de período + calendário + modal (`:174-197`, `:343-449`) | Excesso de números e controles | Só mês com ‹ ›; outro período e serviços/produtos no `MoreMenu` |
| Aba | R3 | "Painel Financeiro" (`:133`) com aba "Financeiro"; "FATURAMENTO" (`:492`), "COMPOSIÇÃO" (`:710`), "Média" (`:512`), "Pendente" (`:1524`) | Linguagem de contador | "Financeiro", "Entrou", "Falta receber", "Recebido" |
| Aba | Filtro escondido | Toque em Recebido/A Receber filtra a tela (`:598-638`); toque no cliente (com seta) refiltra o painel inteiro (`:994-1003`, `order_store.dart:2063-2066`) | A seta promete abrir algo; os valores mudam sem aviso | Toque abre a OS (uma) ou as OS do cliente (várias); sem filtro por toque |
| Aba | R4 | 4 cartões "Sem dados..." empilhados (`:833-836`, `:1091-1094`, `:1219-1222`, `:1374-1377`) | "Sem dados de produtos" fixo para quem só faz serviço | Seção vazia some; mês vazio = um `EmptyState` |
| Aba | R7/cores | `systemGreen/Orange/Blue/Purple` (`:466-467`, `:691-692`, `:1025`); laranja em texto ~2,2:1 (`:1025`); `activeBlue` (`:138`, `:236`, `:278`, `:315`) | Texto laranja ilegível, roxo, azul do iOS | Papéis `success`/`warning`/`accentText` |
| Aba | i18n | "ordens" fixo (`:512`, `:651`, `:1413`); `DateFormat` `pt_BR`/`dd/MM/yy` (`:88-90`, `:1455`); erro cru `e.toString()` (`:1658`) | "ordens" e data BR em en/es; erro técnico | l10n com plural; `FormatService().formatDate`; texto fixo de erro |
| Aba | R6/a11y | Lápis 28 (`:251`), chevrons 32 (`:275`, `:323`); textos 11-13 em caixa alta (`:179-195`, `:494`, `:712`, `:1526`); compartilhar sem rótulo (`:134-141`) | Alvos e letras pequenos; leitor diz só "botão" | Alvo 44; mínimo 15, sentence case; compartilhar vai para o "…" com texto |
| Pagamentos | R3 + perigo | Link vermelho "A Receber" apaga todos os pagamentos (`payment_management_screen.dart:358-367`, `:949-971`) | Rótulo de status que vira botão de apagar | `DestructiveAction` "Desfazer pagamentos" no "…", confirmação com o valor |
| Pagamentos | R1/R2/R4 | Resumo de 4 linhas antes da ação (`:113-122`); filled + 3 links azuis (`:584`, `:563-571`, `:609-617`, `order_charge_card.dart:318-325`); desconto como 1º controle (`:384-462`) | 4 coisas azuis; desconto raro no topo | "Recebi R$ X" como único botão; desconto, anexo e Asaas no "…" |
| Pagamentos | Gesto/R6 | Remover só arrastando (`:689-706`); clipe 16px sem rótulo (`:760-767`); `CurrencyTextInputFormatter` fixo `pt_BR` (`:493-495`) | Não acha como apagar; alvo mudo; R$ em en/es | Toque → folha (ver comprovante, remover); alvo 44; `MoneyField` |
| Cobrança/Nova | R7/R2/fluxo | Pendente em `systemBlue`, vencida em `systemRed` (`order_charge_card.dart:18-31`); "Gerar nova cobrança" `Size.zero` (`:299-311`); botão filled ~44 no fim da lista (`create_charge_screen.dart:419`); depois de criar, só um diálogo (`payment_management_screen.dart:282-284`) | Status com cor de ação/perigo; alvo de ~20px; botão some com teclado; 2 passos a mais para mandar o link | `OrderStatusStyle`-like (`warning`/`success` + texto); alvo 44; `AppBottomBar` 58; abrir `ShareLinkSheet` logo após criar |

## Tela proposta

### Financeiro · aba (prancha "Financeiro · aba")

Só monta para quem tem `viewFinancialReports` (decisão na spec de Início, `2026-10-09-telas-inicio-design.md`); o `ProtectedRoute` (`:122-124`) fica como proteção extra.

1. **Topo (`AppTopBar`, tela raiz):** só "…". `MoreMenu`: "Outro período" (semana, ano, datas), "Serviços e produtos" (os rankings de `:1087-1304` em tela própria), "Compartilhar relatório" (o PDF de `:1716+`).
2. **Título (`ScreenTitle`):** "Financeiro". Abaixo, seletor de mês "‹ Outubro de 2026 ›" (setas com alvo 44 e `Semantics`; tocar no texto volta ao mês atual, sem a frase "Toque para voltar ao atual" de `:310-316`).
3. **Próximo passo (`NextStepBlock`):** frase "Falta receber R$ 1.730 de 3 clientes"; linha de apoio "A Ana deve há mais tempo: R$ 1.250 desde 02/10."; `PrimaryButton` "Mandar cobrança para Ana". O botão abre o envio do link da OS que já existe: `ShareLinkSheet.show(context, order)` (`lib/screens/widgets/share_link_sheet.dart:25-39`), o mesmo usado pela cobrança (`order_charge_card.dart:231`) e pela OS (`order_form.dart:1866`). A OS escolhida é a pendente mais antiga desse cliente. O cliente paga pelo link `/q/{token}` (com Pix/boleto se houver cobrança Asaas aberta). Sem dívida no mês: o bloco some.
4. **Conteúdo:**
   - `SectionLabel` "Falta receber". `AppListRow`: "Ana Ribeiro" ……… "R$ 1.250"; linha 2 "OS 183 · desde 02/10"; seta. Uma OS → abre a OS; várias → "2 OS · desde 02/10" e abre a lista de OS do cliente. Ordem: mais antiga primeiro. Mostra 5 + `TextLink` "Ver todos (12)".
   - `SectionLabel` "Recebido". Últimas OS pagas do mês: cliente, valor, "OS 186 · pago 08/10", `StatusDot` `success` "Pago". Toque abre a OS.
   - Saem: barra pago×falta, barra serviço×produto (azul/roxo), "Média", contagens "N ordens", rankings, segmentado de 5 períodos, filtros por toque.
5. **Resumo (`SummaryLine`, fixa acima da tab bar):** "Entrou R$ 8.300 · Falta R$ 1.730" ("Falta" em `warning`).
6. **Barra fixa:** só a tab bar.

Estados:
- **Mês sem OS:** `EmptyState` "Nenhuma OS em outubro." (sem bloco, sem resumo).
- **Tudo recebido:** bloco some; lista "Recebido" e resumo "Entrou R$ 8.300 · Falta R$ 0".
- **Erro:** "Não deu para carregar o financeiro." + `TextLink` "Tentar de novo" (substitui `:1658`).
- **Carregando:** título e seletor de mês aparecem; listas com o indicador atual.

### Financeiro · modo escuro (prancha "Financeiro · modo escuro")

Mesmas zonas; cores só por `AppColors.*.resolveFrom(context)`; `warning` de "Falta" e `success` de "Pago" nos valores escuros de `app_colors.dart`. Teste de widget em claro e escuro.

### Pagamentos da OS, cobrança e nova cobrança (sem prancha; alinhar com a sessão da OS)

Correções que valem qualquer que seja o desenho final:
- Pagamentos: um `PrimaryButton` "Recebi R$ 166" que acompanha o valor do `MoneyField`; "Dar desconto", "Anexar comprovante", "Cobrar pelo Pix ou boleto", "Desfazer pagamentos" no `MoreMenu`; sai "Pagar valor total" (`:597-623`); estado de orçamento diz "Aprove o orçamento para registrar pagamento." (`:302-321`); textos "Falta receber", "Já recebido", "Nenhum pagamento ainda"; sucesso sem diálogo (`:1232-1257`), o bloco passa a "Tudo recebido".
- Cobrança na OS: uma linha de status (`StatusDot` + "Aguardando pagamento · vence 12/10") com toque → action sheet (mandar link, copiar link de pagamento, cancelar cobrança); aviso de diferença de valor em `NextStepBlock` `warning` (hoje 14pt cinza, `order_charge_card.dart:278-293`).
- Nova cobrança: título "Cobrar R$ 166"; "Pagar até" no lugar de "Vencimento"; "À vista" padrão, parcelado numa linha que abre folha (`create_charge_screen.dart:351-392`); `AppBottomBar` "Gerar e mandar link"; ao criar, abre `ShareLinkSheet` direto.

### Integrações e conexão Asaas (só achados)

- Integrações: "Revogar" 14pt vermelho inline com `padding: zero` (`integration_list_screen.dart:316-325`); "+" sem rótulo e vazio sem botão (`:244-251`, `:286-308`); seção Asaas depois dos tokens MCP (`:252-258`); textos 12-13 (`:158`, `:302`). Correção: "Desligar" na folha da linha, botão no vazio, Asaas primeiro, 15pt, alvo 44.
- Conexão Asaas: "Chave de API", "sandbox", "Ambiente" (l10n `asaasApiKey`, `asaasOpenSandboxPanel`, `asaasEnvironment`); link de sandbox para todos (`asaas_connection_screen.dart:281-285`); selo colorido "Teste/Produção" (`:329-359`); filled ~44 (`:314`). Correção: "Código de acesso do Asaas", sandbox só em debug, `StatusDot` + texto, `PrimaryButton` "Conectar".

## Componentes usados

`AppTopBar`, `ScreenTitle`, `NextStepBlock`, `PrimaryButton`, `TextLink`, `MoreMenu`, `DestructiveAction`, `SectionLabel`, `AppListRow`, `StatusDot`, `OrderStatusStyle`, `EmptyState`, `SummaryLine`, `MoneyField`, `AppBottomBar`.

Componente novo a adicionar no doc comum:
- `PeriodStepper`: "‹ Outubro de 2026 ›" abaixo do `ScreenTitle`; setas com alvo 44 e `Semantics` ("Mês anterior"/"Próximo mês"); toque no texto volta ao mês atual; mês por `FormatService`.
- `SummaryLine` fixa: hoje o doc comum a define na zona 5; precisa da variante "fixa acima da tab bar" (como a `AppBottomBar` em telas de aba).

## Fora de escopo / alinhar com a sessão da OS

- Desenho final de Pagamentos da OS, Cobrança na OS e Nova cobrança: "Recebi R$ X" como próximo passo da própria OS e esta tela virando folha/etapa dela.
- Regras de cobrança Asaas (valores, webhook, baixa): `2026-10-04-asaas-cobranca-os-design.md`.
- PDF do relatório (sem acentos por `_latinCharactersOnly`, "Veiculo" fixo em `:1740`): fica como está; só muda o caminho (vai para o "…").

## Ordem de implementação

Cada passo é um PR com teste de widget; textos novos nos 3 `.arb` + `fvm flutter gen-l10n`.

1. **Textos e i18n da aba** (sem mudar layout): "Financeiro" no título, plural "ordens" no l10n, datas por `FormatService`, erro sem `e.toString()`. Teste: en/es sem "ordens" e sem data BR. risk:low. l10n: `financialLoadError`, `ordersCount` (plural), se não existir.
2. **Tirar os filtros por toque e os vazios empilhados.** Toque no cliente abre OS/lista de OS; seção vazia some; mês vazio = `EmptyState`. Teste: toque no cliente faz push; mês vazio mostra uma frase. risk:low. l10n: `financialEmptyMonth` ("Nenhuma OS em {month}.").
3. **Estrutura nova** (`PeriodStepper`, seções "Falta receber" e "Recebido", `SummaryLine` fixa, `MoreMenu` com outro período / serviços e produtos / compartilhar relatório). Os rankings passam para tela própria reaproveitando o código atual. Teste: ordem por mais antiga; "Ver todos (N)"; "…" tem as 3 opções. risk:low. l10n: `financialToReceive`, `financialReceived`, `financialSummary` ("Entrou {in} · Falta {out}"), `orderSince` ("OS {n} · desde {date}"), `ordersSince`, `otherPeriod`, `servicesAndProducts`, `shareReport`, `previousMonth`, `nextMonth`.
4. **Próximo passo + "Mandar cobrança para ..."** abrindo `ShareLinkSheet` com a OS pendente mais antiga. Teste: frase e cliente certos; bloco some sem dívida; toque chama o sheet com a OS esperada. risk:low (reusa envio existente, sem escrita nova). l10n: `financialNextStep` ("Falta receber {amount} de {n} clientes", plural), `financialOldestDebt` ("{name} deve há mais tempo: {amount} desde {date}."), `sendChargeTo` ("Mandar cobrança para {name}").
5. **Cores e tamanhos** (papéis `AppColors`, mínimo 15, alvos 44, modo escuro). Teste em claro e escuro. risk:low.
6. **Pagamentos/cobrança:** só depois de alinhar com a sessão da OS. A parte que mexe em billing/pagamento é risk:high (CLAUDE.md); as trocas de texto e alvo podem ir antes como risk:low.

## Perguntas em aberto

- "Mandar cobrança" para cliente com várias OS pendentes: manda o link da mais antiga (proposta) ou abre a lista para escolher? Hoje não existe link que junte várias OS.
- Empresa no piloto Asaas sem cobrança aberta na OS: o botão só manda o link da OS (proposta) ou já oferece gerar a cobrança antes?
- "Falta receber" conta só OS do mês escolhido ou tudo o que está em aberto até hoje? A dívida antiga de outro mês sumiria no mês novo.
