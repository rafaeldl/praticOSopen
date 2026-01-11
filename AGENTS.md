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

### 0. Convenções de Nomenclatura (CRÍTICO)

**OBRIGATÓRIO: Código, tipos e dados SEMPRE em inglês**

```dart
// ✅ CORRETO
class OrderStatus {
  static const pending = 'pending';
  static const approved = 'approved';
  static const completed = 'completed';
  static const cancelled = 'cancelled';
}

enum PaymentMethod { cash, creditCard, debitCard, pix, bankTransfer }
enum UserRole { owner, admin, technician, viewer }

// ❌ ERRADO - NÃO usar português
class StatusOS {
  static const pendente = 'pendente';
  static const aprovado = 'aprovado';
}
```

**O que DEVE ser em inglês:**
- ✅ Classes: `Order`, `Customer`, `PaymentMethod`
- ✅ Propriedades: `scheduledDate`, `paymentMethod`, `totalAmount`
- ✅ Métodos: `calculateTotal()`, `validateStatus()`, `processPayment()`
- ✅ Constantes: `pending`, `approved`, `completed`
- ✅ Enums: `PaymentMethod.creditCard`, `UserRole.admin`
- ✅ Chaves JSON: `{"status": "pending", "scheduledDate": "..."}`
- ✅ Valores no Firestore: `status: "approved"`, `role: "technician"`

**O que PODE ser em português:**
- ✅ Strings de UI: `Text('Pendente')`, `'Total a Pagar'`
- ✅ Mensagens de erro: `'CPF inválido'`, `'Campos obrigatórios'`
- ⚠️ Comentários: Preferência por inglês, mas português é aceitável

**Exemplos práticos:**

```dart
// ✅ Correto - Modelo com lógica em inglês, UI em português
class Order extends BaseAuditCompany {
  String? status; // 'pending', 'approved', 'completed'
  DateTime? scheduledDate;
  double? totalAmount;

  String getStatusLabel() {
    switch (status) {
      case 'pending': return 'Pendente';
      case 'approved': return 'Aprovado';
      case 'completed': return 'Concluído';
      default: return 'Desconhecido';
    }
  }
}

// ✅ Correto - Repository em inglês
class OrderRepository extends TenantRepository<Order> {
  Future<List<Order>> findByStatus(String status) async {
    return await findAll(args: [QueryArgs('status', status)]);
  }
}

// ❌ ERRADO - Mistura de idiomas
class Order {
  String? statusDaOS; // ERRADO
  DateTime? dataAgendamento; // ERRADO
  double? valorTotal; // ERRADO
}
```

**Firestore Document Structure (SEMPRE inglês):**
```json
{
  "status": "pending",
  "scheduledDate": "2025-01-09T10:00:00Z",
  "totalAmount": 150.00,
  "paymentMethod": "creditCard",
  "customer": {
    "id": "abc123",
    "name": "João Silva"
  }
}
```

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

1. **🚨 INGLÊS NO CÓDIGO (CRÍTICO):** TODO código, tipos, constantes, enums, propriedades, métodos, chaves JSON e valores no banco DEVEM ser em inglês. Português apenas para UI strings visíveis ao usuário.
2. **🏷️ CONVENTIONAL COMMITS (OBRIGATÓRIO):** Usar formato padronizado para commits. Ver seção abaixo.
3. **Multi-Tenancy é Prioridade:** Verifique sempre se está usando a estrutura correta de company/roles.
4. **UX/UI Guidelines:**
    - **App:** Cupertino/iOS-first. Siga `@docs/UX_GUIDELINES.md`.
    - **Web:** Dark Premium Theme. Siga `@docs/WEB_UX_GUIDELINES.md`.
5. **Build Runner:** `fvm flutter pub run build_runner build --delete-conflicting-outputs` é obrigatório após mudar Stores/Models.
6. **AuthService:** Use `AuthService` para criar novos usuários, não grave direto no banco.
7. **CollaboratorStore:** Use este store para gerenciar membros da equipe, não use `CompanyStore` para isso.
8. **📝 DOCUMENTAÇÃO OBRIGATÓRIA:** Ao finalizar uma nova feature, SEMPRE documentar (ver seção abaixo).

---

## Conventional Commits (Versionamento Automático)

O projeto usa versionamento automático baseado em Conventional Commits. **Todo commit deve seguir o formato:**

```
<type>(<scope>): <description>
```

### Tipos de Commit e Versão Gerada

| Tipo | Descrição | Versão |
|------|-----------|--------|
| `feat` | Nova funcionalidade | **Minor** (1.0.0 → 1.1.0) |
| `feat!` | Feature com breaking change | **Major** (1.0.0 → 2.0.0) |
| `fix` | Correção de bug | **Patch** (1.0.0 → 1.0.1) |
| `perf` | Melhoria de performance | Patch |
| `refactor` | Refatoração de código | Patch |
| `docs` | Documentação | Patch |
| `style` | Formatação de código | Patch |
| `test` | Testes | Patch |
| `chore` | Manutenção | Patch |
| `ci` | CI/CD | Patch |
| `build` | Build system | Patch |

### Scopes Comuns

- `auth` - Autenticação
- `orders` - Ordens de serviço
- `customers` - Clientes
- `ui` - Interface do usuário
- `storage` - Firebase Storage
- `db` - Firestore

### Exemplos

```bash
# ✅ CORRETO

# Feature (gera Minor bump)
git commit -m "feat: add dark mode toggle"
git commit -m "feat(orders): add bulk status update"

# Fix (gera Patch bump)
git commit -m "fix: resolve crash on login"
git commit -m "fix(auth): handle expired token gracefully"

# Breaking change (gera Major bump)
git commit -m "feat!: new authentication system"
git commit -m "feat: new order flow

BREAKING CHANGE: removed 'pending_payment' status"

# Outros (geram Patch bump)
git commit -m "refactor(ui): reorganize widget structure"
git commit -m "perf: lazy load order images"
git commit -m "chore: update dependencies"
git commit -m "docs: update API documentation"
git commit -m "test: add unit tests for Order"

# ❌ ERRADO

git commit -m "add dark mode"           # Falta tipo
git commit -m "FEAT: add dark mode"     # Maiúsculo
git commit -m "feat - add dark mode"    # Formato errado
git commit -m "feat: added dark mode"   # Tempo verbal errado (usar imperativo)
git commit -m "feature: add dark mode"  # Tipo não reconhecido
```

### Regras de Prioridade

Quando múltiplos commits são analisados, o bump de maior prioridade vence:

1. **Major** - Qualquer commit com `!` ou `BREAKING CHANGE`
2. **Minor** - Qualquer commit `feat`
3. **Patch** - Todos os outros tipos reconhecidos

Ver `docs/AUTO_VERSIONING.md` para documentação completa.

---

## Documentação de Novas Funcionalidades (OBRIGATÓRIO)

**REGRA:** Toda nova funcionalidade desenvolvida DEVE ser documentada antes de ser considerada completa.

### Estrutura de Documentação

```
docs/                              # Documentação técnica (desenvolvedores)
├── FEATURE_NAME.md               # Arquitetura, fluxos, regras de negócio

firebase/hosting/public/docs/      # Documentação pública (usuários finais)
├── feature.html                  # Português (principal)
├── feature-en.html               # Inglês
├── feature-es.html               # Espanhol
└── docs.css                      # Estilos compartilhados
```

### 1. Documentação Técnica (`docs/`)

Criar arquivo `docs/FEATURE_NAME.md` contendo:

| Seção | Conteúdo |
|-------|----------|
| Visão Geral | Descrição breve da funcionalidade |
| Arquitetura | Models, Stores, Repositories envolvidos |
| Estrutura Firestore | Collections, documentos, subcollections |
| Fluxo de Dados | Diagrama ou descrição do fluxo |
| Regras de Negócio | Lista de regras implementadas |
| Permissões | Roles que têm acesso à feature |
| Exemplos de Uso | Código de exemplo (quando aplicável) |

### 2. Documentação Pública (`firebase/hosting/public/docs/`)

Para features visíveis ao usuário final, criar documentação HTML:

**Arquivos obrigatórios:**
- `feature.html` - Português (idioma principal)
- `feature-en.html` - Inglês
- `feature-es.html` - Espanhol

**Template base:**
```html
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Nome da Feature - PraticOS</title>
  <link rel="stylesheet" href="docs.css">
</head>
<body>
  <header>
    <h1>Nome da Feature</h1>
    <nav class="lang-switcher">
      <a href="feature.html" class="active">PT</a>
      <a href="feature-en.html">EN</a>
      <a href="feature-es.html">ES</a>
    </nav>
  </header>
  <main>
    <section>
      <h2>Como Funciona</h2>
      <!-- Explicação para usuário final -->
    </section>
    <section>
      <h2>Passo a Passo</h2>
      <!-- Tutorial com screenshots se necessário -->
    </section>
  </main>
  <footer>
    <a href="index.html">← Voltar para Documentação</a>
  </footer>
</body>
</html>
```

### Checklist de Documentação

Antes de considerar uma feature **COMPLETA**, verificar:

```
□ docs/FEATURE_NAME.md criado com arquitetura completa
□ firebase/hosting/public/docs/feature.html criado (PT)
□ firebase/hosting/public/docs/feature-en.html criado (EN)
□ firebase/hosting/public/docs/feature-es.html criado (ES)
□ index.html atualizado com link para nova feature (se aplicável)
□ docs.css atualizado (se novos estilos forem necessários)
```

### Matriz de Documentação

| Tipo de Mudança | docs/ (técnica) | public/docs/ (usuário) |
|-----------------|-----------------|------------------------|
| Nova feature completa | ✅ Criar | ✅ Criar (3 idiomas) |
| Mudança em feature existente | ✅ Atualizar | ✅ Atualizar |
| Bug fix | ❌ Não | ❌ Não |
| Refatoração interna | ✅ Se mudar arquitetura | ❌ Não |
| Nova API/integração | ✅ Criar | ❌ Geralmente não |

### Exemplos de Documentação Existente

**Técnica (`docs/`):**
- `docs/FINANCEIRO.md` - Sistema financeiro
- `docs/MULTI_TENANCY.md` - Arquitetura multi-tenant
- `docs/formularios_dinamicos.md` - Formulários dinâmicos
- `docs/perfis_usuarios.md` - Perfis de usuários

**Pública (`firebase/hosting/public/docs/`):**
- `financeiro.html` / `financeiro-en.html` / `financeiro-es.html`
- `perfis.html` / `perfis-en.html` / `perfis-es.html`