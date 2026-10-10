# Telas do app: componentes comuns

Status: proposta · 2026-10-09 · base: `docs/APP_DESIGN_SYSTEM.md` (PR #326)

Este é o único lugar onde os componentes das telas redesenhadas são definidos. As specs de cada grupo de telas só citam o nome daqui. Se um grupo precisar de algo novo, o componente entra neste doc, não na spec do grupo.

Protótipos: canvas https://claude.ai/artifact/NfHsv1Ge52LXGdpd9ZYihz, página "Telas do app". Todos os componentes abaixo aparecem lá.

## Por que um doc comum

A auditoria (ver `2026-10-09-telas-inventario-design.md`) achou o mesmo problema repetido em quase todas as telas, cada um resolvido de um jeito:

- O mapa de cor de status de OS existe em pelo menos 3 cópias (`home.dart:1068-1083`, `agenda_screen.dart:485-500`, `devices/device_detail_screen.dart:46-59`), cada uma com cores diferentes e sem texto junto.
- O status de aparelho tem 3 cópias de `_statusColor` (`device_list_screen.dart:355-368`, `device_form_screen.dart:60-73`, `device_detail_screen.dart:46-59`).
- "Salvar" é um texto pequeno no canto da barra em todos os formulários (cliente, aparelho, serviço, produto).
- Lista e formulário de serviço e de produto são cópias: 4 arquivos, ~1.260 linhas.
- Nenhuma tela usa `AppColors` nem `AppTypography`.

## Onde ficam

`lib/widgets/app/` (pasta nova), um arquivo por componente. Cores só por `AppColors.*.resolveFrom(context)`, texto só por `AppTypography`, medidas só por `AppSpacing`/`AppSizes`/`AppRadii`. Textos sempre por `context.l10n`.

## Componentes

### 1. Estrutura da tela (as 6 zonas)

| Componente | Zona | O que é | Regras |
|---|---|---|---|
| `AppTopBar` | 1 | Voltar (texto do destino: "‹ Clientes"), nome curto no meio ("OS 186"), até 2 ícones à direita (ex.: sino, "…") | No máximo 3 itens. Ícone sempre com `Semantics(label:)`. Alvo 44. Em tela raiz de aba não tem voltar |
| `ScreenTitle` | 2 | Título `AppTypography.title` (30) + subtítulo `callout` em `textSecondary` | O subtítulo conta algo real ("12 em aberto", "38 clientes"). Nunca repete o título |
| `NextStepBlock` | 3 | Bloco `accentSoft` com rótulo curto opcional (15), uma frase (`highlight` 22) e, opcionalmente, o `PrimaryButton` ou um link sublinhado | Uma frase só. Variante `warning` (`warningSoft`/`onWarningSoft`) para "falta algo"/atraso. Variante `info` com frase em 19 regular para explicações (ex.: onboarding). Some quando não há próximo passo |
| `AppBottomBar` | 6 | Barra fixa com um botão de largura total (formulários: "Salvar cliente") ou foto + "Falar" (telas com assistente) | Em telas de aba fica acima da tab bar. Fundo `background`, linha `separator` em cima |
| `SummaryLine` | 5 | Linha forte (borda 2 em `text`), total à esquerda e "Falta …" em `warning` | Só aparece quando há valor a resumir |

### 2. Ações

| Componente | O que é | Regras |
|---|---|---|
| `PrimaryButton` | Único botão preenchido da tela, `accent`/`onAccent`, altura 58, canto 16, `bodyStrong` | **Um por tela.** Se o `NextStepBlock` já tem botão, o `AppBottomBar` usa `SecondaryButton` (e vice-versa) |
| `SecondaryButton` | `secondaryFill`/`onSecondaryFill`, altura ≥48, ícone opcional à esquerda | Para "Ligar", "WhatsApp", "Convidar outra pessoa" |
| `TextLink` | Texto `accentText`, `callout` semibold, alvo ≥44 | "+ Mais dados", "Começar sem exemplos", "Ver as atrasadas" |
| `DestructiveAction` | Texto `danger`, só dentro do "…" ou de action sheet | Confirmação sempre diz o que some: "Apagar Ana Ribeiro?" / botões "Apagar" e "Voltar" |
| `MoreMenu` | `CupertinoActionSheet` aberto pelo "…" | É para onde vai tudo o que é raro (R4): editar, apagar, filtros raros, outro período, compartilhar relatório |

### 3. Listas

| Componente | O que é | Regras |
|---|---|---|
| `SectionLabel` | Rótulo de seção `label` 15 em `textSecondary`, sentence case | Nunca `toUpperCase()`. Seção vazia não aparece |
| `AppListRow` | Linha sem cartão: título `bodyStrong` 19; linha 2 `callout` 17 `textSecondary`; linha 3 `label` 15; valor à direita em `body` com `AppTypography.tabular`; miniatura 44 opcional; seta opcional | Separador `separator` entre linhas. Altura mínima 60. A seta só aparece quando o toque abre outra tela (no modo escolher não tem seta) |
| `AddRow` | Primeira linha da lista em modo escolher: círculo `secondaryFill` com "+" e texto `accentText` ("Cadastrar cliente novo") | Substitui o "+" solto da barra no modo escolher |
| `StatusDot` | Ponto de 9 + texto, na mesma cor de papel | **Nunca ponto sem texto** (R7). Nunca selo preenchido |
| `OrderStatusStyle` | Mapa único `status da OS → (papel de cor, texto l10n)` | `quote` → `textSecondary` "Orçamento"; `approved` → `accentText` "Aprovada"; `progress` → `warning` "Em andamento"; `done` → `success` "Concluída"; `canceled` → `danger` "Cancelada". Atraso é um estado à parte: `warning` em negrito, "Atrasada 2 dias". Usado por home, agenda, cliente, aparelho, financeiro |
| `DeviceStatusStyle` | O mesmo, para o status de aparelho (gestão de equipamentos) | Substitui as 3 cópias de `_statusColor` |
| `EmptyState` | Uma frase + um `TextLink` ou `PrimaryButton` | Frase pronta no l10n com o rótulo do segmento, nada montado aos pedaços ("Você ainda não tem clientes", não "Não cliente cadastrado") |

### 4. Entrada de dados

| Componente | O que é | Regras |
|---|---|---|
| `AppSearchField` | `CupertinoSearchTextField` com `secondaryFill`, altura 44, canto 12, placeholder que diz o que busca ("Buscar por nome ou telefone") | — |
| `SegmentToggle` | `CupertinoSlidingSegmentedControl` de 2 opções, altura ≥44, texto 17 | Máximo 2 ou 3 opções. Filtros além disso vão para o `MoreMenu` |
| `AppFormField` | Rótulo `label` 15 acima + campo `body` 19 em `secondaryFill`, canto 12, altura 52, dica opcional embaixo | Placeholder é exemplo do segmento ("Ex.: Fiat Uno 2015"), nunca "Selecionar" |
| `MoneyField` | `AppFormField` com `FormatService` (locale) para máscara e leitura | Substitui os `CurrencyTextInputFormatter` com `pt_BR` e `R$` fixos |
| `MoreFieldsLink` | `TextLink` "+ Mais dados (e-mail, CPF ou CNPJ, endereço)" que revela os campos raros | No modo editar, os campos que já têm valor aparecem direto |
| `SuggestField` | `AppFormField` com sugestões embaixo enquanto digita (ex.: modelo → "Fiat Uno 2015 · Fiat · Carro") | Substitui a cadeia categoria → marca → modelo (3 telas) por uma busca |

### 5. Estados, folhas e período

| Componente | O que é | Regras |
|---|---|---|
| `LoadingState` | Uma frase só ("Preparando seu PraticOS…") com indicador | Sem lista de etapas técnicas |
| `ErrorState` | Variante do `EmptyState`: frase fixa ("Não deu para terminar. Confira a internet e tente de novo.") + `PrimaryButton` "Tentar de novo" | Nunca mostra a exceção (`e.toString()`); ela vai para o log. Toda tela de erro tem saída |
| `PeriodStepper` | "‹ Outubro de 2026 ›" abaixo do `ScreenTitle` | Setas com alvo 44 e `Semantics` ("Mês anterior"/"Próximo mês"); tocar no texto volta ao mês atual; mês por `FormatService` |
| `ShareSheet` | Folha única para mandar convite e link da OS: `PrimaryButton` "Mandar pelo WhatsApp", `SecondaryButton` "Copiar" e "Outros apps" | Sem botão verde da marca (texto branco no verde dá ~2:1). Substitui os botões de `invite_share_sheet.dart` e `share_link_sheet.dart` |
| `RolePickerSheet` | Lista de papéis, cada um com uma frase ("Técnico: faz os serviços, não vê preços") | Usada por Equipe e Novo colaborador |

Variantes de componentes já listados:
- `AppListRow` **selecionável**: marcação à direita e `Semantics(selected:)`, para multisseleção (especialidades no primeiro acesso).
- `SectionLabel` **de índice**: letra ("A", "C") nas listas longas em ordem alfabética (aba Clientes).
- `SummaryLine` **fixa**: presa acima da tab bar, como a `AppBottomBar` nas telas de aba (Financeiro).

Exceção documentada ao "um botão azul": no login, "Continuar com Apple" segue o padrão da Apple (preto/branco) e convive com o `SecondaryButton` do Google.

### 6. Textos com o rótulo do segmento

`EntityPhrases`: frases completas no l10n, com placeholder e gênero, para "cliente", "veículo/aparelho", "serviço", "produto". Ex.: `emptyEntityList(entity)`, `pickEntityTitle(entity)` ("Qual é o veículo?"), `newEntity(entity)`, `deleteEntityConfirm(name)`. Já existem variantes femininas soltas em `app_pt.arb:678-685` que nenhuma tela usa. Corrige "Não cliente cadastrado" (`home_customer_list.dart:125`) e "Para qual equipamento?" (`l10n.selectDeviceFor` em `device_picker_sheet.dart:125`, que ignora o rótulo do segmento).

## O que sai junto

- `CupertinoColors.activeBlue`/`systemBlue` como cor de ação, `systemPurple`/`systemIndigo`/`systemTeal` como cor de status: trocar pelos papéis.
- Ícones coloridos em ladrilho na aba Mais (12 cores, `settings.dart`): saem. A lista fica só com texto.
- `toUpperCase()` em cabeçalho de seção: sai (`SectionLabel`).
- Textos de 10 a 14 px: viram 15 no mínimo.

## Ordem de implementação

1. `OrderStatusStyle` + `StatusDot` (+ `DeviceStatusStyle`). É o que mais aparece e corrige R7 em todas as listas de uma vez.
2. `AppListRow`, `SectionLabel`, `EmptyState`, `EntityPhrases`.
3. `PrimaryButton`, `SecondaryButton`, `TextLink`, `AppBottomBar`.
4. `AppTopBar`, `ScreenTitle`, `NextStepBlock`, `MoreMenu`.
5. `AppSearchField`, `SegmentToggle`, `AppFormField`, `MoneyField`, `MoreFieldsLink`, `SuggestField`, `SummaryLine`.

Cada componente entra com um teste de widget (claro e escuro) e com a primeira tela que o usa. Nada de criar a biblioteca inteira antes da primeira tela.

A troca do `primaryColor` global (`main.dart:149`, hoje `activeBlue`) entra junto com a primeira tela redesenhada, como já diz o `APP_DESIGN_SYSTEM.md`. A sessão da OS pode chegar primeiro: quem chegar primeiro cria os componentes 1–4, e o outro reutiliza.
