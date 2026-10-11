# APP_DESIGN_SYSTEM.md

## Visão Geral

Padrão visual do aplicativo PraticOS. Vale para toda tela nova ou redesenhada. Os nossos usuários não são técnicos, então o padrão prioriza clareza: **uma pergunta por tela, um botão principal, português do dia a dia**.

Ele complementa o `docs/UX_GUIDELINES.md` (widgets Cupertino, listas, formulários). Quando os dois divergirem em cor, tipografia ou estrutura de tela, vale este documento.

Protótipos de referência (canvas): https://claude.ai/artifact/NfHsv1Ge52LXGdpd9ZYihz — página "Telas do app" (todas as telas, ligadas pelo Play) e a prancha "Padrão do app".

## Arquitetura

| Arquivo | Conteúdo |
|---|---|
| `lib/theme/app_colors.dart` | `AppColors`: papéis de cor como `CupertinoDynamicColor` (claro e escuro) |
| `lib/theme/app_typography.dart` | `AppTypography`: escala de texto |
| `lib/theme/app_spacing.dart` | `AppSpacing`, `AppSizes`, `AppRadii` |
| `lib/theme/app_glass.dart` | `AppGlass`: vidro da camada de navegação (regra 11), com volta para fundo opaco |
| `test/theme/app_colors_contrast_test.dart` | Mede o contraste WCAG AA de cada par: claro, escuro e as duas variantes de "Aumentar contraste" |
| `test/theme/app_typography_test.dart` | Título 34 e texto que cresce com o `textScaler` |
| `test/theme/app_glass_test.dart` | Vidro translúcido e a volta para fundo opaco |
| `lib/screens/widgets/app_list_row.dart`, `section_label.dart`, `list_states.dart` | Componentes de lista (ver "Componentes de lista") |
| `test/widgets/list_base_components_test.dart` | Chevron, quebra de texto e empilhamento em texto grande |

`lib/theme/app_theme.dart` (azul `#2563EB`) e o `primaryColor: CupertinoColors.activeBlue` de `lib/main.dart` são o padrão antigo. Telas migram para os tokens novos à medida que forem redesenhadas; a troca do `primaryColor` global entra junto com a primeira tela redesenhada (a OS).

## Regras

1. **Uma pergunta por tela:** "o que eu faço agora?". A resposta aparece no topo, em uma frase.
2. **Um botão azul por tela.** Só a ação principal é preenchida com `accent`. As demais usam `secondaryFill` ou viram link (`accentText`).
3. **Português do dia a dia.** "Falta receber R$ 166", "Próximo passo: começar o serviço". Nada de "saldo devedor", "etapa 2 de 4" ou siglas.
4. **Mostrar só o que existe.** Recursos ocasionais (checklist, contrato, endereço, desconto, vários aparelhos) só aparecem na tela quando o registro tem. Para adicionar: menu "…"/"+" ou o assistente.
5. **A IA sempre pergunta antes.** O que ela vai mudar aparece com marca-texto (`marker`) e o botão de confirmação diz o que acontece ("Está certo, pode fazer").
6. **Toque fácil.** Botão principal com 58 de altura (`AppSizes.primaryButtonHeight`); qualquer outro alvo com pelo menos 44.
7. **Cor nunca sozinha.** Todo status tem texto junto. A cor fica no ponto; o texto do status é neutro (`textSecondary`), para não ser confundido com link. Nunca selo colorido (ver `UX_GUIDELINES.md`).
8. **O texto cresce.** Todo texto acompanha o "Tamanho do texto" do iPhone (Dynamic Type). Nada de altura fixa para texto nem reticências em nome, título de linha ou valor: a linha quebra. Ver "Tipografia".
9. **Cadastro novo abre por cima.** "Novo cliente", "Novo veículo", "Novo serviço" abrem como sheet (tamanho grande), com "Cancelar" à esquerda e o botão grande embaixo como confirmação. Telas de edição de algo que já existe (Sua conta, Dados da empresa) abrem empurradas, com "Voltar".
10. **Componentes do iPhone quando existem.** Abas, interruptor (verde do sistema), escolha com ✓ à direita, menu "…" com o símbolo `ellipsis`, sheet com fechar à esquerda, botão "Continuar com Apple" nativo (`SignInWithAppleButton`, com logo e proporção da Apple). Não desenhar uma versão própria.
11. **Vidro só na navegação (Liquid Glass).** Barra de abas, botões do topo (voltar, "…", sino), menus "…", sheets pequenas e o botão principal flutuante acima das abas usam vidro: fundo translúcido com desfoque e sombra leve. O botão principal flutuante é vidro tingido com o azul da marca. O conteúdo (listas, bloco do próximo passo, campos, fundo) fica **sempre opaco** ("Don't use Liquid Glass in the content layer", HIG `materials`). Com "Reduzir transparência" ligado no iPhone, o vidro vira fundo opaco (`surface`).
   - **Implementação no Flutter:** o Flutter ainda não tem o Liquid Glass nativo (issue flutter/flutter#170310 aberta, P3; o pacote oficial `cupertino_ui` 1.1.2 não tem vidro). Até lá, usar o `AppGlass` (`lib/theme/app_glass.dart`: `ClipRRect` + `BackdropFilter` com desfoque + preenchimento translúcido) só na barra de abas, na barra de topo e nas sheets pequenas, medindo o custo de desempenho. Ele vira fundo opaco (sem desfoque) quando "Aumentar contraste" está ligado (`MediaQuery.highContrastOf`), quando recebe `reduceTransparency: true` ou `enabled: false`. O Flutter não expõe "Reduzir transparência" no `MediaQuery`: ler `UIAccessibility.isReduceTransparencyEnabled` por um canal nativo e passar em `reduceTransparency`. Trocar pelo oficial quando o `cupertino_ui` trouxer o material. Barra de abas nativa via pacote de terceiros (ex.: `real_liquid_glass`) fica como teste isolado, risk:high.

## Cores

Cada cor tem um papel só. Componentes usam o papel, nunca o hex.

| Papel (`AppColors.`) | Claro | Escuro | Uso |
|---|---|---|---|
| `accent` / `onAccent` | `#116BB5` / branco | `#116BB5` / branco | O único botão preenchido da tela. Azul da marca (mesmo do site) |
| `accentText` | `#116BB5` | `#67AAED` | Links e ações em texto ("Trocar", "Voltar") |
| `accentSoft` / `onAccentSoft` | `#E0F1FF` / `#0B3D80` | `#142F4B` / branco | Bloco "próximo passo" |
| `secondaryFill` / `onSecondaryFill` | `#F2F2F7` / texto | `#2C2C2E` / texto | Todas as outras ações |
| `assistantFill` / `onAssistantFill` | `#1C1C1E` / branco | `#F2F2F7` / `#1C1C1E` | Botão "Falar" do assistente, sempre no mesmo lugar |
| `marker` / `onMarker` | `#FCF2A2` / `#1C1C1E` | igual | Amarelo do logo: só o que a IA vai mudar |
| `text` / `textSecondary` | `#1C1C1E` / `#6C6C70` | branco / `#AEAEB2` | Texto principal e de apoio |
| `background` / `surface` | branco / branco | preto / `#1C1C1E` | Fundo da tela / blocos |
| `separator` | `#EFEFF4` | `#38383A` | Linhas entre itens |
| `success` | `#1D7D3E` | `#65C67D` | Pago, concluído. Nunca em botão |
| `warning` / `warningSoft` / `onWarningSoft` | `#974D00` / `#FFEBD2` / `#7A3B00` | `#ECA851` / `#3E290F` / `#ECA851` | Falta algo: valor, pagamento, foto |
| `danger` | `#C93029` | `#F17264` | Ações destrutivas (cancelar OS, apagar) e problema (OS atrasada) |

Por que o azul da marca e não o do iOS: é a cor da marca (a HIG aceita uma cor de destaque própria, usada com moderação). O contraste ajuda nos textos pequenos: `#007AFF` sobre branco dá 4,02:1, abaixo dos 4,5:1 que a HIG pede para texto até 17 pt (links), e o `#116BB5` dá 5,51:1. No botão principal (19 semibold), a HIG pede 3:1, então ali o contraste não é o motivo.

**Aumentar contraste:** a HIG pede, para cores próprias, uma variante clara, uma escura e uma bem mais contrastada para "Aumentar contraste". Cada token usa `CupertinoDynamicColor.withBrightnessAndContrast` (`highContrastColor` / `darkHighContrastColor`) e o `resolveFrom(context)` escolhe a variante sozinho. Nessas variantes o texto fica mais escuro no claro (`text` preto, `textSecondary` `#3A3A3C`, `accentText` `#0A4F8A`, `danger` `#A1201A`) e mais claro no escuro (`textSecondary` `#D1D1D6`, `accentText` `#9DCBF7`, `danger` `#FF9A8F`), e o `separator` fica mais visível. O teste mede as quatro variantes, exige que "Aumentar contraste" nunca diminua o contraste de um par e que `textSecondary` chegue a 7:1.

**Interruptor:** usar o `CupertinoSwitch` com o verde padrão do sistema. `success` é para status, não para controle.

Por que não um roxo para a IA: duas cores preenchidas disputam o papel de "ação principal" e confundem. A IA se identifica pelo lugar fixo (barra de baixo) e pelo marca-texto amarelo.

Status de OS (cor no ponto, texto em `textSecondary`): `quote` cinza, `approved` azul (`accentText`), `progress` âmbar (`warning`), `done` verde (`success`), `canceled` cinza (o texto "Cancelada" diferencia). **Atrasada** não é status, é problema: ponto e texto em `danger`, texto em negrito ("Atrasada 2 dias").

## Tipografia

Fonte do sistema (SF Pro). Rótulos em sentence case, nunca em caixa alta.

| `AppTypography.` | Tamanho | Uso |
|---|---|---|
| `title` | 34 bold | Título da tela: o Large Title do sistema (`CupertinoSliverNavigationBar.largeTitle`), que vira título pequeno ao rolar. Sem `height` próprio |
| `highlight` | 22 semibold | Frase do próximo passo, o que o usuário falou |
| `body` / `bodyStrong` | 19 | Linhas, valores, botões |
| `callout` | 17 | Links, linhas secundárias |
| `label` | 15 | Rótulo de seção (`textSecondary`) |

Valores em dinheiro usam `AppTypography.tabular` e sempre `FormatService`.

**Dynamic Type.** Os tamanhos acima são os do tamanho padrão do iPhone. O corpo é 19 (e não 17 como no iOS) porque o público tem a vista cansada; 19 equivale ao Body no tamanho "xL". Todos crescem proporcionalmente com o `MediaQuery.textScaler`, que o Flutter já aplica: **nunca** travar ou limitar o `textScaler`, nem usar altura fixa em linha com texto. O `height` dos estilos é sempre multiplicador do tamanho da fonte (nunca altura em pixels), então a linha cresce junto. Em tamanhos de acessibilidade, a linha de lista empilha o valor embaixo do nome. Protótipo: prancha "Início · texto grande (Dynamic Type)".

## Componentes de lista

Entram nas telas à medida que elas são redesenhadas. Todos usam `AppColors`/`AppTypography` com `.resolveFrom(context)`.

| Widget | Uso |
|---|---|
| `AppListRow` | Linha de lista: `leading` opcional, `title` (quebra, sem reticências), `subtitle`, valor à direita (`trailing`, com números tabulares). O chevron aparece só quando há `onTap`, ou seja, quando a linha abre outra tela (`showChevron` força). Altura mínima 44. Com `textScaler` a partir de 1,35 (tamanhos de acessibilidade) o valor desce para baixo do título |
| `SectionLabel` | Rótulo de seção acima da lista: `label` em `textSecondary`, sentence case (nunca caixa alta), anunciado como cabeçalho pelo leitor de tela |
| `EmptyState` | Lista vazia: frase, dica opcional e uma ação em texto opcional |
| `ErrorState` | Falha ao carregar, com "Tentar novamente" (`onRetry`) e mensagem padrão localizada (`listLoadError`) |
| `LoadingState` | `CupertinoActivityIndicator` com rótulo opcional e `Semantics` de "Carregando..." |

```dart
AppListRow(
  title: customer.name!,
  subtitle: order.deviceName,
  trailing: FormatService().formatCurrency(order.total),
  onTap: () => openOrder(order),
)
```

## Estrutura de toda tela

Seis zonas, sempre nesta ordem. Zonas vazias não aparecem.

1. **Barra de topo:** a barra de navegação do sistema: voltar, nome curto do registro ("OS 186") e "…". No máximo esses três.
2. **Título:** o título grande do sistema (`title`), com subtítulo em `textSecondary`.
3. **Próximo passo:** bloco `accentSoft` com uma frase e o único botão `accent`.
4. **Conteúdo:** listas simples (rótulo + linhas com `separator`). Sem cartão dentro de cartão.
5. **Resumo:** linha forte acima, totais e o que falta.
6. **Embaixo:** foto + "Falar" (`assistantFill`) nas telas com assistente; ou um botão de largura total nas telas de formulário ("Salvar OS"). Sem faixa opaca com borda: o conteúdo rola por baixo e some num degradê (efeito de borda de rolagem). Nas telas com abas, o botão flutua logo acima da barra de abas (acessório da tab bar), não numa segunda barra.

**Abas:** a ordem é sempre Início, Clientes, Agenda, Financeiro, Mais. Quem não usa uma aba (técnico sem Financeiro, empresa sem agenda) não a vê, mas as outras mantêm a mesma ordem.

Margens: texto com `AppSpacing.pageMargin` (24), blocos e botões com `AppSpacing.blockMargin` (16). Cantos: botões 16, blocos 20, campos 12.

## Fluxo de Dados

Tokens são constantes; não há estado. Resolva a cor no build:

```dart
Container(
  color: AppColors.accentSoft.resolveFrom(context),
  child: Text(
    context.l10n.nextStepStartService,
    style: AppTypography.highlight.copyWith(
      color: AppColors.onAccentSoft.resolveFrom(context),
    ),
  ),
)
```

## Exemplos de Uso

Botão principal:

```dart
SizedBox(
  height: AppSizes.primaryButtonHeight,
  width: double.infinity,
  child: CupertinoButton(
    color: AppColors.accent.resolveFrom(context),
    borderRadius: BorderRadius.circular(AppRadii.button),
    onPressed: onStart,
    child: Text(
      context.l10n.startService,
      style: AppTypography.bodyStrong.copyWith(
        color: AppColors.onAccent.resolveFrom(context),
      ),
    ),
  ),
)
```

## Ao mudar uma cor

Mude o valor em `app_colors.dart` e rode `fvm flutter test test/theme/`. O teste mede todos os pares (texto ≥ 4,5:1, componentes ≥ 3:1) no claro, no escuro e nas duas variantes de "Aumentar contraste". Mudou uma cor? Ajuste também a variante de contraste dela. Se um par novo entrar no padrão, adicione-o à lista do teste.
