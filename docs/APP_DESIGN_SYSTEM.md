# APP_DESIGN_SYSTEM.md

## Visão Geral

Padrão visual do aplicativo PraticOS. Vale para toda tela nova ou redesenhada. Os nossos usuários não são técnicos, então o padrão prioriza clareza: **uma pergunta por tela, um botão principal, português do dia a dia**.

Ele complementa o `docs/UX_GUIDELINES.md` (widgets Cupertino, listas, formulários). Quando os dois divergirem em cor, tipografia ou estrutura de tela, vale este documento.

Protótipos de referência (canvas): https://claude.ai/artifact/NfHsv1Ge52LXGdpd9ZYihz — linha "E" e a prancha "Padrão do app".

## Arquitetura

| Arquivo | Conteúdo |
|---|---|
| `lib/theme/app_colors.dart` | `AppColors`: papéis de cor como `CupertinoDynamicColor` (claro e escuro) |
| `lib/theme/app_typography.dart` | `AppTypography`: escala de texto |
| `lib/theme/app_spacing.dart` | `AppSpacing`, `AppSizes`, `AppRadii` |
| `test/theme/app_colors_contrast_test.dart` | Mede o contraste WCAG AA de cada par, nos dois modos |

`lib/theme/app_theme.dart` (azul `#2563EB`) e o `primaryColor: CupertinoColors.activeBlue` de `lib/main.dart` são o padrão antigo. Telas migram para os tokens novos à medida que forem redesenhadas; a troca do `primaryColor` global entra junto com a primeira tela redesenhada (a OS).

## Regras

1. **Uma pergunta por tela:** "o que eu faço agora?". A resposta aparece no topo, em uma frase.
2. **Um botão azul por tela.** Só a ação principal é preenchida com `accent`. As demais usam `secondaryFill` ou viram link (`accentText`).
3. **Português do dia a dia.** "Falta receber R$ 166", "Próximo passo: começar o serviço". Nada de "saldo devedor", "etapa 2 de 4" ou siglas.
4. **Mostrar só o que existe.** Recursos ocasionais (checklist, contrato, endereço, desconto, vários aparelhos) só aparecem na tela quando o registro tem. Para adicionar: menu "…"/"+" ou o assistente.
5. **A IA sempre pergunta antes.** O que ela vai mudar aparece com marca-texto (`marker`) e o botão de confirmação diz o que acontece ("Está certo, pode fazer").
6. **Toque fácil.** Botão principal com 58 de altura (`AppSizes.primaryButtonHeight`); qualquer outro alvo com pelo menos 44.
7. **Cor nunca sozinha.** Todo status tem texto junto. Ponto colorido + texto, nunca selo colorido (ver `UX_GUIDELINES.md`).

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
| `danger` | `#C93029` | `#F17264` | Só ações destrutivas (cancelar OS, apagar) |

Por que não o azul do iOS: `CupertinoColors.activeBlue` (`#007AFF`) com texto branco dá 4,02:1, abaixo do mínimo de 4,5:1. O `#116BB5` dá 5,51:1.

Por que não um roxo para a IA: duas cores preenchidas disputam o papel de "ação principal" e confundem. A IA se identifica pelo lugar fixo (barra de baixo) e pelo marca-texto amarelo.

Status de OS (ponto + texto): `quote` cinza (`textSecondary`), `approved` azul (`accentText`), `progress` âmbar (`warning`), `done` verde (`success`), `canceled` vermelho (`danger`).

## Tipografia

Fonte do sistema (SF Pro). Rótulos em sentence case, nunca em caixa alta.

| `AppTypography.` | Tamanho | Uso |
|---|---|---|
| `title` | 30 bold | Título da tela |
| `highlight` | 22 semibold | Frase do próximo passo, o que o usuário falou |
| `body` / `bodyStrong` | 19 | Linhas, valores, botões |
| `callout` | 17 | Links, linhas secundárias |
| `label` | 15 | Rótulo de seção (`textSecondary`) |

Valores em dinheiro usam `AppTypography.tabular` e sempre `FormatService`.

## Estrutura de toda tela

Seis zonas, sempre nesta ordem. Zonas vazias não aparecem.

1. **Barra de topo:** voltar, nome curto do registro ("OS 186") e "…". No máximo esses três.
2. **Título:** grande (`title`), com subtítulo em `textSecondary`.
3. **Próximo passo:** bloco `accentSoft` com uma frase e o único botão `accent`.
4. **Conteúdo:** listas simples (rótulo + linhas com `separator`). Sem cartão dentro de cartão.
5. **Resumo:** linha forte acima, totais e o que falta.
6. **Barra fixa de baixo:** foto + "Falar" (`assistantFill`) nas telas com assistente; ou um botão de largura total nas telas de formulário ("Salvar OS").

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

Mude o valor em `app_colors.dart` e rode `fvm flutter test test/theme/`. O teste mede todos os pares (texto ≥ 4,5:1, componentes ≥ 3:1) nos dois modos. Se um par novo entrar no padrão, adicione-o à lista do teste.
