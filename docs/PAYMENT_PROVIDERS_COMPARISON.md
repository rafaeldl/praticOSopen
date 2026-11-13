# Provedores de pagamento para os planos na web

Pesquisa de 13/11/2026 para decidir como cobrar os planos pela web (issue #664, PR #738). Só páginas públicas; nenhuma conta foi criada. Taxas mudam: conferir na conta antes de ligar.

## Decisão (13/11/2026)

- **Brasil:** venda na web pelo Asaas (opção A, PR #738).
- **Fora do Brasil:** por enquanto, sem venda na web. Empresa com país diferente de `BR` vê na web "Fora do Brasil, a assinatura é feita pelo app do PraticOS no celular", com os links da App Store e do Google Play, e compra dentro do app, na loja. O checkout recusa com 409 `OUTSIDE_BRAZIL` (`docs/WEB_CHECKOUT.md`).
- **Paddle:** fica para quando houver procura de fora.

## Resumo

**Recomendação: opção A, em duas etapas.**

1. **Brasil: manter o Asaas** (PR #738 como está). É o mais barato onde importa (Pix e boleto no anual sobram 99%+ do Business e do Pro), emite a NFS-e da Rafsoft por R$ 0,49 e já está pronto e testado no sandbox.
2. **Exterior: não construir agora.** Quando houver procura real, usar o **Paddle** (merchant of record): cuida do imposto lá fora, aceita Brasil como vendedor e custa parecido com o Stripe para quem paga em dólar. Antes disso, dá para testar sem código a opção "pagador estrangeiro" do próprio Asaas (só cartão internacional, em reais).

**Por que não levar tudo para o Stripe (B):** no Brasil ele sai mais caro (cartão 3,99% + R$ 0,39 + 0,7% do Billing contra 2,99% + R$ 0,49 do Asaas), o Pix é só por convite e não serve para assinatura (Pix Automático não existe para empresa brasileira), boleto custa R$ 3,45, não emite NFS-e, o cartão cai em 30 dias, e o RevenueCat Web Billing (o jeito sem o truque do promocional) só aceita cartão e proíbe venda B2B. Seria refazer o #738 para receber menos.

## 1. Tabela de taxas

Tudo visto em 13/11/2026. "Padrão" é a taxa depois de qualquer promoção.

### Asaas (conta PJ da Rafsoft)

| Item | Valor | Fonte |
|---|---|---|
| Cartão de crédito à vista | 2,99% + R$ 0,49 (promo de 90 dias para conta nova: 1,99% + R$ 0,49) | [preços](https://www.asaas.com/precos-e-taxas), [regulamento da promo](https://central.ajuda.asaas.com/hc/pt-br/articles/32095332785947-Regulamento-Promo%C3%A7%C3%A3o-3-meses-de-taxas-reduzidas) |
| Cartão recorrente (assinatura) | Mesma tabela, por cobrança paga | [preços](https://www.asaas.com/precos-e-taxas), [ajuda](https://central.ajuda.asaas.com/hc/pt-br/articles/31997100041371) |
| Cartão parcelado | 2–6x: 3,49% + R$ 0,49; 7–12x: 3,99% + R$ 0,49 | [preços](https://www.asaas.com/precos-e-taxas) |
| Pix (cobrança com QR dinâmico) | R$ 2,15 por Pix (a página mostra também R$ 1,08, provavelmente a promo; o regulamento diz R$ 1,99 → R$ 0,99) | [preços](https://www.asaas.com/precos-e-taxas), [regulamento](https://central.ajuda.asaas.com/hc/pt-br/articles/32095332785947-Regulamento-Promo%C3%A7%C3%A3o-3-meses-de-taxas-reduzidas) |
| Boleto pago | R$ 2,15 (mesma divergência do Pix) | idem |
| Mensalidade | Nenhuma no Plano Básico | [ajuda](https://central.ajuda.asaas.com/hc/pt-br/articles/58296058455835) |
| Aviso por e-mail + SMS | R$ 0,99 por cobrança paga (pode desligar) | [preços](https://www.asaas.com/precos-e-taxas) |
| NFS-e automática | R$ 0,49 por nota | [preços](https://www.asaas.com/precos-e-taxas), [ajuda](https://central.ajuda.asaas.com/hc/pt-br/articles/52856022472219) |
| Prazo de recebimento | Cartão D+32; Pix na hora; boleto no dia útil seguinte | [cartão](https://www.asaas.com/cobranca-cartao), [Pix](https://central.ajuda.asaas.com/hc/pt-br/articles/57282005212443), [boleto](https://central.ajuda.asaas.com/hc/pt-br/articles/53177663105051) |
| Antecipação | Cartão à vista 1,25% ao mês; boleto a partir de 5,79% ao mês | [preços](https://www.asaas.com/precos-e-taxas) |
| Estorno | Sem taxa no cartão e no Pix (a taxa original não volta); boleto pago R$ 5,00 | [API](https://docs.asaas.com/reference/estornar-cobranca), [boleto](https://central.ajuda.asaas.com/hc/pt-br/articles/53160979714331) |
| Chargeback | Sem taxa publicada; perde o valor e "arca com os custos" | [termos](https://central.ajuda.asaas.com/hc/pt-br/articles/32097763260699) |
| Saque | 30 Pix por mês grátis, depois R$ 2,00; TED R$ 5,00 | [preços](https://www.asaas.com/precos-e-taxas) |
| Cliente estrangeiro | Só depois que o Asaas libera (até 4 dias úteis). Só cartão internacional, sem Pix, boleto ou parcelado. Cobra em reais (nenhuma página fala em outra moeda). `cpfCnpj` continua obrigatório na API, com `foreignCustomer: true`; a doc não diz o que mandar. Não emite NFS-e para estrangeiro sem CPF/CNPJ e endereço no Brasil | [ajuda](https://central.ajuda.asaas.com/hc/pt-br/articles/31972902909851), [API](https://docs.asaas.com/reference/criar-novo-cliente), [NFS-e](https://central.ajuda.asaas.com/hc/pt-br/articles/58306029757723) |

### Stripe (conta no Brasil)

| Item | Valor | Fonte |
|---|---|---|
| Cartão nacional | 3,99% + R$ 0,39 (a página do Billing mostra R$ 0,50) | [preços](https://stripe.com/br/pricing), [Billing](https://stripe.com/br/billing/pricing) |
| Cartão internacional | +2% | [preços](https://stripe.com/br/pricing) |
| Conversão de moeda | 0% para a empresa; o cliente paga 2–4% no câmbio (Adaptive Pricing). Conta BR liquida em reais; preço direto em dólar não confirmado | [docs](https://docs.stripe.com/payments/currencies/localize-prices/adaptive-pricing) |
| Pix | 1,19%, **só por convite**, só pagamento avulso. "O Pix Automático não está disponível no Brasil" para empresa brasileira | [preços](https://stripe.com/br/pricing/local-payment-methods), [docs](https://docs.stripe.com/payments/pix) |
| Boleto | R$ 3,45 por boleto pago; funciona em assinatura, mas cada fatura é um boleto novo; não estorna | [preços](https://stripe.com/br/pricing), [docs](https://docs.stripe.com/payments/boleto) |
| Stripe Billing | +0,7% do volume cobrado | [Billing](https://stripe.com/br/billing/pricing) |
| Stripe Tax | Brasil fora da lista (não calcula ISS, PIS, COFINS) | [países](https://docs.stripe.com/tax/supported-countries) |
| NFS-e | Não emite. Precisa de emissor à parte (NFE.io etc.) ou do nosso fluxo direto no Emissor Nacional (`docs/NFSE_DIRECT.md`) | [suporte](https://support.stripe.com/questions/nota-fiscal-eletr%C3%B4nica-de-servi%C3%A7os-invoices-(nf-e)) |
| Prazo | Cartão 30 dias; cobrança internacional 5 dias; Pix e boleto 2 dias úteis. Antecipação só por parceiro, sem preço publicado | [repasses](https://docs.stripe.com/payouts) |
| Estorno | Sem taxa; a taxa original não volta | [preços](https://stripe.com/br/pricing) |
| Disputa (chargeback) | R$ 55 ao receber, R$ 55 para contestar (volta se ganhar) | [preços](https://stripe.com/br/pricing) |
| Managed Payments (Stripe como merchant of record) | Não aceita empresa no Brasil | [elegibilidade](https://docs.stripe.com/payments/managed-payments/eligibility) |

### RevenueCat

| Item | Valor | Fonte |
|---|---|---|
| Taxa própria | Grátis até US$ 2.500 de receita mensal acompanhada (app + web juntos), depois 1% | [preços](https://www.revenuecat.com/pricing) |
| Web Billing | Sem custo extra além do RevenueCat e do Stripe; usa o nosso Stripe. Não cobra os 0,7% do Billing | [docs](https://www.revenuecat.com/docs/web/overview) |
| Formas de pagamento | Só cartão, Apple Pay e Google Pay. **Sem Pix e sem boleto** | [docs](https://www.revenuecat.com/docs/web/web-billing/payment-methods) |
| Moedas | Real (mínimo R$ 4,99) e dólar | [docs](https://www.revenuecat.com/docs/web/web-billing/multi-currency-support) |
| Restrição | **Não permite venda B2B** nem clientes na Índia. Nosso cliente é empresa | [docs](https://www.revenuecat.com/docs/web/overview) |
| Libera o plano direto? | Sim. Link `pay.rev.cat/<token>/<appUserId>` (nosso `companyId`) associa a compra na hora, sem promocional | [docs](https://www.revenuecat.com/docs/web/web-billing/web-purchase-links) |
| Integração Stripe Billing (assinatura nossa no Stripe) | Também libera direto (`POST /v1/receipts` com `fetch_token`), mas Pix e boleto não são suportados; paga os 0,7% do Billing | [docs](https://www.revenuecat.com/docs/web/integrations/stripe) |

### Outras opções

| Provedor | Taxas | Exterior | Fonte |
|---|---|---|---|
| Mercado Pago | Cartão 4,98% na hora, 4,48% em 14 dias, 3,99% em 30 dias; Pix 0,99%; boleto 3,99%; sem mensalidade. Taxa de assinatura não publicada | Só reais, exige CPF | [link de pagamento](https://www.mercadopago.com.br/ferramentas-para-vender/link-de-pagamento) |
| Pagar.me | Pix 0,99%; cartão 4,19%; boleto e recorrência sob consulta | Só Brasil | [preços](https://pagar.me/precos/) |
| Iugu | Pix 0,99%; boleto R$ 2,19 + R$ 0,40; cartão 3,34% + R$ 0,40; mensalidade sob consulta (fonte de terceiros) | Só Brasil | [quasa.io](https://quasa.io/pt/media/asaas-ou-iugu-tarifa-publicada-vence-ate-o-volume-pedir-proposta) |
| Paddle (merchant of record) | 5% + US$ 0,50, sem mensalidade. Repasse mensal por wire ou Payoneer (mínimo US$ 100, wire pode custar US$ 15) | Aceita vendedor do Brasil. Cobra imposto lá fora. Aceita Pix Automático em reais desde 03/09/2026 | [preços](https://www.paddle.com/pricing), [países](https://www.paddle.com/help/start/intro-to-paddle/which-countries-are-supported-by-paddle), [repasse](https://www.paddle.com/help/manage/get-paid/when-and-how-do-i-get-paid), [Pix](https://developer.paddle.com/changelog/2026/pix-automatico) |
| Dodo Payments (merchant of record) | 4% + US$ 0,40; +1,5% cartão internacional; +0,5% assinatura; saque SWIFT US$ 25 | Aceita Brasil. Mais nova, regras de saque confusas | [preços](https://dodopayments.com/pricing), [países](https://docs.dodopayments.com/miscellaneous/accepted-countries-and-territories) |
| Lemon Squeezy | 5% + US$ 0,50 | Sendo migrada para o Stripe Managed Payments (que não aceita Brasil); saque só por PayPal | [preços](https://www.lemonsqueezy.com/pricing), [2026](https://www.lemonsqueezy.com/blog/2026-update) |
| Polar.sh | 5% + US$ 0,50 | Não paga para o Brasil | [países](https://polar.sh/docs/merchant-of-record/supported-countries) |

## 2. Quanto sobra de cada plano

Taxa padrão (sem promoção), uma cobrança por vez. Entre parênteses, quanto foi de taxa.

- **Asaas** inclui NFS-e (R$ 0,49) e o aviso por e-mail/SMS (R$ 0,99, opcional: sem ele sobra R$ 0,99 a mais).
- **Stripe, Mercado Pago e Paddle** não incluem nota. Com o nosso fluxo direto no Emissor Nacional, a nota não tem custo por emissão, mas é trabalho a mais.
- **RevenueCat 1%** só entra se a receita acompanhada passar de US$ 2.500 por mês.
- **Paddle** convertido a R$ 5,40 por dólar (premissa; ajustar ao câmbio do dia).

| Opção | Starter mensal R$ 59,90 | Starter anual R$ 599 | Pro mensal R$ 119 | Pro anual R$ 1.190 | Business mensal R$ 249 | Business anual R$ 2.490 |
|---|---:|---:|---:|---:|---:|---:|
| Asaas cartão | R$ 56,14 (6,3%) | R$ 579,12 (3,3%) | R$ 113,47 (4,6%) | R$ 1.152,45 (3,2%) | R$ 239,58 (3,8%) | R$ 2.413,58 (3,1%) |
| Asaas cartão, promo 90 dias | R$ 56,74 (5,3%) | R$ 585,11 (2,3%) | R$ 114,66 (3,6%) | R$ 1.164,35 (2,2%) | R$ 242,07 (2,8%) | R$ 2.438,48 (2,1%) |
| Asaas Pix ou boleto | R$ 56,27 (6,1%) | R$ 595,37 (0,6%) | R$ 115,37 (3,1%) | R$ 1.186,37 (0,3%) | R$ 245,37 (1,5%) | R$ 2.486,37 (0,1%) |
| Stripe Billing cartão | R$ 56,70 (5,3%) | R$ 570,52 (4,8%) | R$ 113,03 (5,0%) | R$ 1.133,80 (4,7%) | R$ 236,93 (4,8%) | R$ 2.372,83 (4,7%) |
| Stripe Billing boleto | R$ 56,03 (6,5%) | R$ 591,36 (1,3%) | R$ 114,72 (3,6%) | R$ 1.178,22 (1,0%) | R$ 243,81 (2,1%) | R$ 2.469,12 (0,8%) |
| RevenueCat Web Billing cartão (com o 1%) | R$ 56,52 (5,6%) | R$ 568,72 (5,1%) | R$ 112,67 (5,3%) | R$ 1.130,23 (5,0%) | R$ 236,18 (5,1%) | R$ 2.365,36 (5,0%) |
| Mercado Pago cartão em 30 dias | R$ 57,51 (4,0%) | R$ 575,10 (4,0%) | R$ 114,25 (4,0%) | R$ 1.142,52 (4,0%) | R$ 239,06 (4,0%) | R$ 2.390,65 (4,0%) |
| Mercado Pago Pix | R$ 59,31 (1,0%) | R$ 593,07 (1,0%) | R$ 117,82 (1,0%) | R$ 1.178,22 (1,0%) | R$ 246,53 (1,0%) | R$ 2.465,35 (1,0%) |
| Paddle (cartão ou Pix) | R$ 54,20 (9,5%) | R$ 566,35 (5,5%) | R$ 110,35 (7,3%) | R$ 1.127,80 (5,2%) | R$ 233,85 (6,1%) | R$ 2.362,80 (5,1%) |

Leitura:

- **No mensal, quase empata:** todos ficam entre 4% e 6,5%, menos o Pix do Mercado Pago (1%). No Starter mensal o fixo pesa e o Asaas fica parecido com o Stripe.
- **No anual, o Asaas por Pix ou boleto ganha longe:** taxa fixa sobre valor alto (0,1% a 0,6%), e é a forma que o #738 já oferece no anual.
- **Mercado Pago Pix é o mais barato no mensal,** mas Pix não renova sozinho, a assinatura do Mercado Pago não tem taxa publicada e falta nota fiscal. A diferença para o Asaas é de R$ 2 a R$ 4 por mês por cliente: não paga a troca agora.

### Cliente no exterior pagando em dólar

Preços em dólar são hipotéticos (ainda não existem): Starter US$ 12, Pro US$ 24, Business US$ 49 por mês, a R$ 5,40.

| Opção | Starter US$ 12 | Pro US$ 24 | Business US$ 49 | Observação |
|---|---:|---:|---:|---|
| Stripe BR, cartão estrangeiro + Billing | R$ 60,07 (7,3%) | R$ 120,54 (7,0%) | R$ 246,51 (6,8%) | Imposto lá fora e nota de exportação por nossa conta |
| RevenueCat Web Billing (Stripe BR + 1%) | R$ 59,88 (7,6%) | R$ 120,15 (7,3%) | R$ 245,71 (7,1%) | Proíbe venda B2B |
| Paddle | R$ 58,86 (9,2%) | R$ 120,42 (7,1%) | R$ 248,67 (6,0%) | Paddle cuida do imposto e da fatura; saque wire até US$ 15 por mês |
| Dodo | R$ 58,75 (9,3%) | R$ 119,66 (7,7%) | R$ 246,56 (6,8%) | Mais nova; saque SWIFT US$ 25 |
| Asaas, pagador estrangeiro | — | — | — | Só em reais (o cliente paga o câmbio do banco dele); taxa do cartão internacional não publicada |

No exterior a taxa é parecida (6% a 9%) em qualquer caminho. O que decide é o imposto e a papelada:

- **Stripe direto:** a Rafsoft vira responsável por IVA e sales tax de cada país, e o Stripe Tax não ajuda numa conta brasileira.
- **Paddle:** a Paddle é quem vende para o cliente final. A Rafsoft fatura só para a Paddle. A leitura provável, a confirmar com o contador, é uma NFS-e de exportação por repasse, não uma por cliente.
- **Exportação de serviço:** sem ISS (LC 116/2003, art. 2º, I), e com PIS/COFINS isentos ou fora do DAS conforme o regime, ponto a confirmar com o contador. A NFS-e continua obrigatória, marcada como exportação ([agilize](https://agilize.com.br/blog/gestao-contabil-e-fiscal/exportacao-de-servicos), [contabilidadezen](https://www.contabilidadezen.com.br/blog/nota-fiscal-exportacao-servicos-2026/)).
- **Nosso fluxo direto no Emissor Nacional** pode emitir essa nota de exportação.

## 3. Além da taxa

| | Asaas (A, Brasil) | Stripe tudo (B) | RevenueCat Web Billing | Paddle (exterior) |
|---|---|---|---|---|
| Trabalho | Pronto no #738 | Refazer checkout, webhook e cancelamento | Pouco (link de compra), mas só cartão | Novo provedor ao lado do Asaas |
| Pix e boleto | Sim, com renovação por fatura | Pix só por convite e avulso; boleto R$ 3,45 | Não | Pix Automático só se cobrar em reais pela Paddle |
| NFS-e | Automática, R$ 0,49 | Emissor à parte ou o nosso direto | Idem Stripe | Uma de exportação por repasse (a confirmar) |
| Libera o plano | Promocional do RevenueCat (truque do #738) | Integração Stripe do RevenueCat, direto | Direto | Promocional, igual ao Asaas (ou integração Paddle do RevenueCat, se houver: verificar) |
| Conciliação | Extrato Asaas em reais, nota casada com a cobrança | Repasse diário com 30 dias de atraso; nota em outro sistema | Idem Stripe | Repasse mensal em dólar; uma nota por repasse |
| Dinheiro | Pix na hora, cartão D+32 | Cartão 30 dias | 30 dias | Mensal |

**Regras da Apple:** não mudam com o provedor. O app não pode ter link, botão ou texto levando à compra na web (3.1.1 e 3.1.3(b)); o site e o app web podem vender. O #738 já segue isso: a compra só aparece no app web, e o app só mostra "Seu plano está ativo". Qualquer provedor novo entra do mesmo jeito, só no app web e no site.

## 4. O que mudaria no código (não implementado)

**Agora (A, Brasil):**
- Nada além do #738. Antes de ligar, conferir em Menu > Taxas qual é o Pix e o boleto de verdade (R$ 2,15 ou R$ 1,99).
- Decidir se o aviso de R$ 0,99 fica ligado: o próprio app web já mostra a fatura.
- Pensar em liberar Pix e boleto também no mensal (`config/webCheckout.billingTypes`). Hoje é só cartão, porque Pix e boleto não renovam sozinhos.

**Exterior com Paddle (quando houver procura):**
- `firebase/functions/src/services/web-billing/`:
  - criar `paddle-client.ts`;
  - generalizar `web-billing.service.ts` para ter um provedor (`provider: 'asaas' | 'paddle'` no `WebBillingRecord`);
  - em `web-billing-rules.ts`, preços em dólar ao lado de `WEB_PRICES`.
- Rota nova `routes/webhooks/paddle-billing.routes.ts`, com assinatura do webhook da Paddle. Mapear os eventos `transaction.completed`, `subscription.canceled` e `adjustment.created` (reembolso e chargeback) para as mesmas ações de hoje: dar o promocional, revogar, cancelar.
- Antes, verificar se o RevenueCat tem integração com a Paddle. Se tiver, ela libera o plano direto, sem o promocional.
- `SubscribeView.vue`: perguntar o país. Brasil segue com o Asaas; fora usa o checkout da Paddle (Paddle.js) com o `companyId` em `customData`.
- Segredos novos `PADDLE_API_KEY` e `PADDLE_WEBHOOK_SECRET`. Nota de exportação por repasse pelo fluxo `NFSE_DIRECT`.

**Se um dia for para o Stripe:**
- Usar a integração Stripe do RevenueCat (`POST /v1/receipts` com o `sub_…` e o `companyId`) e apagar `revenuecat-promotional.ts` e `web-origin.ts` nesse caminho.
- O checkout passa a ser o Stripe Checkout.
- A NFS-e sai pelo fluxo direto, disparada pelo `invoice.paid`.

**Teste barato antes de tudo:**
- Pedir ao Asaas a liberação de "pagadores estrangeiros" no sandbox.
- Ver o que o `cpfCnpj` aceita com `foreignCustomer: true`.
- Se funcionar, um cliente de fora já assina em reais com cartão internacional, sem provedor novo. Fica sem nota automática; ela sairia pelo fluxo direto.

## Pendências a confirmar

- **Asaas:** taxa real de Pix e boleto na conta (R$ 2,15 ou R$ 1,99); custo do chargeback; taxa do cartão internacional para pagador estrangeiro.
- **Stripe:** se a conta BR pode ter preço em dólar; se o RevenueCat Web Billing funciona com Stripe BR.
- **Paddle:** taxa de câmbio e de chargeback; aprovação da conta.
- **Contador:** se a Paddle conta como tomador estrangeiro (nota de exportação por repasse); se brasileiro que paga a Paddle em reais com Pix ainda conta como exportação; e o tratamento no Simples.
