# STORE_PLANS_SETUP.md

## Visão Geral

Passo a passo manual para deixar App Store Connect, Google Play Console e
RevenueCat iguais à tabela de planos de novembro de 2026 (épico #721, issue
#727). Os textos abaixo já estão prontos para colar e cabem nos limites de
cada console.

**Quando fazer:** só depois que os limites novos estiverem no app publicado
(#723, #724, #725). Antes disso a loja prometeria o que o app ainda não faz.
Os preços e os produtos anuais podem ser criados antes, desde que não fiquem
à venda no paywall.

Os lanes de promote (`ios/fastlane/Fastfile` e `android/fastlane/Fastfile`)
também publicam os textos da ficha. Por isso o PR #730 só pode ser mesclado
junto com o release que liga os planos novos.

Os textos da ficha (descrição, texto promocional, notas da revisão) estão em
`ios/fastlane/metadata/` e `android/fastlane/metadata/android/`, e sobem pelo
fluxo de `docs/STORE_LISTING.md`.

## Tabela de referência

| Produto | Preço (Brasil) | Plano (entitlement) |
|---|---|---|
| `praticos_starter_monthly` | R$ 59,90 por mês | `starter` |
| `praticos_starter_annual` | R$ 599 por ano | `starter` |
| `praticos_pro_monthly` | R$ 119 por mês | `pro` |
| `praticos_pro_annual` | R$ 1.190 por ano | `pro` |
| `praticos_business_monthly` | R$ 249 por mês | `business` |
| `praticos_business_annual` | R$ 2.490 por ano | `business` |

O anual sai pelo preço de 10 meses. Não existe teste grátis em nenhum plano.
A IA é incluída em todos os planos, inclusive no Grátis: nos textos das
lojas e do paywall ela não é diferencial de plano pago e nunca aparece com
número de uso.
O servidor já reconhece os seis IDs (`PRODUCT_TO_PLAN` em
`firebase/functions/src/services/subscription-plans.ts`), mas o caminho
principal é o entitlement, então cada produto precisa estar ligado ao
entitlement certo na RevenueCat.

## 1. App Store Connect

Caminho: App Store Connect > PraticOS > Monetização > Assinaturas > grupo
`PraticOS`.

### 1.1 Produtos anuais

Os mensais já existem. Para cada plano, criar o anual (se ainda não existir):

| Nome de referência | ID do produto | Duração |
|---|---|---|
| Starter anual | `praticos_starter_annual` | 1 ano |
| Pro anual | `praticos_pro_annual` | 1 ano |
| Business anual | `praticos_business_annual` | 1 ano |

### 1.2 Níveis do grupo

Mensal e anual do mesmo plano ficam no **mesmo nível**, assim a troca entre
eles é só de período:

| Nível | Produtos |
|---|---|
| 1 | Business mensal e anual |
| 2 | Pro mensal e anual |
| 3 | Starter mensal e anual |

### 1.3 Preços

Em cada produto, Preço da assinatura > país base Brasil, com os valores da
tabela de referência. Deixar a Apple calcular os outros países. Conferir que
os mensais continuam R$ 59,90, R$ 119 e R$ 249.

### 1.4 Nome de exibição e descrição (Localização da App Store)

Limites da Apple: nome com até 30 caracteres, descrição com até 45. O mensal
e o anual do mesmo plano usam a mesma descrição.

**Português (Brasil)**

| Produto | Nome de exibição | Descrição |
|---|---|---|
| Starter mensal | Starter mensal | Para quem trabalha sozinho e emite nota |
| Starter anual | Starter anual | Para quem trabalha sozinho e emite nota |
| Pro mensal | Pro mensal | Para equipe pequena: até 5 pessoas |
| Pro anual | Pro anual | Para equipe pequena: até 5 pessoas |
| Business mensal | Business mensal | Para empresa: até 20 pessoas |
| Business anual | Business anual | Para empresa: até 20 pessoas |

**English (U.S.)**

| Produto | Nome de exibição | Descrição |
|---|---|---|
| Starter mensal | Starter monthly | For those who work alone and issue invoices |
| Starter anual | Starter yearly | For those who work alone and issue invoices |
| Pro mensal | Pro monthly | For a small team: up to 5 people |
| Pro anual | Pro yearly | For a small team: up to 5 people |
| Business mensal | Business monthly | For companies: up to 20 people |
| Business anual | Business yearly | For companies: up to 20 people |

**Español (España)**

| Produto | Nome de exibição | Descrição |
|---|---|---|
| Starter mensal | Starter mensual | Para quien trabaja solo y emite factura |
| Starter anual | Starter anual | Para quien trabaja solo y emite factura |
| Pro mensal | Pro mensual | Para equipo pequeño: hasta 5 personas |
| Pro anual | Pro anual | Para equipo pequeño: hasta 5 personas |
| Business mensal | Business mensual | Para empresas: hasta 20 personas |
| Business anual | Business anual | Para empresas: hasta 20 personas |

Nome de exibição do grupo (Localização do grupo de assinaturas), se pedir:
`PraticOS` nos três idiomas.

### 1.5 Purchase Options (assentos)

Em cada um dos seis produtos, abrir **Purchase Options**. A Apple liga o
multiseat (compra com quantidade, Apple Business e Apple School Manager) por
padrão em assinaturas criadas depois de 14/09/2026. O PraticOS ainda não trata
assento comprado pela Apple (a RevenueCat não documenta o caso), então:

- Deixar só a compra individual dentro do app.
- Desligar Apple Business e Apple School Manager, se aparecerem ligados. Só o
  Account Holder consegue.
- Compartilhamento Familiar: desligado.

### 1.6 Ofertas

Nenhuma oferta introdutória nem teste grátis. A garantia de 7 dias (#728) não
é oferta da loja: na Apple o reembolso é decisão da Apple.

### 1.7 Revisão dos anuais

- Cada produto novo precisa de uma captura para a revisão (tamanho de iPhone,
  1290x2796, senão dá `IMAGE_INCORRECT_DIMENSIONS`): o paywall aberto já com o
  anual.
- Mandar os anuais junto com a versão que traz os limites novos, na mesma
  submissão. A resposta pronta, se a Apple perguntar, está em
  `ios/fastlane/app_review_reply_iap.txt`; as notas da revisão já citam os
  seis IDs.
- O lane `Promote Release` do iOS envia sozinho para revisão e não anexa
  assinatura: anexar à mão no App Store Connect.

## 2. Google Play Console

Caminho: Play Console > PraticOS > Monetizar > Produtos > Assinaturas.

### 2.1 Produtos anuais

Criar uma assinatura por plano anual, com o mesmo ID usado na Apple:

| ID do produto | Plano base | Renovação | Preço Brasil |
|---|---|---|---|
| `praticos_starter_annual` | `annual` | Renovação automática, 1 ano | R$ 599,00 |
| `praticos_pro_annual` | `annual` | Renovação automática, 1 ano | R$ 1.190,00 |
| `praticos_business_annual` | `annual` | Renovação automática, 1 ano | R$ 2.490,00 |

Nos mensais, conferir o plano base mensal: R$ 59,90, R$ 119,00 e R$ 249,00.
Outros países: deixar o Google converter. Sem oferta de teste ou introdutória.
Ativar os planos base.

Se preferir um produto só por plano (mensal e anual como dois planos base da
mesma assinatura), o ID do anual na RevenueCat passa a ser
`praticos_starter_monthly:annual`, e o nome "monthly" no ID fica enganoso.
Por isso a recomendação é produto separado.

### 2.2 Nome e benefícios

Limites do Google: nome com até 55 caracteres, até 4 benefícios com até 40
caracteres cada, descrição com até 80. Mensal e anual do mesmo plano usam os
mesmos textos.

**Português (Brasil)**

| Plano | Nome | Benefícios |
|---|---|---|
| Starter | PraticOS Starter | Nota fiscal de serviço · PDF e recibo só com a sua marca · Checklists do seu jeito · Até 50 OS por mês e 2 pessoas |
| Pro | PraticOS Pro | Tudo do Starter · Até 150 OS por mês e 5 pessoas · Agenda e permissões de cada pessoa · Etapas, painel na TV e contratos |
| Business | PraticOS Business | Tudo do Pro · Até 500 OS por mês e 20 pessoas · Ações em várias OS de uma vez · Conexão com ChatGPT, Claude e API |

Descrições: Starter "Para quem trabalha sozinho e emite nota", Pro "Para
equipe pequena", Business "Para empresa".

**English (United States)**

| Plano | Nome | Benefícios |
|---|---|---|
| Starter | PraticOS Starter | Service invoices (Brazil) · PDF and receipt with only your brand · Your own checklists · Up to 50 orders a month and 2 people |
| Pro | PraticOS Pro | Everything in Starter · Up to 150 orders a month and 5 people · Schedule and roles for each person · Job stages, TV board and contracts |
| Business | PraticOS Business | Everything in Pro · Up to 500 orders a month, 20 people · Actions on many orders at once · ChatGPT, Claude connection and API |

Descrições: Starter "For those who work alone and issue invoices", Pro "For a
small team", Business "For companies".

**Español (España)**

| Plano | Nome | Benefícios |
|---|---|---|
| Starter | PraticOS Starter | Factura de servicio (Brasil) · PDF y recibo solo con tu marca · Tus propios checklists · Hasta 50 órdenes al mes y 2 personas |
| Pro | PraticOS Pro | Todo lo del Starter · Hasta 150 órdenes al mes y 5 personas · Agenda y permisos de cada persona · Etapas, panel en la TV y contratos |
| Business | PraticOS Business | Todo lo del Pro · Hasta 500 órdenes al mes, 20 personas · Acciones en varias órdenes a la vez · Conexión con ChatGPT, Claude y API |

Descrições: Starter "Para quien trabaja solo y emite factura", Pro "Para un
equipo pequeño", Business "Para empresas".

## 3. RevenueCat

Caminho: app.revenuecat.com > projeto PraticOS.

### 3.1 Produtos e entitlements

1. Product catalog > Products: importar os três anuais da App Store e os três
   do Play (no Play aparecem como `praticos_starter_annual:annual` etc.).
2. Ligar cada produto ao entitlement do plano: Starter mensal e anual em
   `starter`, Pro em `pro`, Business em `business`.

### 3.2 Oferta `default`

Seis pacotes, um por produto, com os IDs:

| Pacote | App Store | Play |
|---|---|---|
| `starter_monthly` | `praticos_starter_monthly` | `praticos_starter_monthly` (plano base mensal) |
| `starter_annual` | `praticos_starter_annual` | `praticos_starter_annual:annual` |
| `pro_monthly` | `praticos_pro_monthly` | `praticos_pro_monthly` (plano base mensal) |
| `pro_annual` | `praticos_pro_annual` | `praticos_pro_annual:annual` |
| `business_monthly` | `praticos_business_monthly` | `praticos_business_monthly` (plano base mensal) |
| `business_annual` | `praticos_business_annual` | `praticos_business_annual:annual` |

Se os pacotes mensais atuais tiverem outros IDs, manter os que existem: o app
não lê ID de pacote, só abre o paywall.

### 3.3 Paywall

No paywall da oferta `default`: três abas ou cartões (Starter, Pro,
Business), chave Mensal/Anual, mesma ordem da tabela. O preço vem da loja,
nunca digitado. Textos em pt, en e es:

**Português**

- Título: `Escolha o plano do seu trabalho`
- Subtítulo: `A IA vem incluída em todos os planos.`
- Chave: `Mensal` / `Anual (pague 10 meses)`
- Starter, "Para quem trabalha sozinho e emite nota":
  - Até 50 OS por mês e 2 pessoas
  - Nota fiscal de serviço
  - PDF e recibo só com a sua marca
  - Checklists do seu jeito
  - Pedido de avaliação ao cliente
  - Cobrança ao cliente
- Pro, "Para equipe pequena". Tudo do Starter, mais:
  - Até 150 OS por mês e 5 pessoas
  - O que cada pessoa pode ver e fazer
  - Agenda de cada pessoa
  - Etapas do serviço e painel na TV
  - Contratos
  - IA no financeiro e relatório em planilha
- Business, "Para empresa". Tudo do Pro, mais:
  - Até 500 OS por mês e 20 pessoas
  - Ações em várias OS de uma vez
  - Conexão com ChatGPT e Claude
  - API
- Botão: `Assinar {{ product.store_product_name }}` ou `Continuar`
- Rodapé: `Renova sozinho. Cancele quando quiser na loja.` + Restaurar
  compras, Termos e Privacidade (já existem).

**English**

- Title: `Pick the plan for your work`
- Subtitle: `AI is included in every plan.`
- Toggle: `Monthly` / `Yearly (pay for 10 months)`
- Starter, "For those who work alone and issue invoices":
  - Up to 50 work orders a month and 2 people
  - Service invoices (Brazil)
  - PDF and receipt with only your brand
  - Your own checklists
  - Rating requests to customers
  - Payment requests to customers
- Pro, "For a small team". Everything in Starter, plus:
  - Up to 150 work orders a month and 5 people
  - What each person can see and do
  - A schedule for each person
  - Job stages and a TV board
  - Contracts
  - AI in the financial tab and spreadsheet reports
- Business, "For companies". Everything in Pro, plus:
  - Up to 500 work orders a month and 20 people
  - Actions on many work orders at once
  - Connection to ChatGPT and Claude
  - API
- Footer: `Renews automatically. Cancel anytime in the store.`

**Español**

- Título: `Elige el plan para tu trabajo`
- Subtítulo: `La IA viene incluida en todos los planes.`
- Selector: `Mensual` / `Anual (pagas 10 meses)`
- Starter, "Para quien trabaja solo y emite factura":
  - Hasta 50 órdenes al mes y 2 personas
  - Factura de servicio (Brasil)
  - PDF y recibo solo con tu marca
  - Tus propios checklists
  - Petición de valoración al cliente
  - Cobros al cliente
- Pro, "Para un equipo pequeño". Todo lo del Starter, y además:
  - Hasta 150 órdenes al mes y 5 personas
  - Lo que cada persona puede ver y hacer
  - Agenda de cada persona
  - Etapas del trabajo y panel en la TV
  - Contratos
  - IA en el financiero e informes en hoja de cálculo
- Business, "Para empresas". Todo lo del Pro, y además:
  - Hasta 500 órdenes al mes y 20 personas
  - Acciones en varias órdenes a la vez
  - Conexión con ChatGPT y Claude
  - API
- Pie: `Se renueva solo. Cancela cuando quieras en la tienda.`

Publicar o paywall só junto com a versão do app que tem os limites novos.

## 4. Conferir depois

- [ ] Sandbox iOS: comprar Starter anual, trocar para Pro mensal, restaurar em
      outro aparelho; conferir `companies/{id}.subscription.plan` no Firestore.
- [ ] Play (testador de licença): o mesmo.
- [ ] Paywall nos três idiomas, com texto grande, mostrando os seis preços.
- [ ] Subir a ficha (descrição, promocional, notas) pelo fluxo de
      `docs/STORE_LISTING.md`, na mesma semana da versão.
