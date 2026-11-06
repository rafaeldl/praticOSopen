# WEB_APP_DESIGN.md

## Visão Geral

Padrão visual e de interação do app web do PraticOS (`firebase/webapp/`, servido em `/web`). Vale para toda tela autenticada no navegador. O app móvel segue `docs/APP_DESIGN_SYSTEM.md`, e o site institucional segue `firebase/hosting/design.md`. A arquitetura está em `docs/WEB_APP.md`.

A ideia em uma frase: **o tema Campo do site, em forma de ferramenta de mesa.** Papel quente, tinta e barra lateral azul-marinho, ação principal amarela e números alinhados em coluna, com as regras de produto do app. Nada de Cupertino e nada de layout de marketing.

**Status: construído.** Este documento descreve o que está no ar. A referência visual foi o protótipo da branch `claude/web-app-prototype-bb3bbf`; onde a proposta antiga deste documento e o protótipo divergiam, venceu o protótipo.

### O que mudou desde a proposta

| Proposta (out/2026) | Construído |
|---|---|
| Tema "Ordem de Serviço" (papel claro, tinta grafite) | Tema **Campo**, o mesmo do site (`tokens.css`) |
| Botão principal azul | Botão principal **amarelo** (`--color-marker`) com texto marinho. Azul fica para link, foco e seleção |
| Mestre-detalhe com o detalhe trocando de lugar | **Painel ao lado** da lista, que não é camada |
| Quadro de OS como tela própria, prioridade baixa | **Quadro como aba** da lista (Lista \| Quadro) |
| Archivo nos títulos, IBM Plex Sans no texto | **IBM Plex Sans em tudo**, títulos inclusive. Outfit só no logo |
| Densidade compacta como padrão | **Confortável** como padrão, sem escolha por pessoa (no protótipo: Densidade "Confortável" e Fonte "Mais sóbria"; em `app.css`: `--font-display`, `--font-body` e `--font-num` IBM Plex Sans, `--row-y` 0,8 rem, `--ctl` 2,75 rem, que vale para botão, input e select) |
| Receber como tela de mesa | **Receber como aba do Financeiro** (Resumo, Receber, Relatório) |
| Mobile no navegador não é alvo | Funciona no celular, com abas embaixo e listas no lugar de tabelas |

## O que vem de cada lugar

| Vem do app (regra de produto) | Vem do site (identidade) | Só existe na mesa |
|---|---|---|
| Uma pergunta por tela, um botão principal | Tokens de `tokens.css` (tema Campo) | Lista com painel ao lado |
| Português do dia a dia, sem sigla | Papel, marinho e amarelo | Tabelas com seleção e ações em lote |
| Mostrar só o que o registro tem | Réguas em vez de cartões e sombras | Atalhos e paleta (`⌘K`) |
| Status: ponto + texto, nunca selo | Sem gradiente, sem vidro | URLs compartilháveis e várias abas |
| Atrasada em vermelho, com texto em negrito | Sucesso silencioso, sem confete | Arrastar, sempre com alternativa |

## Regras

1. **Uma pergunta por tela, respondida no topo.** A lista diz "12 em aberto · 2 atrasadas · R$ 480 para receber". A OS diz "Falta receber R$ 166".
2. **Um botão amarelo por área de trabalho.** A lista e o painel aberto são áreas separadas; o painel só tem amarelo se houver próximo passo. Selecionar linhas troca a barra de filtros pelas ações do lote.
3. **Tudo se faz pelo teclado.** Arrastar sempre tem alternativa com um clique ou tecla (WCAG 2.5.7): o quadro tem o botão "…" e `Shift` + seta, a agenda tem `Shift` + setas e `Enter`.
4. **Toda tela tem URL.** OS, cliente, filtro, aba, mês e período ficam na URL (`?order=`, `?f=`, `?view=board`, `?month=`). Copiar o endereço leva ao mesmo lugar, sujeito à permissão de quem abriu. Voltar fecha o que estiver aberto.
5. **Permissão é igual à do app.** Quem não pode não vê a ação nem o item do menu. O servidor confere de novo, e a URL direta também é barrada.
6. **Mostrar só o que existe.** Coluna vazia em toda a página não aparece. Recurso ocasional fica no menu "…" ou na paleta.
7. **Sem modo de edição.** Cada linha abre o seu editor. Não há botão "Editar".
8. **Dinheiro e situação nunca mudam por engano.** Pedem confirmação ou Enter e oferecem "Desfazer". Lote sempre mostra antes quantas mudam e de quê para quê.
9. **A IA não mexe em dinheiro.** Nunca recebe, cancela ou apaga sozinha.
   - **Em uma OS:** segue o app. Faz, marca com ✦ e oferece "Desfazer".
   - **Em várias OS:** pergunta antes. Mostra o que cada OS ganharia e só aplica com "Aplicar em N OS".
10. **Cor nunca sozinha.** Status, erro e seleção sempre têm texto ou ícone.
11. **Sem reticências em nome e valor.** A linha quebra. O texto a 200% não corta nada nem cria rolagem lateral.

## Tokens

Fonte única: `firebase/hosting/src/css/tokens.css`, importado por `src/main.ts` (sem cópia à mão). O web acrescenta só o que a ferramenta precisa, em `src/styles/app.css`:

| Papel | Token | Uso no web |
|---|---|---|
| Fundo | `--color-paper` | Fundo da página e da lista |
| Superfície | `--color-card` | Painel da OS, gavetas, diálogos, campos |
| Preenchimento secundário | `--color-paper-2` | Hover, botões secundários, faixa "sem conexão" |
| Texto | `--color-ink` | Marinho no claro, quase branco no escuro |
| Texto secundário | `--color-muted` | Subtítulos, rótulos, situação |
| Régua | `--color-rule` | Separadores (decorativa). A régua forte (`--color-ink`, 2 px) separa o cabeçalho da lista |
| Barra lateral | `--color-navy`, `--color-on-navy` | Navegação; continua marinho no escuro (um pouco mais escuro) |
| Ação principal | `--action-bg` = `--color-marker` | Botão amarelo, texto `--color-marker-ink` |
| Link e seleção | `--color-accent`, `--color-selected` | Links, foco (`--color-focus`), linha aberta |
| Sucesso | `--color-success` | Ponto de concluída |
| Aviso (texto) | `--color-warning-text` (só web) | Em andamento, "Parada". `--color-warning` só no ponto |
| Erro (texto) | `--color-danger-text` (só web) | Atrasada, erro de campo |
| Borda de campo | `--color-control` (só web) | Campos e botões: 3:1 contra o fundo (WCAG 1.4.11) |

Os tokens só do web existem porque o site foi desenhado para títulos: `--color-warning` e `--color-danger` como texto pequeno não passam de 4,5:1, e `--color-rule` como borda de campo fica abaixo de 3:1. Cada um tem valor próprio para o escuro (`:root[data-theme="dark"]`).

Tema: claro por padrão; escuro pelo sistema ou pela escolha em Configurações › Neste navegador (`data-theme`). Com `prefers-contrast: more`, texto secundário e réguas viram `--color-ink` e as bordas engrossam. Com `forced-colors`, pontos, aba atual e seleção ganham contorno do sistema.

## Tipografia

| Uso | Fonte | Tamanho |
|---|---|---|
| Logo | Outfit 800 | 1,45 rem |
| Título da página | IBM Plex Sans 700 | 1,75 rem (1,4 rem abaixo de 48 rem) |
| Título do painel (cliente da OS) | IBM Plex Sans 700 | 1,4 rem |
| Corpo e linha de tabela | IBM Plex Sans 400 | 0,9375 rem (15 px) |
| Rótulo e texto pequeno | IBM Plex Sans 600 | 0,8125 rem (13 px), sentence case |
| Número, valor, placa e nº da OS | IBM Plex Sans 500, `tabular-nums` | 0,9375 rem |
| Tecla (`kbd`) | IBM Plex Mono | 0,72 rem |

IBM Plex Sans em tudo foi escolha do dono: alinha os dígitos em coluna (DM Sans, a do site, não alinha) e lê melhor em tabela. No escuro o corpo fica com peso 350, para não "inchar". Fontes auto-hospedadas (`src/styles/fonts.css`), subset latino, `font-display: swap`.

O corpo é 15, e não 19 como no app, porque na mesa a pessoa precisa ver mais linhas. Quem precisa de letra maior usa o zoom do navegador: tudo em `rem`, e as telas são testadas a 200%.

## Densidade e medidas

Densidade confortável, uma só:

| Item | Mouse | Toque (`pointer: coarse`) e celular |
|---|---|---|
| Campo e botão | 2,75 rem (44 px) | 2,75 rem |
| Botão principal | 2,75 rem | 3,25 rem (52 px) |
| Linha de tabela | `--row-y` 0,8 rem de respiro | idem |
| Alvo mínimo | 24 px (WCAG 2.5.8) | 44 px |

Cantos de 6 px, sem pílula (exceto as iniciais da empresa). Sombra só em camada flutuante (paleta, menu, aviso). Movimento de 160 a 240 ms, só em hover, foco e camada; `prefers-reduced-motion` desliga tudo.

## Estrutura da tela

```
┌──────────────┬───────────────────────────────┬──────────────────────────┐
│ PraticOS     │ Início                [Nova OS]│ ×                    …  │
│ (AB) Oficina │ 12 em aberto · 2 atrasadas     │ Paulo Nunes              │
│ [Buscar ⌘K]  │ (Lista)(Quadro)                │ Fiat Uno · ABC1D23       │
│              │ Em aberto  Atrasadas  Hoje …   │ ● Na oficina · fica      │
│ Início    12 │━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━│   pronta hoje, 17:00     │
│ Agenda       │ 186 Paulo   Fiat Uno  R$ 166 ◄ │ [ Concluir serviço ]     │
│ Financeiro   │ 185 Ana     iPhone 12 R$  80   │ Serviços e peças         │
│ Clientes     │ 184 Bruno   Gol       R$ 310   │ …                        │
│ Notas fiscais│                                │                          │
│ Catálogo     │                                │                          │
│ Equipe       │                                │                          │
│ Configurações│                                │                          │
└──────────────┴───────────────────────────────┴──────────────────────────┘
  barra lateral       lista (régua forte no topo)      painel ao lado
```

- **Barra lateral marinho, 14 rem.** Logo, iniciais e nome da empresa (troca de empresa ali), campo "Buscar" com `⌘K`, e o menu na ordem das abas do app: Início, Agenda, Financeiro; depois Clientes, Notas fiscais, Catálogo e Equipe, cada um só para quem pode abrir. Configurações no pé. Abaixo de 48 rem vira trilho de ícones (3,5 rem) com nome acessível.
- **Painel ao lado, não camada.** A OS (ou cliente, nota) abre à direita, com largura entre 27 e 42 rem (40% da área). O foco fica na lista: `↓`/`↑` (ou `J`/`K`) trocam o que o painel mostra e `Enter` leva o foco para dentro. Quando a área de trabalho fica abaixo de 60 rem, o painel ocupa a área toda, com a mesma URL.
- **Gaveta à direita para criar.** Nova OS, cadastro de cliente, item do catálogo, checklist e recebimento abrem por cima, como camada (`Layer`). `Esc` fecha e pergunta antes de descartar; `⌘ Enter` salva de qualquer campo.
- **Celular (abaixo de 40 rem).** Barra no topo com o logo e "Nova OS", abas embaixo (Início, Agenda, Financeiro, Mais) e listas no lugar de tabelas. O quadro rola de lado, uma coluna por tela. O lote não aparece no celular.

## Telas descritas

Sem imagens: o que se vê em cada tela, na tela grande.

- **Entrada (`/login`).** Faixa marinho à esquerda com o logo e "Sua oficina inteira, em uma tela grande."; à direita, "Entrar no PraticOS", "Use a mesma conta do celular", e três botões: Continuar com Google, Continuar com Apple (preto) e "Já tenho conta com e-mail", que abre e-mail, senha e "Esqueceu a senha?". Quem não está na lista de acesso vê "O PraticOS no computador ainda não foi liberado para você".
- **Início, lista.** Título "Início" com o resumo em uma frase e o botão amarelo "Nova OS". Abas Lista | Quadro, filtros (Em aberto, Atrasadas, Para hoje, Sem receber, Orçamentos, Paradas, Concluídas, Todas; o técnico tem Minhas) com contagem, busca. Régua marinho de 2 px e a tabela: nº, cliente, aparelho e placa, situação (ponto + texto), Quando (visita ou entrega, vermelho se atrasada) e valor com "falta receber". Acima da lista, quando há, "Manutenções chegando". Linha aberta em `--color-selected`.
- **Início, quadro.** Uma coluna por situação, cartões com nº, cliente, aparelho e valor. Dica no topo: arrastar, botão "…" ou `Shift` + seta. Só aparecem destinos que o papel aceita.
- **Lote.** Marcar linhas troca os filtros por "N selecionadas" e as ações: Mudar situação, Responsável, Mandar cobrança, Pedir ao assistente, Receber de {cliente} (mesmo cliente), PDF e Imprimir. Cada mudança abre uma confirmação com a lista de → para; o aviso depois tem "Desfazer".
- **OS no painel.** Título pequeno "OS 186", cliente grande, aparelho, situação com uma frase ("fica pronta hoje, 17:00", "atrasada 2 dias", "Falta receber R$ 166") e o botão amarelo do próximo passo (Aprovar, Começar, Concluir serviço, Retomar, Receber). Depois: serviços e peças por aparelho com o total como recibo, fotos (colar ou arrastar), checklists, contrato, comentários e Detalhes. Menu "…" com o raro, destrutivas no fim. Barra "Peça ao assistente" no pé.
- **Nova OS (gaveta).** Cursor em Cliente, com Recentes; depois veículo ou aparelho, itens com o preço do catálogo e "Mais usados", entrega e "O que o cliente pediu". "+ Cadastrar «nome»" no fim de cada busca. "Salvar" amarelo; `⌘ Enter` salva.
- **Agenda.** Semana ou Dia, grade de horas com faixa "Dia todo" no topo, mês pequeno ao lado com ponto nos dias com OS, filtro "De quem". Blocos arrastáveis de meia em meia hora; mover uma visita que o cliente esperava pergunta antes. A grade aparece mesmo vazia, e clicar num horário livre abre a Nova OS já com o dia e a hora.
- **Financeiro.** Abas Resumo, Receber e Relatório. Resumo: Recebido e Vendido do mês, A receber e Em andamento, e a lista do cartão escolhido. Receber: quem deve, por cliente, das dívidas mais antigas. Relatório: período, totais, composição, rankings, "Exportar CSV", "Exportar planilha" e "Imprimir ou salvar PDF".
- **Paleta (`⌘K`).** Camada no topo com um campo: OS pelo número, clientes, aparelhos, catálogo e ações ("Ir para…", importar planilhas). Cada grupo só para quem abre a tela.

## Componentes

| App | Web | Muda o quê |
|---|---|---|
| `AppListRow`, lista plana | Tabela nativa (`.grid`) | Linhas semânticas, cabeçalho fixo, carrega mais ao rolar. Sem virtualizar, para Ctrl+F e impressão funcionarem |
| `PickerScaffold` | `Combobox` | Escolher continua sendo pesquisa, no lugar. Vazio mostra Recentes e Mais usados. "+ Cadastrar «texto»" no fim, ✓ no atual, "Nenhum …" para tirar. ARIA com `aria-activedescendant` |
| `FormSheet` | Gaveta (`Layer`) à direita | `Esc` fecha e pergunta antes de descartar; `⌘ Enter` salva |
| `showPullDownMenu` | `Menu` | Mesmos grupos, destrutivas no fim, setas e letras. Preso ao botão; no celular, folha embaixo |
| `CupertinoAlertDialog` | `Dialog` | Foco preso, `Esc` cancela, botão padrão nunca é o destrutivo |
| `AppGlass` | Não existe | Sem vidro na web |
| `AssistantBar` | Barra "Peça ao assistente" | Digitar, colar imagem, arrastar arquivo |
| `EmptyState`, `ErrorState`, `LoadingState` | Iguais | Mesmas frases, das mesmas chaves de tradução |
| Status | `StatusLabel` | Ponto + texto, nome da situação do segmento |
| Valor | `MoneyInput` | Lê como digitado: 150 é 150, nunca 1,50 |

Os componentes base aparecem em `/web/dev/components`, só nos builds de emulador.

## Teclado

| Tecla | Ação | Onde |
|---|---|---|
| `⌘/Ctrl K` | Paleta: buscar e comandos | Sempre |
| `?` | Lista de atalhos | Fora de campo |
| `N` | Nova OS | Fora de campo |
| `0`–`9` | Abre a paleta com o número (achar a OS) | Fora de campo |
| `/` | Buscar na lista | Listas |
| `↓` / `↑` ou `J` / `K` | Próxima ou anterior, abrindo no painel | Lista de OS |
| `Enter` | Levar o foco para o painel | Lista de OS |
| `Espaço` | Marcar a linha para o lote | Lista de OS |
| `A` | Adicionar serviço ou peça | OS aberta |
| `S` | Mudar a situação | OS aberta |
| `C` | Trocar o cliente | OS aberta |
| `D` | Agendar a visita | OS aberta |
| `M` | Mandar para o cliente | OS aberta |
| `R` | Receber (valor que falta e a forma do último pagamento já vêm; `Enter` confirma) | OS aberta |
| `P` | Próximo passo (o botão azul) | OS aberta |
| `W` | Mandar pelo WhatsApp direto (sem telefone, abre "Mandar") | OS aberta |
| `-` | Dar desconto | OS aberta |
| `↑` / `↓`, `Home` / `End`, primeira letra | Andar nas opções de uma pergunta ("Qual a situação?", menu "…") | Lista de opções |
| `↑` / `↓` (`Shift`: meia hora) | Mudar o dia da data digitada | Agendar e prazo |
| `⌘/Ctrl Enter` | Salvar | Gaveta e formulário |
| `←` / `→` | Período anterior e seguinte | Agenda, Financeiro, Relatório, Notas |
| `T` | Hoje | Agenda |
| `Shift` + setas | Mover cartão ou visita | Quadro, Agenda |
| `Esc` | Fechar a camada de cima | Sempre |

Regras:

- Tecla de uma letra só age fora de campo de texto, e pode ser desligada em Configurações › Neste navegador › "Usar atalhos de uma tecla" (WCAG 2.1.4).
- Nada captura `Ctrl+F`, `Ctrl+P`, `Ctrl+L`, `Ctrl+T`, `Ctrl+W` nem as setas do leitor de tela.
- Foco visível em `--color-focus`, 2 px, sem animação; na barra lateral, amarelo. Barra fixa nunca cobre o foco (2.4.11).
- Abrir camada leva o foco para dentro; fechar devolve para quem abriu.
- Escolha sugerida vem pronta para `Enter`: no campo de busca vazio a primeira sugestão (ou a atual, ✓) já está ativa; em campo opcional sem sugestão, `Enter` segue para o próximo campo. Em "Mandar" o foco abre no WhatsApp. O botão azul segue o que a pessoa fez da última vez a partir daquela situação (ex.: Aprovado → Concluído), só para frente e só se permitido.
- Na paleta, ações que batem com o texto ("desc" → Dar desconto, "cli" → Novo cliente) vêm antes dos registros; "Cadastrar cliente «texto»" fica por último.
- Data digitada: "amanhã 14h", "+3", "seg 8:30", "9/5 14h" (em inglês, mês/dia e "2pm"); o seletor nativo continua embaixo e mostra o que foi entendido.
- Pergunta que não bloqueia (próxima manutenção) fica dentro da OS, não por cima.
- Mudança de lista avisa o leitor de tela por `aria-live`, com a contagem.

## Nova OS em menos de 45 segundos

Roteiro de referência: cliente já cadastrado, um serviço do catálogo, valor do catálogo. `N` abre a gaveta com o cursor em Cliente e os recentes listados; `↓` e `Enter` escolhem; o veículo único entra sozinho; digitar o serviço e `Enter` põe o item com o preço; `⌘ Enter` salva. O teste E2E cronometra esse roteiro e falha acima de 45 s.

O modelo KLM da descoberta (`docs/web-app/keyboard-flows.md`) deu 8,7 s nesse roteiro e 21,7 s com tudo novo. A meta de reduzir 50% do tempo não vem do teclado: o web ganha em sequência e em lote (Recentes, Mais usados, ações em várias OS).

## Comportamentos

- **Tempo real:** a lista e a OS aberta se atualizam sozinhas para quem vê valores. Se outra pessoa mudou o que está em edição, aparece aviso e nada é sobrescrito (`409` com a versão nova).
- **Sem conexão:** faixa "Sem conexão. O que você digitar não será salvo." no topo; gravação falha com frase, nunca fica numa fila que parece feita. Offline completo fica no celular.
- **Sair:** computador da oficina é compartilhado. Sair pede confirmação e apaga o cache do navegador.
- **Foto:** escolher, colar ou arrastar. Câmera fica no celular.
- **Impressão:** folha própria, no tema claro, sem navegação (`@media print`). O PDF da OS é o mesmo do app, montado no navegador.

## Idiomas

pt, en e es, com as mesmas chaves do app quando o sentido é igual (`lib/l10n/app_*.arb`) e as do web em `src/i18n/web_*.json`. Moeda, datas e fuso seguem o país da empresa, não o idioma. Rótulos do ramo ("Veículo", "Aparelho") vêm do segmento, com a mesma prioridade do app.

## Checklist de tela nova

- [ ] Responde uma pergunta no topo, com no máximo um botão amarelo por área
- [ ] Funciona só com teclado, com foco visível e ordem lógica
- [ ] URL reabre o mesmo estado e respeita a permissão (`meta.access`)
- [ ] Estados vazio, erro e carregando cobertos
- [ ] axe sem violação em claro e escuro (`e2e/a11y.spec.ts`)
- [ ] Testada a 200% de zoom, em pt, en e es, e abaixo de 40 rem
- [ ] Linha na `docs/web-app/parity-matrix.yaml` atualizada
