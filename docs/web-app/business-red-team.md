# Web app: red team do negócio

Data: 2026-10-31. Objetivo: tentar provar que o web não compensa. Não é aconselhamento jurídico. Itens marcados com **[advogado]** precisam de revisão. Valores de receita ficam fora do repositório.

## Veredito

**Vale só em parte, e não agora.** Paridade total não vale com a base de hoje. O custo de infraestrutura não é o problema. O problema é falta de demanda medida, tempo do Rafael e risco na revisão do iOS.

- Não começar antes do corte da cortesia (07/12) e da aprovação do iOS novo.
- Primeiro, testar interesse sem construir o web (Portão 0), em contato direto e antes da oferta de 07/12.
- Revisão de 31/10: 20 empresas usam de verdade, com 1 assinatura de loja ativa. O veredito fica mais forte. As 3 telas pedem 4,5 assinaturas Pro para empatar, ou 22% da base real. A paridade em Nuxt pede 12, ou 60%.
- Se passar, fazer só 3 telas. Paridade só com o Portão 2.

A melhor defesa do web é uma só: a maior empresa trabalha como escritório e pode valer sozinha um plano alto. Isso justifica perguntar a ela, não construir paridade.

## 1. A demanda é o ponto fraco

| Dado | Valor | Fonte |
|---|---|---|
| Empresas com OS em 90 dias | 118 de 766 | Firestore, 31/10 |
| Mediana de OS em 90 dias entre elas | 2 | Firestore, 31/10 |
| Parte da maior empresa nas OS de 90 dias | 38% (top 5: 58%) | Firestore, 31/10 |
| Empresas ativas com 2 ou mais usuários agindo | 3 de 118 (12 têm 2 ou mais cadastrados) | Firestore, 31/10 |
| Empresas com 5 ou mais OS em 30 dias | 21; com 20 ou mais: 1 | snapshot de 04/10, **superado:** das 20 que usam de verdade, 13 têm 5 ou mais e 5 têm 20 ou mais |
| Fotos anexadas na primeira hora após a OS | 74% | Firestore, 31/10 |
| Usuários de celular e tablet | 610 (computador: 17, no site). **Inválido como base:** 414 dos 488 usuários de Android parecem robôs | GA4 |
| Pedidos de versão para computador | nenhum achado | discovery, issues e `business/` |

Leitura: a "recepção" do objetivo quase não existe na base, pois a base é de uma pessoa, no celular e em campo. Limite da busca: não olhei e-mail de suporte nem avaliações das lojas, então "nenhum" significa "não registrado", não "não existe".

A favor do web:

- A maior empresa cria cerca de 7 OS por dia em horário comercial, 98% em dias úteis, quase sem foto. Parece trabalho de mesa.
- Concorrentes como o Jobber têm web completo. Empresas maiores podem exigir isso, mas ainda não medi quantas.
- O plano de venda por fora (nota, boleto, Hotmart) precisa de um lugar que não seja o app.

## 2. Custo mensal de duas interfaces

Histórico de `lib/screens` em 12 meses (nov/2025 a out/2026): 318 commits `feat`/`fix`, ou 26,5 por mês. O ritmo vem em ondas: 5 meses sem nada, 118 em janeiro e 92 em outubro. A mediana mensal é de 6,5.

| Premissa | Valor | Base |
|---|---|---|
| Mudanças a repetir no Nuxt | 60% | amostra de 60 commits lidos por título, ±10 pontos |
| Mudanças a repetir no Flutter Web | 25% | estimativa: lógica compartilhada, layout de mesa à parte |
| Commits por PR | 2,7 | 348 commits e 128 PRs em outubro |
| Custo de agente por PR | US$ 10 (R$ 55 a R$ 5,50) | uso real de outubro: US$ 1.295 a preço de tabela / 128 PRs |
| Tempo do Rafael por PR | 30 min | premissa |
| Fixo mensal (navegadores, dependências, suporte) | 3h / 2h / 2h | premissa |
| Hora do Rafael | R$ 150 | premissa |

| Cenário | PRs/mês | Horas | Agentes | Total/mês | Pico (como outubro) | Construção (ordem de grandeza) |
|---|---|---|---|---|---|---|
| Paridade em Nuxt | 6 | 6h | R$ 330 | **R$ 1.250** | R$ 3.200 | US$ 3 mil, 150 PRs, 75h |
| Paridade em Flutter Web | 2,5 | 3,3h | R$ 140 | **R$ 650** | R$ 1.500 | US$ 1 mil, 50 PRs, 25h |
| 3 telas em Nuxt | 1 | 2,5h | R$ 55 | **R$ 440** | R$ 750 | US$ 450, 25 PRs, 12h |

Os totais incluem R$ 10 a R$ 20 de infraestrutura. Em mês parado o custo cai bem abaixo disso. O valor de agente é teto: outubro custou US$ 1.295 a preço de tabela, mas se o Rafael usa assinatura fixa, o gasto real muda. A construção usa como base as 69 mil linhas de `lib/screens` e lógica, com fator 2 para acabamento.

**Comparação:** o Nuxt consome 6h/mês, quase metade das 13h/mês de venda e marketing. Se sair do mesmo tempo, o custo real é a conversão de 07/12. Ponto de equilíbrio, em assinaturas Pro líquidas adicionais por mês:

| Cenário | Com horas | Só dinheiro |
|---|---|---|
| Nuxt | 12 | 3,5 |
| Flutter Web | 6,5 | 1,6 |
| 3 telas | 4,5 | 0,6 |

Paridade em Nuxt exige, só para empatar, mais assinaturas novas que a meta inteira de 10 pagantes até 31/12.

**Custos que não aparecem na tabela:**

- **Regra duplicada:** em Nuxt, regras de valores, permissões e status existem em Dart e TypeScript. Os casos de contrato em `docs/web-app/contract-cases/` reduzem esse risco, mas também precisam de manutenção.
- **Escrita concorrente:** o app grava a OS inteira. Dois clientes editando a mesma OS podem perder dados sem contrato de escrita claro.
- **Flutter Web:** 105 dos 134 arquivos de tela usam Cupertino, e é provável que falhem no objetivo de ser mais rápido que o app. A meta de LCP não foi medida aqui.

## 3. Custo no Firebase

Medido no Cloud Monitoring, 30 dias até 31/10, Firestore em `southamerica-east1`. Não há exportação de fatura para BigQuery, então não vi a conta real.

| Item | Valor |
|---|---|
| Leituras | 15,8 milhões (14,6 milhões acima da franquia diária) |
| Gravações | 19.979 (dentro da franquia) |
| Preço de leitura em São Paulo | US$ 0,045 por 100 mil (catálogo Cloud Billing) |
| Custo estimado de leituras | **US$ 6,60/mês** |
| Requisições Cloud Run, todos os serviços | ~16.600 (franquia gratuita de 2 milhões) |
| Sessões do app | ~1.000/mês (3.009 em 90 dias, GA4) |
| Leituras por sessão | **~15.800** |

| Sessões web/mês | 500 leituras por sessão (paginado) | 15.800 por sessão (porte direto) |
|---|---|---|
| 300 | US$ 0,07 | US$ 2,10 |
| 3.000 (10 vezes) | US$ 0,68 | US$ 21 |

Hosting e Cloud Run ficam na franquia nesses volumes. O que pode pesar:

- **Busca global em menos de 200 ms:** o Firestore não faz busca em texto. Exige serviço externo (gasto recorrente, precisa de aprovação) ou índice no navegador, que traz o problema da seção 6.
- **Leituras altas:** são 793 por gravação. Em fins de semana as leituras costumam cair mais de 50 vezes, o que acompanha só a maior empresa. **Hipótese não provada:** essa empresa carrega listas inteiras. Vale investigar independentemente do web, pois o mesmo padrão copiado para o web multiplicaria o custo.

## 4. Canibalização

- **A receita vem só das assinaturas nas lojas, via RevenueCat.** O Asaas cobra a OS na conta da própria empresa, então não é receita do PraticOS.
- **Hoje há pouco a canibalizar:** a base nunca foi cobrada e a cortesia termina em 07/12.
- **Vender no web quebra o sistema atual:**
  - `docs/SUBSCRIPTION.md` proíbe outra forma de pagamento.
  - O webhook grava `source: store`, e sem direito ativo no RevenueCat volta a empresa para Free. Uma venda fora da loja seria apagada no próximo evento.
  - Precisaria de nova origem de assinatura, conciliação e bloqueio de cobrança dupla, tudo com `risk:high`.
- **Ganho por venda é pequeno:** cartão no Asaas custa R$ 0,49 + 2,99%, Pix e boleto R$ 2,15 por cobrança, contra 15% nas lojas. Sobra ~11 pontos de margem. Isso não paga billing próprio, nota fiscal e suporte, ainda mais sem venda 1:1. **[contador]** Nota e impostos da venda direta.
- **Risco maior: vazar o Free.** Os limites do plano ficam no cliente, e sem chave RevenueCat o app roda sem limite (`docs/SUBSCRIPTION.md`). O web não pode sair sem aplicar os mesmos limites, de preferência no servidor.

## 5. Regras das lojas

Consulta em 31/10/2026. A página da Apple não mostra data de revisão.

| Pergunta | Apple (Brasil) | Google Play (Brasil) |
|---|---|---|
| O site pode vender plano? | As regras cobrem o app, não o site. 3.1.3 permite comunicar fora do app à própria base. | Pode, e a comunicação fora do app é livre. |
| Quem comprou no web usa no app? | Sim, por 3.1.3(b), **se o mesmo item existir como IAP**. | Permitido em app só de consumo. Para app que também vende, **confirmar**. |
| Quem pagou IAP entra no web? | Sim, a assinatura é da empresa, e 3.1.3(b) cobre o acesso entre plataformas. | Sim. |
| O app pode falar do web? | Sem compra, sim: "use no computador". Sem levar a preços. **[advogado]** | Sim, e links administrativos são aceitos, se não levarem a pagamento. |
| O app pode linkar para compra? | Só com entitlement de compra externa, IAP lado a lado, relatório mensal e **10% a 15% de comissão** (desde 18/06/2026). | Só via programa elegível. User Choice Billing inclui Brasil, com 4 pontos a menos. External Offers é só EEA. |
| Comissão na loja | 10% + 5% de processamento para Small Business, 21% + 5% para os demais. | 15% no plano atual. |

Riscos específicos:

1. **Rejeição 3.1.1 ainda sem prova de solução.** A Apple rejeitou em 10/10 o cadastro de empresas mesmo com IAP no build. O "modo individual" ainda precisa passar na revisão, e a última versão promovida é a 1.56.0. Um web com cadastro de empresa dá ao revisor outro motivo. **Lançar só depois da aprovação.**
2. **Plano anual fora da loja viola a condição de 3.1.3(b).** Hoje o IAP é só mensal. O anual de fundador ou a oferta via Hotmart precisam existir como IAP antes de serem aceitos no app.
3. **Regras que não servem:** reader (3.1.3(a)) é só para revistas, livros, áudio, música e vídeo. 3.1.3(f) é para VoIP, armazenamento, e-mail e hospedagem. 3.1.3(c) exige venda só a organizações, e o PraticOS vende a pessoas e pequenas empresas.
4. **Small Business sem confirmação:** o pedido é de 09/10. Sem ele, a Apple no Brasil custa 26%, não 15%.
5. **EUA:** links e botões são permitidos sem entitlement. Isso depende do teste nas lojas e de decisão judicial; a conferir antes do uso. **[advogado]**
6. **Mudança em aberto:** as novas taxas do Google começaram por EEA, Reino Unido e EUA (30/06/2026). Para o resto do mundo só achei fonte secundária (até 30/09/2027).

## 6. LGPD e segurança

O web muda o risco principal: o celular é pessoal, o computador da oficina é compartilhado.

| Risco | Medida mínima |
|---|---|
| Sessão aberta em computador compartilhado | Sessão por aba, bloqueio por inatividade, "sair de todos os dispositivos" |
| Dados no cache do navegador (CPF, telefone, placa, fotos) | Cache persistente desligado por padrão, `no-store` em páginas com dados |
| Índice local para a busca | Não guardar dados pessoais em IndexedDB, ou deixar a busca no servidor |
| Exportação e impressão (PDF em Downloads, planilha, fila de impressão) | Exportar por papel, registro de quem exportou, sem dados pessoais na URL |
| Funcionário copiando a base no computador | Limites por papel nas regras e no servidor, registro de acesso |
| Extensões de navegador | CSP estrita e aviso nos termos |

**[advogado]**

- A política de privacidade não cita cookies nem navegador.
- Falta definir os papéis de controlador e operador sobre os clientes das oficinas (LGPD, arts. 37, 39 e 46).
- Verificar o prazo de comunicação de incidente (art. 48 e Resolução ANPD 15/2024: 3 dias úteis).

## 7. Alternativas mais baratas

| Alternativa | Esforço | Resolve | Veredito |
|---|---|---|---|
| Portão 0: pergunta às 12 empresas-alvo, antes da oferta de 07/12 | Sem PR, cerca de 1h05 do Rafael, ou 5h30 em conversas | Mede a demanda | **Fazer primeiro** |
| Exportar para planilha | 1 a 2 PRs | Contador, relatórios | **Fazer se pedirem** |
| Reduzir leituras no app | 1 a 3 PRs | Custo e velocidade em empresas grandes | **Investigar** |
| 3 telas no Nuxt que já existe (`firebase/web`, 6,6 mil linhas): lista de OS, nova OS, clientes | 25 PRs | Trabalho de mesa | **Se passar no Portão 0** |
| Link "Continuar no computador" | Parte das 3 telas | Digitar OS longa | Junto com as 3 telas |
| Layout de iPad | Médio | Quase nada: 13 usuários em tablet, dos quais 10 parecem robôs | Não |
| PWA do Flutter | 50 PRs | Rápido de lançar, mas sem layout de mesa, e a arquitetura deve medir | Não como produto; pode ser prova técnica |

## 8. Critério de morte

**Portão 0 (leitura em 15/01/2027, no máximo). Sem código web.** A versão anterior usava lista no app e esperava 70% de instalação. Saiu porque depende de loja e de atualização: cerca de metade dos pares usuário e versão logados ainda está antes da 1.63.

**Quem:** as 12 das 20 empresas com perfil de mesa. São as que têm até 15% das OS com foto e 50% ou mais com pagamento, ou 2 ou mais membros. Lista por ID só no diretório privado.

**Como:** decidido em [`demand-test.md`](demand-test.md): uma mensagem curta com uma pergunta, antes da oferta de 07/12, sem mostrar tela e sem prometer data. Silêncio conta como não.

Seguir só com **as três** condições:

- 6 ou mais das 12 dizem por escrito que usariam toda semana e citam uma tarefa concreta.
- Pelo menos 1 das 5 maiores empresas está entre elas.
- 5 ou mais pagantes entre as 20 que usam de verdade, após o corte de 07/12.

Interesse declarado é sinal fraco, por isso a terceira condição pede pagamento. Empresa duplicada conta uma vez.

Falhou em qualquer uma: **parar** e reavaliar em 6 meses.

**Portão 1 (60 dias depois das 3 telas no ar).** Parar e desligar se qualquer condição ocorrer:

- Menos de 3 empresas ativas por semana. Meta para continuar: 6.
- Menos de 40% das OS dessas empresas feitas no web.
- Nenhuma assinatura nova ou mantida que cite o web.

**Portão 2 (paridade).** Só com 20 ou mais pagantes e 30% deles usando o web toda semana, por 8 semanas seguidas. Hoje isso equivale a todas as empresas que usam de verdade, então depende de a base crescer.

**Parada imediata, a qualquer momento:**

- Dado de uma empresa visto por outra.
- Rejeição de loja que cite o web.
- Manutenção acima de 8h/mês por 2 meses seguidos.

## Fontes

Internas (agregadas): Firestore e GA4 de produção (leitura), Cloud Monitoring, catálogo Cloud Billing, `git log`, uso de tokens de outubro, `docs/SUBSCRIPTION.md`, `docs/superpowers/specs/2026-10-07-paid-plans-iap-design.md`.

Externas, consultadas em 2026-10-31:

- [Apple: App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Apple: mudanças no iOS no Brasil, 18/06/2026](https://www.apple.com/newsroom/2026/06/apple-announces-changes-to-ios-in-brazil/)
- [Appcharge: resumo das taxas no Brasil, 21/06/2026 (secundária)](https://appcharge.com/blog/apple-brazil-framework-is-now-live-what-publishers-need-to-know)
- [RevenueCat: guia de compra app para web, 2026 (secundária)](https://www.revenuecat.com/app-to-web-purchase-guidelines)
- [Google Play: política de pagamentos](https://support.google.com/googleplay/android-developer/answer/9858738?hl=en)
- [Google Play: entendendo a política de pagamentos](https://support.google.com/googleplay/android-developer/answer/10281818?hl=en)
- [Google Play: User Choice Billing](https://support.google.com/googleplay/android-developer/answer/13821247?hl=en)
- [Google Play: External Offers (EEA)](https://support.google.com/googleplay/android-developer/answer/14372887?hl=en)
- [9to5Google: taxas do Play, 24/06/2026 (secundária)](https://9to5google.com/2026/06/24/google-play-store-external-billing-june-30/)
- [Asaas: preços e taxas](https://www.asaas.com/precos-e-taxas)
- [Claude: preços](https://claude.com/pricing)
