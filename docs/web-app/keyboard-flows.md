# Fluxos de teclado: velocidade do web contra o app

**Isto é modelo, não teste com pessoas.** Os tempos humanos saem de uma conta (KLM). O roteiro cronometrado com pessoas ainda precisa ser feito antes de prometer qualquer número.

Base: commit `fd9e64da`, 2026-10-31. Dados sintéticos no Firebase Emulator (projeto demo), com 10 mil OS, 1.500 clientes e 27 itens de catálogo. Protótipo descartável em Vite + Vue, fora do repositório.

## Resultado

| Meta | Resultado no modelo |
|---|---:|
| OS completa em menos de 45 s só no teclado | **Atingida:** 21,7 s no pior caso (cliente e veículo novos, valor digitado), com 0,09 s de máquina |
| Top 10 com 50% ou mais de redução de tempo | **Não atingida:** 0 de 18 cenários |
| Top 10 com 50% ou mais de redução de passos | **2 de 18:** ir para a OS seguinte e receber em sequência |

No tempo, 7 cenários ganham, 2 empatam e 9 perdem para o app. O desenho vence em sequência, não em tarefa isolada. Depois do redesenho o app já é curto: a busca abre com foco, o item entra com o valor do catálogo sem mais uma tela, e "Receber" já marca todas as OS do cliente. As decisões são as mesmas nos dois lados, e elas pesam mais que as teclas.

## Modelo

Igual nos dois lados:

- **Passo:** uma tecla ou um toque, a 240 ms. `Ctrl+X` conta 2.
- **Decisão:** 1,2 s para começar a tarefa e para cada campo preenchido ou opção escolhida.
- **Letras:** o web digita até o alvo ficar entre os 4 primeiros e usa `↓`. O app digita até o alvo ficar entre as 6 linhas acima do teclado.

Web: passos contados na execução real com Playwright, média de 5 rodadas (4 em T3a, por causa de um homônimo no sorteio). Só teclado. App: passos contados no código de `lib/screens`, sem execução.

Conferido no simulador iOS, sem salvar nada: o começo da Nova OS e o foco na busca de cliente, sem toque a mais. O restante do app segue a leitura do código.

## Tabela por tarefa

"Sensibilidade" não é a comparação principal. Troca só o lado do app para digitação de celular (333 ms por tecla) e 0,5 s por transição de tela. Serve para mostrar que o resultado depende muito disso.

| # | Tarefa | App: passos, s | Web: passos, s | Menos passos | Menos tempo | Sensibilidade | Máquina web |
|---|---|---:|---:|---:|---:|---:|---:|
| 1 | Abrir OS pela placa, recente | 4,4; 3,5 | 5,2; 3,6 | -18% | -6% | 11% | 34 ms |
| 1 | Ir para a OS seguinte | 2,0; 1,7 | 1,0; 1,4 | **50%** | 14% | 46% | 27 ms |
| 2 | Lançar serviço na OS aberta | 4,6; 3,5 | 6,8; 5,2 | -48% | -49% | -10% | 38 ms |
| 3 | Nova OS, cliente de 1 veículo | 16,5; 7,6 | 16,2; 8,7 | 2% | -15% | 25% | 61 ms |
| 3 | Nova OS, cliente recente | 9,8; 6,7 | 11,4; 8,3 | -16% | -24% | 21% | 55 ms |
| 3 | Nova OS, empresa com 50 clientes | 11,6; 6,9 | 10,4; 7,8 | 10% | -13% | 27% | 54 ms |
| 3 | Nova OS, 2+ veículos, valor digitado | 20,6; 10,9 | 18,2; 10,4 | 12% | 5% | 38% | 55 ms |
| 3 | Nova OS completa, tudo novo | 60,0; 22,8 | 55,4; 21,7 | 8% | 5% | 36% | 89 ms |
| 4 | Cadastrar veículo na OS aberta | 20,0; 8,4 | 20,0; 8,4 | 0% | 0% | 29% | 56 ms |
| 5 | Receber uma OS | 3,0; 3,1 | 2,0; 2,9 | 33% | 8% | 38% | 28 ms |
| 5 | Receber 3 OS do mesmo cliente | 4,0; 4,6 | 19,0; 8,2 | -375% | -79% | -35% | 64 ms |
| 5 | Receber 3 OS em sequência, clientes diferentes | 18,0; 12,7 | 6,0; 9,8 | **67%** | 23% | 55% | 96 ms |
| 6 | Trocar o cliente da OS | 6,4; 3,9 | 7,8; 4,3 | -22% | -9% | 20% | 46 ms |
| 6 | Cliente novo ao criar a OS | 27,8; 10,3 | 26,0; 9,8 | 6% | 4% | 34% | 29 ms |
| 7 | Mandar pelo WhatsApp | 3,0; 3,1 | 3,0; 3,1 | 0% | 0% | 24% | 20 ms |
| 8 | Anexar foto que já está no aparelho | 4,0; 4,6 | 3,0; 3,1 | 25% | 32% | 49% | 12 ms |
| 9 | Lançar peça na OS aberta | 3,2; 3,2 | 4,6; 4,7 | -44% | -48% | -10% | 30 ms |
| 10 | Agendar dia e hora | 5,0; 6,0 | 13,0; 6,7 | -160% | -12% | 10% | 41 ms |

"Máquina web" é o tempo do script no emulador local, sem rede real. Não entra na conta humana. O desconto, parte da tarefa 5, não foi medido.

## Onde não chega a 50%, e por quê

- **Abrir OS:** o app gasta poucas letras porque filtra só as OS carregadas. A OS antiga não aparece lá. No web, a busca alcança todas, e esse caso não tem comparação.
- **Lançar item:** o web pede um passo de valor que o app não tem.
- **Nova OS:** as mesmas decisões nos dois lados. Com 1.500 clientes, o nome exige muitas letras.
- **Receber do mesmo cliente:** o app marca todas de uma vez. Selecionar linha por linha no web perde feio.
- **Veículo e cliente novos:** digitar o mesmo texto custa o mesmo no modelo. O ganho real do teclado físico só aparece na sensibilidade.
- **WhatsApp:** o último passo é do WhatsApp nos dois lados.
- **Foto:** o modelo assume a foto já no computador. Ela nasce no celular, então o caso real favorece o app. Vale o QR "Continuar no celular".
- **Agendar:** a data digitada custa mais teclas que dois arrastes na roda do app.

## Ajustes testados no protótipo

| Ajuste | Efeito no modelo |
|---|---|
| `Enter` no item adiciona com o valor do catálogo; digitar o valor fica para quando precisa | Lançar serviço: de -49% para -8%. Lançar peça: de -48% para -3%. Nova OS, 1 veículo: de -15% para 1% |
| `R` na OS já traz as outras OS em aberto do cliente | Receber 3 do mesmo cliente: de -79% para -52%, ainda perde |
| Data curta, como `sex 14` | Agendar: de -12% para 8% |

Com isso o web empata com o app, mas continua longe de 50%. O caminho para ir além é tirar decisões, não teclas: "Recentes" e "mais usados" no campo vazio, como o app já faz, repetir a última OS e lançar várias linhas de uma vez. Isso ainda não foi modelado.

## Letras até achar o cliente

O desenho fala em 3 letras. Foram medidas 200 buscas com recência como desempate, em dados sintéticos. Nomes reais podem se comportar de outro jeito.

| Clientes na empresa | Teclas em média | p90 |
|---:|---:|---:|
| 1.500, frase inteira | 10,0 | 14 |
| 1.500, início de cada palavra (`pau rib`) | 7,8 | 10 |
| 50 | 2,9 | 4 |
| 21 (p95 fora da maior empresa) | 2,3 | 3 |

## Acessibilidade e zoom

- **axe (WCAG 2.2 A e AA):** 0 violações em 11 estados, nos 6 cruzamentos de claro e escuro com pt, en e es. Linhas fora da tela ficam como "incompleto" no contraste, então os pares de cor foram medidos à parte. axe não substitui leitor de tela, que não foi testado.
- **Zoom:** 200% em 1440×900 e 1280×720, 400% em 1280×1024. Sem rolagem lateral, e o fluxo Nova OS passou até o fim, com foco visível.
- **Falhas achadas e corrigidas no protótipo:** o rodapé fixo do `Drawer` cobria o campo em foco a 200% em 1280×720, e abrir o detalhe abaixo de 1100 px mandava o foco para o `body`.
- **Atalhos:** `Ctrl+F`, `Ctrl+L`, `Ctrl+T` e `Ctrl+P` ficam com o navegador. Letras digitadas em campo não disparam atalho. `Esc` com dados pergunta antes de descartar. O foco fica preso na camada e volta à linha.
- **Busca na paleta:** menos de 1 ms em 10 mil OS, com índice local na memória. Não mede a carga inicial desse índice.

## Limites

- O modelo não inclui erro, leitura da tela, conversa com o cliente nem curva de aprendizado de atalhos. Esses fatores tendem a pesar contra o teclado no início.
- Mouse não foi medido. Muita gente vai usar teclado e mouse juntos.
- Prova só o caminho feito por teclado no protótipo, não o produto final.
- Foto, link de envio e WhatsApp foram simulados. Criar OS e receber passaram pelas regras do Firestore no emulador.
