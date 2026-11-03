# WEB_APP_DESIGN.md

## Visão Geral

Padrão visual e de interação do app web do PraticOS. Vale para toda tela autenticada no navegador. O app móvel segue `docs/APP_DESIGN_SYSTEM.md`, e o site institucional segue `firebase/hosting/design.md`.

A ideia em uma frase: **a mesma ordem de serviço do site, em forma de ferramenta de mesa.** Papel claro, tinta grafite, réguas e números em mono, com a clareza de produto do app. Nada de Cupertino e nada de layout de marketing.

Status: proposta, junto com `docs/web-app/ADR-001-web-architecture.md`. Vale para qualquer das opções de arquitetura.

## O que vem de cada lugar

| Vem do app (regra de produto) | Vem do site (identidade) | Só existe na mesa |
|---|---|---|
| Uma pergunta por tela, um botão azul | Tokens de `tokens.css` | Mestre-detalhe |
| Português do dia a dia, sem sigla | IBM Plex Sans, IBM Plex Mono e Archivo | Tabelas densas com seleção |
| Mostrar só o que o registro tem | Réguas em vez de cartões e sombras | Atalhos e paleta de comandos |
| Status: ponto + texto, nunca selo | Azul como sinal, sem gradiente | URLs compartilháveis e várias abas |
| Atrasada em `danger`, com texto em negrito | Sucesso silencioso, sem confete | Arrastar, sempre com alternativa |

## Regras

1. **Uma pergunta por tela, respondida no topo.** A tela da OS diz "Falta receber R$ 166". A lista diz "12 em aberto · 2 atrasadas".
2. **Um botão azul por área de trabalho.** A lista e o painel de detalhe aberto são áreas separadas, mas o painel só tem azul se houver próximo passo. Seleção em lote troca o azul da lista pela ação do lote.
3. **Tudo se faz pelo teclado.** Nenhuma ação depende do mouse. Arrastar sempre tem alternativa com um clique ou tecla (WCAG 2.5.7).
4. **Toda tela tem URL.** OS, cliente, filtro e aba aberta ficam na URL. Copiar o endereço e abrir em outra aba leva ao mesmo lugar, sujeito à permissão de quem abriu.
5. **Permissão é igual à do app.** Quem não pode não vê a ação. O servidor confere de novo, e a URL direta também é barrada.
6. **Mostrar só o que existe.** Coluna vazia em toda a página não aparece. Recurso ocasional fica no menu "…" ou na paleta.
7. **Sem editar em modo.** Cada campo abre seu editor no lugar. Não há botão "Editar".
8. **Salvar é claro.** Edição no lugar salva ao sair do campo e mostra "Salvo" discreto. Alteração em dinheiro ou situação nunca salva por engano: pede Enter e pode ser desfeita.
9. **A IA não mexe em dinheiro.** Nunca recebe, cancela ou apaga sozinha.
   - **Em um registro:** segue o app. Faz, marca com ✦ e oferece "Desfazer".
   - **Em vários registros:** pergunta antes. Mostra a lista do que vai mudar e só aplica com confirmação.
10. **Cor nunca sozinha.** Status, erro e seleção sempre têm texto ou ícone.
11. **Texto sem reticências em nome e valor.** Em tabela, a linha quebra. Só descrição longa pode ser cortada, com o texto completo disponível no detalhe.

A regra 9 consolida duas formulações: o app aplica na hora, com desfazer, e o brief do web diz que a IA pergunta antes. Em lote, desfazer não basta.

## Tokens

Fonte única: `firebase/hosting/src/css/tokens.css`. O azul já é o mesmo: `--color-accent` (`oklch(52% 0.14 250)`) dá `#116BB5`, igual a `AppColors.accent`. Todo cliente web importa esse arquivo, sem cópia à mão.

| Papel no app | Token web | Claro | Escuro |
|---|---|---|---|
| `background` | `--color-paper` | `#F9F6F2` | `#0C1015` |
| `surface` | `--color-card` | `#FDFCFA` | `#151A1F` |
| `secondaryFill` | `--color-paper-2` | `#F1EEE9` | `#13181D` |
| `text` | `--color-ink` | `#131920` | `#EFECE8` |
| `textSecondary` | `--color-muted` | `#43484F` | `#B3B8BE` |
| `separator` | `--color-rule` | `#D4D1CA` | `#2E333A` |
| `accent` / `accentText` | `--color-accent` | `#116BB5` | `#6CB2EC` |
| `accentSoft` | `--color-accent-soft` | `#D5EBFE` | `#192F46` |
| `success` | `--color-success` | `#1D7D3E` | `#69C27E` |
| `danger` | `--color-danger` | `#C93029` | `#EF675A` |

Contraste medido com as fórmulas de OKLCH e WCAG. Três ajustes são necessários, porque o site foi desenhado para títulos e não para tabelas:

| Problema | Medido | Ajuste |
|---|---|---|
| `--color-warning` como texto no claro | 2,56:1 sobre papel | Token novo `--color-warning-text`, `#974D00` no claro e `#ECA851` no escuro (os do app). `--color-warning` fica só no ponto de status |
| `--color-rule` como borda de campo | 1,42:1 (WCAG 1.4.11 pede 3:1) | Token novo `--color-control-border`, usando `--color-neutral`. Régua continua decorativa |
| `--color-success` sobre `--color-paper-2` | 4,48:1 | Status fica sobre `--color-paper` ou `--color-card` |
| `--color-danger` sobre `accent-soft` | 4,35:1 no claro, 4,4:1 no escuro | Linha selecionada usa `accent-soft` e todo texto em `ink`. Atrasada mantém ponto e negrito |

`--color-marker` não entra nas telas autenticadas. A marcação da IA é ✦ azul, como no app.

### Divergência do `firebase/web`

Hoje `firebase/web` usa Inter e DM Sans, `#2563EB`, selos coloridos e outro significado de cor: orçamento azul e aprovada verde, enquanto o app usa orçamento cinza e aprovada azul.

- Trocar as fontes e `brand.primary` por tokens compartilhados, com a Tailwind lendo as variáveis CSS.
- Trocar selos por ponto + texto, com o mapa de cor do app.
- Fazer em PR próprio, antes das telas novas. `/q` e `/pro` são vistas por clientes finais, então entram com comparação visual.
- Manter `/admin` por último, por ser uso interno.

## Tipografia

| Uso | Fonte | Tamanho | Observação |
|---|---|---|---|
| Título da página | Archivo 700 | 22 | Só um por página. Sem escala de display |
| Título do painel | IBM Plex Sans 600 | 18 | Cliente da OS |
| Corpo e linha de tabela | IBM Plex Sans 400 | 15 | Padrão |
| Rótulo e cabeçalho de coluna | IBM Plex Sans 600 | 13 | Sentence case, `--color-muted`. O mono em caixa alta do site não entra na ferramenta |
| Número, valor, placa e nº da OS | IBM Plex Mono 400/500 | 14 | Tabular, sempre via formatação de locale |

O corpo é 15, e não 19 como no app, porque na mesa a pessoa fica mais longe do limite de toque e precisa ver mais linhas. Quem tem a vista cansada usa o zoom do navegador: a tela funciona até 200% (WCAG 1.4.4) e até 400% em coluna única (1.4.10). Tudo em `rem`, nunca em `px` fixo para texto.

Fontes auto-hospedadas, com `font-display: swap` e subset latino. Só IBM Plex Sans é pré-carregada, para proteger o LCP.

## Densidade e medidas

| Item | Compacto (padrão com mouse) | Confortável |
|---|---|---|
| Linha de tabela (altura mínima) | 36 px | 44 px |
| Campo | 36 px | 44 px |
| Botão principal | 40 px | 44 px |
| Alvo mínimo | 24 px (WCAG 2.5.8) | 44 px |

Em tela de toque (`pointer: coarse`), começa em Confortável. A escolha fica por pessoa. Margens usam a escala de `tokens.css`. Cantos: 6 px, sem pílula. Sombra só em camada flutuante (paleta, menu).

## Estrutura da tela

```
┌────────┬──────────────────────┬──────────────────────────┐
│ Início │ 12 em aberto · 2 atr.│ OS 186 · Paulo Nunes     │
│ Agenda │ [Filtros]   [Nova OS]│ Fiat Uno · ABC-1D23      │
│ Financ.│──────────────────────│ ● Em andamento · Fica    │
│ Client.│ OS  Cliente  Total   │   pronto hoje, 17:00     │
│ Catál. │ 186 Paulo    R$ 166 ◄│ [Marcar como pronta]     │
│        │ 185 Ana      R$  80  │ Serviços e peças         │
│ Perfil │ 184 Bruno    R$ 310  │ ...                      │
└────────┴──────────────────────┴──────────────────────────┘
 Navegação     Lista (mestre)        Detalhe (no mesmo lugar)
```

- **Navegação lateral:** mesma ordem das abas do app, Início, Agenda, Financeiro. Clientes e Catálogo ficam logo abaixo, porque na mesa há lugar. Equipe e ajustes ficam em Perfil. Colapsa em ícones com texto acessível.
- **Mestre-detalhe a partir de 1100 px.** Abaixo, a lista ocupa a tela e o detalhe abre como página própria, com a mesma URL.
- **O painel não é camada:** o foco fica na lista, e `J`/`K` trocam o que o painel mostra. `Enter` leva o foco para o painel. Abaixo de 1100 px, o foco vai para o título da página aberta.
- **Largura máxima da leitura:** 72ch no detalhe. Tabela usa toda a largura.
- **Mobile no navegador:** não é alvo. Funciona em coluna única, com aviso para usar o app.

### Zonas do detalhe da OS

Mesma ordem do app: cabeçalho (cliente, veículo, situação e uma frase), próximo passo, "O que o cliente pediu", "Serviços e peças" com total como recibo, fotos, comentários, checklists e detalhes.

## Componentes

| App | Web | Muda o quê |
|---|---|---|
| `AppListRow`, lista plana | `DataTable` | Linhas semânticas (`table`), paginação de 100 linhas, cabeçalho fixo, ordenação. Virtualizar esconde linhas do Ctrl+F e da impressão, então só vale com busca própria |
| `PickerScaffold` (tela de escolher) | `Combobox` | Escolher continua sendo pesquisa, mas no lugar, digitando. Campo vazio já mostra Recentes e Mais usados, como no app. Busca pelo início de cada palavra. "+ Cadastrar “texto”" no fim, ✓ no atual, "Nenhum …" no topo |
| `FormSheet` | `Drawer` à direita | Cadastro novo abre por cima da lista. `Esc` fecha e pergunta antes de descartar; `Ctrl+Enter` salva de qualquer campo. Rodapé não fica fixo em tela baixa, para não cobrir o foco |
| `showPullDownMenu` | `Menu` | Mesmos grupos, destrutivas no fim, com setas e letras |
| `CupertinoAlertDialog` | `Dialog` | Foco preso, `Esc` cancela, botão padrão nunca é o destrutivo |
| `AppGlass` | Não existe | Sem vidro na web |
| `AssistantBar` (Foto/Falar) | Barra do assistente | Colar imagem, arrastar arquivo, digitar. Microfone onde o navegador deixar |
| `EmptyState`, `ErrorState`, `LoadingState` | Iguais | Mesmas frases, vindas das mesmas chaves de tradução |

`Combobox` segue o padrão ARIA com `aria-activedescendant`. `DataTable` usa `grid` só quando houver edição por célula. Nos dois casos, a tabela nativa continua sendo a base, para Ctrl+F, seleção de texto e impressão funcionarem.

## Teclado

| Tecla | Ação | Onde |
|---|---|---|
| `Ctrl/⌘ K` | Paleta de comandos e busca global | Sempre |
| `N` | Nova OS | Fora de campo |
| `/` | Filtrar a lista atual | Fora de campo |
| `J` / `K` ou `↓` / `↑` | Próxima ou anterior | Lista |
| `Enter` | Abrir no painel | Lista |
| `Ctrl/⌘ Enter` | Abrir em nova aba (com mouse: `Ctrl`-clique) ou salvar formulário | Lista, formulário |
| `Espaço` | Selecionar a linha | Lista |
| `A` | Adicionar serviço ou peça | OS aberta |
| `C` / `V` | Trocar cliente / veículo | OS aberta |
| `D` | Agendar, aceitando texto curto como `sex 14` | OS aberta |
| `M` | Mandar ao cliente | OS aberta |
| `F` | Anexar foto | OS aberta |
| `S` | Trocar situação | OS aberta |
| `R` | Receber. Já traz as outras OS em aberto do cliente | OS aberta ou linha da lista |
| `Esc` | Fechar a camada de cima | Sempre |
| `?` | Lista de atalhos | Fora de campo |

Regras:

- Tecla simples só age fora de campo de texto. Ajustes tem "Desligar atalhos de uma tecla" (WCAG 2.1.4).
- Nada captura `Ctrl+F`, `Ctrl+P`, `Ctrl+L`, `Ctrl+T`, `Ctrl+W` e nem as setas do leitor de tela. `Ctrl+P` imprime a OS aberta com folha própria.
- Foco visível usa `--color-focus`, com contorno de 2 px, sem animação. Barra fixa nunca cobre o foco (2.4.11).
- Abrir camada leva o foco para dentro; fechar devolve o foco para quem abriu.
- Mudança de lista avisa o leitor de tela por região `aria-live`, com a contagem.

## Nova OS em menos de 45 segundos

Roteiro de referência: cliente já cadastrado, um serviço do catálogo e valor do catálogo. A OS abre em `Drawer`, com o cursor em "Cliente" e os recentes já listados.

| Passo | Teclas |
|---|---|
| Abrir | `N` |
| Cliente | `↓` nos recentes, ou digitar, e `Enter` |
| Veículo ou aparelho | `Enter` no sugerido, ou `Tab` para pular |
| Serviço | digitar, `Enter`. Já entra com o valor do catálogo |
| Outro item | repetir |
| Salvar | `Ctrl+Enter` de qualquer campo |

Valor diferente: `Tab` a partir do item e digitar.

Modelo KLM, não teste com pessoas: 8,7 s nesse roteiro e 21,7 s com tudo novo, ambos abaixo de 45 s. Com 1.500 clientes, o nome exige 10 teclas em média. Com 50 clientes ou menos, 3. Detalhes em `docs/web-app/keyboard-flows.md`.

**A meta de 50% não vem do teclado.** O app já é curto, e as decisões são as mesmas. No modelo, nenhum dos 18 cenários reduz 50% do tempo, 7 ganham, 2 empatam e 9 perdem. O web ganha em sequência e em lote. Para ganhar mais é preciso tirar decisões: recentes, repetir OS, lançar várias linhas.

**Busca na maior empresa:** a maioria dos clientes citados nas OS dela não tem cadastro em `customers`. A combobox precisa buscar também o que está gravado na OS, para evitar duplicar.

## Telas de mesa

Por ordem de evidência de uso:

1. **Lista de OS com seleção e ações em lote.** Filtros na URL. Mudar situação, responsável e imprimir em lote.
2. **Receber vários.** `R` já traz as OS em aberto do cliente, e selecionar linha por linha fica para clientes diferentes. O uso real tem recebimento em lote, e o app já marca todas do cliente de uma vez.
3. **Busca global e paleta.** OS, cliente, placa, telefone e comando no mesmo campo.
4. **Importação de clientes e catálogo.** Mostra o que vai entrar antes de gravar.
5. **Agenda da equipe.** Coluna por pessoa, arrastar para reagendar, com "Mudar data" no menu da OS.
6. **Quadro de OS.** Prioridade baixa: a maior empresa quase não usa o fluxo de situação.
7. **Relatórios cruzados, impressão em lote e IA em seleção.** Depois de haver demanda.

## Comportamentos

- **Tempo real:** a lista e a OS aberta atualizam sozinhas. Se outra pessoa mudou o que está em edição, aparece aviso e nada é sobrescrito.
- **Sem conexão:** faixa fixa "Sem conexão. O que você digitar não será salvo". Gravação fica bloqueada. Offline completo fica no celular.
- **Sair:** computador da oficina é compartilhado. Cache persistente desligado por padrão, "Sair de todos os aparelhos" no perfil, bloqueio por inatividade configurável.
- **Foto:** colar, arrastar ou escolher arquivo. Para câmera, QR "Continuar no celular" abre a mesma OS no app.
- **Impressão:** folha própria, a partir do tema claro, sem navegação.
- **Movimento:** 160 a 240 ms, só em hover, foco e camada. `prefers-reduced-motion` desliga.

## Idiomas e temas

pt, en e es, com as mesmas chaves do app quando o sentido for igual. Moeda segue o país da empresa, como proposto em `docs/web-app/business-rules-map.md`. Tema claro é o padrão, escuro segue o sistema ou a escolha salva (`data-theme`). Labels de segmento usam `/segments`, com a mesma ordem de prioridade do app.

## Checklist de tela nova

- [ ] Responde uma pergunta no topo, com no máximo um botão azul por área
- [ ] Funciona só com teclado, com foco visível e ordem lógica
- [ ] URL reabre o mesmo estado e respeita a permissão
- [ ] Estados vazio, erro e carregando cobertos
- [ ] axe sem violação em claro e escuro
- [ ] Testada em 200% de zoom, em pt, en e es
- [ ] Linha na `docs/web-app/parity-matrix.yaml` atualizada
