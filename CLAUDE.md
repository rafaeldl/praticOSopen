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

**Templates:** `/companies/{companyId}/forms/{formId}`
**Instâncias:** `/companies/{companyId}/orders/{orderId}/forms/{instanceId}`
**Fotos:** `tenants/{companyId}/orders/{orderId}/forms/{instanceId}/items/{itemId}/`

## Internacionalização (i18n)

O sistema suporta múltiplos idiomas (pt-BR, en-US, es-ES) com detecção automática.

### Uso de Strings Localizadas

```dart
import 'package:praticos/extensions/context_extensions.dart';

// Strings simples
Text(context.l10n.save)
Text(context.l10n.cancel)

// Strings com parâmetros
Text(context.l10n.welcome('João'))

// Plurais (ICU format)
Text(context.l10n.itemCount(5))  // "5 itens" (pt), "5 items" (en)
```

### FormatService - Formatação Consciente de Locale

```dart
import 'package:praticos/services/format_service.dart';

final formatService = FormatService();
formatService.setLocale(AppLocalizations.of(context).localeName);

// Datas
formatService.formatDate(DateTime.now());         // 09/01/2025 (pt), 01/09/2025 (en)
formatService.formatDateTime(DateTime.now());     // 09/01/2025 14:30, 01/09/2025 2:30 PM
formatService.formatDateLong(DateTime.now());     // 9 de janeiro de 2025

// Moedas (detecta símbolo automaticamente)
formatService.formatCurrency(1234.56);
// pt-BR → R$ 1.234,56
// en-US → $1,234.56
// es-ES → 1.234,56 €

// Números decimais
formatService.formatDecimal(1234.56);             // 1.234,56 (pt), 1,234.56 (en)

// Porcentagem
formatService.formatPercent(15.5);                // 15,5%
```

### Parsing de Valores do Usuário

```dart
// Para parsear valores de TextFields de moeda
double _parseValue(String value) {
  try {
    final parsed = FormatService().currencyFormat.parse(value);
    return parsed.toDouble();
  } catch (e) {
    return 0;
  }
}
```

### Adicionar Nova Tradução

1. **Adicionar nos 3 arquivos .arb:**
```json
// lib/l10n/app_pt.arb
"newKey": "Texto em português"

// lib/l10n/app_en.arb
"newKey": "Text in English"

// lib/l10n/app_es.arb
"newKey": "Texto en español"
```

2. **Gerar arquivos:**
```bash
fvm flutter gen-l10n
```

3. **Usar no código:**
```dart
Text(context.l10n.newKey)
```

### Regras de Localização

**✅ SEMPRE localizar:**
- Títulos de telas
- Labels de campos
- Botões e ações
- Mensagens de erro/sucesso
- Placeholders
- Headers de seções
- Estados vazios
- Diálogos

**❌ NUNCA localizar:**
- Nomes próprios (clientes, empresas)
- Dados do usuário
- IDs técnicos
- Comentários de código

**⚠️ Números e moedas:**
- SEMPRE usar `FormatService`
- NUNCA formatar manualmente
- NUNCA usar `toStringAsFixed()` direto

Ver `docs/I18N.md` para detalhes completos.

## Campos Customizados por Segmento

Cada segmento pode ter labels customizados para adaptar terminologia.

### SegmentConfigService

```dart
import 'package:praticos/services/segment_config_service.dart';

final segmentService = SegmentConfigService();

// Obter label customizado com fallback i18n
final deviceLabel = segmentService.getLabel(
  'device',
  fallback: context.l10n.device,
);

Text(deviceLabel)  // "Veículo" (mecânica), "Aparelho" (eletrônica), "Dispositivo" (padrão)
```

### Campos Customizáveis

| Campo | Chave | Exemplo Mecânica | Exemplo Eletrônica |
|-------|-------|------------------|---------------------|
| Dispositivo | `device` | Veículo | Aparelho |
| Placeholder | `devicePlaceholder` | Ex: Fiat Uno 2015 | Ex: iPhone 12 |
| Produto | `product` | Peça | Componente |

### Ordem de Prioridade

```
1. customLabels do segmento (se disponível)
   ↓
2. Tradução i18n do idioma atual (fallback obrigatório)
   ↓
3. String padrão em inglês (último recurso)
```

### Exemplo Completo

```dart
// ✅ CORRETO - i18n + customização de segmento
final deviceLabel = SegmentConfigService().getLabel(
  'device',
  fallback: context.l10n.device,
);

CupertinoNavigationBar(
  middle: Text(deviceLabel),
  // pt-BR + mecânica → "Veículo"
  // en-US + mecânica → "Vehicle"
  // pt-BR + eletrônica → "Aparelho"
  // pt-BR + sem segmento → "Dispositivo"
)

// ❌ ERRADO - Hardcoded
CupertinoNavigationBar(
  middle: Text('Veículo'),  // Não adapta idioma nem segmento
)
```

Ver `docs/SEGMENT_CUSTOM_FIELDS.md` para detalhes completos.

## Deploy

### Versionamento Automático (Conventional Commits)

O projeto usa versionamento automático baseado em Conventional Commits.

**Formato:** `<type>(<scope>): <description>`

| Tipo | Descrição | Versão |
|------|-----------|--------|
| `feat` | Nova funcionalidade | Minor (1.0.0 → 1.1.0) |
| `feat!` | Feature com breaking change | Major (1.0.0 → 2.0.0) |
| `fix` | Correção de bug | Patch (1.0.0 → 1.0.1) |
| `perf` | Melhoria de performance | Patch |
| `refactor` | Refatoração de código | Patch |
| `docs` | Documentação | Patch |
| `style` | Formatação de código | Patch |
| `test` | Testes | Patch |
| `chore` | Manutenção | Patch |
| `ci` | CI/CD | Patch |
| `build` | Build system | Patch |

**Exemplos:**
```bash
# Feature (Minor)
git commit -m "feat: add dark mode toggle"
git commit -m "feat(orders): add bulk status update"

# Fix (Patch)
git commit -m "fix: resolve crash on login"
git commit -m "fix(auth): handle expired token"

# Breaking change (Major) - usar ! ou BREAKING CHANGE
git commit -m "feat!: new authentication flow"
git commit -m "feat: new API

BREAKING CHANGE: removed v1 endpoints"

# Outros (Patch)
git commit -m "refactor(ui): reorganize widgets"
git commit -m "perf: optimize image loading"
git commit -m "chore: update dependencies"
```

**Scopes comuns:** `auth`, `orders`, `customers`, `ui`, `storage`, `db`

Ver `docs/AUTO_VERSIONING.md` para detalhes completos.

### Fluxo de Release

```
PR mergeado na master
        ↓
auto-version.yml → cria tag v*-rc
        ↓
Build + Upload para TestFlight/Internal
        ↓
Artefatos salvos no GitHub Releases
        ↓
[Após testes] Workflow "Promote Release"
        ↓
Mesmo binário vai para produção
```

### Comandos Locais (quando necessário)

```bash
# Android
cd android
bundle exec fastlane internal           # Internal track (manual)

# iOS
cd ios
bundle exec fastlane beta               # TestFlight (manual)
```

### CI/CD
- **Push master**: Cria tag `-rc` automaticamente, deploy para teste
- **Promote Release**: Workflow manual para promover RC para produção
- **Artefatos**: Salvos no GitHub Releases (AAB + IPA)

## Regras Importantes

1. **Inglês no Código**: SEMPRE usar inglês para classes, variáveis, constantes, enums, chaves JSON e valores no banco
2. **i18n Obrigatório**: SEMPRE usar `context.l10n` para strings visíveis ao usuário, NUNCA hardcoded
3. **FormatService Obrigatório**: SEMPRE usar `FormatService` para datas, números e moedas, NUNCA formatar manualmente
4. **Segmento + i18n**: Labels customizáveis DEVEM ter fallback com `context.l10n`
5. **Conventional Commits**: Usar formato `tipo: descrição` para commits (feat, fix, refactor, etc.)
6. **Multi-Tenancy é Prioridade**: Sempre verificar estrutura de company/roles
7. **Build Runner**: Executar após alterar Stores/Models, e `fvm flutter gen-l10n` após alterar .arb
8. **AuthService**: Usar para criar novos usuários (não gravar direto no banco)
9. **CollaboratorStore**: Usar para gerenciar membros da equipe (não usar CompanyStore)
10. **Cupertino-first**: App deve parecer nativo iOS
11. **Dark Mode**: Sempre usar `.resolveFrom(context)` para cores dinâmicas
12. **Documentação Obrigatória**: Documentar toda nova funcionalidade (ver seção abaixo)

---

## Documentação de Novas Funcionalidades (OBRIGATÓRIO)

Ao desenvolver uma nova funcionalidade, **SEMPRE** criar/atualizar a documentação correspondente:

### 1. Documentação Técnica (`docs/`)

Criar arquivo Markdown em `docs/` com:

```markdown
# NOME_DA_FEATURE.md

## Visão Geral
Breve descrição da funcionalidade.

## Arquitetura
- Models envolvidos
- Stores/Repositories
- Estrutura Firestore

## Fluxo de Dados
Diagrama ou descrição do fluxo.

## Regras de Negócio
Lista de regras implementadas.

## Exemplos de Uso
Código de exemplo quando aplicável.
```

**Nomenclatura:** `FEATURE_NAME.md` (em inglês, UPPER_SNAKE_CASE)

### 2. Documentação Pública (`firebase/hosting/public/docs/`)

Atualizar/criar documentação para usuários finais:

**Estrutura de arquivos:**
```
firebase/hosting/public/docs/
├── feature.html         # Português (principal)
├── feature-en.html      # Inglês
├── feature-es.html      # Espanhol
└── docs.css             # Estilos compartilhados
```

**Template HTML:**
```html
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <title>Nome da Feature - PraticOS</title>
  <link rel="stylesheet" href="docs.css">
</head>
<body>
  <header>
    <h1>Nome da Feature</h1>
    <nav>
      <a href="feature.html" class="active">PT</a>
      <a href="feature-en.html">EN</a>
      <a href="feature-es.html">ES</a>
    </nav>
  </header>
  <main>
    <!-- Conteúdo da documentação -->
  </main>
</body>
</html>
```

### Checklist de Documentação

Antes de finalizar uma feature, verificar:

- [ ] Arquivo `docs/FEATURE_NAME.md` criado/atualizado
- [ ] Documentação técnica completa (arquitetura, fluxos, regras)
- [ ] Arquivo `firebase/hosting/public/docs/feature.html` criado (PT)
- [ ] Versões em inglês (`-en.html`) e espanhol (`-es.html`) criadas
- [ ] Links no `index.html` atualizados (se aplicável)
- [ ] CSS compartilhado (`docs.css`) atualizado se necessário

### Quando Documentar

| Tipo de Mudança | docs/ | public/docs/ |
|-----------------|-------|--------------|
| Nova feature completa | ✅ Obrigatório | ✅ Obrigatório |
| Mudança significativa em feature existente | ✅ Atualizar | ✅ Atualizar |
| Bug fix | ❌ Não necessário | ❌ Não necessário |
| Refatoração interna | ✅ Se mudar arquitetura | ❌ Não necessário |
| Nova API/Endpoint | ✅ Obrigatório | ❌ Geralmente não |

## Documentação Adicional

- `docs/AUTO_VERSIONING.md` - Versionamento automático e Conventional Commits
- `docs/I18N.md` - Sistema de internacionalização completo
- `docs/SEGMENT_CUSTOM_FIELDS.md` - Campos customizados por segmento
- `docs/UX_GUIDELINES.md` - Padrões visuais iOS/Cupertino
- `docs/WEB_UX_GUIDELINES.md` - Padrões para site institucional
- `docs/MULTI_TENANCY.md` - Detalhes da arquitetura multi-tenant
- `docs/formularios_dinamicos.md` - Especificação de checklists/vistorias
- `docs/DEPLOYMENT.md` - Guia completo de deploy
