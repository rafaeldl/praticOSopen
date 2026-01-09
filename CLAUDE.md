# CLAUDE.md - Instruções para Claude Code

Este documento fornece contexto e diretrizes para Claude Code trabalhar no projeto PraticOS.

## Projeto

**PraticOS** - Sistema de gestão de ordens de serviço (OS) desenvolvido em Flutter com Firebase.

### Stack Principal
- **Flutter** (versão no `.fvmrc`, usar FVM)
- **Firebase**: Firestore, Auth, Storage
- **MobX**: Gerenciamento de estado reativo
- **Fastlane**: Automação de deploy (iOS/Android)

### Arquitetura em Camadas

```
UI Layer (Screens/Widgets)       → lib/screens/
State Management (MobX)          → lib/mobx/
Business Logic (Repositories)    → lib/repositories/
Data Models (JSON Serializable)  → lib/models/
External Services                → lib/services/
```

### Fluxo de Dados

```
Firebase (Backend)
    ↓
Repositories (TenantRepository/RepositoryV2)
    ↓
Stores (MobX - estado reativo)
    ↓
UI Screens (Observer widgets)
```

## Comandos Essenciais

```bash
# Gerar código MobX/JSON (OBRIGATÓRIO após alterar Stores/Models)
fvm flutter pub run build_runner build --delete-conflicting-outputs

# Watch mode para desenvolvimento
fvm flutter pub run build_runner watch

# Análise de código
fvm flutter analyze
```

## Estrutura de Pastas

```
lib/
├── main.dart                    # Entry point, rotas, Firebase init
├── global.dart                  # Estado global (currentUser, companyAggr)
├── models/                      # Modelos de dados
│   ├── base.dart               # Classe base (id)
│   ├── base_audit.dart         # Campos de auditoria
│   ├── base_audit_company.dart # Multi-tenancy
│   └── *.g.dart                # Arquivos gerados (JSON)
├── mobx/                        # Stores MobX
│   └── *.g.dart                # Arquivos gerados (MobX)
├── repositories/                # Camada de dados
│   ├── tenant/                 # TenantRepository (subcollections)
│   └── repository.dart         # Base genérica
├── screens/                     # Telas UI
│   ├── customers/              # Módulo clientes
│   ├── dashboard/              # Dashboard financeiro
│   ├── menu_navigation/        # Navegação principal
│   └── widgets/                # Widgets reutilizáveis
└── services/                    # Serviços externos
    ├── photo_service.dart      # Firebase Storage
    └── auth_service.dart       # Autenticação
```

## Multi-Tenancy

O sistema usa isolamento por empresa (tenant). **Toda operação deve considerar o companyId**.

### Estrutura de Permissões
- **Path**: `/companies/{companyId}/roles/{roleId}`
- **Gerenciamento**: `CollaboratorStore` + `RoleRepositoryV2`

### Onde aplicar `companyId`:
1. **Models**: Herdar de `BaseAuditCompany` (campo `company`)
2. **Repositories**: Usar `TenantRepository` ou filtrar com `QueryArgs('company.id', companyId)`
3. **Stores**: Atribuir `entity.company = Global.companyAggr`
4. **Storage**: Path `tenants/{companyId}/orders/{orderId}/photos/`

## Padrões de Código

### Convenções de Nomenclatura (OBRIGATÓRIO)

**SEMPRE use inglês para código, tipos e dados:**

```dart
// ✅ CORRETO - Inglês
class OrderStatus {
  static const pending = 'pending';
  static const approved = 'approved';
  static const completed = 'completed';
}

enum PaymentMethod {
  cash,
  creditCard,
  debitCard,
  pix
}

// ❌ ERRADO - Português
class StatusOS {
  static const pendente = 'pendente';
  static const aprovado = 'aprovado';
  static const concluido = 'concluido';
}
```

**Regras:**
1. **Classes, variáveis, métodos, propriedades**: Sempre em inglês
2. **Constantes e Enums**: Sempre em inglês
3. **Chaves de JSON/Firestore**: Sempre em inglês
4. **Valores salvos no banco**: Sempre em inglês
5. **Comentários**: Podem ser em português (preferência por inglês)
6. **Strings visíveis ao usuário**: Em português (UI labels, mensagens)

**Exemplos práticos:**

```dart
// ✅ Modelo correto
class Order extends BaseAuditCompany {
  String? status; // 'pending', 'approved', 'completed'
  DateTime? scheduledDate;
  CustomerAggr? customer;
  List<OrderService>? services;
}

// ✅ Enum correto
enum UserRole {
  owner,
  admin,
  technician,
  viewer
}

// ✅ UI em português, lógica em inglês
Text(order.status == 'pending' ? 'Pendente' : 'Concluído')

// ❌ Evitar mistura
String statusDaOS = 'pendente'; // ERRADO
```

**Campos no Firestore:**
```json
{
  "status": "pending",
  "scheduledDate": "2025-01-09T10:00:00Z",
  "customer": {...},
  "paymentMethod": "creditCard"
}
```

### Modelos (Full + Aggregate)

Cada entidade tem DUAS classes:

```dart
// Classe completa - todos os campos
@JsonSerializable(explicitToJson: true)
class Customer extends BaseAuditCompany {
  String? name;
  // ... todos os campos
  CustomerAggr toAggr() => _$CustomerAggrFromJson(this.toJson());
}

// Classe agregada - campos essenciais (para embedar em outros docs)
@JsonSerializable()
class CustomerAggr {
  String? id;
  String? name;
}
```

### Stores MobX

```dart
import 'package:mobx/mobx.dart';
part 'customer_store.g.dart';

class CustomerStore = _CustomerStore with _$CustomerStore;

abstract class _CustomerStore with Store {
  final CustomerRepository repository = CustomerRepository();

  @observable
  ObservableStream<List<Customer>>? customerList;

  @action
  Future<void> load() async { ... }
}
```

### Repositories

Prefira `TenantRepository` para novas features:

```dart
class CustomerRepository extends TenantRepository<Customer> {
  // Automaticamente acessa /companies/{companyId}/customers/
}
```

## UX/UI Guidelines

### App (iOS/Cupertino-first)

**Widgets obrigatórios:**
- `CupertinoPageScaffold` + `CupertinoSliverNavigationBar`
- `CupertinoListSection.insetGrouped` para formulários
- `CupertinoAlertDialog` para confirmações
- `CupertinoActionSheet` para menus/opções
- `CupertinoSearchTextField` para busca

**Dark Mode - Cores dinâmicas:**
```dart
// CORRETO - usar .resolveFrom(context)
color: CupertinoColors.label.resolveFrom(context)

// ERRADO - não adapta ao dark mode
color: CupertinoColors.label
```

**Cores que REQUEREM `.resolveFrom(context)`:**
- `CupertinoColors.label`, `secondaryLabel`
- `CupertinoColors.systemBackground`, `systemGroupedBackground`
- `CupertinoColors.systemGrey`, `systemGrey5`
- `CupertinoColors.separator`

**Cores estáticas (não precisam de resolução):**
- `CupertinoColors.white`, `black`
- `CupertinoColors.activeBlue`, `systemRed`, `systemGreen`

**Status Indicators:**
- Usar dots coloridos (8-10px) em vez de badges pesados
- Azul = Novo/Aprovado, Verde = Concluído, Vermelho = Problema

### Web (Dark Premium Theme)

- Background: `#0A0E17` (deep blue/black)
- Gradients para CTAs
- Glassmorphism para navegação
- Fonte: `Outfit` (headings), `DM Sans` (body)

## Formulários Dinâmicos

Sistema de checklists e vistorias personalizados.

**Templates:** `/companies/{companyId}/form_templates/{formId}`
**Instâncias:** `/companies/{companyId}/orders/{orderId}/forms/{instanceId}`
**Fotos:** `tenants/{companyId}/orders/{orderId}/forms/{instanceId}/items/{itemId}/`

## Deploy

### Android (Play Store)
```bash
cd android
bundle exec fastlane internal           # Internal track
bundle exec fastlane deploy_with_metadata  # Com metadados
bundle exec fastlane promote_to_production
```

### iOS (App Store)
```bash
cd ios
bundle exec fastlane beta               # TestFlight
bundle exec fastlane release_store      # App Store
```

### CI/CD
- **Push master**: Deploy para trilhas internas (Internal/TestFlight)
- **Tag `v*`**: Deploy para produção

## Regras Importantes

1. **Inglês no Código**: SEMPRE usar inglês para classes, variáveis, constantes, enums, chaves JSON e valores no banco
2. **Multi-Tenancy é Prioridade**: Sempre verificar estrutura de company/roles
3. **Build Runner**: Executar após alterar Stores/Models
4. **AuthService**: Usar para criar novos usuários (não gravar direto no banco)
5. **CollaboratorStore**: Usar para gerenciar membros da equipe (não usar CompanyStore)
6. **Cupertino-first**: App deve parecer nativo iOS
7. **Dark Mode**: Sempre usar `.resolveFrom(context)` para cores dinâmicas

## Documentação Adicional

- `docs/UX_GUIDELINES.md` - Padrões visuais iOS/Cupertino
- `docs/WEB_UX_GUIDELINES.md` - Padrões para site institucional
- `docs/MULTI_TENANCY.md` - Detalhes da arquitetura multi-tenant
- `docs/formularios_dinamicos.md` - Especificação de checklists/vistorias
- `docs/DEPLOYMENT.md` - Guia completo de deploy
