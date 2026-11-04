# Comparação cronometrada: app no celular contra app web

Rodada 1: master `9b29b518`, 2026-11-03. Rodada 2 (atalhos e escolhas sugeridas): `feat/webapp-keyboard-speed`, 2026-11-04. Mesmo roteiro nos dois lados, perfil admin, empresa de teste com 10 clientes (1 veículo cada), 5 serviços e 5 peças. Esse tamanho é o da empresa típica: fora a maior, o p95 é 21 clientes (`usage-findings.md`).

**O que foi medido e o que foi estimado**

- **Web, medido:** o build de produção (`build:e2e`, mesmo bundle com as portas do emulador) contra o Emulator Suite no projeto `demo-praticos`. Playwright conta cada tecla e clique e cronometra da primeira tecla até o estado final, 5 rodadas por tarefa. Script: `firebase/webapp/e2e/perf/timed-comparison.spec.ts` (`CMP=1`).
- **App, estimado:** passos contados no código de `lib/screens`, sem rodar o app. O build do app aponta para portas fixas do emulador (8080, 9099, 9199) e para o projeto real, e um agente no simulador não mede tempo humano. Nenhum tempo do app foi medido.
- **Tempo humano, estimado nos dois lados:** KLM, o mesmo modelo de `keyboard-flows.md`: 0,24 s por passo, 1,2 s por decisão (começar a tarefa e cada campo ou opção). Na rodada 1 as decisões eram as mesmas nos dois lados; na rodada 2 o web tira as que viraram sugestão (ver abaixo). "Máquina" é o tempo do script no emulador e não entra na conta humana.
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

## Resultado (rodada 2: atalhos e escolhas sugeridas)

Remedido em 2026-11-04, branch `feat/webapp-keyboard-speed`, mesmo roteiro e mesmo KLM; 5 rodadas por tarefa, passos iguais em todas as rodadas (T1: 11 numa, 12 nas outras). O script agora escreve as decisões de cada caminho e imprime o KLM (`klm` na linha `CMP`). Decisão: começar a tarefa e cada campo ou opção que a pessoa precisa escolher. Sugestão confirmada com `Enter` ou tecla direta não é escolha; no app, escolher a opção num menu é.

| # | Passos app | Passos web | Tempo app (KLM) | Tempo web (KLM) | Menos passos | Menos tempo | Meta | Caminho no web |
|---|---:|---:|---:|---:|---:|---:|---|---|
| T1 | 14 | 12 | 8,2 s | 7,7 s | 14% | 6% | Não | `N`, `Enter` (1º cliente já ativo, ou letras + `↓`), item, `Tab`, 180, `Ctrl+Enter` |
| T2 | 6 | 2 | 3,8 s | 2,9 s | 67% | 24% | Só passos | `5` abre a busca com o número, `Enter` |
| T3 | 3 | 1 | 4,3 s | 1,4 s | 67% | 67% | **Sim** (da 2ª vez) | `P`: o botão azul lembra Aprovado → Concluído; a pergunta da manutenção fica na OS |
| T3 1ª vez | 3 | 3 | 4,3 s | 3,1 s | 0% | 27% | Não | `S`, `C`, `Enter` |
| T4 | 5 | 2 | 3,6 s | 1,7 s | 60% | 53% | **Sim** (sinal pago em Pix) | `R`, `Enter`: valor e forma do último pagamento já vêm |
| T4 sem pagamento antes | 5 | 5 | 3,6 s | 3,6 s | 0% | 0% | Não | `R`, `Tab`, `p`, `Tab`, `Enter` |
| T5 | 2 | 1 | 2,9 s | 1,4 s | 50% | 50% | **Sim** | `W` abre o WhatsApp; `M`, `Enter` também (2 passos, foco já no WhatsApp) |
| T6 | 27 | 26 | 10,1 s | 9,8 s | 4% | 3% | Não | `⌘K`, nome, `Enter` em "Cadastrar cliente «nome»", telefone (foco já nele), `Enter` |
| T7 | 6 | 9 | 5,0 s | 5,8 s | -50% | -15% | Não | `D`, `+7 8:30`, `Enter` (antes: 15 passos) |
| T8 | 1 | 0 | 1,4 s | 1,2 s | 100% | 14% | Só passos | Valor no topo da Início |
| T9 | 3 | 3 | 3,1 s | 3,1 s | 0% | 0% | Não | `A`, `↓` ou uma letra, `Enter` (o 1º dos Mais usados já ativo) |
| T10 | 5 | 4 | 4,8 s | 3,4 s | 20% | 30% | Não | `-`, 20, `Enter` |

Tempo app de T5: 2,88 s (2 passos, 2 decisões); o web dá 1,44 s, exatamente a metade.

**Meta (50% menos tempo e passos): 3 de 10** (T3 a partir da 2ª vez, T4 quando a OS já tem pagamento em Pix ou o último recebimento neste navegador foi Pix, T5). Antes: 0 de 10. Máquina web: 0,2 a 0,9 s por tarefa no emulador (as tarefas que gravam esperam a resposta da API; não entra no KLM).

### O que mudou no web

- Campo de busca vazio já com a primeira sugestão ativa (Recentes, Mais usados, ou a atual ✓); campo opcional sem sugestão (aparelho do cliente que não tem) continua com `Enter` = próximo campo.
- "Qual a situação?" e o menu "…": `↑`/`↓`, `Home`/`End` e primeira letra; o foco abre na situação do botão azul.
- `P` faz o próximo passo. O passo lembra, por empresa e neste navegador, para onde a pessoa foi a partir daquela situação (só para frente, só se permitido).
- Próxima manutenção: a pergunta fica dentro da OS, com "Agora não"; seguir trabalhando não pede dispensar (no app é uma folha por cima).
- Mandar: foco abre em "Mandar pelo WhatsApp" (`Enter` manda); `W` abre o WhatsApp direto e, se o navegador bloquear a aba, a folha fica com o botão em foco.
- Receber: forma do último pagamento da OS, senão a última usada neste navegador; `Enter` no valor confirma. Sem histórico, vem vazia como antes.
- `-` abre "Dar desconto". Na paleta, ações por nome ("Dar desconto", "Remarcar a visita", "Receber", "Mandar pelo WhatsApp", "Próximo passo", "Novo cliente") e elas vêm antes dos registros quando o texto bate.
- "Cadastrar cliente «texto»" na paleta abre o formulário com o nome e o cursor no telefone.
- Um número em qualquer tela abre a paleta com ele.
- Agendar e prazo: campo curto que entende "amanhã 14h", "+3", "seg 8:30", "9/5 14h" (pt, en, es); `↑`/`↓` muda o dia, com `Shift` meia hora. O seletor nativo continua e o arrastar na agenda não mudou.
- Atalhos novos aparecem no "?", com texto nos 3 idiomas; todos são de uma tecla, sem modificador (nada conflita com o navegador) e desligam junto com "Usar atalhos de uma tecla".

### Por que 7 tarefas ainda não batem

Com 1,2 s por decisão e 0,24 s por passo, uma tarefa só chega a 50% se o web tiver no máximo metade das decisões do app. Onde a decisão é o conteúdo (quem, o quê, quanto, quando), ela não some com sugestão.

| # | Decisões app | Decisões web | Piso do web (decisões x 1,2 s) | Meta de tempo | Por quê |
|---|---:|---:|---:|---:|---|
| T1 | 4 | 4 | 4,8 s | 4,1 s | Cliente, item e valor 180 são escolha da pessoa |
| T2 | 2 | 2 | 2,4 s | 1,9 s | O número é dado da pessoa; nos passos o web já ganha 67% |
| T6 | 3 | 3 | 3,6 s | 5,05 s | Cabe no tempo, mas 22 dos 26 passos são o nome e o telefone digitados (meta de passos: 13) |
| T7 | 3 | 3 | 3,6 s | 2,5 s | Dia e hora são escolha; o KLM conta o arraste do app como um toque, o que favorece o app |
| T8 | 1 | 1 | 1,2 s | 0,7 s | Olhar é a única decisão; o web já tem 0 passos |
| T9 | 2 | 2 | 2,4 s | 1,55 s | Qual peça é escolha |
| T10 | 3 | 2 | 2,4 s | 2,4 s | O valor é escolha; com o atalho, sobra 3,36 s |

Para essas, o ganho de 50% está no trabalho em série, que o roteiro de tarefas isoladas não mede: OS em sequência, receber várias de uma vez, lançar várias linhas.

## Resultado da rodada 1 (base `9b29b518`)

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

Na rodada 1 a meta não foi atingida em nenhuma tarefa, e a OS completa só com teclado ficou em 8,2 s (meta: menos de 45 s). As causas apontadas lá (busca sem opção ativa, situação de `Tab` em `Tab`, foco no topo do "Mandar", sem comando de cliente novo, data em 12 dígitos, sem atalho de desconto) são as que a rodada 2 corrigiu.

## Limites

- App não medido: passos lidos no código. Com mais de 10 clientes a busca de cliente aparece no app e a conta de T1 muda.
- KLM não inclui erro, leitura da tela, conversa com o cliente nem curva de aprendizado dos atalhos.
- Dados de teste pequenos e nomes sintéticos. Com 1.500 clientes (a maior empresa) os dois lados digitam mais.
- Data e hora do web: na rodada 1, a ordem do Chromium em pt-BR (dia, mês, ano); na rodada 2, o campo curto (T7 remarca de amanhã 14h para daqui a 7 dias 8:30).
- T3 e T4 dependem de histórico (a pessoa já foi de Aprovado a Concluído uma vez; a OS já tem pagamento em Pix). As linhas "1ª vez" e "sem pagamento antes" mostram o caso sem histórico.
- O tempo de máquina vem do emulador local, sem rede real.
