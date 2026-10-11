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
- "Falta receber" = soma de `total - paidAmount` das OS do cliente que não são orçamento, canceladas nem pagas (qualquer mês); só aparece com `viewPrices` e quando há saldo. "Mandar extrato em PDF" não existe ainda (não há gerador de extrato).
- "Usados por último" = clientes distintos das últimas 50 OS (sem campo novo).
- Apagar cliente não apaga as OS.

## Exemplos de Uso
```dart
final result = await Navigator.pushNamed(context, '/customer_list', arguments: {'order': order});
if (result is CustomerPick) { store.setCustomer(result.customer); /* result.device */ }
```
