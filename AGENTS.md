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

### Fluxo de Dados (Atualizado v1.0)

```
Firebase (Backend)
    ↓
Repositories (V2 / Tenant-aware)
    ↓
Stores (Estado reativo - MobX)
    ↓
UI Screens (Observer widgets)
    ↓
Interação do Usuário
```

**Nota:** O fluxo de cadastro (Signup) agora passa pelo `AuthService` para garantir a criação correta de usuários, empresas e permissões (roles) na nova estrutura multi-tenant.

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
│   ├── company_store.dart      # Empresa (Dados gerais)
│   ├── collaborator_store.dart # Gestão de Colaboradores (Novo!)
│   └── *.g.dart                # Arquivos gerados (MobX)
├── repositories/                # Camada de dados
│   ├── repository.dart         # Base genérica (Legada)
│   ├── v2/                     # Repositories V2 (Dual-Write/Read)
│   ├── tenant/                 # Repositories Tenant (Subcollections)
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
    ├── photo_service.dart      # Firebase Storage
    └── auth_service.dart       # Autenticação e Cadastro (Novo!)
```

---

## Multi-Tenancy (Arquitetura v1.0)

O sistema migrou para uma arquitetura robusta de multi-tenancy.

### Estrutura de Permissões (Roles)
- **Antiga:** Collection raiz `roles` e array `users` dentro do documento `companies`. (LEGADO)
- **Nova:** Subcollection `/companies/{companyId}/roles/{roleId}`.
- **Gerenciamento:** Feito pelo `CollaboratorStore` usando `RoleRepositoryV2`.

### Onde o `companyId` é aplicado:

1. **Modelos:** Todo modelo que estende `BaseAuditCompany` tem campo `company`
2. **Repositories:**
    - `Repository` (Legado): Filtra via `QueryArgs('company.id', companyId)`.
    - `TenantRepository`: Acessa direto a subcollection `/companies/{companyId}/...`.
    - `RepositoryV2`: Abstrai a lógica de qual usar (controlado por Feature Flags).
3. **Stores:** Ao criar entidades, atribui `entity.company = Global.companyAggr`
4. **Storage:** Fotos salvas em `tenants/{companyId}/orders/{orderId}/photos/`

### Fluxo de autenticação e Claims:

```
Login (Google/Apple)
    ↓
Firebase Auth retorna User
    ↓
Custom Claims (Cloud Function) injeta roles no token
    ↓
Security Rules validam acesso baseado nas claims
```

**Scripts de Manutenção:**
Se as permissões não atualizarem, use os scripts em `firebase/scripts/`:
- `npm run refresh-claims`: Força atualização das claims de usuários.

---

## Formulários Dinâmicos (Nova Feature)

Arquitetura para checklists, vistorias e perguntas personalizadas. Detalhes em `@docs/formularios_dinamicos.md`.

### Estrutura
- **Templates:** Definições do formulário (`FormTemplate`).
    - Escopo Empresa: `/companies/{companyId}/form_templates/{formId}`
    - Escopo Segmento (Global): `/segments/{segmentId}/form_templates/{formId}`
- **Instâncias:** Dados preenchidos vinculados à OS (`FormInstance`).
    - Path: `/companies/{companyId}/orders/{orderId}/forms/{instanceId}`
- **Fotos:** Armazenadas por item do formulário em `tenants/{companyId}/orders/{orderId}/forms/{instanceId}/items/{itemId}/`

### Regras de Negócio
1. **Obrigatoriedade:** Serviços (`Service`) e Produtos (`Product`) podem exigir templates específicos (`requiredFormTemplateRefs`).
2. **Bloqueio:** A OS não pode ser fechada/concluída se houver formulários obrigatórios com status diferente de `completed`.
3. **Validação:** Feita no client (App) antes de submeter status `completed`.

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

  CustomerAggr();
  factory CustomerAggr.fromJson(Map<String, dynamic> json) => _$CustomerAggrFromJson(json);
  Map<String, dynamic> toJson() => _$CustomerAggrToJson(this);
}
```

### 2. Repositories (V2 Preference)

Prefira usar `RepositoryV2` ou `TenantRepository` para novas features, garantindo compatibilidade futura.

**Estrutura base:**
```dart
class CustomerRepository extends Repository<Customer> {
  static String collectionName = 'customers';
  // ... implementação
}
```

**IMPORTANTE:** Toda query em repositório legado DEVE incluir `QueryArgs('company.id', companyId)`.

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

  // Actions...
}
```

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

## Dicas para Agentes de IA

1. **Multi-Tenancy é Prioridade:** Verifique sempre se está usando a estrutura correta de company/roles.
2. **UX/UI Guidelines:**
    - **App:** Cupertino/iOS-first. Siga `@docs/UX_GUIDELINES.md`.
    - **Web:** Dark Premium Theme. Siga `@docs/WEB_UX_GUIDELINES.md`.
3. **Build Runner:** `fvm flutter pub run build_runner build --delete-conflicting-outputs` é obrigatório após mudar Stores/Models.
4. **AuthService:** Use `AuthService` para criar novos usuários, não grave direto no banco.
5. **CollaboratorStore:** Use este store para gerenciar membros da equipe, não use `CompanyStore` para isso.