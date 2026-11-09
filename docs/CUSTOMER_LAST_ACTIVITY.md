# CUSTOMER_LAST_ACTIVITY.md

## Visão Geral

Cada cliente guarda a data da última movimentação (`lastActivityAt`). A lista de
clientes do web abre em **Recentes**: quem teve movimento mais recente fica no
topo. A opção **A–Z** volta para a lista por nome, agrupada por letra. A escolha
fica guardada no navegador (`praticos.customersOrder`).

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
