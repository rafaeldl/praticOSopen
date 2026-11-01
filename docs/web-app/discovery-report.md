# App web: relatório de descoberta

Data: 2026-10-31. Dados de produção lidos em 02/08 a 31/10/2026, só agregados. Nada foi publicado, e nenhuma regra, API ou dado de produção mudou. Revisado no mesmo dia com a análise independente de uso, com dados até 30/10.

## Resposta curta

**O app web é viável e a arquitetura está clara, mas paridade total não se paga hoje.** Recomendo validar a demanda antes de escrever a primeira tela e corrigir as falhas de permissão dentro da empresa antes de ampliar cobrança, nota fiscal ou equipes. Elas existem com ou sem web.

| Pergunta | Resposta |
|---|---|
| Dá para construir? | Sim. Vue + Vite no Hosting cumpre INP, busca e acessibilidade no protótipo. Ver [ADR](ADR-001-web-architecture.md) |
| Vale paridade total agora? | Não. Só 20 empresas usam de verdade (faixa de 16 a 20), e há 1 assinatura de loja ativa. Nenhum pedido registrado |
| O que vem primeiro? | A primeira OS completa e a oferta para as 20 antes de 07/12. O teste de interesse vem antes da oferta, separado e sem código web. Ver [`demand-test.md`](demand-test.md) |
| Qual o maior risco? | Papéis dentro da mesma empresa gravam o que a tela proíbe. Independe do web. A exposição hoje é pequena: 11 membros reais têm papel restrito, e Asaas e nota fiscal não têm uso real |

## Decisões para o Rafael

Aprovadas em 2026-10-31:

- **Arquitetura:** [ADR-001](ADR-001-web-architecture.md).
- **Ordem e Portão 0:** validar a demanda antes de construir. A forma leve, com uma pergunta por mensagem, é proposta em [`demand-test.md`](demand-test.md).

Pendentes:

3. **Segurança:** autorizar a correção das falhas dentro da empresa, com plano para não quebrar versões antigas do app.
4. **Meta de 50%:** manter só para sequência e lote, ou tirar decisões do fluxo.
5. **Recepção:** não existe esse papel. Consultor só vê as próprias OS, e supervisor não vê preço. Definir se vira papel novo.
6. **Idiomas:** aceitar só pt-BR nas Fases 1 e 2, com os textos já em chaves. As 20 empresas são pt-BR, e os 29 cadastros em outros idiomas têm zero empresas ativas. Inglês e espanhol entrariam antes da abertura pública.

## O que os dados mostram

Detalhes em [`usage-findings.md`](usage-findings.md).

- **`/order` é a tela nº 1 e o uso é concentrado.** 10 telas, 19% dos arquivos, têm 93% das visitas com nome (78% contando rotas sem nome). Todas são o fluxo da OS. As visitas pesam para a maior empresa, então a prioridade agora se apoia no que as 20 fazem.
- **A premissa de paridade antes do diferencial não se sustenta como ordem de entrega.** A cauda soma 0,9% das visitas, com a ressalva de que abas só são medidas desde 13/10.
- **A base real é de 20 empresas.** Há 75 empresas com OS com conteúdo em 90 dias, e 20 usam de verdade. Em 81 de 82 empresas com autor conhecido, uma pessoa cria tudo. Das 20, 7 têm 2 ou mais membros.
- **Só uma empresa passa de 10 mil OS, e ela parece trabalhar de mesa.** Tem 42% das OS e 67% do valor digitado em 90 dias. É o melhor argumento a favor do web e também um risco de concentração.
- **O celular continua no jogo.** 16% das OS têm foto, e 74% das fotos entram na primeira hora. O web complementa o app.
- **Quem preferiria o computador segue como hipótese.** O GA4 só vê celular e tablet.

## Revisão com a análise de uso

**A recomendação não muda e fica mais forte.** Com 20 empresas reais e 1 assinatura, as 3 telas pedem cerca de 22% da base no plano Pro para empatar, e a paridade pede 60%. Mudam o desenho do teste, a ordem e os dados de apoio.

| O que mudou | Antes | Agora | Por quê |
|---|---|---|---|
| Teste de demanda | Lista de interesse no app, base de 21 empresas, início ao chegar em 70% de instalação | Contato direto com as 12 empresas com mais perfil de mesa, antes da oferta de 07/12. Sem PR e sem esperar versão. Forma em [`demand-test.md`](demand-test.md) | A base de 21 era de 04/10. Cerca de metade dos pares usuário e versão logados ainda está antes da 1.63 |
| Portão 0 | 8 de 21 | 6 de 12, mais 1 das 5 maiores e 5 pagantes | Base real, e 5 cobre o empate das 3 telas |
| Prioridade do web | Nada antes do teste | Primeira OS completa e oferta de 07/12 vêm antes | 74% das contas não chegam à primeira OS com conteúdo, e 7 das 20 passam do limite Free quando a cortesia acabar |
| Fase 2 | Sem data da OS | Com data da OS e comentário interno | 14 das 20 agendam, e 8 das 20 comentam |
| Fase 4 | Financeiro e contratos na fila | Só depois de uso real no app | Financeiro tem zero empresas reais, e contratos tem 1 |
| Quadro de OS | Candidato | Fora por enquanto | A maior empresa mantém toda OS como aprovada |
| Permissões | Corrigir já | Corrigir antes de ampliar cobrança, nota ou equipes, e antes da Fase 1 | Só 11 membros reais têm papel restrito. Asaas e nota não têm uso real |

Dados do GA4 que deixam de valer: os 488 usuários de Android, porque 414 parecem robôs, e a suspeita de subcontagem no iOS, porque 86 logados no GA4 batem com 90 no Auth. Em trabalho real são 19 usuários no Android e 17 no iOS. Os 111 pares de empresas possivelmente duplicadas não afetam as 20, mas inflam cadastros em cerca de 15%, então nenhum portão usa cadastro como base.

O que continua igual: arquitetura, metas técnicas, matriz, 12.439 OS da maior empresa (contadas sem as cópias legadas) e a falha da meta de 50%.

## Metas

| Meta | Situação | Evidência |
|---|---|---|
| Matriz de paridade | Mapeada: 514 linhas, 134 de 134 arquivos de tela, 34 exceções propostas, nenhuma aprovada | [`parity-matrix.yaml`](parity-matrix.yaml) |
| OS completa em < 45 s | Passa no modelo: 21,7 s no pior caso. Não testado com pessoas | [`keyboard-flows.md`](keyboard-flows.md) |
| 50% menos tempo e passos | **Falha no modelo:** 0 de 18 cenários em tempo, 2 de 18 em passos. O app já é curto, e as decisões são iguais | [`keyboard-flows.md`](keyboard-flows.md) |
| INP < 150 ms | Passa: 32 ms no protótipo | Benchmarks |
| LCP p75 < 1,5 s | Passa no LCP (1.046 ms) e com cache (580 ms). Lista visível na 1ª visita em Fast 4G: 1.690 ms, **falha por 190 ms**, por latência. No cabo, 1.118 ms | Benchmarks |
| Busca < 200 ms | Passa a consulta (6,6 ms). Falta decidir como montar o índice | ADR |
| Zero vazamento entre empresas | 166 testes de regras verdes, incluindo 38 novos. Sem quebra encontrada | [`security-summary.md`](security-summary.md) |
| Zero divergência de permissões | **Falha hoje.** Há divergências entre tela, regras e API | [`business-rules-map.md`](business-rules-map.md) |
| WCAG AA | axe sem violação no protótipo. Faltam leitor de tela real e ajustes de cor previstos no design | Benchmarks, [`WEB_APP_DESIGN.md`](../WEB_APP_DESIGN.md) |
| 50+ linhas visíveis | Física da tela: 41 em 1080p e 28 em 768p com linha de 24 px. Só 18 px chega lá, o que conflita com alvo mínimo. Proposta: 36 px por padrão, para leitura | Benchmarks |

Metas que recomendo ajustar, com evidência:

- Acompanhar "lista visível" em vez de LCP puro.
- Tratar 50+ linhas como opção de tela grande.
- Cobrar os 50% só em sequência e lote, ou incluir no escopo tirar decisões do fluxo (recentes, repetir OS, lançar várias linhas). A ser confirmado com cronômetro.

## Riscos fora do web

**Permissões dentro da mesma empresa.** Parte do que a tela proíbe o servidor aceita, inclusive com efeito em dinheiro. O web não cria esse risco: basta uma conta de membro. O detalhe está no diretório privado de discovery.

**Bug de total.** `computeTotal` ignora `value × quantity` em OS criada por API ou MCP. Remover o desconto grava total sem os produtos. O caso está em `contract-cases/order-totals.json`.

## Negócio

Ver [`business-red-team.md`](business-red-team.md).

- **Custo:** paridade em Vue, cerca de R$ 1.250/mês e 6 h, pelas premissas do red team. 3 telas, R$ 440 e 2,5 h. Infraestrutura é irrelevante.
- **Lojas:** o web não pode atrapalhar a revisão do iOS. Lançar depois da aprovação do modo individual. Não vender plano no web agora: quebra o webhook e o ganho é de ~11 pontos.
- **Limites de plano** ficam no cliente. O web não pode sair sem aplicá-los no servidor.

## Roteiro

Cada fase só começa com a anterior aprovada. A matriz é o placar de todas.

| Fase | Entrega | Portão de saída |
|---|---|---|
| **0. Sem código web** | Pergunta às 12 empresas-alvo antes da oferta de 07/12 ([`demand-test.md`](demand-test.md)), correções de permissão e do total, investigar as leituras altas | **Portão 0:** 6 ou mais das 12 dizem por escrito que usariam no computador, 1 ou mais das 5 maiores está entre elas, 5 ou mais pagantes depois de 07/12. Prazo: 15/01/2027. Critério em [`business-red-team.md`](business-red-team.md) |
| **1. Fatia** | Só pt-BR, se aprovado. Tokens unificados no `firebase/web`, login, escolha de empresa, lista e detalhe só leitura, atrás de flag | Piloto com a maior empresa. Metas de performance e axe no CI |
| **2. Núcleo** | Nova OS, itens, cliente, veículo, data da OS, comentário interno, receber e enviar ao cliente. Depende dos itens 1 a 4 do ADR | **Portão 1, 60 dias:** 6 empresas por semana (mínimo 3), 40% das OS delas no web |
| **3. Velocidade** | Ações em lote, receber vários, paleta, busca global, importação, repetir OS | 10 tarefas com cronômetro contra o app |
| **4. Cauda** | Agenda da equipe, checklists, nota e o resto da matriz, por demanda. Financeiro, contratos e cobrança Asaas só depois de uso real no app | **Portão 2:** 20 ou mais pagantes, 30% usando web toda semana por 8 semanas |

O Portão 2 pede tantos pagantes quanto as empresas que usam hoje, então paridade total depende de a base crescer.

Parada imediata: dado de uma empresa visto por outra, rejeição de loja citando o web ou manutenção acima de 8 h/mês por 2 meses.

Junto com a Fase 1 entram os processos que ainda são `risk:high`: casos de contrato nos workflows e a checagem da matriz, descrita em `parity-summary.md`.

## O que não foi feito ou medido

- Teste com pessoas, tanto de velocidade quanto de leitor de tela.
- Suporte e avaliações das lojas não foram lidos, então "nenhum pedido" significa "não registrado".
- Firefox, Safari e notebook com GPU integrada.
- Tempo real de tarefas no app: o Firestore não registra.
- Matriz montada por extrator e leitura de menus, não linha a linha das 44 mil linhas de telas.
- Custos usam premissas do red team, como R$ 150/h e 60% de repetição.

## Arquivos

| Arquivo | Conteúdo |
|---|---|
| [`ADR-001-web-architecture.md`](ADR-001-web-architecture.md) | Decisão aprovada |
| [`demand-test.md`](demand-test.md) | Teste de demanda: critério, mensagem e contagem |
| [`../WEB_APP_DESIGN.md`](../WEB_APP_DESIGN.md) | Padrão do app web |
| [`usage-findings.md`](usage-findings.md) | Uso real, agregado |
| [`parity-matrix.yaml`](parity-matrix.yaml), [`parity-summary.md`](parity-summary.md) | Matriz de paridade |
| [`business-rules-map.md`](business-rules-map.md), [`contract-cases/`](contract-cases/) | Regras e casos compartilhados |
| [`architecture-benchmarks.md`](architecture-benchmarks.md) | Medições |
| [`keyboard-flows.md`](keyboard-flows.md) | Passos e tempo modelados |
| [`security-summary.md`](security-summary.md) | Isolamento e papéis |
| [`business-red-team.md`](business-red-team.md) | Custo, lojas e critério de morte |
