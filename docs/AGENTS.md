# AGENTS.md - Guia para Agentes de IA

Este documento fornece contexto e diretrizes para agentes de IA trabalharem no projeto PraticOS.

## Visão Geral do Projeto

**PraticOS** é um aplicativo Flutter para gestão de ordens de serviço (OS) com:
- Multi-tenancy (isolamento por empresa/tenant)
- Firebase como backend (Firestore, Auth, Storage)
- MobX para gerenciamento de estado reativo
- Arquitetura em camadas bem definida

---

## Arquitetura

```
┌─────────────────────────────────────────┐
│         UI Layer (Screens/Widgets)      │  lib/screens/
├─────────────────────────────────────────┤
│     State Management Layer (MobX)       │  lib/mobx/
├─────────────────────────────────────────┤
│      Business Logic (Repositories)      │  lib/repositories/
├─────────────────────────────────────────┤
│     Data Models (JSON Serializable)     │  lib/models/
├─────────────────────────────────────────┤
│  External Services (Firebase, Storage)  │  lib/services/
└─────────────────────────────────────────┘
```

### Fluxo de Dados

```
Firebase (Backend)
    ↓
Repositories (Acesso a dados)
    ↓
Stores (Estado reativo - MobX)
    ↓
UI Screens (Observer widgets)
    ↓
Interação do Usuário
```

---

## Estrutura de Pastas

```
lib/
├── main.dart                    # Entry point, rotas, Firebase init
├── global.dart                  # Estado global (currentUser, companyAggr)
├── models/                      # Modelos de dados
│   ├── base.dart               # Classe base (id)
│   ├── base_audit.dart         # Campos de auditoria
│   ├── base_audit_company.dart # Multi-tenancy
│   ├── order.dart              # Order + OrderAggr + OrderService + OrderProduct
│   ├── order_photo.dart        # Fotos da OS
│   ├── customer.dart           # Cliente
│   ├── product.dart            # Produto
│   ├── service.dart            # Serviço
│   ├── device.dart             # Dispositivo/Veículo
│   ├── company.dart            # Empresa/Tenant
│   ├── user.dart               # Usuário
│   └── *.g.dart                # Arquivos gerados (JSON)
├── mobx/                        # Stores MobX
│   ├── order_store.dart        # Estado de ordens
│   ├── customer_store.dart     # Estado de clientes
│   ├── product_store.dart      # Estado de produtos
│   ├── service_store.dart      # Estado de serviços
│   ├── device_store.dart       # Estado de dispositivos
│   ├── auth_store.dart         # Autenticação
│   ├── company_store.dart      # Empresa
│   └── *.g.dart                # Arquivos gerados (MobX)
├── repositories/                # Camada de dados
│   ├── repository.dart         # Base genérica
│   ├── order_repository.dart
│   ├── customer_repository.dart
│   └── ...
├── screens/                     # Telas UI
│   ├── order_form.dart         # Formulário de OS
│   ├── menu_navigation/        # Navegação principal
│   ├── customers/              # Telas de cliente
│   ├── dashboard/              # Dashboard financeiro
│   └── widgets/                # Widgets reutilizáveis
└── services/                    # Serviços externos
    └── photo_service.dart      # Firebase Storage
```

---

## Padrões de Código

### 1. Modelos (Models)

**Hierarquia de herança:**
```dart
Base                        // id, toJson()
└── BaseAudit              // createdAt, createdBy, updatedAt, updatedBy
    └── BaseAuditCompany   // company (multi-tenancy)
```

**Padrão: Classe Full + Aggregate**

Cada entidade tem DUAS classes:

```dart
// Classe completa - todos os campos
@JsonSerializable(explicitToJson: true)
class Customer extends BaseAuditCompany {
  String? name;
  String? phone;
  String? email;
  // ... todos os campos

  Customer();
  factory Customer.fromJson(Map<String, dynamic> json) => _$CustomerFromJson(json);
  Map<String, dynamic> toJson() => _$CustomerToJson(this);
  CustomerAggr toAggr() => _$CustomerAggrFromJson(this.toJson());
}

// Classe agregada - apenas campos essenciais (para embedar em outros docs)
@JsonSerializable()
class CustomerAggr {
  String? id;
  String? name;
  String? phone;

  CustomerAggr();
  factory CustomerAggr.fromJson(Map<String, dynamic> json) => _$CustomerAggrFromJson(json);
  Map<String, dynamic> toJson() => _$CustomerAggrToJson(this);
}
```

### 2. Repositories

**Estrutura base:**
```dart
class CustomerRepository extends Repository<Customer> {
  static String collectionName = 'customers';

  CustomerRepository() : super(collectionName);

  @override
  Customer fromJson(data) => Customer.fromJson(data);

  @override
  Map<String, dynamic> toJson(Customer customer) => customer.toJson();

  // Métodos customizados com filtro de tenant
  Future<List<Customer>> getCustomers() async {
    String? companyId = prefs.getString('companyId');

    return getQueryList(
      args: [QueryArgs('company.id', companyId)],  // SEMPRE filtrar por company
      orderBy: [OrderBy('name')],
    );
  }
}
```

**IMPORTANTE:** Toda query DEVE incluir `QueryArgs('company.id', companyId)` para garantir isolamento de tenant.

### 3. Stores (MobX)

**Estrutura padrão:**
```dart
import 'package:mobx/mobx.dart';
part 'customer_store.g.dart';

class CustomerStore = _CustomerStore with _$CustomerStore;

abstract class _CustomerStore with Store {
  final CustomerRepository repository = CustomerRepository();

  // Observables
  @observable
  ObservableStream<List<Customer>>? customerList;

  @observable
  Customer? customer;

  // Computed
  @computed
  String? get customerName => customer?.name;

  // Actions
  @action
  void loadCustomers() {
    customerList = repository.streamQueryList(
      args: [QueryArgs('company.id', companyId)],
    ).asObservable();
  }

  @action
  Future<void> saveCustomer(Customer c) async {
    c.company = Global.companyAggr;
    c.createdAt = DateTime.now();
    c.createdBy = Global.userAggr;
    await repository.createItem(c);
  }
}
```

### 4. Telas (Screens)

**Padrão com Observer:**
```dart
class CustomerListScreen extends StatefulWidget {
  @override
  _CustomerListScreenState createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  late CustomerStore _store;

  @override
  void initState() {
    super.initState();
    _store = CustomerStore();
    _store.loadCustomers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Observer(
        builder: (_) {
          final customers = _store.customerList?.value ?? [];
          return ListView.builder(
            itemCount: customers.length,
            itemBuilder: (context, index) => CustomerTile(customer: customers[index]),
          );
        },
      ),
    );
  }
}
```

---

## Multi-Tenancy

### Onde o `companyId` é aplicado:

1. **Modelos:** Todo modelo que estende `BaseAuditCompany` tem campo `company`
2. **Repositories:** Toda query inclui `QueryArgs('company.id', companyId)`
3. **Stores:** Ao criar entidades, atribui `entity.company = Global.companyAggr`
4. **Storage:** Fotos salvas em `tenants/{companyId}/orders/{orderId}/photos/`

### Fluxo de autenticação:

```
Login (Google Sign-In)
    ↓
Firebase Auth retorna User
    ↓
AuthStore busca/cria Company do usuário
    ↓
Salva companyId no SharedPreferences
    ↓
Todas queries filtram por company.id
```

---

## Convenções de Nomenclatura

### Arquivos
- Screens: `*_screen.dart` ou `*_form.dart`
- Modals: `modal_*.dart`
- Widgets: `*_widget.dart`
- Models: singular (`order.dart`, `customer.dart`)
- Stores: `*_store.dart`
- Repositories: `*_repository.dart`

### Classes
- Models: PascalCase (`Order`, `Customer`)
- Aggregates: sufixo `Aggr` (`OrderAggr`, `CustomerAggr`)
- Stores: sufixo `Store` (`OrderStore`)
- Repositories: sufixo `Repository` (`OrderRepository`)

### Coleções Firebase
- Lowercase, plural: `orders`, `customers`, `products`, `services`, `devices`

---

## Como Adicionar Nova Feature

### 1. Criar Model (`lib/models/nova_entidade.dart`)

```dart
import 'package:praticos/models/base_audit_company.dart';
import 'package:json_annotation/json_annotation.dart';

part 'nova_entidade.g.dart';

@JsonSerializable(explicitToJson: true)
class NovaEntidade extends BaseAuditCompany {
  String? nome;
  double? valor;

  NovaEntidade();
  factory NovaEntidade.fromJson(Map<String, dynamic> json) => _$NovaEntidadeFromJson(json);
  Map<String, dynamic> toJson() => _$NovaEntidadeToJson(this);
  NovaEntidadeAggr toAggr() => _$NovaEntidadeAggrFromJson(this.toJson());
}

@JsonSerializable()
class NovaEntidadeAggr {
  String? id;
  String? nome;

  NovaEntidadeAggr();
  factory NovaEntidadeAggr.fromJson(Map<String, dynamic> json) => _$NovaEntidadeAggrFromJson(json);
  Map<String, dynamic> toJson() => _$NovaEntidadeAggrToJson(this);
}
```

### 2. Criar Repository (`lib/repositories/nova_entidade_repository.dart`)

```dart
import 'package:praticos/models/nova_entidade.dart';
import 'package:praticos/repositories/repository.dart';

class NovaEntidadeRepository extends Repository<NovaEntidade> {
  static String collectionName = 'nova_entidades';

  NovaEntidadeRepository() : super(collectionName);

  @override
  NovaEntidade fromJson(data) => NovaEntidade.fromJson(data);

  @override
  Map<String, dynamic> toJson(NovaEntidade entity) => entity.toJson();
}
```

### 3. Criar Store (`lib/mobx/nova_entidade_store.dart`)

```dart
import 'package:mobx/mobx.dart';
import 'package:praticos/models/nova_entidade.dart';
import 'package:praticos/repositories/nova_entidade_repository.dart';
import 'package:praticos/repositories/repository.dart';
import 'package:praticos/global.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'nova_entidade_store.g.dart';

class NovaEntidadeStore = _NovaEntidadeStore with _$NovaEntidadeStore;

abstract class _NovaEntidadeStore with Store {
  final NovaEntidadeRepository repository = NovaEntidadeRepository();
  String? companyId;

  @observable
  ObservableStream<List<NovaEntidade>>? entityList;

  @observable
  NovaEntidade? entity;

  _NovaEntidadeStore() {
    SharedPreferences.getInstance().then((prefs) {
      companyId = prefs.getString('companyId');
      loadEntities();
    });
  }

  @action
  void loadEntities() {
    entityList = repository.streamQueryList(
      args: [QueryArgs('company.id', companyId)],
      orderBy: [OrderBy('nome')],
    ).asObservable();
  }

  @action
  Future<void> saveEntity(NovaEntidade e) async {
    e.company = Global.companyAggr;
    e.createdAt = DateTime.now();
    e.createdBy = Global.userAggr;
    await repository.createItem(e);
  }

  @action
  Future<void> deleteEntity(String? id) async {
    await repository.removeItem(id);
  }
}
```

### 4. Rodar Build Runner

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 5. Criar Screens e adicionar rotas em `main.dart`

---

## Arquivos Importantes

| Arquivo | Descrição |
|---------|-----------|
| `lib/main.dart` | Entry point, rotas, inicialização Firebase |
| `lib/global.dart` | Estado global (currentUser, companyAggr, userAggr) |
| `lib/repositories/repository.dart` | Classe base genérica para todos repositories |
| `lib/models/base_audit_company.dart` | Base para entidades multi-tenant |
| `lib/mobx/order_store.dart` | Store principal, mais complexo (~700 linhas) |
| `lib/screens/order_form.dart` | Tela de OS (~990 linhas) |
| `UX_GUIDELINES.md` | Diretrizes de Design (Apple HIG) |
| `pubspec.yaml` | Dependências do projeto |
| `firestore.indexes.json` | Índices compostos do Firestore |

---

## Dependências Principais

```yaml
# Estado
mobx: ^2.3.0
flutter_mobx: ^2.2.0
mobx_codegen: ^2.7.1  # dev

# Firebase
firebase_core: ^3.14.0
cloud_firestore: ^5.6.9
firebase_auth: ^5.6.0
firebase_storage: ^12.4.4
google_sign_in: ^6.3.0

# Serialização
json_annotation: ^4.8.1
json_serializable: ^6.7.1

# Utilitários
shared_preferences: ^2.5.3
image_picker: ^1.1.2
intl: ^0.20.2
```

---

## Checklist para Novas Features

### Antes de começar:
- [ ] Entender o modelo de dados existente
- [ ] Verificar se a entidade precisa de multi-tenancy (usar `BaseAuditCompany`)
- [ ] Planejar campos do modelo e agregado

### Durante desenvolvimento:
- [ ] Criar model com `@JsonSerializable(explicitToJson: true)`
- [ ] Criar classe Aggr para referências
- [ ] Criar repository estendendo `Repository<T>`
- [ ] Criar store com observables e actions
- [ ] **SEMPRE** filtrar por `company.id` nas queries
- [ ] Rodar `flutter pub run build_runner build`

### Antes de commit:
- [ ] Verificar se `.g.dart` foram gerados
- [ ] Testar isolamento de tenant
- [ ] Remover prints de debug
- [ ] Verificar imports organizados

---

## Padrões de Query

### Query com filtros:
```dart
List<QueryArgs> args = [
  QueryArgs('company.id', companyId),           // OBRIGATÓRIO
  QueryArgs('status', 'approved'),              // Igual
  QueryArgs('total', 100, oper: 'isGreaterThan'), // Maior que
];

List<OrderBy> orderBy = [
  OrderBy('createdAt', descending: true),
];

final results = await repository.getQueryList(
  args: args,
  orderBy: orderBy,
  limit: 10,
);
```

### Stream reativo:
```dart
@observable
ObservableStream<List<Order>>? orderList;

@action
void loadOrders() {
  orderList = repository.streamQueryList(
    args: [QueryArgs('company.id', companyId)],
    orderBy: [OrderBy('createdAt', descending: true)],
  ).asObservable();
}
```

---

## Firebase Storage - Organização

Estrutura de pastas:
```
tenants/
└── {companyId}/
    └── orders/
        └── {orderId}/
            └── photos/
                ├── {timestamp1}.jpg
                └── {timestamp2}.jpg
```

---

## Temas e Cores

```dart
// Cores principais (definidas em main.dart)
primaryColor: Color(0xFF3498db)    // Azul
secondaryColor: Color(0xFFf1c40f)  // Amarelo
```

---

## Dicas para Agentes de IA

1. **Sempre verificar multi-tenancy:** Toda nova feature que lida com dados deve filtrar por `company.id`

2. **Seguir o Apple HIG:** Toda nova tela ou alteração de UI deve seguir estritamente o `UX_GUIDELINES.md` e os padrões de design da Apple (Cupertino).

3. **Usar padrão Aggregate:** Ao referenciar outras entidades, use a classe `*Aggr`

3. **Rodar build_runner:** Após modificar models ou stores, sempre rodar:
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

4. **Observer para reatividade:** Envolver widgets que dependem de estado MobX com `Observer(builder: ...)`

5. **Streams para tempo real:** Usar `streamQueryList()` para dados que precisam atualizar automaticamente

6. **SharedPreferences:** O `companyId` e `userId` ficam salvos localmente para uso offline

7. **Não editar arquivos .g.dart:** São gerados automaticamente

8. **Imports organizados:** Dart -> Flutter -> Packages -> Local -> Generated (part)

---

## Como Executar o Projeto

1. **Configurar o Flutter:** Certifique-se de ter o Flutter SDK instalado
2. **Configurar o Firebase:** Crie um projeto no Firebase e adicione os arquivos de configuração
3. **Instalar dependências:** `flutter pub get`
4. **Gerar arquivos:** `flutter pub run build_runner build --delete-conflicting-outputs`
5. **Executar:** `flutter run`
