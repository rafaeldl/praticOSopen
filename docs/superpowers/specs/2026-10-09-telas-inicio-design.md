# Telas do app: Início (abas, lista de OS, agenda, notificações, avaliações, loading)

Status: proposta · 2026-10-09 · base: `docs/APP_DESIGN_SYSTEM.md` · componentes: `2026-10-09-telas-componentes-design.md`

Protótipos: canvas https://claude.ai/artifact/NfHsv1Ge52LXGdpd9ZYihz, página "Telas do app". Pranchas deste grupo: "Início · lista de OS", "Início · modo escuro", "Início · primeira vez".

## Telas do grupo

| Tela | Arquivo | Uso | O que muda |
|---|---|---|---|
| Abas | `lib/screens/menu_navigation/navigation_controller.dart` | sempre visível | Financeiro só para quem tem permissão; cor da marca nas abas |
| Início · lista de OS | `lib/screens/menu_navigation/home.dart` (1.131 linhas) | diário, várias vezes | Redesenho completo (6 zonas, status com texto, "Nova OS" como botão principal) |
| Agenda | `lib/screens/agenda/agenda_screen.dart` | diário para quem agenda | Só correções (cor, status, texto); sem prancha |
| Notificações | `lib/screens/notifications/notification_list_screen.dart`, `notification_list_tile.dart` | semanal | Só correções; sem prancha |
| Avaliações | `lib/screens/ratings/ratings_screen.dart` | mensal | Só correções; sem prancha |
| Loading | `lib/screens/loading_screen.dart` | toda abertura | Fundo certo no modo escuro |
| Modais mortos | `lib/screens/modal_menu.dart`, `modal_status.dart`, `modal_bottom_sheet.dart` | nenhum | Apagar (nenhuma chamada em `lib/`) |

## Problema atual (achados)

| Tela | Regra | Evidência | O que o usuário vê | Correção |
|---|---|---|---|---|
| Abas | R4 | `navigation_controller.dart:30-37` (comentário "Financial tab is always included"); a checagem fica dentro da tela, `financial_dashboard_simple.dart:122-124` | Técnico toca "Financeiro" e cai numa tela que só diz "não pode" | Montar a aba só com `hasPermission(viewFinancialReports)` |
| Abas | Cor | `lib/main.dart:149` `primaryColor: CupertinoColors.activeBlue` | Azul do iOS em abas, ícones e links | `AppColors.accent` (entra com esta tela) |
| Início | R7 | Status só na cor do selo do número: `home.dart:729`, `:944-962`; nenhuma linha escreve o status (`:794-887`) | Tem que decorar cor (roxo = andamento, laranja = orçamento) | `StatusDot` + texto via `OrderStatusStyle`; número em texto normal |
| Início | Cores | `_getCupertinoStatusColor` `home.dart:1068-1083`, `_getFilterChipColor` `:469-492` | ~9 matizes na mesma tela (roxo, teal, índigo...) | `OrderStatusStyle` único (home + agenda) |
| Início | R1/R2 | Sem próximo passo; criar OS é um "+" igual ao sino (`:293-308` vs `:250-292`); abre em "Todos" (`:35`, `:54`) misturando concluídas | Tela não diz o que fazer agora; ação principal escondida | `NextStepBlock` + `PrimaryButton` "Nova OS" no `AppBottomBar`; padrão "Em aberto" |
| Início | R7/a11y | Chips só com ícone quando não selecionados (`:444-456`), sem `Semantics` (`:410`), altura 36 (`:390`), escondidos até puxar a lista (`:41`, `:161-173`) | Fila de 7-10 ícones mudos que aparecem "do nada" | `SegmentToggle` "Em aberto / Todas"; o resto no `MoreMenu` |
| Início | R7 | Atrasada = só relógio vermelho 14pt (`:870-877`); paga = só cifrão verde (`:878-885`) | Dois iconezinhos sem palavra | "Atrasada 2 dias" (`warning`, negrito) e "Pago" (`success`) com texto |
| Início | Tipografia | 10pt no prefixo do número (`:984-994`), 13pt no aparelho (`:860`), 11pt no % (`:1059`) | Texto pequeno em toda linha | Mínimo 15 (`AppListRow`) |
| Início | R3/i18n | Vazio: "Nenhuma OS encontrada / Nenhum dado disponível" sem ação (`:614-629`); "Ver Mais" usado como explicação (`:661-668`); rótulos de filtro fora do l10n (`:49-51`, `:1101-1131`), "Entrega" (`:55`) | Mensagens sem sentido; filtro em outra língua | `EmptyState`/prancha "primeira vez"; chaves `.arb` |
| Início | R4 | Sem foto, caixa cinza 56×56 (`:932-941`) | Quadrado vazio em quase toda linha | Miniatura só com `coverPhotoUrl` |
| Agenda | Cores/R7 | `activeBlue` em dia, pontos, setas, hora (`agenda_screen.dart:175-178`, `:214-217`, `:140`, `:336`); `_getStatusColor` `:485-500`; filtro de técnico só ícone (`:83-99`) | Azul do iOS; status por cor; ninguém sabe que filtra | `accent`/`accentText`; `OrderStatusStyle`; texto "Toda a equipe ▾" |
| Notificações | R7/i18n | Ladrilho colorido por tipo (`notification_list_tile.dart:48-61`), dourado `0xFFFFD700` (`:186`); "Agora", "2d" fixos (`:208-214`); hora 12pt (`:96-101`) | Ícone colorido, abreviação, texto miúdo | Ícone neutro `textSecondary`; l10n "agora", "há 2 dias"; 15pt |
| Avaliações | Contraste | Nota branca sobre amarelo/teal/laranja (`ratings_screen.dart:327-343`, `:437-452`); `toStringAsFixed(1)` (`:211`); `toUpperCase()` (`:152`) | "3" ilegível; "4.5" em vez de "4,5"; caixa alta | "3 de 5" em `text`; `FormatService().formatDecimal`; `SectionLabel` |
| Loading | Dark mode | `CupertinoColors.systemBackground` sem resolver (`loading_screen.dart:11-12`) | Clarão branco ao abrir no escuro | `AppColors.background.resolveFrom(context)` |

## Tela proposta

### Abas

5 abas para quem tem `viewFinancialReports` (Início, Clientes, Agenda, Financeiro, Mais); 4 para os demais. A navegação é por índice (`navigation_controller.dart:104-110`, `:161`; `home_customer_list.dart:235` usa `setCurrentIndex(0)`). Ao montar a lista condicional, os índices passam a vir de uma lista de abas visíveis (enum), não de números fixos. Cor das abas ativas: `accent` (troca de `main.dart:149`).

### Início · lista de OS (prancha "Início · lista de OS")

1. **Topo (`AppTopBar`, tela raiz, sem voltar):** buscar, sino (`Semantics` "Avisos, 3 novos") e "…". O "…" (`MoreMenu`): "Ver concluídas", "Ver canceladas", "A receber", "Contratos" (só com `useContracts`), "Filtrar por cliente".
2. **Título (`ScreenTitle`):** "Ordens de serviço" (rótulo do segmento, `config.serviceOrderPlural`); subtítulo "12 em aberto".
3. **Próximo passo (`NextStepBlock`):** uma frase, prioridade nesta ordem:
   - há atrasadas → variante `warning`: rótulo "Hoje", frase "2 OS passaram do prazo de entrega.", `TextLink` "Ver as atrasadas" (rola até a seção Atrasadas);
   - há prazo hoje → "3 OS para entregar hoje." + "Ver";
   - orçamentos parados > 7 dias (mesma regra de `engagement_scheduler.dart:100-110`) → "4 orçamentos esperando resposta do cliente." + "Ver";
   - nada disso → bloco some.
   O bloco não tem botão: o botão da tela está na zona 6.
4. **Conteúdo:** `SegmentToggle` "Em aberto | Todas" (padrão "Em aberto"). Lista agrupada por `SectionLabel`, só grupos com OS: "Atrasadas", "Para hoje", "Em andamento", "Esperando aprovação", "Aprovadas". Agrupamento em "Todas": ver perguntas em aberto. Cada `AppListRow`:
   - linha 1: "Ana Ribeiro" ……… "R$ 1.250" (`tabular`; valor só com `viewPrices`, como hoje em `home.dart:838`);
   - linha 2: `StatusDot` + "Atrasada 2 dias" (ou "Em andamento · entrega 12/10"); "Pago" em `success` quando pago;
   - linha 3: "OS 184 · Fiat Uno 2015" (rótulo do aparelho pelo segmento);
   - miniatura 44 só se houver foto; seta (abre a OS).
   "Ver Mais" (`:194-224`) sai: a rolagem infinita já existe (`:135-149`).
5. **Resumo:** não tem (o dinheiro fica na aba Financeiro).
6. **Barra fixa (`AppBottomBar`, acima da tab bar):** `PrimaryButton` "Nova OS" (abre `/order`, como `:302`). É o único botão preenchido da tela. Quando o assistente chegar à home, esta barra vira foto + "Falar" e "Nova OS" passa a ser o caminho do assistente; o desenho fica igual ao da tela da OS (alinhar com a sessão da OS).

Sai da 1ª tela: o "+" da barra, os 7-10 chips com ícone (vão para "…"), selos coloridos de número, ícones soltos de relógio/cifrão, quadrado cinza sem foto, banner WhatsApp (flag off em `feature_flags.dart:6`; se religar, segue os achados da auditoria), "Ver Mais".

Estados:
- **Busca sem resultado:** "Não achei nas OS carregadas." + `TextLink` "Buscar nas mais antigas".
- **"Em aberto" vazio, mas a empresa tem OS:** `EmptyState` "Nenhuma OS em aberto." + `TextLink` "Ver todas".
- **Erro de carga:** "Não deu para carregar as OS." + `TextLink` "Tentar de novo".
- **Carregando:** a lista mostra o indicador atual; título e barra já aparecem.

### Início · primeira vez (prancha "Início · primeira vez")

Empresa sem nenhuma OS. Topo e título iguais (subtítulo some). `NextStepBlock` (padrão) com a frase "Crie sua primeira ordem de serviço..." (texto completo da prancha) e o `PrimaryButton` "Nova OS" dentro do bloco; a `AppBottomBar` não aparece (um botão azul por tela). Abaixo, `SectionLabel` "Como funciona" e lista de 3 passos (texto da prancha), sem cartão. Sem `SegmentToggle`, sem busca.

### Início · modo escuro (prancha "Início · modo escuro")

Mesmas zonas; cores só por papéis `AppColors.*.resolveFrom(context)`. `warningSoft` do bloco e o `warning` de "Atrasada" seguem os valores escuros do `app_colors.dart`. Teste de widget em claro e escuro.

### Agenda, notificações, avaliações, loading (sem prancha)

Só as correções da tabela de achados, sem mudar a estrutura:
- Agenda: `OrderStatusStyle` + `StatusDot`; linha 1 = cliente, linha 2 = "Aprovada · OS 1234 · aparelho" (sai "OS #"); data do dia como `SectionLabel`; filtro de técnico com texto; vazio do dia: "Nada marcado para este dia." + `TextLink` "Agendar uma OS" (abre `/order` com a data). Lista e calendário sem cartão.
- Notificações: ícone neutro, ponto `accentText` + negrito para não lida (sem fundo azul, `notification_list_tile.dart:32-34`), tempo relativo no l10n, 15pt, lista sem cartão.
- Avaliações: "Nota média 4,5 · 23 avaliações" numa linha (sai a caixa dentro de cartão `ratings_screen.dart:250-256`); nota "3 de 5" em texto; estrelas em `text`/`textSecondary`; puxar para atualizar no lugar do ícone (`:76-83`); 15pt mínimo.
- Loading: `CupertinoPageScaffold` com `AppColors.background.resolveFrom(context)`.

## Componentes usados

`AppTopBar`, `ScreenTitle`, `NextStepBlock` (padrão e `warning`), `AppBottomBar`, `PrimaryButton`, `TextLink`, `MoreMenu`, `SegmentToggle`, `AppSearchField`, `SectionLabel`, `AppListRow`, `StatusDot`, `OrderStatusStyle`, `EmptyState`.

Componente novo a adicionar no doc comum: nenhum. (A auditoria pede `WeekStrip` para a agenda, mas a agenda não tem prancha nem redesenho nesta fase.)

## Fora de escopo / alinhar com a sessão da OS

- Tela da OS (`/order`) e o que acontece ao tocar "Nova OS".
- A troca de "Nova OS" por foto + "Falar" na `AppBottomBar` quando o assistente chegar: mesmo componente e mesma regra da tela da OS.
- Aba Clientes (`home_customer_list.dart`): spec de clientes.
- Redesenho da agenda (semana, próximo compromisso): só se a agenda ganhar prancha.

## Ordem de implementação

Cada passo é um PR com teste de widget; textos novos nos 3 `.arb` + `fvm flutter gen-l10n`.

1. **Apagar modais mortos** (`modal_menu.dart`, `modal_status.dart`, `modal_bottom_sheet.dart`). Teste: `fvm flutter analyze` limpo. risk:low. l10n: nenhum.
2. **Loading no escuro.** Teste de widget em escuro conferindo a cor de fundo. risk:low. l10n: nenhum.
3. **Aba Financeiro só com permissão.** Lista de abas visíveis + índice por enum; teste com usuário sem `viewFinancialReports` (4 abas, "Mais" abre certo; `setCurrentIndex(0)` continua abrindo Início). risk:low (UI; não mexe em regra de permissão). l10n: nenhum.
4. **`OrderStatusStyle` + `StatusDot` na home e na agenda** (+ troca de `main.dart:149` para `accent`). Teste: cada status gera o texto e o papel certos. risk:low. l10n: `orderLateDays` ("Atrasada {n} dias", plural).
5. **Linha nova da lista** (`AppListRow`: cliente + valor, status, "OS 184 · aparelho"; miniatura só com foto; "Pago" com texto). risk:low. l10n: `orderRowNumberDevice` ("OS {number} · {device}").
6. **Filtros:** `SegmentToggle` "Em aberto | Todas" (padrão "Em aberto"), seções por grupo, resto no `MoreMenu`; saem os chips e `_PtLabels/_EnLabels/_EsLabels`. Teste: grupos vazios não aparecem; "…" lista "Contratos" só com `useContracts`. risk:low. l10n: `filterOpen`, `filterAll`, `sectionLate`, `sectionDueToday`, `sectionInProgress`, `sectionWaitingApproval`, `sectionApproved`, `moreShowDone`, `moreShowCanceled`, `moreToReceive`, `moreFilterByCustomer`.
7. **Topo + título + `NextStepBlock` + `AppBottomBar` "Nova OS"** e estados (vazio, primeira vez, busca, erro). Teste: prioridade das frases; primeira vez sem barra fixa; sino com rótulo acessível. risk:low. l10n: `homeOpenCount` ("{n} em aberto"), `nextStepLate` ("{n} OS passaram do prazo de entrega."), `nextStepDueToday`, `nextStepQuotesWaiting`, `seeLate` ("Ver as atrasadas"), `notificationsA11y` ("Avisos, {n} novos"), `firstOrderTitle`, `howItWorksSteps` (3 chaves), `searchNotFoundLoaded`, `searchOlder`, `noOpenOrders`, `loadOrdersError`, `newOrder`.
8. **Agenda (correções).** risk:low. l10n: `agendaEmptyDay`, `agendaScheduleHere`, `agendaWholeTeam`.
9. **Notificações e avaliações (correções).** risk:low. l10n: `timeNow`, `timeMinutesAgo`, `timeHoursAgo`, `timeDaysAgo` (plurais), `ratingOutOfFive`, `ratingSummary`.

## Perguntas em aberto

- Aba Agenda para quem não usa agendamento (`useScheduling` desligado): esconder e acessar pelo "…" da home, ou manter? Hoje mostra só prazos (`agenda_screen.dart:295-296`).
- "Todas": agrupar por mês ou lista corrida? A prancha só mostra "Em aberto".
- Nome da aba: prancha usa "Ordens de serviço" como título; a aba continua "Início"?
