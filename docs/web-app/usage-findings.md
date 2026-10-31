# Uso real do app: o que o web app precisa resolver primeiro

Janela: 02/08 a 31/10/2026 (90 dias), salvo indicação. Fontes: Firestore de produção e GA4 (iOS e Android), só leitura. Sem 11 empresas internas ou de demonstração. Só agregados.

Legenda: **[M]** medido, **[E]** estimativa com a conta explicada, **[I]** inferência, **HIPÓTESE** ainda sem dado.

## Conclusões

1. **`/order` é a tela nº 1.** [M] Tem 41% das visitas a telas com nome. Mesmo descontando as voltas de subtelas, continua no topo [E].
2. **A base é pequena e uma empresa pesa muito.** [M] Foram 118 empresas com OS em 90 dias, 1.232 OS, 17 com OS em 4 semanas ou mais e 7 em 8 semanas ou mais. A maior empresa tem 38% das OS dos 90 dias e 86% das OS da história.
3. **"Recepção" quase não aparece nos dados.** [M] Em 81 das 82 empresas com autor conhecido, uma só pessoa criou todas as OS. Se existe recepção, ela usa o login do dono ou não usa o app [I].
4. **"Paridade total antes do diferencial" não se sustenta como ordem de entrega.** O destino pode continuar, mas o núcleo vem antes da cauda (ver Concentração).
5. **Só uma empresa chega a 10 mil OS.** [M] A segunda tem menos de 200.

## Top 10 tarefas

Volume em 90 dias. "Sem a nº 1" exclui a maior empresa. Visitas são do GA4, nos dois sistemas. Papel: quase tudo é `admin`, então a coluna diz quem faz na prática [I].

| # | Tarefa | Volume [M] | Sem a nº 1 [M] | Quem | Depende do celular? [I] |
|---|---|---|---|---|---|
| 1 | Abrir e consultar OS | 15.889 visitas a `/order` (~6 mil aberturas [E]) | n/d | Dono | Não |
| 2 | Lançar serviço na OS | 2.166 linhas; 9.329 visitas | 935 linhas | Dono | Não |
| 3 | Criar OS | 1.232 | 769 | Dono | Não, mas parte é feita em campo |
| 4 | Lançar veículo/aparelho | 697 cadastros; 5.169 visitas | 227 cadastros | Dono | Não |
| 5 | Registrar pagamento ou desconto | 793 + 142 | 356 + 60 | Dono | Não |
| 6 | Escolher ou cadastrar cliente | 607 cadastros; 2.831 visitas | 597 cadastros | Dono | Não |
| 7 | Enviar a OS ao cliente | 1.208 aberturas da tela de compartilhar (só iOS); 195 OS com link | 189 OS com link | Dono | Em parte: hoje passa pela tela nativa e pelo WhatsApp |
| 8 | Anexar foto | 512 fotos em 190 OS | 508 fotos em 188 OS | Dono/técnico | **Sim** |
| 9 | Lançar peça/produto | 383 linhas; 1.972 visitas | 368 linhas | Dono | Não |
| 10 | Agendar | 360 OS com data, 218 para o futuro | as mesmas 360 | Dono | Não para marcar; consultar pode ser em campo |

Abaixo do top 10: 281 comentários internos, 90 do cliente pelo link, 69 checklists (21 empresas, 131 fotos) [M]. Checklist depende do celular [I].

**Dependência real do celular:** [M] 16% das OS têm foto ou checklist com foto (25% sem a nº 1), em 37 empresas para foto. Entre as 16 empresas regulares fora a nº 1, 5 fotografam em 50% ou mais das OS e 11 em até 14%. Quando há foto, 74% entram na primeira hora da OS. No iOS, a galeria abriu 208 vezes e a câmera 17: boa parte da foto já está no aparelho quando é anexada [M/I].

## O dia de cada um

**Dono de balcão: um caso só, a maior empresa.** [M] Trabalha em horário comercial, cria OS em sequência e recebe em lotes, quase sem foto, agenda ou checklist. Usa OS e recebimento, não o fluxo de situação. Reaproveita pouco os veículos já cadastrados, o que encarece a busca e abre espaço para "receber várias" [I]. Os números ficam fora do repositório, porque descrevem um cliente só.

**Dono-técnico: as 16 empresas regulares fora a nº 1.** [M]
- Mediana de 1,9 OS por semana, 1,65 por dia ativo e 12,5 dias ativos em 90.
- Todas as 117 empresas fora a nº 1: 62% das OS entre 8h e 18h, **29% depois das 18h**, 10% antes das 8h, 16% no fim de semana.
- A OS costuma ser uma ação curta: 28% das OS saem em sequências de 3 ou mais.
- 43% das OS têm endereço (50 empresas) e 47% têm data. Das datas, 61% são futuras, com mediana de 3 dias. Atende fora [I].
- 32% dos pagamentos entram em até 24 horas da OS. Mediana de 3,4 dias.

**Recepção: sem dado direto.**
- [M] 15 empresas têm 2 ou mais usuários (12 ativas), e só 3 têm 2 ou mais usuários agindo no período.
- [M] Nessas 12, perfis fora de `admin` criaram 17 de 615 OS com autor conhecido e não registraram pagamento. Só 1 empresa mostra divisão: um `supervisor` cria e o `admin` recebe.
- [I] O dia da recepção hoje só dá para supor a partir do balcão da nº 1: abre OS na chegada, lança serviço e veículo, recebe em lote, envia ao cliente. Pode ser o dono ou alguém no mesmo login. Os dados não distinguem.

## Concentração

- [M] 24 nomes de tela tiveram visitas, de 52 arquivos de tela no app. Foram 60.179 visitas no total: 39.101 com nome, 10.030 em `/`, 11.048 sem nome.
- [M] **6 telas (25% dos nomes) têm 80% das visitas com nome. 10 telas (19% dos arquivos) têm 93%.** Contando as 7.622 visitas de telas Flutter sem nome, as 10 ficam com 78%.
- [M] As 10 são o fluxo da OS: `/order`, `/service_list`, `/order_service`, `/customer_list`, `/device_form`, `/device_list`, `/payment_management`, `/product_list`, `/accumulated_value_list`, `/order_product`.
- [M] Cauda: Financeiro, Agenda, Contratos, Nota Fiscal, Receber do cliente e Checklists somam 353 visitas, 0,9%. Abas só são medidas desde 13/10, então Financeiro e Agenda estão subcontados.

**Leitura da premissa:** 80/20 confirmado com folga. Sequência sugerida: fluxo da OS com receber e cliente, depois diferencial de velocidade (lançar em lote, receber vários, teclado), e a cauda por demanda. Três cuidados: a cauda pode crescer porque as telas são novas; uma tarefa faltando empurra a pessoa de volta ao celular; foto continua no celular de qualquer forma, então o web complementa o app, não o substitui.

## Tamanho das empresas

Em OS no total, 766 empresas reais. [M]

| Grupo | p50 | p95 | Máximo |
|---|---|---|---|
| Todas | 0 | 10 | acima de 10 mil |
| Com 1 OS ou mais (361) | 1 | 26 | acima de 10 mil |
| Ativas em 90 dias, OS no período (118) | 2 | 30 | n/d |

- Faixas: 43 empresas com 10 OS ou mais, 11 com 50 ou mais, 5 com 100 ou mais, 1 com 500 ou mais.
- Por OS: 2,07 itens em média (p95 6), 1,69 sem a nº 1.
- Cadastros fora da nº 1, p50/p95/máximo: clientes 1/21/105, veículos ou aparelhos 1/37/108, produtos 2/37/170, serviços 2/30/118.
- Na maior empresa, a maioria dos clientes citados nas OS não tem documento em `customers`: a busca no web precisa olhar os dados gravados na OS.

A meta de desempenho com 10 mil OS descreve uma empresa só, que é justamente a mais parecida com o usuário de computador.

## HIPÓTESE: quem preferiria o computador

Nada aqui vem de medição. O GA4 só vê celular e tablet (tablet é 0,5% das visitas) [M].

- **H1, balcão com volume:** dono ou recepção com 5 ou mais OS por dia, ou que recebe em lote. Sinal: a nº 1, única com esse padrão constante.
- **H2, fechamento de fim do dia:** dono-técnico que lança depois das 18h (29% das OS). Pode ser só o celular no sofá.
- **H3, quem não vai usar:** técnico em campo com muita foto.

Como validar:
1. Conversar com a nº 1 e com 3 ou 4 regulares: quem lança, em que aparelho, se existe computador no balcão, se dividem login.
2. Colocar no app uma pergunta rápida ou um "usar no computador" de teste, e cruzar por empresa.
3. No piloto, medir aparelho, OS por sessão e tarefas feitas no web e no celular.

## Lacunas

- **GA4 sem recorte:** `company_id`, `segment` e `user_role` não estão registradas como dimensões. Sem corte por empresa ou papel no GA4; o Firestore cobriu parte disso.
- **Visitas a `/order` infladas:** o observador conta também a volta de subtela. A estimativa de ~6 mil tira cinco subtelas (`/order_service`, `/order_product`, `/customer_list`, `/device_list`, `/payment_management`).
- **Telas sem nome:** 18% das visitas. 7.622 são rotas Flutter sem nome e cerca de 3.400 são telas nativas. Detalhe do cliente, por exemplo, não aparece.
- **Envio da OS:** o evento `share` só cobre o link (267). As 1.208 aberturas da tela de compartilhar no iOS provavelmente incluem PDF [I]. Android não mostra isso.
- **Tempo de execução:** não há histórico de situação e `completedAt` é novo (2 OS na janela). `updatedAt` existe em 30% das OS. Não dá para medir duração da OS nem quanto tempo cada tarefa leva hoje.
- **Leitura:** consulta não deixa rastro no Firestore. Para leitura só há GA4, sem corte por empresa.
- **iOS e ATT:** os eventos próprios batem com o Firestore em totais, incluindo empresas de teste: OS 1.337 × 1.260, pagamentos 866 × 950, fotos 565 × 528, clientes 661 × 613. A subcontagem esperada não aparece nesses totais.
- **Equipe:** `memberships` mostra 4 empresas com 2 ou mais usuários, `users.companies` mostra 15. Este documento usa `users.companies`.
- **Autor:** 79 OS sem `createdBy` (6%), em 59 empresas.
- **Horas:** `createdAt` da OS, fotos e pagamentos usam a hora do aparelho, sem fuso gravado. `completedAt` é UTC.
- **IA:** uso de foto e voz do assistente não foi separado aqui. A OS não marca a origem.
- **Base pequena:** a nº 1 é um caso, não um segmento. Empresas internas foram tiradas por nome, então pode ter sobrado alguma.
