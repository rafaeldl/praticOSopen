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
| `lib/screens/widgets/glass_bar_button.dart` | `AppNavBar` (título grande + botões do topo), `GlassBarButton` ("+", "…", compartilhar), `GlassBackButton` |
| `lib/screens/widgets/pull_down_menu.dart` | `showPullDownMenu`: menu "…" em vidro, com grupos (`PullDownGroup`) e ações com ícone (`PullDownItem`) |
| `lib/screens/widgets/picker_screen.dart` | `PickerScaffold<T>`, `pickOne`, `AppSearchField`: telas de escolher (ver "Telas de escolher") |
| `lib/screens/order/new_order_form.dart` | Peças de cadastro em sheet: `NewOrderTopBar` (X e ✓), `FormCard`, `FormRow`, `FormPill`, `FormPhotos`; e as peças da IA: `AssistantBar` (Foto/Falar), `AssistantTranscript`, `AssistantNote` |
| `lib/screens/widgets/form_sheet.dart` | `FormSheet` (cadastro novo em sheet grande: X e ✓, linha do que falta, pergunta antes de descartar), `FormSheetRoute` (trava o arrastar para baixo com algo preenchido), `FormFieldsCard` (cartão com campos de texto) e `FormMoreCard` ("Mais dados" que abre no cartão). Usado por Novo cliente, Novo veículo, Novo serviço/produto, Novo checklist e Convidar pessoa |
| `lib/screens/order/speech_listener.dart` | Microfone (`speech_to_text`) usado pela barra Falar |

`lib/theme/app_theme.dart` (azul `#2563EB`) e o `primaryColor: CupertinoColors.activeBlue` de `lib/main.dart` são o padrão antigo. Telas migram para os tokens novos à medida que forem redesenhadas; a troca do `primaryColor` global entra junto com a primeira tela redesenhada (a OS).

## Regras

1. **Uma pergunta por tela:** "o que eu faço agora?". A resposta aparece no topo, em uma frase.
2. **Um botão azul por tela.** Só a ação principal é preenchida com `accent`. As demais usam `secondaryFill` ou viram link (`accentText`).
3. **Português do dia a dia.** "Falta receber R$ 166", "Próximo passo: começar o serviço". Nada de "saldo devedor", "etapa 2 de 4" ou siglas.
4. **Mostrar só o que existe.** Recursos ocasionais (checklist, contrato, endereço, desconto, vários aparelhos) só aparecem na tela quando o registro tem. Para adicionar: menu "…"/"+" ou o assistente.
5. **A IA faz e mostra o que fez.** Foto e Falar aplicam na hora, sem tela de confirmação. Cada campo que a IA mexeu ganha um ✦ azul (`FormRow.marked`) e aparece o aviso "Preenchi o que está marcado. Confira e salve. · Desfazer"; "Desfazer" volta tudo daquela fala/foto de uma vez. A IA só acrescenta (cliente, veículo, itens, relato, prazo) e não troca o que a pessoa já escolheu. **Nunca** recebe pagamento, cancela ou apaga sozinha. Erros aparecem nesse mesmo aviso, nunca em alerta. Ver "IA na tela".
6. **Toque fácil.** Botão principal com 58 de altura (`AppSizes.primaryButtonHeight`); qualquer outro alvo com pelo menos 44.
7. **Cor nunca sozinha.** Todo status tem texto junto. A cor fica no ponto; o texto do status é neutro (`textSecondary`), para não ser confundido com link. Nunca selo colorido (ver `UX_GUIDELINES.md`).
8. **O texto cresce.** Todo texto acompanha o "Tamanho do texto" do iPhone (Dynamic Type). Nada de altura fixa para texto nem reticências em nome, título de linha ou valor: a linha quebra. Ver "Tipografia".
9. **Cadastro novo abre por cima.** "Nova OS", "Novo cliente", "Novo veículo", "Novo serviço", "Novo checklist" e "Convidar pessoa" abrem como sheet (tamanho grande), como o Lembretes e o Calendário: "X" à esquerda e "✓" à direita no topo, em vidro. O "✓" fica cinza até dar para salvar e azul quando dá; quando ele está cinza, uma linha em `textSecondary` diz o que falta ("Escolha o cliente para salvar"). Com algo preenchido, o "X" pergunta antes de descartar e arrastar a sheet para baixo fica travado. O formulário usa cartões brancos sobre fundo cinza (`AppColors.groupedBackground`); só formulário de criar/editar usa cartões, telas de consulta continuam com lista plana. Ferramentas (Foto, Falar) ficam numa barra de vidro embaixo. O que é ocasional fica num cartão "Mais opções" que **abre ali mesmo**, mostrando os campos dentro do cartão (sem outra janela); fechado, ele resume o que está marcado. O "✓" salva e fecha; não há botão "Salvar" embaixo. A Nova OS é a referência. Os outros cadastros seguem o padrão pelo `FormSheet` (`lib/screens/widgets/form_sheet.dart`, aberto com `FormSheet.show`), com "Mais dados" aberto de início quando o registro já tem algum dos campos de lá:
   - **Novo cliente**: ✓ azul com o nome; e-mail, CPF/CNPJ e endereço em "Mais dados".
   - **Novo veículo**: ✓ azul com a placa/série; foto, marca, categoria e campos do ramo em "Mais dados".
   - **Novo serviço/produto** (catálogo, `CatalogItemForm`): ✓ azul com o nome; nome e preço no 1º cartão, foto e campos do ramo em "Mais dados".
   - **Novo checklist** (`FormTemplateFormScreen(asSheet: true)`): ✓ azul com o nome e pelo menos uma pergunta (a linha do que falta diz qual dos dois); cartão "Perguntas" com "Adicionar pergunta", tocar numa muda, deslizar tira; descrição em "Mais dados".
   - **Convidar pessoa** (`InviteForm`, via `CollaboratorFormScreen`): ✓ azul com o e-mail ou o WhatsApp; nome, e-mail e WhatsApp no 1º cartão, o papel num cartão abaixo.

   O `AppSheet` ficou só para sheet pequena com ação à direita (período, item da OS, papel); não tem mais botão grande embaixo. Telas de edição de algo que já existe (Sua conta, Dados da empresa) abrem empurradas, com "Voltar".
10. **Componentes do iPhone quando existem.** Abas, interruptor (verde do sistema), escolha com ✓ à direita, menu "…" com o símbolo `ellipsis`, sheet com fechar à esquerda, botão "Continuar com Apple" nativo (`SignInWithAppleButton`, com logo e proporção da Apple). Não desenhar uma versão própria.
11. **Vidro só na navegação (Liquid Glass).** Barra de abas, botões do topo (voltar, "…", sino), menus "…", sheets pequenas e o botão principal flutuante acima das abas usam vidro: fundo translúcido com desfoque e sombra leve. O botão principal flutuante é vidro tingido com o azul da marca. Os botões da barra Foto/Falar também são vidro (são controles). O conteúdo (listas, cartões, campos, fundo, o texto ouvido pela IA e o aviso "Preenchi… · Desfazer") fica **sempre opaco** ("Don't use Liquid Glass in the content layer", HIG `materials`). Com "Reduzir transparência" ligado no iPhone, o vidro vira fundo opaco (`surface`).
   - **Implementação no Flutter:** o Flutter ainda não tem o Liquid Glass nativo (issue flutter/flutter#170310 aberta, P3; o pacote oficial `cupertino_ui` 1.1.2 não tem vidro). Até lá, usar o `AppGlass` (`lib/theme/app_glass.dart`: `ClipRRect` + `BackdropFilter` com desfoque + preenchimento translúcido) só na barra de abas, na barra de topo e nas sheets pequenas, medindo o custo de desempenho. Ele vira fundo opaco (sem desfoque) quando "Aumentar contraste" está ligado (`MediaQuery.highContrastOf`), quando recebe `reduceTransparency: true` ou `enabled: false`. O Flutter não expõe "Reduzir transparência" no `MediaQuery`: ler `UIAccessibility.isReduceTransparencyEnabled` por um canal nativo e passar em `reduceTransparency`. Trocar pelo oficial quando o `cupertino_ui` trouxer o material. Barra de abas nativa via pacote de terceiros (ex.: `real_liquid_glass`) fica como teste isolado, risk:high.

12. **Escolher é uma tela, não um menu.** Qualquer escolha numa lista (cliente, veículo, situação, responsável, checklist) abre a tela de escolher (`PickerScaffold`/`pickOne`), nunca um `CupertinoActionSheet`. Tocar no que já está na OS (o nome do cliente, o veículo) abre direto a tela de trocar, sem menu no meio. Ver "Telas de escolher".
13. **Sem botão "Editar".** Cada linha abre o seu editor: o que já existe abre empurrado ou em sheet pequena; item novo abre em sheet grande (regra 9).
14. **Menu "…" para o raro.** Fica no topo, em vidro (`showPullDownMenu`), com grupos separados e ícone em cada ação. Ordem: mudar a situação › · "Adicionar à OS" (só o que o registro ainda não tem) · arquivo (Ver PDF, Copiar link) · destrutivas em vermelho no fim (Cancelar, Apagar), sempre com confirmação. O que é frequente sai do menu e ganha lugar próprio (link na seção, botão do topo ou Foto na barra).

## Cores

Cada cor tem um papel só. Componentes usam o papel, nunca o hex.

| Papel (`AppColors.`) | Claro | Escuro | Uso |
|---|---|---|---|
| `accent` / `onAccent` | `#116BB5` / branco | `#116BB5` / branco | O único botão preenchido da tela. Azul da marca (mesmo do site) |
| `accentText` | `#116BB5` | `#67AAED` | Links e ações em texto ("Trocar", "Voltar") |
| `accentSoft` / `onAccentSoft` | `#E0F1FF` / `#0B3D80` | `#142F4B` / branco | Bloco "próximo passo" (Início, Financeiro, Receber). A tela da OS não usa: lá o próximo passo é o botão azul |
| `secondaryFill` / `onSecondaryFill` | `#F2F2F7` / texto | `#2C2C2E` / texto | Todas as outras ações |
| `assistantFill` / `onAssistantFill` | `#1C1C1E` / branco | `#F2F2F7` / `#1C1C1E` | Legado: o "Falar" agora é vidro com ícone e texto em `accentText`. Não usar em tela nova |
| `marker` / `onMarker` | `#FCF2A2` / `#1C1C1E` | igual | Legado (`AppListRow.marked`). O que a IA preencheu agora leva ✦ em `accent`. Não usar em tela nova |
| `text` / `textSecondary` | `#1C1C1E` / `#6C6C70` | branco / `#AEAEB2` | Texto principal e de apoio |
| `background` / `surface` | branco / branco | preto / `#1C1C1E` | Fundo da tela / blocos |
| `separator` | `#EFEFF4` | `#38383A` | Linhas entre itens |
| `success` | `#1D7D3E` | `#65C67D` | Pago, concluído. Nunca em botão |
| `warning` / `warningSoft` / `onWarningSoft` | `#974D00` / `#FFEBD2` / `#7A3B00` | `#ECA851` / `#3E290F` / `#ECA851` | Falta algo: valor, pagamento, foto |
| `danger` | `#C93029` | `#F17264` | Ações destrutivas (cancelar OS, apagar) e problema (OS atrasada) |

Por que o azul da marca e não o do iOS: é a cor da marca (a HIG aceita uma cor de destaque própria, usada com moderação). O contraste ajuda nos textos pequenos: `#007AFF` sobre branco dá 4,02:1, abaixo dos 4,5:1 que a HIG pede para texto até 17 pt (links), e o `#116BB5` dá 5,51:1. No botão principal (19 semibold), a HIG pede 3:1, então ali o contraste não é o motivo.

**Aumentar contraste:** a HIG pede, para cores próprias, uma variante clara, uma escura e uma bem mais contrastada para "Aumentar contraste". Cada token usa `CupertinoDynamicColor.withBrightnessAndContrast` (`highContrastColor` / `darkHighContrastColor`) e o `resolveFrom(context)` escolhe a variante sozinho. Nessas variantes o texto fica mais escuro no claro (`text` preto, `textSecondary` `#3A3A3C`, `accentText` `#0A4F8A`, `danger` `#A1201A`) e mais claro no escuro (`textSecondary` `#D1D1D6`, `accentText` `#9DCBF7`, `danger` `#FF9A8F`), e o `separator` fica mais visível. O teste mede as quatro variantes, exige que "Aumentar contraste" nunca diminua o contraste de um par e que `textSecondary` chegue a 7:1.

**Interruptor:** usar o `CupertinoSwitch` com o verde padrão do sistema. `success` é para status, não para controle.

Por que não um roxo para a IA: duas cores preenchidas disputam o papel de "ação principal" e confundem. A IA se identifica pelo lugar fixo (barra de baixo) e pelo ✦ azul no que ela preencheu.

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

## Telas de escolher

Toda tela que escolhe algo (cliente, veículo, serviço/peça, checklist, situação, responsável, valor acumulado, vários veículos) usa `PickerScaffold<T>` (`lib/screens/widgets/picker_screen.dart`):

- Abre empurrada; na Nova OS empilha no Navigator interno da sheet (rotas nomeadas de sempre).
- Título grande = a pergunta ("Qual cliente?", "Qual veículo?", "O que vai ser feito?", "Qual checklist?", "Qual a situação?", "Quem é o responsável?"), `subtitle` opcional ("de Paulo Nunes").
- Busca (`AppSearchField`) só com **mais de 10 itens** (`kPickerSearchThreshold`); depois de digitar ela fica. `alwaysShowSearch` só onde digitar é o jeito de criar (serviço/peça, valor acumulado).
- Abrir pelo registro: tocar no que já está escolhido (cliente, veículo na OS) abre direto esta tela, com o ✓ no atual.
- Cadastrar novo: botão "+" de vidro no topo, à direita (`addLabel` vira o rótulo de acessibilidade, `onAdd`), como no Contatos. Cadastro abre em sheet e, ao salvar, já volta escolhido. Buscou e não achou: aparece na lista "+ Cadastrar “texto”" (`onCreate`, já com o texto no cadastro) e uma frase curta em `textSecondary`.
- Tirar o que está escolhido: opção "Nenhum …" como linha comum no topo da lista (padrão do Ajustes/Calendário), nunca botão vermelho nem "Limpar" no topo. Ex.: "Nenhum veículo" ao trocar o veículo da OS.
- Linhas planas sem chevron (`PickerItem`); tocar escolhe e volta. O escolhido tem ✓ azul (`AppListRow.selected`), depois do valor quando houver.
- Seções com `SectionLabel` (Recentes/Todos, Mais usados, Do cliente/Outros).
- Múltipla escolha (`multiple: true`): tocar marca/desmarca; o ✓ redondo do topo (`PickerConfirmButton`, cinza enquanto `onConfirm` é null, azul quando dá) confirma. Sem botão "Confirmar" embaixo.
- Vazio: `EmptyState` com a ação de criar. Status: `StatusDot` como `leading` e texto em peso normal (`strongTitles: false`).

Lista curta e fixa (situação, responsável): `pickOne`. Os cadastros que o "+" abre (cliente, veículo, serviço, checklist) abrem na sheet da regra 9 (`FormSheet`).

```dart
final status = await pickOne<String>(
  context,
  title: context.l10n.pickerStatusTitle,
  selected: order.status,
  options: [
    for (final s in ['quote', 'approved', 'progress', 'done', 'canceled'])
      PickerItem(
        value: s,
        title: OrderStatusStyle.label(context.l10n, s),
        leading: StatusDot(color: OrderStatusStyle.dotColor(s)),
      ),
  ],
);
```

## Estrutura de toda tela

Zonas, sempre nesta ordem. Zona vazia não aparece.

1. **Barra de topo** (vidro): voltar, título curto do registro ("OS 186", menos de 15 letras) e no máximo dois botões à direita (ex.: compartilhar e "…"). Telas de coleção (Início, listas) usam o título grande do sistema; telas de um registro (OS) usam o título pequeno, porque quem identifica o registro é o cabeçalho.
2. **Cabeçalho** (conteúdo): o nome que identifica o registro em destaque (cliente da OS), o apoio em `textSecondary` (veículo · placa), a situação como ponto + texto e **uma frase** do que falta ("Fica pronto hoje, 17:00", "Falta receber R$ 166"). Atrasada: ponto e texto em `danger`, negrito.
3. **Ação principal:** o único botão `accent`, 58 de altura, largura total, logo abaixo do cabeçalho, com o próximo passo ("Começar serviço", "Marcar como pronta", "Receber R$ 166"). Fica no conteúdo, não preso embaixo. Sem próximo passo, sem botão. Telas de lista podem usar o bloco `accentSoft` (`NextStepBlock`).
4. **Conteúdo:** listas planas (`SectionLabel` + linhas com `separator`), seção vazia não aparece. Cartões só em formulário (regra 9). Sem cartão dentro de cartão. Ações frequentes de uma seção viram link no fim dela ("+ Adicionar serviço ou peça").
5. **Resumo:** junto do que ele resume, como recibo (itens → Total → "Falta receber ›").
6. **Embaixo:** a barra de vidro Foto/Falar (`AssistantBar`) nas telas com IA, sempre presa ao fundo da tela mesmo com pouco conteúdo. Sem faixa opaca com borda: o conteúdo rola por baixo, e o fim da lista sobe acima da barra e do aviso da IA. Nas telas com abas, o botão flutua logo acima da barra de abas (acessório da tab bar), não numa segunda barra.

**Tela da OS** (`order_screen_v2.dart`, OS salva): topo "OS N" com compartilhar ("Mandar para o cliente") e "…"; cabeçalho com cliente (tocar troca o cliente), veículo · placa (tocar troca o veículo), situação e a frase; botão do próximo passo (Aprovar orçamento → Começar serviço → Marcar como pronta → Receber R$ X); depois "O que o cliente pediu", "Serviços e peças" (com Total e "Falta receber ›" só com "Valores e cobrança" ligado), fotos em faixa, os 2 últimos comentários e "Ver todos (N) ›" (tela própria, `OrderCommentsScreen`), checklists ("7 de 10 respondidas") e "Detalhes" (agendamento, responsável, local, contrato, documentos). "peça" aparece só embaixo de produto.

**Nova OS** (sheet grande, `openNewOrder`): cartões nesta ordem: cliente/veículo → "O que vai ser feito" → "O que o cliente pediu" (opcional; vai para o campo "Observação" do ramo ou vira o 1º comentário) → Fotos → "Fica pronto" → "Mais opções" (Situação, Visita, Responsável, Local, abrindo no cartão). As escolhas empilham no Navigator interno da sheet.

**IA na tela** (Nova OS e OS):
- **Barra:** dois botões de vidro separados, "Foto" (texto em `text`) e "Falar" (texto em `accentText`), com ícone e rótulo. Sem IA na empresa, só "Foto".
- **Falar:** a própria barra vira "Ouvindo…", com onda azul, ■ (parar e preencher) e X (cancelar); o texto ouvido aparece num cartão opaco acima. Sem microfone, vira campo de texto. Nada de tela separada.
- **Foto:** vai direto para as fotos da OS e a barra mostra "Lendo as fotos…".
- **Resultado:** ✦ nos campos e aviso opaco com "Desfazer" (regra 5).

**Abas:** só os lugares do dia a dia, sempre na ordem Início (ícone da casa), Agenda, Financeiro. Clientes, catálogo, contratos, equipe e ajustes pertencem à OS ou à empresa e abrem pelo botão do perfil, no topo da Início. Ao lado das abas fica o "+" azul (Nova OS), que é uma ação e não uma aba: azul cheio, sem vidro. Quem não usa uma aba (técnico sem Financeiro, empresa sem agenda) não a vê, mas as outras mantêm a mesma ordem. Sem "+" e com menos de 3 abas (técnico), a cápsula fica centralizada. No código: `AppTab` e `visibleAppTabs()` (`lib/screens/menu_navigation/app_tabs.dart`) decidem as abas visíveis (Agenda some com `Company.useScheduling` desligado; Financeiro só com `viewFinancialReports`); a barra é o `GlassTabBar` (vidro do `AppGlass`, parâmetro `action` para o "+"), e o nome de analytics de cada índice segue as abas visíveis.

**Início:** `Home` liga a store ao `HomeContent` (`lib/screens/menu_navigation/home_content.dart`, só dados e callbacks, testável). Zonas: sino e perfil em vidro no topo, título grande com subtítulo ("12 em aberto · 2 atrasadas"), filtros "Em aberto | Concluídas | Todas" (técnico: bloco "Agora" e "Minhas | Todas") e lista no estilo do Mail (`OrderListRow`: cliente e total, veículo · serviço, status em cinza; atrasada com ponto vermelho e status em `danger`). Sem grupos: a ordem resolve (atrasadas primeiro). A busca só aparece ao puxar a lista para baixo. "Nova OS" é o "+" azul ao lado das abas. Regras puras em `home_groups.dart`. Sem nenhuma OS na empresa, a tela vira o estado de primeira vez, apontando para o "+".

**Agenda** (`lib/screens/agenda/agenda_screen.dart`, store `AgendaStore`): mesmo fundo e lista plana da Início. Topo com título grande e um "…" em vidro: "Ver o mês"/"Ver a semana", "Hoje" (só fora de hoje) e, para dono/gerente/supervisor, "De quem: Toda a equipe" (abre `pickOne` "De quem mostrar?"). Abaixo, "‹ Outubro de 2026 ›" (as setas andam uma semana ou um mês) e a semana do dia escolhido (dia escolhido em `accentSoft`, ponto cinza nos dias com OS); no modo mês, o `TableCalendar` com os papéis de cor. Com filtro, a linha "Só de Bruno · Mostrar todos". Depois "Quinta-feira, 8 de outubro · 2 marcados" e as OS do dia: cliente e hora (ou "Dia todo"), ponto + "situação · OS N" (atrasada em `danger`, negrito), veículo · "com" responsável. Dia vazio: `EmptyState`.

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
