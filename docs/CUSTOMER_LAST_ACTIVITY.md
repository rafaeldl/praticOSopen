# CUSTOMER_LAST_ACTIVITY.md

## Visão Geral

Cada cliente guarda a data da última movimentação (`lastActivityAt`). A lista de
clientes do web e a aba Clientes do app abrem em **Recentes**: quem teve
movimento mais recente fica no topo. A opção **A–Z** volta para a lista por nome,
agrupada por letra. A escolha fica guardada no navegador
(`praticos.customersOrder`) e no aparelho (`customersOrder` no SharedPreferences).

Conta como movimentação:
- cliente criado;
- cadastro do cliente editado (qualquer campo);
- OS do cliente criada ou alterada (situação, itens, pagamento, data...).

## Arquitetura

- **Campo:** `companies/{companyId}/customers/{customerId}.lastActivityAt`, texto
  ISO em UTC (`2026-11-09T12:00:00.000Z`). Só o servidor grava. O app e o web
  não enviam o campo, e o app salva com `set(merge)`, então não apaga.
- **Serviço:** `firebase/functions/src/services/customer-activity.service.ts`.
- **Gatilhos** (`firebase/functions/src/index.ts`):
  - `firestoreUpdateTenantOSNumber` (OS criada) e `onOrderUpdatedAsaas` (OS
    alterada) chamam `touchCustomerOfOrder` com o cliente da OS (`customer.id`).
  - `onCustomerWrittenActivity` (cliente criado ou editado) chama
    `touchCustomerOnWrite`.
- **Lista do web:** `GET /v1/app/customers` devolve `lastActivity` em cada linha
  (`lastActivityOf` em `app-directory.service.ts`). Antes do preenchimento, usa a
  data mais recente entre `updatedAt` e `createdAt` do cliente.
- **Tela:** `firebase/webapp/src/views/customers/CustomersView.vue` (ordem
  `byRecent` em `lib/customers/model.ts`). A coluna "Última movimentação" só
  aparece quando cabe: com texto grande ou com o cliente aberto ao lado, ela some,
  mas a ordem continua.

- **App:** `Customer.lastActivityAt` só é lido (`includeToJson: false`), então
  salvar o cliente nunca grava uma data velha por cima. A aba Clientes
  (`lib/screens/menu_navigation/home_customer_list.dart`) tem o controle
  Recentes / A–Z e mostra o dia ("Hoje", "Ontem", "06/11") à direita de cada
  linha. A ordem e a data vêm de `sortByRecent` e `customerLastActivity` em
  `lib/utils/customer_utils.dart`, com a mesma regra do web para quem ainda não
  tem a data.

## Regras de Negócio

- Uma data mais antiga nunca substitui uma mais nova (eventos podem chegar fora
  de ordem ou repetidos).
- Se a data atual tem menos de 1 minuto, não grava de novo. Assim, várias
  gravações seguidas da mesma OS geram uma escrita só no cliente.
- OS que muda de cliente conta como movimentação só do cliente novo.
- Quando o servidor grava só a data, o gatilho do cliente vê que nada mais mudou
  e para (não entra em laço).
- Cliente apagado não recebe data.

## Preenchimento dos clientes que já existem

Rodar uma vez, depois do deploy das Functions:

```bash
cd firebase/functions
npx ts-node scripts/backfill-customer-activity.ts --dry-run
npx ts-node scripts/backfill-customer-activity.ts
```

Para cada cliente, usa a data mais recente entre `createdAt`/`updatedAt` do
cliente e `createdAt`/`updatedAt` das OS dele. Pode rodar de novo sem problema.
`--company=<id>` limita a uma empresa.

## Números da lista gravados no cliente

A bolinha "X OS em aberto / X OS atrasadas" e o "Falta receber" de cada linha
também ficam no próprio cliente. Assim, abrir a lista (app e web) lê só a coleção
de clientes, sem consultar OS, para quem vê todas as OS.

### Campos (só o servidor grava)

| Campo | O que é |
|-------|---------|
| `openOrders` | Quantas OS em aberto: `quote`, `approved`, `progress` (`OPEN_STATUSES` em `customer-summary.ts`). |
| `owed` | Falta receber: a regra do A receber (`customerOwed`), a mesma soma da tela do cliente. |
| `openDueDates` | Dias prometidos (`dueDate`) das OS em aberto que têm data, em ISO UTC, do mais antigo ao mais novo. O primeiro é a próxima entrega. |

Atrasada muda com o tempo, sem escrita: a tela conta quantos dias de
`openDueDates` estão antes de hoje (por dia; no web, no fuso da empresa; no app,
no fuso do aparelho, como a Início). Por isso a lista grava os dias e não um
número de atrasadas. A data sem hora (`2026-11-20`) e a data sem fuso, que o app
grava, são lidas no fuso da empresa (`instantOf`).

No app, `Customer.openOrders`, `owed` e `openDueDates` são só leitura
(`includeToJson: false`), como `lastActivityAt`.

### Como o servidor mantém

- **Serviço:** `firebase/functions/src/services/customer-aggregates.service.ts`.
- **Gatilhos:** OS criada (`firestoreUpdateTenantOSNumber`), alterada
  (`onOrderUpdatedAsaas`) e apagada (`onOrderDeletedCleanup`) chamam
  `recountCustomersOfOrder`.
- Recalcula o cliente inteiro: consulta todas as OS dele (`customer.id`, só os
  campos da conta) e grava os três campos. Evento repetido ou perdido é corrigido
  no próximo.
- Só recalcula quando muda algo que entra na conta: situação, `dueDate`, `total`,
  `paidAmount`, `payment` ou o cliente. Editar itens, fotos ou o nome do cliente
  na OS não consulta nada (o total muda junto quando um item muda de valor).
- OS que troca de cliente recalcula o antigo e o novo.
- Só grava quando um número mudou. O gatilho do cliente (`customerChanged`)
  ignora esses campos e `lastActivityAt`, então não vira movimentação nem laço.
- Sem transação: ler todas as OS do cliente numa transação travaria as OS que o
  app está editando. Duas mudanças do mesmo cliente no mesmo instante podem deixar
  a conta velha até a próxima mudança ou até rodar o preenchimento de novo.

### Quem lê o quê

- **Quem vê todas as OS** (`viewAllOrders`: dono/admin, gerente e supervisor): em aberto e
  atrasadas vêm do cliente. Nenhuma OS é lida.
- **Consultor e técnico:** veem só as OS deles (regras do Firestore). Os números
  do cliente contam as OS de todo mundo, então para eles a lista continua contando
  as OS que eles podem ler (`OrderScope` no web, `openOrdersByCustomer` no app).
- **Falta receber:** só para quem lê o Financeiro, e vem do cliente (`owed`). Antes
  já era a soma de todas as OS da empresa, não só das que a pessoa vê.

`GET /v1/app/customers` (`customerDirectory` em `app-directory.service.ts`) segue
essa regra; o front do web não mudou. No app, `HomeCustomerList` usa
`customerOpenSummary` (`lib/utils/customer_utils.dart`).

Diferenças em relação à conta antiga:
- O web somava o Falta receber pela consulta do Financeiro (`payment` `unpaid`,
  `partial` ou `null`), que não acha OS sem o campo `payment`. A soma do cliente
  usa todas as OS dele, como a tela do cliente. O app usava `getUnpaidOrders`,
  com o mesmo limite.
- O app contava as em aberto só nas últimas `kOpenOrdersLimit` OS; agora conta
  todas.

Ponto de atenção: `owed` fica no documento do cliente, que qualquer membro da
empresa pode ler pelo Firestore. A API do web só devolve `owed` para quem lê o
Financeiro, mas o app de um técnico consegue ler o campo direto.

### Preenchimento

Rodar logo depois do deploy das Functions (até lá a lista mostra os clientes sem
bolinha e sem Falta receber):

```bash
cd firebase/functions
npx ts-node scripts/backfill-customer-aggregates.ts --dry-run
npx ts-node scripts/backfill-customer-aggregates.ts
```

Conta todas as OS de cada cliente com a mesma regra do gatilho e grava só o que
mudou. Pode rodar de novo (corrige uma conta que ficou velha). `--company=<id>`
limita a uma empresa.
