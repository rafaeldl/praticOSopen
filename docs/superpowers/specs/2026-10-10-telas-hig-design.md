# Telas do app: revisão pelo Apple HIG

Status: aplicado nos protótipos e no `APP_DESIGN_SYSTEM.md` · 2026-10-10 · base: `2026-10-09-telas-mapa-design.md`, `docs/APP_DESIGN_SYSTEM.md`

Revisão das 40 telas propostas (canvas https://claude.ai/artifact/NfHsv1Ge52LXGdpd9ZYihz, página "Telas do app") contra o Apple Human Interface Guidelines. A auditoria completa, com a frase da Apple em cada achado, está abaixo da tabela de aplicação.

## O que foi aplicado (2026-10-10)

| Achado | Onde mudou |
|---|---|
| Texto fixo e reticências (Dynamic Type) | Regra 8 e seção Tipografia do `APP_DESIGN_SYSTEM.md`; linhas quebram em vez de cortar; prancha nova "Início · texto grande (Dynamic Type)" |
| Botão "Continuar com Apple" desenhado à mão | Regra 10: `SignInWithAppleButton` nativo (pacote `sign_in_with_apple` já está no `pubspec.yaml`); protótipo com logo e título em 43% da altura |
| Cadastro novo como tela empurrada | Regra 9: "Novo cliente/veículo/serviço" viram sheet com "Cancelar" à esquerda |
| Barra opaca de 58 pt acima da tab bar | Zona 6: botão flutua acima da barra de abas (acessório), sem faixa opaca; nas outras telas, degradê de borda de rolagem; tab bar flutuante |
| Título 30 próprio | Título = Large Title do sistema (34), que recolhe ao rolar |
| Ordem das abas diferente por papel | Ordem fixa: Início, Clientes, Agenda, Financeiro, Mais |
| Cor com dois sentidos | Cor fica no ponto, texto do status neutro; "Atrasada" passa a `danger` (problema); "Cancelada" cinza |
| Checkbox e radio do Mac | Escolha com ✓ à direita (Especialidades, Convidar pessoa) |
| Linhas que abrem tela sem seta | Seta nas linhas da Início, Agenda, Avisos, OS do cliente e do veículo |
| Fechar do sheet à direita | Fechar à esquerda (Mandar convite) |
| Toggle com o verde `success` | Verde padrão do sistema; `success` só para status |
| "Aparência" dentro do app | Removida de Preferências; segue o ajuste do iPhone |
| Justificativa do azul da marca | Corrigida no `APP_DESIGN_SYSTEM.md` (contraste vale para links ≤ 17 pt; no botão o motivo é a marca) |
| Números do Relatório não fechavam | Corrigido: Serviços R$ 5.730 + Produtos R$ 2.570 = Entrou R$ 8.300 |
| "Sair" em vermelho | Cor de link (vermelho só para apagar e cancelar) |
| Estrelas vazias quase invisíveis, régua do resumo branca no escuro | Contraste corrigido; régua com `separator` |
| "Vamos colocar…" (nós), "Dono" × "Administrador" | Texto sem "nós"; um nome só: Administrador |
| Contratos explicava o caminho em vez de levar até ele | Link "Abrir uma OS" |
| "Comigo" no segmented control | "Minhas" |

## Pendente (vai junto da implementação)

- **Aumentar contraste:** variante de cada token com `CupertinoDynamicColor.withBrightnessAndContrast` + teste (regra no `APP_DESIGN_SYSTEM.md`).
- **`AppTypography.title` 30 → 34** em `lib/theme/app_typography.dart`, e linha de lista que empilha o valor em tamanhos de acessibilidade.
- **Ícones SF Symbols** no lugar dos SVGs próprios (escalam com o texto); aba ativa com símbolo preenchido.
- **Tab bar visível** nas telas empurradas a partir de uma aba (o `CupertinoTabView` do app já faz isso; nos protótipos as telas de detalhe aparecem sem a barra só por simplificação).
- **Botão de limpar** (`clearButtonMode`) nos campos de texto e na busca.
- **Títulos curtos** (até 15 caracteres) para quando o título grande recolhe: "Ordens de serviço" → "OS" na barra pequena.
- **Especialidades pré-marcadas** pelo ramo, para a etapa poder ser pulada (`onboarding.md`).
- **Bloco "próximo passo"**: testar fundo neutro com só o rótulo colorido (botão azul sobre azul-claro é sobreposição de cores parecidas). Mantido por ora.

---

Fonte: skill `apple-hig` (release 2026-09-27, snapshot Apple 2026-09-12). Lidas as 16 bases (tier 1) e, por relevância: `designing-for-ios`, `tab-bars`, `toolbars` (não existe `navigation-bars.md`; a HIG trata a barra de navegação como toolbar), `lists-and-tables`, `buttons`, `toggles`, `segmented-controls`, `search-fields`, `text-fields`, `sheets`, `action-sheets`, `onboarding`, `charts` e `sign-in-with-apple` (por causa do botão da Apple).
Material: 40 screenshots, `app-*.dc.html` e `gen/gen.py`. As citações estão em inglês, sem tradução, com a força original. "Gravidade" e "correção" são avaliação minha, não regra da Apple.

---

## Auditoria (2026-10-10)

### 1. Resumo

1. **De acordo:** estrutura simples e linguagem clara, um botão preenchido por tela, alvos ≥ 44 pt, status com ponto **e** texto (nunca só cor), switches só em linhas de lista, cores com variante clara e escura e teste de contraste, mensagens de erro que dizem como resolver.
2. **Não está de acordo (mais grave):** tamanhos fixos sem Dynamic Type, com títulos de linha em `nowrap` + reticências. Já há texto cortado no tamanho padrão (Ramo, Catálogo, Escolher serviço).
3. **Cor com dois sentidos:** o azul da marca marca ao mesmo tempo o que é tocável (links, aba ativa) e o status "Aprovada", e o âmbar serve tanto para "Em andamento" quanto para "Atrasada".
4. **Fora do padrão iOS:** checkbox e radio de macOS (Especialidades, Convidar), linhas que abrem outra tela sem seta (Início, Agenda, OS do cliente/veículo), configuração própria de "Aparência", botão "Continuar com Apple" feito à mão (sem logo, proporção errada), "X" do sheet à direita, ordem das abas diferente para o técnico.
5. **Decisões do padrão:** título 30, corpo 19 e azul `#116BB5` são aceitáveis se escalarem com o Dynamic Type e se o azul ganhar variante de contraste aumentado. A barra fixa de 58 pt acima da tab bar e os formulários abertos por push (sem Cancelar) são os pontos que mais se afastam da HIG.

---

### 2. Conflitos entre o APP_DESIGN_SYSTEM e a HIG

| Decisão do padrão | Cláusula HIG (verbatim) + arquivo | Gravidade | Recomendação |
|---|---|---|---|
| **Título 30 bold** fixo, em vez do Large Title de 34 | "Use a large title to help people stay oriented; by default it becomes standard while scrolling and returns to large at the top." (`toolbars.md`, iOS) · "**Consider using the built-in text styles.** With system fonts, they ensure support for Dynamic Type" (`typography.md`) | Média | **Ajustar.** Usar o título grande da barra de navegação do sistema (34 no tamanho L), que também vira título pequeno ao rolar. Hoje o protótipo não tem título recolhido. Se quiser manter 30, que seja um estilo derivado que escale com o Dynamic Type. O valor 30 em si é o de menos. |
| **Corpo 19** em vez do Body 17 | "For custom type styles, use these defaults and minimums: … iOS, iPadOS \| 17 pt \| 11 pt" (`accessibility.md`) · "Be sure to maintain relative hierarchy and distinction when people adjust text size." (`typography.md`) | Baixa | **Manter com justificativa:** público com vista cansada, e 19 é o Body no tamanho xL. A condição é escalar 19 proporcionalmente ao Dynamic Type (seção 5). Sem isso a gravidade passa para alta. |
| **Botão principal preenchido de 58 pt, fixo embaixo, acima da tab bar** (Início "Nova OS", resumo do Financeiro) | "Limit onscreen controls to keep primary content and tasks prominent" (`designing-for-ios.md`) · "Prefer scroll-edge effects to solid/semi-opaque backgrounds beneath controls." (`layout.md`) · "The bar floats at the bottom over Liquid Glass, allowing content to peek through." (`tab-bars.md`) | Média | **Manter a altura de 58** ("the hit region is at least 44x44 pt", `buttons.md`; e "Middle or lower controls tend to be easier to reach", `designing-for-ios.md`). **Ajustar a barra:** tirar o fundo opaco com borda e usar o efeito de borda de rolagem do sistema. Nas telas com abas, avaliar o acessório da tab bar (`TabViewBottomAccessoryPlacement`, citado em `tab-bars.md`) em vez de uma segunda barra empilhada: hoje são cerca de 165 pt de chrome fixo embaixo. |
| **Botão fixo "Salvar …" em formulários abertos por push com "Voltar"** (Novo cliente/serviço/veículo, Conta, Dados da empresa, Editar checklist) | "A sheet requests specific information or presents a scoped, context-related task people complete before returning to the parent view." · "**Provide an alternative to Done**: always pair it with Cancel or Back." · "Single-view sheets: Cancel on the top toolbar's leading edge; Done, when present, trailing." (`sheets.md`) | Média | **Ajustar:** os cadastros "Novo …" abertos de dentro da OS devem ser sheets com "Cancelar" à esquerda. O botão grande embaixo pode continuar como "Done" (decisão de alcance), mas não junto com um "Salvar" no topo ("Avoid showing all three together"). Telas de edição (Conta, Empresa) podem seguir como push. |
| **Azul da marca `#116BB5`** em vez do systemBlue | "Make sure all colors work in light, dark and increased contrast contexts. … For custom colors, make sure to supply light and dark variants, each with a significantly more differentiated increased contrast option." (`color.md`) · "Apply accent color judiciously … Minimize it on controls" (`branding.md`) | Baixa | **Manter** (branding permite cor de destaque). Duas correções: (a) criar a variante de **Increase Contrast** de cada token, que o padrão não tem; (b) a justificativa do doc está incompleta. Pela tabela WCAG da HIG, "18 pt \| All \| 3:1" e "All \| Bold \| 3:1" (`accessibility.md`): o rótulo de 19 semibold só precisa de 3:1. O argumento dos 4,02:1 vale para texto ≤ 17 pt, como links, não para o botão. |
| **"…" no topo** como lugar de recursos ocasionais | Tabela de símbolos: "Editing \| More \| `ellipsis`" (`icons.md`) · "Add **More** only when needed, putting less important actions there." (`toolbars.md`) · "make secondary details and actions discoverable with minimal interaction" (`designing-for-ios.md`) | Baixa | **Manter.** Usar o símbolo `ellipsis` do sistema como menu, sem desenho próprio. Na Agenda e no Relatório o "…" esconde a troca de período. Avaliar deixar a troca de período visível, como já está no Financeiro com as setas. |
| **Bloco "próximo passo" com o botão `accent` dentro** (fundo `accentSoft`) | "Keep to one or two prominent buttons per view." (`buttons.md`) · "Avoid overlapping similar colors in content and controls when possible" (`color.md`) | Baixa | **Manter** (respeita "um ou dois botões de destaque"). Ressalva: botão azul sobre bloco azul-claro é a sobreposição de cores parecidas que a HIG pede para evitar quando possível. Testar o bloco com fundo neutro (`secondarySystemBackground`) e só o kicker colorido. |
| **Tab bar com 5 abas (dono) e 4 abas (técnico), em ordem diferente** | "Keep visual and interaction behavior consistent so people learn quickly and can predict new interactions." (`design-principles.md`) · "Don't disable or hide unavailable sections; explain an empty one instead." (`tab-bars.md`) | Média | **Ajustar a ordem:** dono tem Início, Clientes, Agenda…; técnico tem Início, **Agenda, Clientes**. Usar a mesma ordem relativa. Esconder Financeiro por permissão é decisão de produto: a cláusula fala de seções *indisponíveis*. Aceitável, mas documentar. Usar `TabView` do sistema (Liquid Glass, flutuante) e símbolos preenchidos: "prefer filled symbols" (`tab-bars.md`). |
| **Toggles verdes** (token `success` `#1D7D3E`) | "**Change a switch's default green only if necessary**, for example to your accent color" (`toggles.md`) | Baixa | **Ajustar levemente:** usar o switch nativo com o verde padrão do sistema, não o `success` (que é um verde próprio, mais escuro). Uso em linha de lista está correto: "Use the switch style only in a list row". |
| **Segmented control** ("Em aberto/Todas", "Comigo/Todas", "Serviços (24)/Produtos (31)") | "Consider it for switching between closely related subviews" (`segmented-controls.md`, iOS) · "**Label with nouns or noun phrases**" | Baixa | **Manter.** Uso correto (2 segmentos, mesma lista). Só "Comigo" não é substantivo; "Minhas" ou "Para mim" ficaria mais próximo da regra. |
| **Sheet de convite** (grabber + "X" à direita) | "Single-view sheets: Cancel on the top toolbar's leading edge" · "Include a grabber in a resizable sheet" · "Support swiping vertically to dismiss." (`sheets.md`) · "Close dismisses a modal; prefer their standard symbols without text labels." (`toolbars.md`) | Baixa | **Ajustar:** passar o fechar (`xmark`) para a borda esquerda. Grabber e um botão principal estão corretos. Usar o detent médio do sistema, que o layout já sugere. |
| **Botão "Continuar com Apple" preto**, desenhado à mão, 58 pt, título 19 | "Prefer the system API: it supplies Apple-approved appearance and proportions, localized titles…" · "Keep the button instantly recognizable as Sign in with Apple. Use only artwork downloaded from Apple Design Resources" · "title size is 43% of button height … a 56 pt button a 24 pt title" (`sign-in-with-apple.md`) | **Alta** (App Review avalia) | **Ajustar:** usar `ASAuthorizationAppleIDButton` (título localizado "Continuar com Apple", logo oficial) com `cornerRadius` 16 para casar com os outros botões. Preto no claro está certo ("Black … use on white/light backgrounds"), e o protótipo inverte para branco no escuro, também certo. O que falta: logo da Apple e proporção (19/58 = 33%, a regra pede 43%). |

---

### 3. Achados por tela / padrão repetido

| Tela(s) | O que está na tela | Cláusula HIG (verbatim) + arquivo | Correção concreta |
|---|---|---|---|
| Ramo ("Refrigeração e ar-condicio…"), Catálogo ("Alinhamento e balancea…"), Escolher serviço ("Alinhamento e balanceamen…"); o `row()` usa `white-space:nowrap; text-overflow:ellipsis` em todas as listas | Texto cortado já no tamanho padrão | "**Keep text truncation to a minimum as font size increases.** … Avoid truncating text in scrollable regions unless people can open a separate view for the rest. You can prevent label truncation by allowing as many lines as needed (`numberOfLines`)." (`typography.md`) | Título da linha com várias linhas. Quando não couber, valor (R$) desce para baixo do nome. |
| Início, Início técnico, Agenda, "Últimas OS" do Cliente, "OS deste veículo", Avisos | Linhas que abrem a OS **sem** seta; no Financeiro, Clientes e Contratos as linhas iguais têm seta | "for drill-down, use a disclosure indicator (`UITableViewCell.AccessoryType.disclosureIndicator`)." (`lists-and-tables.md`) | Seta em toda linha que abre outra tela, nas mesmas condições do Financeiro. |
| Início técnico ("Aprovada · começar o serviço" azul), Agenda ("Aprovada · OS 183" azul, dia selecionado azul), Relatório (barra "Serviços" azul) | Azul da marca em texto que não é tocável, igual aos links ("Ver planos", "Usar", "Cadastrar…") | "**Avoid using the same color to mean different things**, especially for status or interactivity: if your brand color marks borderless buttons as interactive, the same or similar color on noninteractive text is confusing." (`color.md`) | Status "Aprovada" com outra cor (ex.: `label` com ponto azul e texto neutro). Na barra do Relatório, usar uma cor de dado diferente do `accent`. |
| Início técnico ("Em andamento" âmbar), Início / Cliente / Veículo ("Atrasada" âmbar) | Dois status diferentes com a mesma cor (o padrão mapeia `progress` e `late` para `warning`) | Mesma cláusula de `color.md`: "especially for status" | Separar as cores: atrasada com mais urgência (`danger` ou âmbar mais forte com ícone) e em andamento com outra. O texto continua junto. |
| Especialidades (checkbox quadrado), Convidar pessoa (radio) | Controles de seleção no estilo macOS | Checkboxes e radio buttons aparecem só em `### macOS` (`toggles.md`) · "option tables often highlight briefly, then add an image like a checkmark." (`lists-and-tables.md`) | Lista do iOS com marca de seleção (`checkmark`) na direita da linha selecionada, para escolha única e múltipla. |
| Preferências → "Aparência: Automática" | Configuração de aparência dentro do app | "Avoid an app-specific appearance setting; it makes people manage two settings and may appear broken when it ignores the system choice." (`dark-mode.md`) | Remover a linha e seguir o sistema. |
| Login | Botão da Apple sem logo; primeira tela pede conta antes de qualquer valor; "Política de privacidade" sem aparência de link | "Delay the request until people have experienced useful content. If an account is required, explain the reason" (`sign-in-with-apple.md`) · "**Avoid relying solely on color** to differentiate objects, indicate interactivity" (`color.md`) | Botão do sistema (seção 2). Subtítulo que diga por que a conta é necessária (ex.: "Suas OS ficam salvas e a equipe vê as mesmas"). Link da política com cor de link. |
| Novo cliente, Novo serviço, Novo veículo | Botão voltar com o texto "Voltar"; nas outras telas aparece o nome da tela anterior | "The standard Back button retraces an information hierarchy and Close dismisses a modal; prefer their standard symbols without text labels." (`toolbars.md`) | Botão voltar do sistema em todo lugar. Se virarem sheets (seção 2), "Cancelar" à esquerda. |
| Cliente, Veículo, Equipe, Plano, Preferências… (telas empurradas a partir de uma aba) | Tab bar some nas telas de detalhe | "Keep the bar visible between sections (a temporary, self-contained modal may cover it)" (`tab-bars.md`) | Manter a tab bar visível nas telas empurradas dentro de cada aba. Escondê-la só em modais. |
| Campos: Nome, Telefone (Negócio, Novo cliente, Convidar), Conta, Dados da empresa, Novo veículo ("Uno"), busca com texto ("troca de emb") | Nenhum botão de limpar no campo | "**Display a trailing Clear button** for erasing input without repeated Delete taps." (`text-fields.md`) | Campo nativo com botão limpar à direita, inclusive no campo de busca. |
| Negócio, Novo cliente, Novo serviço, Convidar | Texto de ajuda do campo começa em x=16; o rótulo do mesmo campo começa em x=24 | "Align related elements" (`layout.md`) | Alinhar a ajuda à margem do rótulo (24). |
| Novo cliente ("+ Mais dados…" centralizado), Novo serviço / Novo veículo ("+ Foto…" à esquerda) | Mesmo tipo de ação, alinhamentos diferentes | "Keep visual and interaction behavior consistent" (`design-principles.md`) | Mesma posição em todas, à esquerda. |
| Negócio ("Vamos colocar umas OS de exemplo") | Usa "nós" | "Avoid *we* altogether; who it means can be unclear." (`writing.md`) | "O app coloca algumas OS de exemplo para você ver como fica. Dá para apagar quando quiser." |
| "Criar meu PraticOS", "Criar minha empresa", "Se eu ficar dias sem abrir o app" × "Sua conta", "Sua empresa", "Seus checklists" | Mistura de primeira e segunda pessoa | "**Use possessive pronouns sparingly** … If you use them, use them consistently and try not to switch perspectives." (`writing.md`) | Escolher uma voz ("você") e tirar possessivos onde não fazem falta: "Criar empresa", "Lembrar se o app ficar dias sem uso", "Checklists". |
| Equipe ("Dono · vê e muda tudo") × Convidar / Conta ("Administrador", "Você é administrador") | Dois nomes para o mesmo papel | "Keep and reference a list of common terms for consistency." (`writing.md`) | Um nome só (o que existir no modelo de papéis) em todas as telas. |
| Contratos ("Para criar um contrato, abra uma OS e ligue 'Repetir esta OS'") | Explica o caminho em vez de levar até ele | "Provide clear next steps on any blank screens, with a button or link if possible." (`writing.md`) | Link "Escolher uma OS para repetir", que abre o seletor de OS. |
| Avaliações | Estrelas vazias com a cor `sep` (`#EFEFF4` sobre branco) quase invisíveis; linha preta de 2 pt no topo | "Avoid colors that make content hard to perceive, like insufficient contrast" (`color.md`) | Estrela vazia com contorno em `secondaryLabel`. A nota "3 de 5" em texto já cobre a acessibilidade. |
| Relatório | Serviços R$ 6.900 + Produtos R$ 3.130 = R$ 10.030, mas "Entrou R$ 8.300"; barra só com cor (`aria-hidden`) | "**Summarize the chart's main message**" · "**Avoid relying solely on color to differentiate data**" (`charts.md`) · "Care about every detail." (`design-principles.md`) | Acertar os números do protótipo. Rótulo de acessibilidade na barra ("Serviços 69%, produtos 31%"). Separador entre as duas cores ("Add visual separation between contiguous areas of color"). |
| Conta ("Sair" vermelho) | Vermelho de ação destrutiva numa ação que não apaga dados | Role "Destructive \| Can destroy data \| System red" (`buttons.md`) | "Sair" com cor de link. Vermelho fica para apagar e cancelar OS, como o próprio padrão diz. |
| Financeiro escuro, Avaliações | Régua do resumo com a cor de texto (linha branca de 2 pt no escuro) | "Use semantic colors that adapt automatically (… `separator` in iOS/iPadOS)." (`dark-mode.md`) | Usar `separator` ou nenhuma linha e deixar o efeito de borda de rolagem separar. |
| Todas (fundos `background`/`surface` próprios, `text2` `#6C6C70`) | Cores de fundo e texto próprias em vez das do sistema | "Prefer system background colors: the system changes base to elevated when a foreground interface (such as a popover or modal sheet) appears … Custom backgrounds can obscure these distinctions." (`dark-mode.md`) · "Prefer system-defined colors, whose accessible variants adapt to contrast and appearance settings." (`accessibility.md`) | Mapear `background` → `systemBackground`, `text`/`textSecondary` → `label`/`secondaryLabel`, `separator` → `separator`, `fill2` → `systemGray6`. Ficam próprias só as cores de marca e status. Corrige o sheet escuro (fundo elevado) e o contraste aumentado de graça. |
| Tab bar e ícones de linha (SVG próprio, traço) | Ícones desenhados à mão; aba ativa sem preenchimento | "Use symbols for objects or concepts wherever interface icons appear, including toolbars, tab bars" (`sf-symbols.md`) · "an iOS tab bar prefers fill" (`sf-symbols.md`) | SF Symbols (ou Cupertino Icons equivalentes no Flutter), variante preenchida na aba. Ganha escala automática com o Dynamic Type. |
| Agenda ("Toda a equipe ▾", faixa da semana) | Menu com triângulo desenhado à mão; pontos sob os dias sem texto | "Express the brand with familiar components." (`branding.md`) · "Describe the interface and content for VoiceOver." (`accessibility.md`) | Botão de menu do sistema para o filtro. Rótulo de acessibilidade nos dias ("quinta, 9, 3 marcados"). |
| Título longo: "Ordens de serviço", "O que usar no app", "A Oficina Exemplo chamou você para a equipe" | Ao recolher para título pequeno, vai cortar | "keep a short title under **15 characters**" (`toolbars.md`) | Título curto para a barra ("OS", "Recursos", "Convite") e a frase longa como subtítulo ou conteúdo. |
| Ramo → Especialidades → Negócio | Etapa opcional ("Dá para mudar depois") no meio do cadastro | "Postpone nonessential setup/customization and provide reasonable defaults." (`onboarding.md`) | Pré-marcar as especialidades do ramo e pular a tela, ou deixar "Pular" visível. Já existe "Refazer a configuração inicial" em Avançado. |

---

### 4. O que está bem alinhado

- **Hierarquia e linguagem:** cada tela começa pelo mais importante, com frases curtas e simples ("Não deu para terminar. Confira a internet…"). Isso atende "Put the most important information first" e "Write clear error messages … say how to fix it" (`writing.md`).
- **Cor nunca sozinha:** status com ponto **e** texto; avisos não lidos com ponto **e** negrito. Atende "Convey state and function with shapes or icons in addition to color" (`accessibility.md`).
- **Alvos de toque:** botões ≥ 44 pt (`.ib` 44×44, linhas ≥ 60, principal 58). Atende "As a general rule, the hit region is at least 44x44 pt" (`buttons.md`). Tamanho mínimo do texto: 12 na tab bar e 15 no conteúdo, acima de 11 pt.
- **Um botão de destaque por tela**, a ação provável preenchida e a destrutiva fora dela. Atende `buttons.md`.
- **Switches só em linhas de lista**, com texto explicando o que fazem quando ligados ("Agenda · Marcar dia e hora das OS"). Atende `toggles.md` e "explain what the setting does when on" (`writing.md`).
- **Busca inline** filtrando uma lista (Clientes, Catálogo, seletores), com placeholder que diz o que se busca. Atende `search-fields.md`.
- **Estados vazios com próximo passo** (Início vazio com "Nova OS", busca sem resultado com "Criar 'Troca de embreagem'"). Atende `writing.md`.
- **Modo escuro** pensado em todos os tokens, com teste de contraste automatizado. Avisos com papel claro.
- **Pedido de dados mínimo:** WhatsApp marcado "Opcional", preço "Pode deixar em branco". Plano com "Restaurar compras".

---

### 5. Dynamic Type e acessibilidade: o que muda quando o texto cresce

O protótipo usa px fixos (30/22/19/17/15/12). No app nativo, cada estilo precisa escalar com a configuração do sistema:

- "Make sure your layout adapts to all font sizes … turn on … Larger Accessibility Text Sizes and confirm the app stays comfortably readable." (`typography.md`). "Ideally, offer text enlargement of at least **200%**" (`accessibility.md`). Como referência, o Body vai de 17 (L) a 53/62 em AX5 (`typography.md`). Com base 19, o corpo passaria de 50 pt. Esse é o cenário a testar, não o 390×844 padrão.

O que quebra no layout atual:

1. **Linhas título + valor** (Início, Financeiro, Catálogo, Agenda): com `nowrap`, o nome vira "Ana R…" e o valor fica intacto. A HIG diz: "Where width is constrained, inline items (like glyphs and timestamps) and container edges can crowd text into truncation or overlap; consider stacking text above secondary items." Em tamanhos de acessibilidade, o valor ou o horário desce para a linha de baixo (`isAccessibilityCategory`).
2. **Barra fixa + tab bar** (cerca de 165 pt hoje): com o botão de 58 crescendo e os rótulos das abas maiores, sobra pouca área de conteúdo. A HIG pede: "**Prioritize important content when responding to text-size changes.** People typically want what they care about enlarged, not always every word (in a tabbed window, not tab titles…)". O conteúdo cresce primeiro; os rótulos das abas não precisam crescer no mesmo ritmo. O botão principal não pode ter altura fixa: "rows/containers may grow to avoid clipping/overlap and allow multiple lines" (`layout.md`).
3. **Bloco "próximo passo"** (22 semibold + botão): em AX5 sozinho ocupa a tela e empurra a lista. Manter a frase, permitir várias linhas e garantir que o resto role. A regra é "Maintain a consistent information hierarchy at any font size, such as keeping primary elements toward the top." (`typography.md`).
4. **Faixa da semana na Agenda** (7 colunas) e **dois botões lado a lado** (Ligar/WhatsApp, Copiar/Outros apps, links do convite): "Reduce the number of text columns as size increases" e "horizontal views may stack" (`layout.md`). Empilhar os botões e trocar a faixa por menos dias ou rolagem horizontal.
5. **Segmented control** com "Serviços (24)": vai cortar. Em tamanhos grandes, tirar a contagem ou deixar o rótulo quebrar linha.
6. **Ícones:** "Increase the size of meaningful interface icons as font size increases. SF Symbols scale automatically." (`typography.md`). Os SVGs fixos de 24 pt (carro, seta, +) não escalam. Usar símbolos do sistema.
7. **Negrito e contraste:** "System fonts automatically support Dynamic Type (where available) and accessibility features such as Bold Text" (`typography.md`). Com fonte do sistema, Bold Text vem de graça; os pesos 600/700 forçados devem partir do estilo, não ser fixos. Para Increase Contrast, cada token próprio precisa da variante ("significantly more differentiated increased contrast option", `color.md`). Testar também com Reduce Transparency (`dark-mode.md`).
8. **VoiceOver:** o HTML já faz boa parte. Pontos de status em `aria-hidden` com o texto lido, "Novo" no ponto de não lido, `aria-label` nos ícones, `role=radio/checkbox`. Faltam: rótulo nos dias da Agenda, resumo da barra do Relatório ("A chart often needs an accessibility label for each important or interactive element", `charts.md`) e os botões nativos da Apple e do sistema, que trazem o próprio texto alternativo.

Conclusão prática: trocar `AppTypography` de tamanhos fixos para estilos que escalam (Large Title/Title/Headline/Body/Callout/Subhead e, se a base 19 ficar, escala proporcional) e testar as telas Início, Financeiro e Catálogo em AX3 e AX5 antes de implementar.
