# DESIGN_TOKENS.md

## Visão Geral

O tema **Campo** é a identidade visual do PraticOS nos três lugares: o site, o app web (`firebase/webapp`) e o app do celular. Este documento diz o que é igual nos três e o que muda em cada um. Os detalhes de cada plataforma continuam nos documentos dela:

| Superfície | Documento da plataforma | Fonte das cores no código |
|---|---|---|
| Site | `firebase/hosting/design.md` | `firebase/hosting/src/css/tokens.css` |
| App web | `docs/WEB_APP_DESIGN.md` | `tokens.css` + `firebase/webapp/src/styles/app.css` |
| App do celular | `docs/APP_DESIGN_SYSTEM.md` | `lib/theme/app_colors.dart` |

A regra em uma frase: **o site é bege porque vende; o sistema é branco porque trabalha. As cores da marca são as mesmas.**

**Status:** aprovado no protótipo em 08/11/2026. O site já está no tema; a paleta do app foi aplicada (cores e componentes compartilhados, não o novo layout da Início). O web recebe a camada "sistema" depois. Cada item abaixo diz onde já vale.

Protótipo: https://claude.ai/artifact/NfHsv1Ge52LXGdpd9ZYihz, página "Tema Campo" (OS aberta, Nova OS, Financeiro, Início, telas da etapa e "Web: fundo bege ou branco?"). A Início tem spec própria: `docs/superpowers/specs/2026-11-08-inicio-lista-os-design.md`.

## As duas camadas

```
Camada 1, marca        marinho · amarelo · azul · cores de situação   → site, web e app
Camada 2, superfície   site (vitrine)          sistema (ferramenta)
                       papel bege, Outfit,     fundo branco, fonte do sistema,
                       faixas e réguas         linhas finas, cinza do Mail
```

### Camada 1: marca (igual nos três)

| Papel | Claro | Escuro | Token CSS | `AppColors` | Uso |
|---|---|---|---|---|---|
| Marinho | `#07294F` | (faixa continua marinho) | `--color-navy` / `--color-ink` | `brandNavy` / `text` | Texto principal, faixas, barra lateral do web, "+" das abas, filtro escolhido |
| Amarelo de ação | `#FFC921`, texto `#07294F` | igual | `--color-marker` / `--color-marker-ink` | **novo** `action` / `onAction` | O botão principal da tela, o ✓ de salvar, o "OK" do modo Selecionar |
| Azul da marca | `#1467C2` | `#7DB6F2` | `--color-accent` | `accent` / `accentText` | Link, foco, linha marcada e aba atual. Nunca botão cheio nem filtro escolhido |
| Atrasada | `#C93029` | `#FF7A6B` | `--color-danger` (`--color-danger-text` no web) | `danger` | Problema: atraso, erro, ação destrutiva |
| Parada e falta receber (texto) | `#975800` | `#F0B45A` | `--color-warning-text` (web) | `warning` | Texto de aviso: "Parada", cifrão de falta receber, título da seção Paradas |
| Em andamento (ponto) | `#D98B09` | `#F0A93B` | `--color-warning` | **novo** `warningDot` | Só a bolinha de "em andamento" e das etapas |
| Concluída | `#1D7D3E` (ponto), `#136239` (texto) | `#65C67D` | `--color-success` / `--color-success-ink` | `success` | Pago, concluído. Nunca em botão |

Os hex do claro e do escuro são os do protótipo. No CSS a fonte da verdade continua sendo `tokens.css` (em oklch). Ao aplicar no app, conferir os pares com o teste de contraste (`test/theme/`).

### Camada 2: cada superfície

| | Site (vitrine) | Sistema: web e app (ferramenta) |
|---|---|---|
| Fundo | Papel bege `--color-paper` | **Branco** (escuro `#0C1015`) |
| Formulário e sheet | Cartão creme sobre papel | Cartão branco sobre cinza-quente `#F2F0EC` (escuro: `#1D2228` sobre `#13181D`), sem contorno |
| Bege | É o fundo | Só apoio: busca, "Lista / Quadro", cabeçalho de tabela, linha com o mouse em cima (`#F1EEE7` / `#F7F5F0`) |
| Separação | Réguas, inclusive a marinho grossa | Linhas finas `#E3E0DA` (escuro `#2A3038`). Sem régua marinho |
| Títulos | Outfit 800 | App: fonte do sistema, título em negrito (700) e nomes em semibold (600). Web: IBM Plex Sans 700. Nunca 800 |
| Texto | DM Sans | App: fonte do sistema. Web: IBM Plex Sans |
| Números | IBM Plex Mono | Mesma fonte do texto, com `tabular-nums` |
| Vidro | Nunca | Só na navegação do app (abas, botões do topo, sheets pequenas), sem sombra e com contorno fino |
| Fotos e faixas | Sim | Não |

## Papéis de texto e superfície do sistema

| Papel | Claro | Escuro | Aumentar contraste (claro) | `AppColors` | Web |
|---|---|---|---|---|---|
| Fundo | branco | `#0C1015` | igual | `background` | `--color-paper` sobrescrito em `app.css` |
| Fundo agrupado | `#F2F0EC` | `#13181D` | igual | `groupedBackground` | idem |
| Cartão | branco | `#1D2228` | igual | `surface` | `--color-card` |
| Preenchimento de apoio | `#F1EEE7` | `#1D2228` | igual | `secondaryFill` | `--color-paper-2` |
| Texto principal | `#07294F` | `#F1EEE8` | igual | `text` | `--color-ink` |
| Texto secundário | `#6B7178` (app: `#646A71`) | `#B4BAC2` | `#3A3F45` | `textSecondary` | `--color-muted` |
| Texto terciário | `#8A8F96` | `#8A9099` | `#5E636A` | **novo** `textTertiary` | **novo** `--color-faint` |
| Linha | `#E3E0DA` | `#2A3038` | mais escura | `separator` | `--color-rule` |
| Seleção (fundo da linha marcada) | `#EAF2FB` | `#16304A` | igual | `accentSoft` | `--color-selected` |

## Regras de cor

1. **Amarelo é a ação principal, uma por tela.** Botão principal (58 de altura no app), ✓ de salvar e "OK" de sair do modo Selecionar. No fundo branco o amarelo tem pouca borda (1,4:1), então leva contorno fino `rgba(7,41,79,.28)`.
2. **Azul é link e seleção.** Nunca botão cheio. Círculo marcado, fundo da linha selecionada, aba atual e "+ Adicionar". O filtro escolhido não é azul: é marinho (regra 3).
3. **Marinho é o resto.** Texto, ações da barra de baixo ("Mudar etapa", "Mudar situação"), "+" das abas, botões do topo e o filtro escolhido (fundo marinho, texto branco; no escuro inverte para creme com texto marinho), como nas abas do site. Pílula no app, cantos de 6 px no web.
4. **Cor nunca sozinha.** Todo aviso tem texto ou ícone: "Atrasada 2 dias", "Parada", cifrão com nome para o VoiceOver.
5. **Bege no sistema é só apoio**, nunca fundo de tela.

## Situação da OS

A bolinha mostra a situação; o problema vem em texto.

| Situação | Ponto (`OrderStatusStyle.dotColor`) | Texto |
|---|---|---|
| Orçamento | cinza (`textSecondary`) | cinza |
| Aprovada | azul (`accentText`) | cinza |
| Em andamento (e qualquer etapa) | âmbar (`warningDot`) | cinza, com o nome da etapa em `text` quando houver |
| Concluída | verde (`success`) | cinza |
| Cancelada | cinza (`textSecondary`; vazio no protótipo) | cinza |

No app vale desde a troca da paleta: cabeçalho da OS, Agenda e histórico de OS (cliente e veículo). A lista da Início ganha esse formato com a spec dela.

Problemas não são situação, aparecem junto dela:

- **Atrasada:** "● Pintura · **Atrasada 2 dias**", em vermelho e negrito. A bolinha continua com a cor da situação.
- **Parada:** "● Aprovada · **Parada**", em âmbar escuro e negrito.
- **Falta receber:** cifrão âmbar colado à esquerda do valor. O valor em si continua cinza.
- **Títulos de seção:** "Atrasadas" em vermelho, "Paradas" em âmbar, os demais em cinza. Todos com ›.

Isso troca a regra antiga (ponto e texto em `danger` só com "Atrasada 2 dias"): agora a situação nunca some.

## Padrões que se repetem

- **Linha de OS:** cliente em semibold e valor à direita (sem ",00"), numa linha só; embaixo, em cinza terciário, veículo · serviço · observação em até 2 linhas. Empresa sem valores mostra "nº 1042" no lugar do valor. Detalhes na spec da Início.
- **Seções tocáveis:** o título abre a lista da seção com "Selecionar".
- **Modo Selecionar:** círculos azuis à esquerda, alças ≡ à direita só onde há ordem (etapas), "OK" amarelo, ações marinho na barra de baixo (cinza sem nada marcado).
- **Aviso com Desfazer:** bloco marinho (escuro: cinza-azulado) com "Desfazer" em amarelo.
- **Bloco "próximo passo" (Financeiro):** marinho com botão amarelo.

## Contraste

| Par | Contraste | Decisão |
|---|---|---|
| Texto terciário `#8A8F96` no branco | 3,3:1 | Só em apoio (serviço, observação, valor). Com "Aumentar contraste": `#5E636A`. No web fica `#6B7178` (4,9:1), porque o teste axe exige 4,5:1 |
| Texto secundário `#6B7178` no branco | ~5:1 | Passa no branco; no `#F2F0EC` dá 4,3:1, por isso o app usa `#646A71` (4,8:1) |
| Âmbar `#975800` no branco | ~6:1 | Passa |
| Marinho no amarelo | alto | Passa |
| Borda do amarelo no branco | 1,4:1 | Contorno fino |
| Verde em texto | precisa de `#136239` | `#1D7D3E` só no ponto |

## Como aplicar

- **App:** trocar os valores de `AppColors`, criar `action`/`onAction`, `textTertiary` e `warningDot`, aposentar o `marker` amarelo-claro legado e a fonte continua a do sistema. Rodar `fvm flutter test test/theme/`. Atualizar `docs/APP_DESIGN_SYSTEM.md` ao terminar.
- **Web:** **não mudar `tokens.css`** (o site muda junto). Sobrescrever só os tokens de superfície em `firebase/webapp/src/styles/app.css` (fundo branco, linha fina, `--color-faint`) e trocar a régua marinho grossa do cabeçalho da lista por linha fina. Atualizar `docs/WEB_APP_DESIGN.md` ao terminar.
- **Site:** nada muda no visual. Quando o app mudar de cara, refazer as fotos e telas do app mostradas no site.
- **Mais tarde:** um arquivo único de cores gerando `app_colors.dart` e o CSS do web, conferido pelo check "Parity" do CI.

| Item | Site | Web | App |
|---|---|---|---|
| Camada da marca | aplicado | aplicado | aplicado |
| Fundo branco e linhas finas | não se aplica | aplicado | aplicado |
| Texto terciário | não se aplica | aplicado | papel criado (`textTertiary`); telas usam aos poucos |
| Situação + problema juntos | não se aplica | aplicado | OS, Agenda e histórico; falta a Início |
| Linha de OS e seções da Início | não se aplica | falta | falta |
