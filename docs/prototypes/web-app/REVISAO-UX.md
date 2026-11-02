# Revisão de UX do protótipo (2026-11-02)

**Situação:** os 5 itens P0, os 10 itens P1 e a linguagem foram aplicados no protótipo (`tests/ux-fixes.mjs`). P2 continua pendente. A sigla "OS" segue sem decisão.

**Correção do item 4:** o relatório original errou o sintoma. O protótipo não acompanhava o histórico: usava `replaceState` e não ouvia `popstate`, então Voltar saía do app em qualquer tela. O teste anterior viu outra coisa porque a rota nem tinha mudado.

Base: Apple HIG (design-principles, accessibility, layout, writing, inclusion, feedback, sheets, modality, gestures, split-views, toolbars, designing-for-ios, designing-for-macos), WCAG 2.2 e guia web.
A HIG é escrita para apps nativos. A adaptação para web é julgamento meu.

Método:
- Medição automática em 390, 320, 820 e 1366 px, mais texto a 200% (`tests/ux-audit.mjs`).
- Teste de comportamento (`tests/ux-beh.mjs`, `tests/ux-ver.mjs`, `tests/ux-ver2.mjs`).
- Usuário simulado por agente, 9 tarefas, 2 perfis, sem ver o código (`tests/persona/relatorio.md`).

Limites: nenhuma pessoa real, nenhum iPhone ou iPad real, VoiceOver não testado.
Os achados de usuário simulado marcados com (agente) não foram reproduzidos por mim. Os demais foram confirmados.

## P0: fazem a pessoa errar

| # | Problema | Evidência | Regra | Correção |
|---|---|---|---|---|
| 1 | Digitar preço soma ao valor antigo | Catálogo: clicar em 90,00 põe o cursor no meio; digitar 100 grava 91.000,00. Nova OS: campo vem com 0 e sem teclado numérico; 150 virou 1500 (agente) | "It's always best to help people avoid errors" | Selecionar tudo ao entrar no campo, máscara de dinheiro, `inputmode="decimal"` |
| 2 | Mudar a data não abre o campo | No celular o foco fica em BODY, então o teclado não sobe. O texto diz "Enter confirma". `OrderDetail.vue:31` recebe a ref já desembrulhada | "make sure you describe gestures correctly"; "Indicate when a gesture isn't available" | Corrigir o foco; seletor de data nativo e botão Salvar no toque. Vale para todos os campos que usam `edit()` |
| 3 | Três datas com nomes confusos | "Entrada", "Prazo" e "Fica pronta" na mesma OS; mudar "Entrada" não muda as outras | "Be clear. Use easily understood words" | Dois nomes claros: "Visita" (ou "Quando") e "Prometido para". Mudar a visita deve oferecer mudar o prometido |
| 4 | Voltar do navegador não fecha a tela | Com a OS aberta o endereço segue `#os`. Voltar troca a tela de trás e a OS continua aberta. Na Nova OS, idem. Quem entrou direto por um link sai do app sem aviso | "get confirmation before closing"; "support swipe-back" | Cada tela aberta entra no histórico; avisar se há dado digitado |
| 5 | Alvos pequenos onde mais se toca | Celular, tela da OS: Tirar 24×24, preço 20 de altura, Adicionar 62×20, data 22. Clientes: 22. Abaixo do padrão de 44 e do mínimo de 28 pt | "iOS, iPadOS 44×44 pt, mínimo 28×28 pt" | Área de toque de 44 com `::after`, sem mudar o visual |

## P1: confundem ou escondem

| # | Problema | Evidência | Correção |
|---|---|---|---|
| 6 | "Mandar ao cliente" só copia, mas a OS mostra "Enviado" | Estado falso depois de só copiar | Abrir o WhatsApp direto, ou mostrar "Copiado" até confirmar |
| 7 | Mudar valor com link já enviado não avisa | OS 1209: valor novo, link antigo (agente) | Avisar e oferecer reenviar |
| 8 | Tablet recebe a tela do computador | 820 px com toque: 38 alvos pequenos na lista e dicas de teclado (N, ⌘K, "Aperte ?") | Usar `pointer: coarse` para alvos grandes e esconder dicas de teclado |
| 9 | Duas ações amarelas | Computador com OS aberta: "Nova OS" e "Marcar como pronta" | Nova OS fica neutra com o painel aberto |
| 10 | "+" com dois sentidos | Em Clientes, o "+" do topo cria OS e o "+ Novo cliente" fica logo abaixo | Dar nome ao botão ou trocar o "+" conforme a tela |
| 11 | Texto a 200% quebra | Abas sobrepostas; Financeiro passa da largura (448 em 390; 1399 em 1366); cartão do Início corta o nome; filtro corta "Toda a equipe" | Abas só com ícone ou em duas linhas; quebrar a grade; "text enlargement of at least 200%" |
| 12 | Letra e botão menores que o app | Celular: corpo 15, secundário 12,5 a 13, botão 44. App: corpo 19, botão 58 | Celular com corpo 17 e secundário 15, botão principal 52 a 58 |
| 13 | Item sai sem confirmar e o Desfazer some em 7 s | Lixeira ao lado do preço; aviso some sozinho | Manter Desfazer até a próxima ação; "prefer explicit dismissal" |
| 14 | Pix já vem marcado ao receber | Quem recebeu em dinheiro precisa trocar (agente) | Lembrar a última forma ou não marcar nenhuma |
| 15 | Ajuste raro no topo de Notas | "Quando emitir" e "Mandar ao contador" antes da lista | Mover para o menu "…" |

### Linguagem
- "OS" aparece 170 vezes nas telas medidas, sem explicação. Regra do projeto: "sem siglas". Decisão: manter ou usar "Serviço".
- Trocar: "Entrada", "Para emitir", "Cliente abriu, ainda não", "O link de pagamento aberto será encerrado", "Cobrança marcada" (não diz se foi), "+ Cadastrar" para um serviço avulso.
- Padronizar: "há 2 dias" e "faz 4 dias".
- Tirar de quem usa toque: "Enter confirma", "Filtrar (aperte /)".
- Tirar: "OS criada em 69 s". É métrica nossa, não informação para a pessoa.

## P2: acabamento
- Título da aba é sempre "PraticOS no computador", mesmo no celular. Cada tela precisa do seu.
- Sem `prefers-contrast`. Em cores forçadas do sistema, somem os pontos de situação e o destaque do filtro e da aba escolhidos.
- Sheets: "Voltar" fecha o Novo cliente; a HIG usa Cancelar para fechar e Voltar para etapa anterior. Sem grabber nem arrastar para fechar.
- Botões desativados sem motivo: "Cadastrar" e "Usar o que colei". "Criar OS" já explica e é o modelo.
- Nome e telefone sem `autocomplete`; telefone com `type=text`.
- Seletor de Notas com 15 px: o Safari do iPhone dá zoom ao tocar. Os demais têm 16.
- "Criar OS" embaixo pode ficar atrás do teclado do iPhone. Não testado em aparelho. A regra do app é "✓" no topo à direita.

## O que já está bom
Sem rolagem lateral em 320 px; todos os campos com rótulo; redução de movimento; tema escuro; "Comece por aqui" e "Próxima cobrança"; confirmações que explicam a consequência; prévia da data; "Falta e-mail" e "Falta CEP" nas notas; "Criar OS" explica o que falta.

## Não se aplica à web
Barra de menus do Mac, SF Symbols, Liquid Glass e vibração.
