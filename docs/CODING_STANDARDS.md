# Coding Standards - PraticOS

Este documento define os padrões de código obrigatórios para o projeto.

## Convenções de Nomenclatura

**Regra fundamental: SEMPRE use inglês para código, tipos e dados.**

### O que usar em inglês:
- Classes, variáveis, métodos, propriedades
- Constantes e Enums
- Chaves de JSON/Firestore
- Valores salvos no banco

### O que usar em português:
- Strings visíveis ao usuário (via i18n)
- Comentários (preferência por inglês)

### Exemplos

```dart
// ✅ CORRETO
class OrderStatus {
  static const pending = 'pending';
  static const approved = 'approved';
  static const completed = 'completed';
}

enum PaymentMethod { cash, creditCard, debitCard, pix }

// ❌ ERRADO
class StatusOS {
  static const pendente = 'pendente';
}
```

### Campos no Firestore

```json
{
  "status": "pending",
  "scheduledDate": "2025-01-09T10:00:00Z",
  "customer": {...},
  "paymentMethod": "creditCard"
}
```

## Padrão de Models (Full + Aggregate)

Cada entidade tem **duas classes**:

```dart
// Classe COMPLETA - todos os campos
@JsonSerializable(explicitToJson: true)
class Customer extends BaseAuditCompany {
  String? name;
  String? email;
  String? phone;
  // ... todos os campos

  CustomerAggr toAggr() => _$CustomerAggrFromJson(this.toJson());
}

// Classe AGREGADA - campos essenciais para embedar
@JsonSerializable()
class CustomerAggr {
  String? id;
  String? name;
}
```

**Quando usar:**
- `Customer` → documento principal em `/companies/{id}/customers/{id}`
- `CustomerAggr` → campo embedded em outros documentos (ex: `order.customer`)

## Stores MobX

```dart
import 'package:mobx/mobx.dart';
part 'customer_store.g.dart';

class CustomerStore = _CustomerStore with _$CustomerStore;

abstract class _CustomerStore with Store {
  final CustomerRepository repository = CustomerRepository();

  @observable
  ObservableStream<List<Customer>>? customerList;

  @action
  Future<void> load() async {
    customerList = repository.streamAll().asObservable();
  }

  @action
  Future<void> save(Customer entity) async {
    entity.company = Global.companyAggr; // Multi-tenancy
    await repository.save(entity);
  }
}
```

**Após alterar Stores/Models:**
```bash
fvm flutter pub run build_runner build --delete-conflicting-outputs
```

## Repositories

Prefira `TenantRepository` para novas features:

```dart
class CustomerRepository extends TenantRepository<Customer> {
  // Automaticamente acessa /companies/{companyId}/customers/
  // Multi-tenancy já incluso
}
```

Para queries customizadas:
```dart
Stream<List<Customer>> streamActive() {
  return streamByQuery([
    QueryArgs('status', 'active'),
  ]);
}
```

## Multi-Tenancy

**Toda operação deve considerar o `companyId`.**

| Camada | Como aplicar |
|--------|--------------|
| Models | Herdar de `BaseAuditCompany` |
| Repositories | Usar `TenantRepository` |
| Stores | `entity.company = Global.companyAggr` |
| Storage | Path `tenants/{companyId}/...` |

## Dark Mode (Cupertino)

**Cores que REQUEREM `.resolveFrom(context)`:**
```dart
// ✅ CORRETO
color: CupertinoColors.label.resolveFrom(context)
color: CupertinoColors.systemBackground.resolveFrom(context)

// ❌ ERRADO - não adapta ao dark mode
color: CupertinoColors.label
```

**Cores dinâmicas:** `label`, `secondaryLabel`, `systemBackground`, `systemGroupedBackground`, `systemGrey`, `separator`

**Cores estáticas (não precisam):** `white`, `black`, `activeBlue`, `systemRed`, `systemGreen`

## Widgets Cupertino Obrigatórios

- `CupertinoPageScaffold` + `CupertinoSliverNavigationBar`
- `CupertinoListSection.insetGrouped` para formulários
- `CupertinoAlertDialog` para confirmações
- `CupertinoActionSheet` para menus/opções
- `CupertinoSearchTextField` para busca

Ver `docs/UX_GUIDELINES.md` para detalhes completos.
