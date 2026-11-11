# WEB_API.md

## Visão Geral

O app web (SPA em `/web`) grava dinheiro, situação e itens da OS pela API `/v1/app`, para existir uma única versão das regras: a do servidor, igual à do app Flutter (`lib/mobx/order_store.dart`, `lib/utils/order_payment_math.dart`, `lib/services/authorization_service.dart`). Os casos em `docs/web-app/contract-cases/` provam que servidor, app e web decidem igual.

O app Flutter não chama estas rotas de OS (só `share` e `charges`, montadas no mesmo caminho). Por isso elas podem mudar sem quebrar versões instaladas. Bot e MCP continuam usando `POST /:id/services` e `/:id/products`, que passam pela mesma lógica.

Especificação completa dos corpos e respostas: `docs/api-spec.yaml` (tag `App Orders`).

## Arquitetura

| Parte | Onde |
|---|---|
| Rotas de OS | `firebase/functions/src/routes/v1/orders.routes.ts` |
| Rotas de recibo | `firebase/functions/src/routes/v1/customer-payments.routes.ts` |
| Itens, situação, pagamento | `services/order.service.ts` |
| Regras puras de itens e totais | `services/order-items.ts` |
| Tirar pagamento, zerar, marcar pago, comprovante | `services/order-finance.service.ts` |
| Apagar OS | `services/order-delete.service.ts` |
| OS parada | `services/order-hold.service.ts` |
| Etapas da OS | `services/order-stage.service.ts` (`docs/WORK_STAGES.md`) |
| Recibos | `services/customer-receipt.service.ts` |
| O que sai do servidor | `services/order-projection.ts` |
| Quem pode | `middleware/app-permission.middleware.ts` |
| Limite de taxa e CORS | `utils/app-rate-limit.utils.ts` |

### Chamada

```
Authorization: Bearer <Firebase ID token>
X-Company-Id: <companyId>
Content-Type: application/json
```

O servidor confere se o usuário é membro da empresa (`resolveCompanyContext`). O papel vem do servidor, nunca do cliente.

Respostas de `/v1/app` saem com `Cache-Control: private, no-store` (preço e cliente num computador compartilhado). Limite de taxa: 300 pedidos por minuto por usuário, contados depois de conferir o token (um escritório divide o mesmo IP), e 1.500 por minuto por IP antes do token.

## Regras de cada escrita

1. **Transação.** Toda escrita que lê a OS roda numa transação do Firestore e confere a permissão de novo na OS fresca (`guard`). Duas pessoas salvando ao mesmo tempo não perdem item uma da outra.
2. **`expectedUpdatedAt` (opcional): a versão da OS, opaca.** A leitura (`GET /orders`, `GET /orders/:id` e as respostas de escrita) traz `version`: o `updatedAt` gravado como está, sem converter fuso (texto continua texto; Timestamp vira os milissegundos). O cliente devolve esse valor igual em `expectedUpdatedAt`; quem lê do Firestore usa a mesma regra. Se a OS mudou desde então, `409 ORDER_CHANGED` e nada é gravado. Por quê: o app grava `updatedAt` em hora local sem fuso (`toIso8601String()` do Dart, com microssegundos), que o navegador e a Function leriam como instantes diferentes. Só a versão exata passa; ISO com `Z`/fuso vale apenas contra Timestamp ou texto com fuso do mesmo instante. Contra texto sem fuso (gravado pelo app), qualquer valor diferente do cru dá 409. OS sem `updatedAt` nunca recusa. Vale em `PATCH /:id`, itens, pagamento e desconto. No `DELETE`, vai na query string. Código: `services/order-version.ts`.
3. **Total do servidor.** O cliente nunca manda o total da OS. Total = soma dos itens com preço − desconto, arredondado ao centavo, nunca abaixo de 0. Produto vale o `total` da linha quando existe, senão `value × quantity`.
4. **Item sem preço.** `value: null` fica "sem valor" e fora do total. Nunca vira 0.
5. **Pago / a pagar.** Segue o total novo. Orçamento e cancelada não têm situação de pagamento (`payment: null`). Quando a situação muda só porque o total mudou, o servidor marca `paymentSyncedAt`, e o gatilho da OS não emite nota "na hora em que for pago" (não entrou dinheiro).
6. **Pagamento até o que falta.** `POST /:id/payments` recusa valor acima do que falta receber, comparando em centavos dentro da transação: `409 PAYMENT_EXCEEDS_BALANCE`, com `error.remainingBalance` (o saldo atual). Assim, web e app recebendo ao mesmo tempo não passam do total. OS de valor 0 não recebe pagamento solto: use `mark-paid`. `mark-paid` lança só o que falta e o recibo do cliente já recusa acima do aberto (`VALUE_EXCEEDS_BALANCE`). Pagamento que chega do Asaas é sempre gravado.
7. **Repetir sem gravar em dobro (`clientTransactionId`).** `POST /:id/payments` e `POST /:id/discounts` aceitam um `clientTransactionId` opcional: um uuid gerado pelo cliente (letras, números e hífen, 8 a 64). Ele vira o `id` da transação. Se a OS já tem uma transação com esse id, nada é gravado e a resposta traz o estado atual com o mesmo `transactionId` (duplo clique, nova tentativa depois de queda de rede). Mesmo id com outro tipo ou valor → `409 TRANSACTION_ID_CONFLICT`. O cliente gera um id novo para cada pagamento que o usuário pede, e reusa o mesmo só ao repetir o envio. As duas rotas aceitam também `expectedUpdatedAt` (409 `ORDER_CHANGED` sobre uma versão mais nova), conferido **depois** de procurar o `clientTransactionId`: repetir depois de a resposta se perder devolve o que já foi gravado.
8. **Data e comprovante.** `paidAt` não pode estar no futuro (folga de 5 minutos de relógio) nem antes do dia em que a OS foi criada (folga de 24 h pelo fuso). O comprovante (`receiptFile`) fica na pasta da OS (`tenants/{companyId}/orders/{orderId}/`, ou do recibo), e a `url` tem de ser a URL de download desse mesmo arquivo no bucket do projeto (`firebasestorage.googleapis.com/v0/b/{bucket}/o/…` ou `storage.googleapis.com/{bucket}/…`).
9. **Arquivo apagado só da pasta do pagamento.** Ao tirar pagamento, zerar ou trocar comprovante, o servidor só apaga do Storage o comprovante dentro da pasta daquele pagamento (`tenants/{companyId}/orders/{orderId}/payments/{transactionId}/`). Outro caminho em `documents` é mantido e registrado em log.
10. **Valores escondidos.** Sem `viewPrices` (técnico, supervisor, ou "Valores e cobrança" desligado) nenhum valor sai do servidor: total, valor e total da linha, preço de catálogo dentro da linha, pagamentos, situação de pagamento, comprovantes. Vale para lista, detalhe e respostas de escrita. Os documentos anexados à OS (`documents` que não são comprovante: sem `type: receipt` e sem `linkedTransactionId`) vão para todos que leem a OS, os mesmos que as regras do Firestore deixam ler (`services/order-projection.ts`).

### Identificador de item e de pagamento

Cada linha da resposta tem `id`. Linhas gravadas pela API guardam um `id` próprio. O app não guarda esse campo, então linhas sem ele recebem um id derivado do que a linha é (serviço/produto, item do catálogo, descrição, valores, aparelho) e da posição entre linhas iguais. Ele não muda quando outras linhas entram ou saem; quando a própria linha muda, o id antigo deixa de achar a linha (`404 ITEM_NOT_FOUND`) e o cliente recarrega. Pagamentos antigos sem `id` seguem a mesma ideia (`legacy_…`).

## Rotas

Base: `/v1/app/orders` (OS), `/v1/app/customers` (clientes e recibos), `/v1/app/devices` (aparelhos), `/v1/app/services`, `/v1/app/products` (catálogo) e `/v1/app/finance` (Financeiro).

| Rota | Quem | Observação |
|---|---|---|
| `GET /orders` | todos | Quem tem `viewAllOrders` vê todas; consultor, as que criou; técnico, as que criou e as atribuídas a ele (como `isOrderAssignee` nas regras e o `OrderScope` do app), em duas consultas unidas pela mesma ordem e cursor, sem repetir e sem `total`. Com `assignedTo=<o próprio uid>`, só as atribuídas, criadas por qualquer um. A união segue a ordem da Firestore (tipo, texto por bytes, depois o id) e não roda `count()`. `number=<n>` acha uma OS pelo número (só o índice do campo, lido em páginas até o fim; devolve só as que a pessoa vê, projetadas). Cursor, filtros e ordem abaixo |
| `GET /orders/:id` | quem vê a OS | O técnico também vê a OS atribuída a ele |
| `POST /orders` | `createOrder` | Situação inicial por papel; valor próprio exige `editPrices`; grava `deviceIds`. `clientOrderId` opcional (uuid do cliente, mesmo formato do `clientTransactionId`) vira o id da OS: repetir devolve a OS já criada (200, sem criar outra); se outra pessoa criou com esse id → `409 ORDER_ID_CONFLICT` |
| `PATCH /orders/:id` | `editOrder` | Situação: fluxo por papel. Datas: `canEditOrderMainFields` (supervisor e técnico só em orçamento). Responsável: `assignOrder` (admin, supervisor e consultor; o consultor só vê, e só troca, as que criou), nome lido do membro. `null` limpa |
| `DELETE /orders/:id` | `canDeleteOrder` | Mesma regra de `order-delete.json`. Ver "Apagar" |
| `POST /orders/:id/items` | main fields | `{kind, catalogId?, value?, quantity?, total?, description?, deviceId?}`. Valor ou total próprio exige `editPrices`. Sem `catalogId` é item avulso: `description` obrigatória, `service`/`product` gravado como `null` (como o app), sem valor fica "sem valor" |
| `PATCH /orders/:id/items/:itemId` | main fields; só `description`: quem vê a OS | Supervisor e técnico mudam a observação depois de aprovada |
| `DELETE /orders/:id/items/:itemId` | main fields | |
| `POST /orders/:id/services`, `/products` | main fields | Para bot, MCP e integrações; respondem `{success, newTotal}` |
| `POST /orders/:id/payments` | `canReceiveOnOrder` | `{amount, paidAt?, paymentMethod?, receiptFile?, description?, clientTransactionId?}`. Desconto aqui → 400 |
| `DELETE /orders/:id/payments/:transactionId` | `canReceiveOnOrder` | Pagamento do Asaas → `409 ASAAS_LOCKED`; parte de recibo → `409 RECEIPT_SHARE` |
| `POST /orders/:id/payments/mark-paid` | `canReceiveOnOrder` | Lança o que falta e marca paga (OS de valor 0 também) |
| `POST /orders/:id/payments/reset` | financeiro | Tira pagamentos e descontos feitos à mão; os do Asaas ficam |
| `PUT`/`DELETE /orders/:id/payments/:transactionId/receipt` | `canReceiveOnOrder` | Comprovante em `tenants/{companyId}/orders/{orderId}/…` |
| `POST /orders/:id/discounts` | financeiro | `{amount, description?, clientTransactionId?}`. Nunca acima do que falta |
| `DELETE /orders/:id/discounts/:transactionId` | financeiro | |
| `DELETE /orders/:id/discounts` | financeiro | Tira todo o desconto, também o que não tem transação |
| `POST /orders/:id/hold` | não consultor | `{reason, note?}`; só aprovada ou em andamento (`409 HOLD_NOT_ALLOWED`) |
| `DELETE /orders/:id/hold` | não consultor | Em qualquer situação; sem marca, nada muda |
| `PUT /orders/:id/stage` | não consultor; começar a aprovada pede a passagem para em andamento | `{stageId, rank?}`. Aprovada passa a em andamento no mesmo write; outra situação → `409 STAGE_NOT_ALLOWED`; etapa fora de `company.workStages` → `422 STAGE_UNKNOWN`. Sem `rank`, vai para o fim (hora do servidor). Mudar de etapa deixa comentário interno "Etapa: X"; reordenar, não |
| `GET /customers/:id/receipts` | quem recebe | Financeiro vê todos; consultor, os que registrou |
| `POST /customers/:id/receipts/:receiptId/cancel` | financeiro ou quem registrou | Desfaz: tira a parte de cada OS e marca `canceled`. Parte antiga sem id de transação (ou que não está mais na OS) → `409 RECEIPT_LEGACY_SHARE`, nada muda |
| `PUT`/`DELETE /customers/:id/receipts/:receiptId/file` | financeiro ou quem registrou | Comprovante em todas as OS do recibo |

### Clientes e aparelhos

`routes/v1/app-customers.routes.ts` e `app-devices.routes.ts`, com a lógica em `services/app-directory.service.ts`. Montadas antes das rotas genéricas: `/v1/customers` e `/v1/devices` (chave de API do bot e do MCP) não mudam. O app Flutter não chama estas rotas.

| Rota | Quem | Observação |
|---|---|---|
| `GET /customers` | `viewCustomers` | Todos os clientes (até 5.000; `meta.truncated` acima) com `open` e `late`: OS aprovadas e na oficina que o papel lê, atrasada pela promessa (`dueDate` antes de agora). `meta.partial` quando o papel não lê todas as OS |
| `GET /customers/:id` | `viewCustomers` | Cliente com e-mail, CPF/CNPJ, endereço e `customData`; `orders` (até 500, as que o papel lê, sem valores sem `viewPrices`); `devices` das OS com quantas OS; `spent` (soma das concluídas) e `owed` (aberto das que não são orçamento, cancelada nem paga), `null` sem `viewPrices`; `receivable`: as OS em que a pessoa pode receber, da mais antiga; `version` (opaca, como nas OS); `ordersTruncated` quando há mais de 500 (são as mais recentes por `createdAt`); `links`: total de OS, recibos e cobranças do cliente, também o que o papel não vê, sem detalhe (dito antes de apagar) |
| `POST /customers` | `manageCustomers` | `{name, phone?, email?, address?, taxId?, customData?}`. `taxId` normalizado e validado (CPF ou CNPJ, também alfanumérico): inválido → 400 |
| `PATCH /customers/:id` | `manageCustomers` | Mesmos campos, mais os dados para nota (abaixo); `null` limpa; `customData` troca o mapa inteiro. Nunca regrava `createdAt`/`createdBy`. `version` (a lida no GET): se alguém salvou depois, `409 CUSTOMER_CHANGED` e nada é gravado; a resposta traz a versão nova |
| `DELETE /customers/:id` | `manageCustomers` | As OS ficam com a cópia do cliente. Aparelhos com `nextMaintenanceCustomer.id` dele ficam só com o nome |
| `POST /customers/import` | `manageCustomers` | `{importId, customers: [...]}`, até 500 por chamada; cada linha vira o documento `{importId}-{n}`, então repetir devolve `existing` em vez de criar de novo. Uma linha inválida recusa a chamada (400) |
| `GET /devices` | `viewDevices` | Todos os aparelhos com situação e `nextMaintenanceDate` |
| `GET /devices/:id` | `viewDevices` | Aparelho com `customData` e a próxima manutenção; `orders` que o papel lê (por `deviceIds` e pelo `device` antigo); `owner` = cliente da OS mais recente entre todas; `lastService` = serviço principal da última concluída |
| `POST /devices`, `PATCH /devices/:id` | `manageDevices` | Modelo ou série obrigatório; série com `trim` e maiúsculas; `status` em `active`, `maintenance`, `inactive`, `decommissioned`. Editar nunca mexe na próxima manutenção. `version` no PATCH: `409 DEVICE_CHANGED` quando mudou. `photo: {url, storagePath}` só no PATCH (o aparelho precisa existir para ter a pasta): arquivo da pasta `tenants/{empresa}/devices/{id}/` e a URL de download desse mesmo arquivo no bucket do projeto, senão `400`; só troca, sem tirar (como o app). Trocar apaga o arquivo antigo se for outro arquivo da mesma pasta |
| `DELETE /devices/:id` | `manageDevices` | |
| `PUT /devices/:id/next-maintenance` | `manageDevices` | `{date: 'AAAA-MM-DD' \| null}`; só de hoje (Brasília) em diante. Grava dono e último serviço, ou mantém o cliente antigo sem dono conhecido, e apaga `nextMaintenanceNoticeFor`. `null` tira data, cliente e serviço |

Dados para nota (NFS-e direta, `docs/NFSE_DIRECT.md`) no `POST` e no `PATCH`: `legalName`, `fiscalAddress {postalCode (8 dígitos), street, number, complement, district, cityCode (IBGE, 7 dígitos), cityName, state (UF)}`, `invoiceEmail`, `autoIssueInvoice` e `invoiceRecipientId` (outro cliente da empresa; o servidor grava o resumo dele em `invoiceRecipient`, e o próprio cliente, um inexistente ou de outra empresa dá `400 INVOICE_RECIPIENT_INVALID`). O `GET /customers/:id` devolve esses campos, com `invoiceRecipient {id, name}`; o `GET /customers` traz `legalName`. CPF/CNPJ repetido é conferido pela tela, como no app.

Testes: `routes/v1/__tests__/app-directory.routes.test.ts` e os casos `customers.*`/`devices.*` de `__tests__/rbac/api-matrix.ts`.

### Catálogo

`routes/v1/app-catalog.routes.ts` (um roteador por tipo: `catalogRoutes('service')` em `/v1/app/services` e `catalogRoutes('product')` em `/v1/app/products`), com a lógica em `services/app-catalog.service.ts`. `/v1/services` e `/v1/products` (chave de API do bot e do MCP) não mudam. O app Flutter não chama estas rotas.

| Rota | Quem | Observação |
|---|---|---|
| `GET /` | `viewServices` / `viewProducts` | Todos os itens (até 5.000; `meta.truncated` acima) com `name`, `photo`, `customData` e `version`. **`value` só com `viewPrices`**: sem ele o campo não vem, nem como `null`. `meta.prices` diz se veio. `meta.mostUsed`: até 5 ids do tipo mais usados nas últimas 50 OS que o papel lê (consultor: as que criou), empate pelo uso mais recente (`mostUsedItemKeys` do app), só itens que ainda existem; falha nessa conta não derruba a lista |
| `GET /:id` | mesmo | Mesma projeção |
| `POST /` | `manageServices` / `manageProducts` | `{name, value?, customData?}`. Nome sem espaços nas pontas; preço arredondado ao centavo; `company` da sessão; `createdAt`/`createdBy` só aqui. Mandar `value` (também `null`) exige `editPrices` |
| `PATCH /:id` | mesmo | `{name?, value?, customData?, photo?, version?}`. Nunca regrava `createdAt`/`createdBy`. `value` exige `editPrices`; sem ele o preço guardado fica. `photo: {url, storagePath}` só de um arquivo em `tenants/{companyId}/{services\|products}/{id}/` do bucket do projeto (no emulador, a URL `http` do emulador de Storage); `photo: null` tira a foto e exige `photoSeen` (a URL que a pessoa viu): se o app trocou a foto no meio tempo (ele não muda `updatedAt`), `409` e nada é apagado; senão apaga só o arquivo daquela URL, nunca a pasta. `version` velha → `409 CATALOG_ITEM_CHANGED` |
| `DELETE /:id` | mesmo | Apaga o item e a pasta da foto. As OS ficam com a cópia |
| `POST /import` | mesmo | `{importId, items: [{name, value?}]}`, até 500 por chamada; cada linha vira `{importId}-{n}`, então repetir devolve `existing`. O mesmo `importId` com outro conteúdo → `409 IMPORT_ID_CONFLICT` (`error.lines`) e nada gravado. Uma linha inválida recusa a chamada. Algum `value` exige `editPrices` |
| `POST /prices` | manage e `editPrices` | `{batchId?, changes: [{id, from, to}]}`, até 500 e sem id repetido, numa transação só (todos ou nenhum), com uma leitura (`getAll`). `batchId` fica no item (`priceBatchId`); o web manda a mesma chave e os mesmos `from` em cada nova tentativa. `from` é o preço que a pessoa viu: item já em `to` fica (repetir depois de a resposta se perder), item em `from` muda, qualquer outro valor (ou item apagado) → `409 CATALOG_ITEM_CHANGED` com `error.ids` e nada gravado. Compara em centavos. Resposta `{updated, unchanged}` |

Testes: `routes/v1/__tests__/app-catalog.routes.test.ts` e os casos `catalog.*` e `nofin.catalog.price` de `__tests__/rbac/api-matrix.ts`.

### Financeiro

`routes/v1/app-finance.routes.ts`, com a lógica em `services/app-finance.service.ts` e o fuso em `utils/company-zone.ts`. Só quem tem `viewFinancialReports` (dono, admin e gerente, com "Valores e cobrança" ligado): o resto recebe 403 antes de qualquer validação, sem número nenhum. Os números são somados aqui, em centavos, e o navegador não lê OS para isso. O app Flutter não chama estas rotas.

| Rota | O quê |
|---|---|
| `GET /finance/summary?month=AAAA-MM` | Recebido e Vendido do mês, A receber e Em andamento de hoje, com as linhas de cada lista (`received`, `sold`, `receivable.debtors`/`deposits`, `progress`). Sem `month`, o mês atual |
| `GET /finance/report?from=AAAA-MM-DD&to=AAAA-MM-DD` | Faturamento, já pago, a receber, quantidade, composição, ranking de clientes, serviços e produtos, e as OS do período. `customer=<id>` (ou `none`) estreita tudo menos o ranking de clientes; `payment=paid\|unpaid` estreita a lista de OS, a composição e os rankings de serviços e produtos (como o app), não os totais nem o ranking de clientes. Até 4.000 dias |
| `GET /finance/receivable` | Financeiro > Receber: toda OS que ainda deve (concluída com saldo e aberta com sinal), da mais antiga |

Regras (contrato `docs/web-app/contract-cases/finance-summary.json`, as mesmas de `lib/utils/financial_summary.dart` e do relatório do app):

- **Dias da empresa.** `zone` (o fuso do navegador) só vale se for um fuso do país da empresa; senão, o principal do país (`companyZone`, igual a `lib/zone.ts` do web). Texto sem fuso, como o app grava, é hora da empresa. O período inclui o último dia (o app deixava de fora, defeito 60).
- **Recebido** pela data de cada pagamento (`paidAt`, senão `createdAt`), em OS de qualquer mês (achadas por `lastPaymentAt`, com a mesma folga de 14 h: o campo lê o texto sem fuso do app como -03:00, e uma empresa a oeste de Brasília que recebe logo depois da meia-noite do dia 1 ficaria de fora). Dinheiro antigo sem transação conta no dia da OS; `payment: 'paid'` sem `paidAmount` conta o total.
- **Vendido e faturamento**: OS criadas no período, sem orçamento nem cancelada.
- **Em aberto**: `payment` `unpaid` ou `partial`, e aprovada, em andamento ou concluída sem `payment`. Cada OS conta num lugar: concluída com saldo e aberta com sinal em A receber; aberta sem nada pago em Em andamento.
- **Relatório**: "a receber" é tudo que não está pago (também parcial e sem situação; o app listava só `unpaid`, defeito 58).
- Leitura em páginas de 1.000, até 20.000 OS por resposta, somando todas as consultas dela: rodam uma depois da outra no mesmo limite (primeiro as em aberto), então nunca passam disso. Acima, `truncated: true` e a tela avisa; `read` diz quantas foram lidas. As em aberto vêm na ordem dos ids (nenhum índice de campo único as ordena por data), então a que falta pode ser qualquer uma. As datas gravadas como texto são comparadas como texto, então a consulta pede 14 h a mais de cada lado e cada OS é posta no dia pelo fuso.

Testes: `routes/v1/__tests__/app-finance.routes.test.ts`, `__tests__/contract-cases.test.ts` e os casos `finance.*` e `nofin.finance.*` de `__tests__/rbac/api-matrix.ts`.

### Primeiro acesso

`routes/v1/onboarding.routes.ts`, com a lógica em `services/onboarding-seed.service.ts` e `services/bootstrap-server.service.ts`. O navegador cria a empresa com o mesmo lote do app (`users/{uid}`, `companies/{id}`, `companies/{id}/memberships/{uid}`, sob as regras `createsOwnCompanyInBatch`), espera a claim e chama esta rota com a empresa nova no `X-Company-Id`.

| Rota | O quê |
|---|---|
| `POST /onboarding/seed` `{withSamples, locale}` | Copia os checklists ativos do ramo (sempre) e, com `withSamples`, serviços, produtos, aparelhos, o cliente de exemplo e quatro OS de exemplo (orçamento, aprovada, em andamento, concluída; entrega amanhã e a cada dois dias, às 09:00 da empresa; a primeira com o primeiro checklist). `locale`: `pt-BR`, `en-US` ou `es-ES` |

- Só `manageCompany` (dono e admin). Ramo, especialidades, nomes e país vêm do documento da empresa, nunca do pedido. Sem especialidade marcada num ramo que tem, usa todas (`seedSubspecialties`, igual a `OnboardingBusiness.seedSubspecialties`).
- Uma vez por empresa: numa transação, grava `onboardingSeededAt` antes de copiar. Já marcada: `409 ONBOARDING_ALREADY_SEEDED`. Criada há mais de um dia ou sem `createdAt` (empresa antiga): `409 ONBOARDING_NOT_NEW`. Nos dois casos nada é gravado.
- Checklists com `create`, só os que faltam: um modelo da empresa nunca é regravado. OS de exemplo com ids `sample-order-1..4`, pagamento nulo como no app.
- `executeServerBootstrap` (o mesmo do cadastro pelo WhatsApp) ganhou as OS de exemplo do app e copia os checklists antes delas.

Testes: `routes/v1/__tests__/onboarding.routes.test.ts` e o caso `onboarding.seed` de `__tests__/rbac/api-matrix.ts`.

**Quem recebe (`canReceiveOnOrder`)**: dono, admin e gerente em qualquer OS; consultor nas OS que criou, com "Valores e cobrança" ligado. Supervisor e técnico nunca. Igual a `canReceiveOnOrderFor` no app e a `canReceiveOnOrder` nas regras do Firestore.

**Financeiro**: `viewFinancialReports` (dono, admin, gerente), com "Valores e cobrança" ligado.

### Lista

`GET /orders?limit=20&cursor=<id>&status=approved,progress&sort=createdAt&direction=desc`

- `limit` até 100; `cursor` é o `pagination.nextCursor` da página anterior.
- `status`: uma ou várias situações separadas por vírgula.
- `sort`: `createdAt` (padrão, mais nova primeiro), `updatedAt`, `number`, `dueDate`, `scheduledDate` (estas duas, mais próxima primeiro). OS sem o campo da ordem ficam fora.
- Filtros: `customerId`, `deviceId`, `assignedTo`, `startDate`/`endDate`. O intervalo vale no campo da ordem: `createdAt`, `scheduledDate` ou `dueDate` (a agenda pede `sort=scheduledDate&startDate=…&endDate=…`); com outra ordem → `400`. As datas ficam gravadas como texto ISO e são comparadas como texto. O app grava visita e entrega em hora local sem fuso, então quem pede folga o intervalo (o web usa 14 h de cada lado) e põe cada OS no dia pelo fuso da empresa.
- `POST` e `PATCH` aceitam `dueDate`/`scheduledDate` com fuso (gravado em UTC) ou sem fuso (`yyyy-mm-ddTHH:mm[:ss[.ffffff]]`, hora local da empresa, gravado como veio, como o app grava). Assim o valor lido no GET pode voltar igual no PATCH. O web grava sem fuso.
- `dueDate` e `scheduledDate` saem como foram gravados quando são texto sem fuso (gravados pelo app, hora local da empresa); com fuso ou Timestamp, saem em UTC. Antes eles viravam UTC lidos no fuso da Function, o que mudava a hora pelo fuso da empresa.
- Cada linha traz `createdBy` (como o detalhe): consultor e técnico só mudam a OS que criaram.
- Combinação sem índice no Firestore → `400 UNSUPPORTED_QUERY`.
- `pagination.total` só na primeira página.

### Apagar

1. Papel: `canDeleteOrder` (admin sempre; gerente e supervisor em orçamento sem dinheiro; consultor e técnico no orçamento sem dinheiro que criaram).
2. Nota fiscal ativa → `409 ORDER_HAS_INVOICE`.
3. Cobrança de várias OS aberta → `409 CUSTOMER_CHARGE_OPEN` (ela cobre outras OS: quem decide é o usuário).
4. Parcelamento com parcela paga → `409 INSTALLMENTS_IN_PROGRESS`.
5. Com cobrança aberta só desta OS, o papel é conferido de novo na OS fresca antes de cancelar qualquer coisa (se entrou dinheiro e o papel não pode mais apagar, recusa e a cobrança fica). Depois a cobrança é cancelada no Asaas. Se não cancelar, a OS fica (`502 ASAAS_UNAVAILABLE`).
6. A OS sai numa transação (o papel é conferido mais uma vez), depois comentários, formulários, fotos, cobranças, arquivos e links do cliente.

## Erros

`{ "success": false, "error": { "code": "…", "message": "…" } }`

| Código | HTTP | Quando |
|---|---|---|
| `VALIDATION_ERROR` | 400 | Corpo inválido |
| `INVALID_DEVICE` | 400 | Aparelho do item não está na OS |
| `INVALID_ASSIGNEE` | 400 | Responsável não é da empresa |
| `INVALID_CURSOR`, `UNSUPPORTED_QUERY` | 400 | Lista |
| `CUSTOMER_NOT_FOUND`, `DEVICE_NOT_FOUND` | 404 | Clientes e aparelhos |
| `INVOICE_RECIPIENT_INVALID` | 400 | "Nota fiscal para" o próprio cliente, um que não existe ou de outra empresa |
| `INVALID_FILE`, `INVALID_PAID_AT` | 400 | Comprovante fora da pasta, de outro bucket ou tipo errado; data inválida, no futuro ou antes da OS |
| `INSUFFICIENT_PERMISSIONS`, `FORBIDDEN` | 403 | Papel |
| `NOT_FOUND`, `ITEM_NOT_FOUND`, `TRANSACTION_NOT_FOUND`, `RECEIPT_NOT_FOUND` | 404 | |
| `ORDER_CHANGED` | 409 | `expectedUpdatedAt` diferente da `version` atual |
| `IMPORT_ID_CONFLICT` | 409 | `importId` do catálogo já usado com outras linhas |
| `CUSTOMER_CHANGED`, `DEVICE_CHANGED`, `CATALOG_ITEM_CHANGED` | 409 | `version` do cliente, do aparelho ou do item diferente; no catálogo, também preço em lote mudado depois (`error.ids`) |
| `ASAAS_LOCKED`, `RECEIPT_SHARE`, `RECEIPT_CANCELED`, `RECEIPT_LEGACY_SHARE`, `HOLD_NOT_ALLOWED` | 409 | Ver rotas |
| `TRANSACTION_ID_CONFLICT` | 409 | `clientTransactionId` já usado com outro tipo ou valor |
| `PAYMENT_EXCEEDS_BALANCE` | 409 | Pagamento acima do que falta; `error.remainingBalance` traz o saldo |
| `ORDER_ID_CONFLICT` | 409 | `clientOrderId` de OS criada por outra pessoa |
| `ORDER_HAS_INVOICE`, `CUSTOMER_CHARGE_OPEN`, `INSTALLMENTS_IN_PROGRESS` | 409 | Apagar |
| `ASAAS_UNAVAILABLE` | 502 | Não deu para cancelar a cobrança aberta |
| `RATE_LIMIT_EXCEEDED` | 429 | |

## Regras de Negócio (decisões)

- `done` não é mais gravado: o app não grava e ninguém lê; `status` é a fonte.
- Mudar a situação de OS antiga paga antes de existir `paidAmount` mantém a situação de pagamento (igual a `syncPaymentStatusWithTotal`).
- Pagamento e desconto acima do que falta são recusados em `POST /payments` e `POST /discounts`. O app (desde o lote 3) também recusa, em centavos, com a OS que tem: offline não pergunta ao servidor, então dois aparelhos offline ainda podem somar mais que o total.
- Marcar e retomar OS parada deixam o mesmo comentário interno do app.
- Desfazer recibo não apaga o arquivo do comprovante, que é do recibo.
- Quantidade de produto é inteira (o app lê como inteiro).

## Exemplos de Uso

```bash
# Adicionar um serviço e não sobrescrever quem salvou antes
curl -X POST "$API/v1/app/orders/$ORDER/items" \
  -H "Authorization: Bearer $TOKEN" -H "X-Company-Id: $COMPANY" \
  -H "Content-Type: application/json" \
  -d '{"kind":"service","catalogId":"s1","expectedUpdatedAt":"2026-11-03T10:00:00.000Z"}'

# Receber R$ 50 em Pix com comprovante
curl -X POST "$API/v1/app/orders/$ORDER/payments" \
  -H "Authorization: Bearer $TOKEN" -H "X-Company-Id: $COMPANY" \
  -H "Content-Type: application/json" \
  -d '{"amount":50,"paymentMethod":"pix","paidAt":"2026-11-03T12:00:00.000Z","clientTransactionId":"'$(uuidgen)'",
       "receiptFile":{"url":"https://firebasestorage.googleapis.com/v0/b/<bucket>/o/<storagePath codificado>?alt=media&token=…","storagePath":"tenants/'$COMPANY'/orders/'$ORDER'/payments/x/comprovante.jpg","contentType":"image/jpeg"}}'
```

## Testes

| Arquivo | Cobre |
|---|---|
| `firebase/functions/src/routes/v1/__tests__/orders.routes.test.ts` | Rotas, transações concorrentes, `expectedUpdatedAt`, projeção, outra empresa |
| `firebase/functions/src/routes/v1/__tests__/app-catalog.routes.test.ts` | Catálogo: preço escondido, `editPrices`, versão, foto, importação e preço em lote |
| `firebase/functions/src/routes/v1/__tests__/app-finance.routes.test.ts` | Financeiro: resumo, relatório e receber, último dia, fuso, papéis e valores desligados |
| `firebase/functions/src/__tests__/rbac/api-matrix.ts` + `rbac-api.test.ts` | Papel × rota |
| `firebase/functions/src/__tests__/contract-cases.test.ts` | `docs/web-app/contract-cases/*.json` no servidor |
| `firebase/functions/src/utils/app-rate-limit.utils.test.ts` | Limite por usuário e CORS |
| `firebase/functions/src/services/asaas/__tests__/order-trigger.service.test.ts`, `invoice.service.test.ts` | Nota automática uma vez só |
