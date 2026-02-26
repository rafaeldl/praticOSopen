# CLAUDE.md - Instruções para Claude Code

Este documento fornece contexto e diretrizes para Claude Code trabalhar no projeto PraticOS.

## Projeto

**PraticOS** - Sistema de gestão de ordens de serviço (OS) desenvolvido em Flutter com Firebase.

### Stack Principal
- **Flutter** (versão no `.fvmrc`, usar FVM)
- **Firebase**: Firestore, Auth, Storage
- **MobX**: Gerenciamento de estado reativo
- **Fastlane**: Automação de deploy (iOS/Android)

### URLs do Projeto
- **Web App (Cliente)**: `https://praticos.web.app/`
- **Share Links**: `https://praticos.web.app/q/{token}`

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

## Bot (OpenClaw)

Bot WhatsApp rodando em GCE VM `praticos-bot` (zona `southamerica-east1-b`). Todos os comandos em `backend/bot/`.

### Comandos Essenciais

```bash
make dev              # Dev local (Docker)
make deploy           # Build + deploy produção
make sync             # Atualiza configs/skills sem rebuild
make logs             # Logs produção
make restart          # Reinicia VM
make clear-sessions   # Limpa sessões e reinicia
```

### Memória (Produção)

Paths na VM: `/var/openclaw/memory/`
- Global: `MEMORY.md`
- Por usuário: `users/+55XXXXXXXXXXX.md`

```bash
# SSH usa --ssh-key-file=~/.ssh/id_ed25519
# Listar memórias
gcloud compute ssh praticos-bot --zone=southamerica-east1-b --ssh-key-file=~/.ssh/id_ed25519 -- 'ls -la /var/openclaw/memory/users/'

# Ler memória de usuário
gcloud compute ssh praticos-bot --zone=southamerica-east1-b --ssh-key-file=~/.ssh/id_ed25519 -- 'cat /var/openclaw/memory/users/+55XXXXXXXXXXX.md'

# Apagar memória (reset do usuário)
gcloud compute ssh praticos-bot --zone=southamerica-east1-b --ssh-key-file=~/.ssh/id_ed25519 -- 'sudo rm /var/openclaw/memory/users/+55XXXXXXXXXXX.md'

# Reiniciar container
gcloud compute ssh praticos-bot --zone=southamerica-east1-b --ssh-key-file=~/.ssh/id_ed25519 -- 'sudo docker restart $(sudo docker ps -q)'
```

### Documentação Completa

- `docs/praticos-bot-central.md` - Arquitetura, features e segurança
- `docs/BOT_WORKSPACE_CONFIG.md` - Configuração do workspace OpenClaw
- `backend/bot/README.md` - Setup, deploy e referência completa

## Google Ads API

Acesso direto ao Google Ads para gerenciamento de campanhas via Python.

### Configuracao

- **Credenciais**: `~/.google-ads.yaml` (NAO vai para o git)
- **Lib Python**: `google-ads` (pip3 install google-ads)
- **Manager ID**: `1569666691` (PraticOS Manager)
- **Customer ID**: `6735014760` (PraticOS - conta de anuncios)

### Uso rapido

```python
import warnings
warnings.filterwarnings('ignore')
from google.ads.googleads.client import GoogleAdsClient

client = GoogleAdsClient.load_from_storage('/Users/rafaeldl/.google-ads.yaml')
ga_service = client.get_service('GoogleAdsService')
CUSTOMER_ID = '6735014760'
```

### Operacoes disponiveis

- Listar e analisar campanhas, ad groups, keywords, anuncios
- Metricas de performance (impressoes, clicks, CTR, custo, conversoes)
- Consultas GAQL customizadas

### Limitacoes

- **Nivel atual**: Acesso as Analises (somente leitura)
- Para criar/editar campanhas via API, solicitar **Acesso Padrao** no Centro de API

Ver `docs/GOOGLE_ADS_API.md` para documentacao completa, exemplos de queries e instrucoes de renovacao de token.

## Meta Ads API

Acesso ao Meta Ads (Facebook/Instagram) para campanhas via Python.

### Configuracao

- **Credenciais**: `~/.meta-ads.yaml` (NAO vai para o git)
- **Lib Python**: `facebook-business` (pip3 install facebook-business)
- **App ID**: `2156455528501761` (PraticOS Ads)
- **Ad Account ID**: `act_521666357871300`

### Uso rapido

```python
import warnings
warnings.filterwarnings('ignore')
from facebook_business.api import FacebookAdsApi
from facebook_business.adobjects.adaccount import AdAccount

APP_ID = '2156455528501761'
APP_SECRET = 'ver ~/.meta-ads.yaml'
ACCESS_TOKEN = 'ver ~/.meta-ads.yaml'

FacebookAdsApi.init(APP_ID, APP_SECRET, ACCESS_TOKEN)
account = AdAccount('act_521666357871300')
```

### Limitacoes

- **Token expira**: Access token do Graph API expira em ~1h. Necessario regerar ou usar token de longa duracao.
- **Escrita disponivel**: Diferente do Google Ads, ja temos permissao de escrita (ads_management).

### Progresso das campanhas

Ver `docs/ADS_CAMPAIGNS.md` para status completo de todas as campanhas, pendencias e historico.

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
14. **Branch obrigatória**: Sempre criar branch `tipo/descricao-curta` a partir da master antes de implementar. Nunca commitar direto na master. Tipos são os mesmos do Conventional Commits (ver seção Deploy)

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
- `docs/SHARE_LINK.md` - Sistema de compartilhamento via magic link
- `docs/UX_GUIDELINES.md` - Padrões visuais iOS/Cupertino
- `docs/WEB_UX_GUIDELINES.md` - Padrões para site institucional
- `docs/WEBSITE_STRUCTURE.md` - Estrutura completa do site Eleventy
- `docs/MULTI_TENANCY.md` - Detalhes da arquitetura multi-tenant
- `docs/formularios_dinamicos.md` - Especificação de checklists/vistorias
- `docs/DEPLOYMENT.md` - Guia completo de deploy
- `docs/praticos-bot-central.md` - Bot WhatsApp: arquitetura e features
- `docs/BOT_WORKSPACE_CONFIG.md` - Configuração do workspace OpenClaw
- `docs/GOOGLE_ADS_API.md` - Acesso ao Google Ads via Claude Code
- `docs/ADS_CAMPAIGNS.md` - Status de campanhas, pendências e progresso
