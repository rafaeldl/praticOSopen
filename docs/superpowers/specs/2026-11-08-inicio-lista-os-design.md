# Início: lista de OS com seções, etapas e seleção em lote

**Data:** 2026-11-08 · **Status:** aprovado no protótipo, não implementado · **Protótipo:** canvas https://claude.ai/artifact/NfHsv1Ge52LXGdpd9ZYihz, página "Tema Campo", fileira "Início: lista de OS" (`inicio-padrao`, `inicio-busca`, `inicio-sem-valores`, `etapa-pintura`, `etapa-pintura-selecionar`, `etapa-escolher`, `etapa-pintura-feito`).

Revê a parte "Início" de `docs/APP_DESIGN_SYSTEM.md` (lista sem grupos, busca sempre visível, ponto de status na linha). Etapas: `docs/WORK_STAGES.md`. As cores do protótipo são as do tema Campo, que ainda está em avaliação; o layout vale com qualquer paleta.

## Problema

A linha da OS chegou a ter nove coisas (ponto, nome, avisos, valor, setinha, veículo, placa, serviço, situação), e a pessoa não sabia para onde olhar. A situação só aparecia pela cor do ponto, as etapas do serviço (que o web já mostra em colunas) não apareciam no celular, e não havia como mudar a situação ou a etapa de várias OS de uma vez.

## Decisões

### Topo

1. **A Início abre sem busca e sem filtros.** Ficam o sino e o perfil, o título grande e uma frase com o filtro atual e o que pede atenção: "**Em aberto** · 2 atrasadas, 2 paradas". Puxar a lista para baixo mostra a busca e os filtros, como a busca escondida do Mail e dos Ajustes.
2. **Com a busca à vista, as abas e o "+" somem** e a lista usa a tela até embaixo. Voltam quando a busca se esconde de novo.
3. **Filtros:** Em aberto, Orçamentos, Concluídas, Todas. "Paradas" deixa de ser filtro porque vira seção.

### Seções (filtro "Em aberto")

4. **A lista é agrupada na ordem do quadro do web**, do que pede ação primeiro:
   1. **Atrasadas** (título em `danger`), vindas de qualquer situação.
   2. **Paradas** (`Order.onHold`).
   3. **Aprovadas**.
   4. **Uma seção por etapa** (`Company.workStages`, na ordem configurada). Sem etapas, uma seção só, **Em andamento**.
5. **Seção vazia some.** Sem atrasadas, a lista começa em Paradas ou na próxima.
6. **Título de etapa abre a fila da etapa** ("Pintura · 3 ›", em `accentText`). O número conta **todas** as OS da etapa, inclusive as que aparecem em Atrasadas ou Paradas, para bater com a fila.
7. **OS em Atrasadas ou Paradas diz onde está**: o texto cinza começa com a situação ou a etapa em `textPrimary` ("**Pintura** · …", "**Aprovada** · …"). Nas outras seções o título já diz.

### Linha da OS

8. **Duas partes, como o Mail:**
   - Em cima: cliente (semibold, `textPrimary`) e, à direita, o valor sem centavos ("R$ 600") e a setinha.
   - Embaixo, em cinza terciário: veículo · serviço: observação, em até 2 linhas, com "…" no fim. Serviços repetidos agrupam ("5× pintura").
9. **Sem ponto de status e sem placa na lista.** A situação está na seção; a placa continua na busca e na OS aberta.
10. **Falta receber:** símbolo de cifrão (`dollarsign.circle`, cor `warning`) colado à esquerda do valor, com nome "Falta receber" para o VoiceOver. É o único sinal da linha.
11. **Empresa sem valores** (`Company.useFinancial` desligado): o número da OS ("nº 1042") no lugar do valor, sem cifrão.
12. **Cliente e veículo não quebram no tamanho padrão** (terminam em "…"). Nos tamanhos de acessibilidade quebram, e o valor e o cifrão descem para baixo do nome, como já faz o `AppListRow`.

### Fila da etapa

13. **Tela própria** (empurrada), com voltar, título grande com o nome da etapa e uma frase ("3 carros na fila, 1 parado. O primeiro está aqui desde ontem.").
14. **Fila numerada** na ordem de `stage.rank`, com todas as OS da etapa. Cada linha igual à da Início, mais "Na pintura desde ontem" (`stage.since`). Atrasada começa com "**Atrasada**" em `danger`; parada com "**Parada** · motivo" em `warning`.
15. **"…" no topo:** imprimir a folha da etapa, como no web.

### Selecionar várias

16. **Botão "Selecionar"** no topo da fila da etapa. No modo:
    - Círculo à esquerda de cada linha (marcada: `accent` com ✓ e fundo `accentSoft`) e alças ≡ à direita para arrastar e mudar a ordem (grava `stage.rank`, como o web).
    - Topo: "Selecionar todas" à esquerda e "OK" em `accent` à direita.
    - No lugar das abas, uma barra de vidro com **Mudar etapa** e **Mudar situação**.
    - Tocar na linha marca ou desmarca; não abre a OS.
17. **Na Início**, segurar uma linha abre o menu do iPhone com "Selecionar", que entra no mesmo modo com a OS já marcada (sem alças, porque a Início não tem ordem manual).
18. **Mudar etapa / Mudar situação** abrem a tela de escolher (`pickOne`): "Para qual etapa?" (✓ na atual, "Nenhuma etapa" volta para Aprovada) e "Para qual situação?".
19. **Vale na hora**, com aviso opaco "Binho e TDS passaram para Polimento." e **Desfazer**. Concluir ou cancelar várias pede confirmação antes ("Concluir 3 OS?"), porque pode disparar cobrança ou nota.
20. **Quando parte não pode mudar** (permissão, OS mudada em outro aparelho), o aviso diz quantas mudaram e quais ficaram de fora.
21. **Mudar para uma etapa põe a OS em andamento**, na mesma chamada (`PUT /v1/app/orders/:id/stage`), como arrastar de Aprovado no web.

## HIG

- Lists and tables: "Keep item text succinct" e, para texto longo, "titles only, with content in a detail view".
- Typography: "Adjust weight, size and color as needed to emphasize important information and show hierarchy".
- Color: "Avoid relying solely on color"; por isso a situação saiu do ponto e foi para o título da seção.
- Typography (Dynamic Type): "Keep text truncation to a minimum as font size increases" e "consider stacking text above secondary items".
- Accessibility: com contraste abaixo de 4,5:1 (o cinza terciário, como no Mail), dar variante mais forte com "Aumentar contraste".

## O que muda no design system ao implementar

- `APP_DESIGN_SYSTEM.md`, parágrafo "Início": busca e filtros escondidos, seções, linha sem ponto, cifrão, nº da OS sem valores.
- Regra de reticências: passa a permitir "…" no nome do cliente e no veículo da lista no tamanho padrão (a OS aberta mostra tudo).
- Status na lista: sai o ponto; atrasada deixa de ser "ponto e texto em `danger`" na linha e vira seção.
- `AppColors`: papel de texto terciário (#8A8F96 no tema Campo) com variante de alto contraste.
