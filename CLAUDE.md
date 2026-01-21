# CLAUDE.md - PraticOS

Sistema de gestão de ordens de serviço (OS) em Flutter com Firebase.

## Stack

- **Flutter** (usar FVM, versão no `.fvmrc`)
- **Firebase**: Firestore, Auth, Storage
- **MobX**: Estado reativo
- **Fastlane**: Deploy iOS/Android

## Arquitetura

```
lib/
├── screens/      # UI (Cupertino-first)
├── mobx/         # Stores (*.g.dart gerados)
├── repositories/ # Acesso a dados (TenantRepository)
├── models/       # Dados (*.g.dart gerados)
├── services/     # Serviços externos
├── main.dart     # Entry point, rotas
└── global.dart   # Estado global (currentUser, companyAggr)
```

**Fluxo:** Firebase → Repositories → Stores (MobX) → UI (Observer)

## Comandos Essenciais

```bash
# Gerar código MobX/JSON (OBRIGATÓRIO após alterar Stores/Models)
fvm flutter pub run build_runner build --delete-conflicting-outputs

# Gerar traduções (OBRIGATÓRIO após alterar .arb)
fvm flutter gen-l10n

# Análise
fvm flutter analyze
```

## Regras Obrigatórias

### 1. Código em Inglês
- Classes, variáveis, enums, chaves JSON: **sempre inglês**
- UI strings: **português via i18n** (`context.l10n.chave`)

```dart
// ✅ status = 'pending', 'approved', 'completed'
// ❌ status = 'pendente', 'aprovado'
```

### 2. Multi-Tenancy
Toda operação considera `companyId`. Usar `TenantRepository` e `entity.company = Global.companyAggr`.

### 3. i18n Obrigatório
```dart
// ✅ context.l10n.save
// ❌ 'Salvar'
```

### 4. FormatService para Números/Datas
```dart
// ✅ FormatService().formatCurrency(valor)
// ❌ valor.toStringAsFixed(2)
```

### 5. Dark Mode
```dart
// ✅ CupertinoColors.label.resolveFrom(context)
// ❌ CupertinoColors.label
```

### 6. Models: Full + Aggregate
```dart
class Customer extends BaseAuditCompany { ... }  // Completo
class CustomerAggr { String? id; String? name; } // Para embedar
```

### 7. Cupertino-first
Usar `CupertinoPageScaffold`, `CupertinoListSection.insetGrouped`, `CupertinoAlertDialog`.

### 8. Conventional Commits
```bash
feat: nova funcionalidade     # Minor
fix: correção                 # Patch
feat!: breaking change        # Major
```

## Serviços Importantes

| Serviço | Uso |
|---------|-----|
| `AuthService` | Criar/autenticar usuários |
| `CollaboratorStore` | Gerenciar membros da equipe |
| `SegmentConfigService` | Labels customizados por segmento |
| `FormatService` | Formatação de números/datas/moedas |

## Estrutura Firestore

```
/companies/{companyId}/
  ├── customers/
  ├── orders/
  ├── roles/
  └── forms/

/tenants/{companyId}/orders/{orderId}/photos/  # Storage
```

## Documentação Detalhada

| Tópico | Arquivo |
|--------|---------|
| Padrões de código | `docs/CODING_STANDARDS.md` |
| i18n completo | `docs/I18N.md` |
| UX/UI iOS | `docs/UX_GUIDELINES.md` |
| UX/UI Web | `docs/WEB_UX_GUIDELINES.md` |
| Multi-tenancy | `docs/MULTI_TENANCY.md` |
| Campos por segmento | `docs/SEGMENT_CUSTOM_FIELDS.md` |
| Validações/máscaras | `docs/FIELD_VALIDATION_MASKS.md` |
| Deploy | `docs/DEPLOYMENT.md` |
| Versionamento | `docs/AUTO_VERSIONING.md` |
| Formulários dinâmicos | `docs/formularios_dinamicos.md` |
| Guia de documentação | `docs/DOCUMENTATION_GUIDE.md` |
