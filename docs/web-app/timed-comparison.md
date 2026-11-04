# Comparação cronometrada: app no celular contra app web

Base: master `9b29b518`, 2026-11-03. Mesmo roteiro nos dois lados, perfil admin, empresa de teste com 10 clientes (1 veículo cada), 5 serviços e 5 peças. Esse tamanho é o da empresa típica: fora a maior, o p95 é 21 clientes (`usage-findings.md`).

**O que foi medido e o que foi estimado**

- **Web, medido:** o build de produção (`build:e2e`, mesmo bundle com as portas do emulador) contra o Emulator Suite no projeto `demo-praticos`. Playwright conta cada tecla e clique e cronometra da primeira tecla até o estado final, 5 rodadas por tarefa. Script: `firebase/webapp/e2e/perf/timed-comparison.spec.ts` (`CMP=1`).
- **App, estimado:** passos contados no código de `lib/screens`, sem rodar o app. O build do app aponta para portas fixas do emulador (8080, 9099, 9199) e para o projeto real, e um agente no simulador não mede tempo humano. Nenhum tempo do app foi medido.
- **Tempo humano, estimado nos dois lados:** KLM, o mesmo modelo de `keyboard-flows.md`: 0,24 s por passo, 1,2 s por decisão (começar a tarefa e cada campo ou opção). As decisões são as mesmas nos dois lados. "Máquina" é o tempo do script no emulador e não entra na conta humana.
- **Sensibilidade:** só o app muda, com 0,333 s por letra no celular e 0,5 s por tela que abre.

Passo: uma tecla, um toque ou um clique. `Ctrl+Enter` conta 2. Cada letra conta 1. Na busca, o web digita até o alvo ficar entre as 4 primeiras opções e usa `↓`.

## Roteiro

| # | Tarefa | Começa em |
|---|---|---|
| T1 | Nova OS: cliente existente, veículo único, serviço do catálogo, valor digitado 180, salvar | Início |
| T2 | Achar e abrir a OS pelo número | Início |
| T3 | Mudar de Aprovado para Concluído e dispensar a pergunta da próxima manutenção | OS aberta |
| T4 | Receber o que falta (R$ 200) em Pix | OS concluída |
| T5 | Mandar ao cliente pelo WhatsApp, até o WhatsApp abrir | OS aberta |
| T6 | Cadastrar cliente: nome de 11 letras e celular de 11 dígitos | Início |
| T7 | Remarcar a visita para outro dia e hora | OS aberta |
| T8 | Ver quanto falta receber na empresa | Início |
| T9 | Adicionar uma peça do catálogo, com o preço do catálogo | OS aberta |
| T10 | Lançar desconto de R$ 20 | OS concluída |

## Resultado

| # | Passos app | Passos web | Tempo app (KLM) | Tempo web (KLM) | Máquina web | Menos passos | Menos tempo | Sensibilidade | Meta |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| T1 | 14 | 14 | 8,2 s | 8,2 s | 0,26 s | 0% | 0% | 23% | Não |
| T2 | 6 | 5 | 3,8 s | 3,6 s | 0,27 s | 17% | 6% | 22% | Não |
| T3 | 3 | 6 | 4,3 s | 5,0 s | 0,16 s | -100% | -17% | 5% | Não |
| T4 | 5 | 5 | 3,6 s | 3,6 s | 0,13 s | 0% | 0% | 29% | Não |
| T5 | 2 | 4 | 2,9 s | 3,4 s | 0,26 s | -100% | -17% | 1% | Não |
| T6 | 27 | 27 (39 só teclado) | 10,1 s | 10,1 s | 0,24 s | 0% | 0% | 29% | Não |
| T7 | 6 | 15 | 5,0 s | 7,2 s | 0,17 s | -150% | -43% | -30% | Não |
| T8 | 1 | 0 | 1,4 s | 1,2 s | 0 s | 100% | 17% | 17% | Só passos |
| T9 | 3 | 4 | 3,1 s | 3,4 s | 0,12 s | -33% | -8% | 10% | Não |
| T10 | 5 | 5 (10 só teclado) | 4,8 s | 4,8 s | 0,18 s | 0% | 0% | 20% | Não |

"Sensibilidade" é a redução de tempo com o app mais lento por digitar no celular e trocar de tela. Em T6 e T10 a coluna web usa o melhor caminho, com mouse no menu; só teclado está entre parênteses.

**Metas**

- **50% menos tempo e passos: não atingida em nenhuma tarefa.** O web empata em 4, ganha pouco em 2 e perde em 4. Só T8 tem 50% menos passos, e ainda assim só 17% menos tempo.
- **OS completa em menos de 45 s só com teclado: atingida.** 8,2 s no KLM, 0,26 s de máquina, 14 passos.

## Onde o web não bate a meta e por quê

A causa comum é a mesma da descoberta: as decisões são iguais nos dois lados e pesam mais que as teclas. Com 1,2 s por decisão, tirar teclas nunca chega a 50%. Só tirar decisões chega lá.

| # | Causa no web | O que tiraria passos |
|---|---|---|
| T1 | Busca vazia começa sem opção ativa, então custa um `↓` a mais no cliente e no item | Já vir com a primeira opção ativa: 12 passos |
| T2 | Empata: `⌘K` vale 2 passos | Nada a fazer. O ganho real é achar OS antiga, que o app não acha porque filtra só as OS carregadas |
| T3 | A lista de situações anda de `Tab` em `Tab` (3 até Concluído) | Setas e primeira letra na lista: `S`, `C`, `Enter`, `Esc` = 4 |
| T4 | Empata: forma de pagamento vem vazia nos dois lados, por decisão de produto | Lembrar a última forma tiraria 2 passos dos dois lados |
| T5 | O foco abre no topo e leva 2 `Tab` até "Mandar pelo WhatsApp" | Foco no botão do WhatsApp quando o cliente tem telefone: `M`, `Enter` = 2 |
| T6 | Sem atalho nem comando para cliente novo. Pela paleta: "clientes" inteiro (os clientes aparecem antes da ação), `/`, nome, `Tab` até "Cadastrar" | Comando "Novo cliente" na paleta ou "Cadastrar «nome»" na própria paleta: cerca de 27 só teclado |
| T7 | Data e hora digitadas: 8 dígitos, `→` (o ano aceita 6 dígitos e não pula sozinho) e 4 dígitos, contra 3 arrastes na roda | Data curta, como `sex 14 8:30`, ou "mesmo horário" pronto. Obs.: o KLM conta o arraste como um toque; na prática um arraste custa mais, então o app está favorecido aqui |
| T8 | Ganha nos passos: o valor já está no topo da Início | Nada. O app mostra só no Financeiro |
| T9 | O item vem dos "Mais usados" sem digitar, mas custa `↓` a mais pelo mesmo motivo de T1 | Primeira opção ativa: 3 |
| T10 | Sem atalho para desconto: só teclado são 5 `Shift+Tab` até "Mais ações" | Atalho ou comando "Desconto" na paleta: 4 só teclado |

Com essas mudanças o web empata ou ganha por pouco em todas as tarefas, mas continua longe de 50% no tempo. O caminho para 50% é o que o web faz e o app não: OS em sequência, receber várias de uma vez, lançar várias linhas, repetir a última OS. Isso não está no top 10 de tarefas isoladas.

## Limites

- App não medido: passos lidos no código. Com mais de 10 clientes a busca de cliente aparece no app e a conta de T1 muda.
- KLM não inclui erro, leitura da tela, conversa com o cliente nem curva de aprendizado dos atalhos.
- Dados de teste pequenos e nomes sintéticos. Com 1.500 clientes (a maior empresa) os dois lados digitam mais.
- Data e hora do web seguem a ordem do Chromium em pt-BR (dia, mês, ano).
- O tempo de máquina vem do emulador local, sem rede real.
