# CUSTOMERS_SCREENS.md

## Visão Geral
Telas de clientes redesenhadas (spec `docs/superpowers/specs/2026-10-09-telas-clientes-design.md`):
aba Clientes, tela do cliente, seletor "Quem é o cliente?" e formulário em sheet.

## Arquitetura
- `lib/screens/menu_navigation/home_customer_list.dart`: aba Clientes (busca por nome, telefone ou placa; seções por letra; ponto de OS aberta/atrasada).
- `lib/screens/customers/customer_detail_screen.dart` (`/customer_detail`): Ligar, WhatsApp, "Nova OS para X", veículos e OS do cliente, "Total gasto".
- `lib/screens/customers/customer_list_screen.dart` (`/customer_list`): seletor usado pela OS. Devolve `CustomerPick(customer, device?)`.
- `lib/screens/customers/customer_form_screen.dart`: novo cliente abre em `AppSheet`; editar continua tela empurrada.
- `lib/services/customer_directory.dart`: interface de leitura/escrita das telas (implementação Firestore + fake nos testes).
- `lib/services/plate_lookup.dart`, `lib/utils/customer_utils.dart`: busca por placa e funções puras (agrupar, somar, veículos distintos).
- Componentes: `AppSheet`, `AppFormField`, `MoreFieldsLink`, `MoneyField`, `AddRow` em `lib/screens/widgets/`.

## Regras de Negócio
- Buscar pela placa no seletor escolhe o cliente e o veículo. O dono do veículo é o cliente da OS mais recente que o contém (o `Device` não guarda cliente).
- Cliente com um único veículo (nas OS dele) tem o veículo escolhido junto, a não ser que a OS já tenha veículo.
- "Total gasto" = soma do `total` das OS concluídas (`status == 'done'`).
- "Falta receber" = o A receber do Financeiro (`customerOwed`, `FinancialSummary.owesNow`): OS concluídas com saldo e OS em andamento já com parte paga. Só aparece com `viewPrices` e quando há saldo, com o link "Receber".
- "Em andamento" = OS aprovadas ou em andamento sem nada pago (`customerInProgress`), que ainda não são dívida. Aparece embaixo do "Falta receber"; quando não há nada a receber, o link "Receber" vem nela, para dar para mandar o extrato.
- "Receber" abre "Receber de {cliente}" com as OS que ele já deve marcadas e as em andamento desmarcadas; com uma OS só, abre o Receber dela. O "…" dessas telas tem "Mandar extrato". No web é igual (`CustomerDetail.vue`): o "Em andamento" sai das OS que a ficha já lê, e `ReceiveCustomerDialog` recebe as marcadas e as em andamento (`checked`, `inProgress`).
- "Usados por último" = clientes distintos das últimas 50 OS (sem campo novo).
- Apagar cliente não apaga as OS.

## Exemplos de Uso
```dart
final result = await Navigator.pushNamed(context, '/customer_list', arguments: {'order': order});
if (result is CustomerPick) { store.setCustomer(result.customer); /* result.device */ }
```
