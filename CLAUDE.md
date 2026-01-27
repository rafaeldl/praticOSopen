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

O site institucional usa **Eleventy (11ty)** como Static Site Generator com templates Nunjucks.

**Stack:**
- **Eleventy 2.0.1**: SSG com templates Nunjucks
- **Dados JSON**: Conteúdo separado dos templates
- **Multi-idioma**: pt, en, es
- **Firebase Hosting**: Deploy

**Estrutura:**
```
firebase/hosting/
├── src/                      # FONTES (editar aqui)
│   ├── _data/               # Dados JSON
│   ├── _includes/           # Layouts, componentes, partials
│   ├── css/                 # Estilos
│   └── *.njk                # Templates de páginas
├── public/                  # OUTPUT (NÃO editar)
└── .eleventy.js             # Configuração
```

**Comandos:**
```bash
cd firebase/hosting
npm run build                # Gerar site
npm run dev                  # Servidor local com hot reload
npm run watch               # Watch mode
```

**Design System:**
- Background: `#0A0E17` (deep blue/black)
- Gradients para CTAs
- Glassmorphism para navegação
- Fonte: `Outfit` (headings), `DM Sans` (body)

Ver `docs/WEBSITE_STRUCTURE.md` para documentação completa.

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
13. **Site Eleventy**: Editar APENAS em `src/`, nunca em `public/`. Executar `npm run build` após alterações

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

### 2. Documentação Pública (Site Eleventy)

O site usa **Eleventy** com templates Nunjucks e dados JSON. **NÃO edite arquivos em `public/`** - eles são gerados automaticamente.

**Estrutura de arquivos:**
```
firebase/hosting/src/
├── _data/docs/          # Dados JSON por artigo
│   ├── perfis.json
│   ├── financeiro.json
│   └── novo-artigo.json # Criar para novo artigo
├── docs/                # Templates Nunjucks
│   ├── index.njk        # Hub de docs (pt)
│   ├── index-en.njk     # Hub de docs (en)
│   ├── index-es.njk     # Hub de docs (es)
│   ├── perfis.njk       # Artigo (pt)
│   ├── perfis-en.njk    # Artigo (en)
│   └── perfis-es.njk    # Artigo (es)
└── css/docs.css         # Estilos de documentação
```

**Para criar novo artigo de documentação:**

1. Criar dados em `src/_data/docs/novo-artigo.json`:
```json
{
  "pt": {
    "sections": [
      {
        "id": "visao-geral",
        "title": "Visão Geral",
        "intro": "Texto introdutório...",
        "infoCard": { "title": "Dica", "content": "Conteúdo da dica" }
      }
    ]
  },
  "en": { "sections": [...] },
  "es": { "sections": [...] }
}
```

2. Criar templates (pt, en, es) em `src/docs/`:
```njk
---
layout: layouts/docs-article.njk
lang: pt-BR
langCode: pt
docsData: novo-artigo
heroTitle: "Título do"
heroTitleHighlight: "Artigo"
sidebarNav:
  - id: visao-geral
    label: Visão Geral
---
```

3. Atualizar `src/_data/docs.json` para incluir no hub

4. Gerar o site:
```bash
cd firebase/hosting && npm run build
```

Ver `docs/WEBSITE_STRUCTURE.md` para documentação completa do sistema Eleventy.

### Checklist de Documentação

Antes de finalizar uma feature, verificar:

- [ ] Arquivo `docs/FEATURE_NAME.md` criado/atualizado
- [ ] Documentação técnica completa (arquitetura, fluxos, regras)
- [ ] Dados JSON criados em `firebase/hosting/src/_data/docs/` (se doc pública)
- [ ] Templates .njk criados em `firebase/hosting/src/docs/` (pt, en, es)
- [ ] Hub de docs atualizado (`src/_data/docs.json`)
- [ ] Build executado (`cd firebase/hosting && npm run build`)

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
- `docs/FIELD_VALIDATION_MASKS.md` - Máscaras e validações por segmento/país
- `docs/UX_GUIDELINES.md` - Padrões visuais iOS/Cupertino
- `docs/WEB_UX_GUIDELINES.md` - Padrões para site institucional
- `docs/WEBSITE_STRUCTURE.md` - Estrutura completa do site Eleventy
- `docs/MULTI_TENANCY.md` - Detalhes da arquitetura multi-tenant
- `docs/formularios_dinamicos.md` - Especificação de checklists/vistorias
- `docs/DEPLOYMENT.md` - Guia completo de deploy
