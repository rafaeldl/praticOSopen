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
- **Path**: `/companies/{companyId}/memberships/{userId}` (o papel do colaborador fica no membership)
- **Gerenciamento**: `CollaboratorStore` + `TenantMembershipRepository`

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

O padrão do app está em `docs/APP_DESIGN_SYSTEM.md` (ler antes de criar ou redesenhar tela) e as specs de telas em `docs/superpowers/specs/`. Quando divergir do `docs/UX_GUIDELINES.md`, vale o design system.

**Regras de tela** (público não técnico, então clareza primeiro):
- Uma pergunta por tela ("o que eu faço agora?"), respondida no topo em uma frase
- Um botão azul (`accent`) por tela; as outras ações usam `secondaryFill` ou viram link (`accentText`)
- Português do dia a dia ("Falta receber R$ 166"), sem siglas nem jargão
- Mostrar só o que o registro tem; recurso ocasional entra pelo menu "…"/"+" ou pelo assistente
- Cadastro novo abre em sheet grande: "X" à esquerda e "✓" à direita no topo (cinza até dar para salvar, azul quando dá), formulário em cartões brancos sobre fundo cinza. Edição do que já existe abre empurrada
- Vidro (`AppGlass`) só na navegação: abas, botões do topo, menus e sheets pequenas. Conteúdo sempre opaco
- Escolher algo (cliente, veículo, situação, responsável, checklist) abre a tela de escolher (`PickerScaffold`/`pickOne`), nunca menu de ações: pergunta como título, "+" no topo para cadastrar, ✓ no atual, "Nenhum …" para tirar, busca só com mais de 10 itens
- Menu "…" (`showPullDownMenu`) só para o raro, em grupos com ícone, destrutivas em vermelho no fim. Sem botão "Editar": cada linha abre o seu editor
- IA (barra de vidro Foto/Falar embaixo) aplica na hora, marca com ✦ azul o que preencheu e mostra aviso opaco com "Desfazer"; nunca recebe, cancela ou apaga sozinha; erro no aviso, nunca em alerta
- Tela de um registro (OS): título pequeno no topo, cabeçalho com quem identifica (cliente), situação e uma frase, e o botão azul do próximo passo logo abaixo
- Toque: botão principal com 58 de altura (`AppSizes.primaryButtonHeight`), qualquer outro alvo com pelo menos 44
- Abas sempre na ordem Início, Agenda, Financeiro (`visibleAppTabs()`), com o "+" azul (Nova OS) ao lado. Clientes e o que era "Mais" abrem pelo botão do perfil, no topo da Início

**Widgets:**
- `CupertinoPageScaffold` + `CupertinoSliverNavigationBar` (título grande)
- `CupertinoListSection.insetGrouped` para formulários
- Listas com `AppListRow`, `SectionLabel`, `EmptyState`, `ErrorState`, `LoadingState` (`lib/screens/widgets/`)
- `CupertinoAlertDialog` para confirmações, `CupertinoActionSheet` para menus, `CupertinoSearchTextField` para busca
- Componente nativo do iPhone quando existe (interruptor, menu "…", "Continuar com Apple"); não desenhar uma versão própria

**Cores:** usar os papéis de `AppColors` (`lib/theme/app_colors.dart`), nunca hex, sempre com `.resolveFrom(context)` (é assim que funcionam o modo escuro e o "Aumentar contraste"):
```dart
// CORRETO
color: AppColors.accent.resolveFrom(context)

// ERRADO - não adapta ao modo escuro
color: AppColors.accent
color: Color(0xFF116BB5)
```
`CupertinoColors` direto e `lib/theme/app_theme.dart` são o padrão antigo, que só continua nas telas ainda não redesenhadas. Ao mudar uma cor, rodar `fvm flutter test test/theme/`.

**Texto:** `AppTypography` (corpo 19, título 34). O texto cresce com o tamanho do texto do iPhone: nunca travar o `textScaler`, nunca usar altura fixa em linha com texto, nunca reticências em nome, título ou valor (a linha quebra).

**Status:** ponto colorido + texto em `textSecondary`, nunca selo colorido. Orçamento cinza, aprovada azul (`accentText`), em andamento âmbar (`warning`), concluída verde (`success`), cancelada cinza. Atrasada é problema: ponto e texto em `danger`, texto em negrito.

### Web (tema "Ordem de Serviço")

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

**Design System** (travado em `firebase/hosting/design.md` — ler antes de mexer no site):
- Linguagem visual de "ordem de serviço": papel claro, tinta grafite, réguas de formulário, números em mono
- Tokens em `src/css/tokens.css`; base compartilhada em `src/css/site.css`; tema claro por padrão, escuro via `data-theme="dark"`
- Fontes: `Archivo` (títulos), `IBM Plex Sans` (texto), `IBM Plex Mono` (números/labels)
- Azul da marca como acento, amarelo do logo só como marca-texto; sem gradientes, glassmorphism ou cards com ícone
- Nada de números inventados (usuários, notas, depoimentos)
- Flags em `src/_data/site.json` (`flags.whatsappBot` desligada enquanto o bot estiver fora)
- `src/style.css` é legado: só `order/` e `login` ainda usam

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

Bot WhatsApp em `backend/bot/`. **Desligado:** a VM `praticos-bot` e o disco foram apagados, e as conversas estão arquivadas em `gs://praticos-bot-archive`. Para recriar, ver `backend/bot/README.md`, `docs/praticos-bot-central.md` e `docs/BOT_WORKSPACE_CONFIG.md`.

## Anúncios (Google Ads e Meta Ads)

Acesso às campanhas via Python, com credenciais em `~/.google-ads.yaml` e `~/.meta-ads.yaml` (fora do git). Google Ads (IDs, exemplos, renovação de token): `docs/GOOGLE_ADS_API.md`. Meta Ads (IDs da conta) e status das campanhas: `docs/ADS_CAMPAIGNS.md`.

## Modo Autônomo (agentes)

Prioridade vem do [`ROADMAP.md`](ROADMAP.md). Trabalho vem de issues.

### Ciclo
1. Pegar a issue aberta com label `agent-ready` mais alta no "Agora" do roadmap (se empatar, a mais antiga).
2. Branch `tipo/descricao-curta` a partir da `master`.
3. Implementar com **teste novo** para o que mudou. Rodar `fvm flutter analyze`, `fvm flutter test` e, se mexer em Functions, `npm test` em `firebase/functions`.
4. Abrir PR com o template, `Closes #N` e o label de risco da issue.
5. Se o CI falhar, corrigir no mesmo PR antes de pegar outra issue.

### Limites
- **WIP: no máximo 2 PRs de agente abertos.** Acima disso, não abrir novos: revisar/consertar os existentes.
- Não mergear PR `risk:high`. Não fazer deploy nem promover release fora do fluxo de CI.
- Bloqueio em passo manual (lojas, consoles, contas, credenciais): label `needs-human`, comentário curto dizendo exatamente o que falta, e seguir para a próxima issue.
- Dados de clientes (nomes, telefones, conversas) **nunca** entram no repositório — ele é público. Só números agregados.
- Medir sucesso por PR mergeado e release publicada, não por documento gerado. Não criar docs de planejamento sem pedido.

### Risco
| `risk:low` (pode auto-mergear com CI verde) | `risk:high` (revisão humana) |
|---|---|
| Bug fix com teste, testes, refatoração local | `firestore.rules`, `storage.rules`, índices |
| Docs técnicas, site/SEO, i18n | Auth, billing, assinatura, IAP, pagamentos |
| UI isolada, dependências patch | Workflows de CI/release, fastlane, assinatura iOS |
| | Migrações de dados, modelos compartilhados, Functions de produção com escrita |

### Propor trabalho
Agentes podem abrir issues com label `agent-proposed` (template "Tarefa"). Só viram `agent-ready` com aprovação do Rafael.

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
15. **Issues em Português**: Issues no GitHub devem ser escritas em português

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
- `docs/STORE_LISTING.md` - Ficha das lojas: textos, prints (como gerar, dados demo), conta da revisão e envio sem publicar
- `docs/APP_TRACKING_TRANSPARENCY.md` - Permissão de rastreamento no iOS (ATT) e exigências da App Review
- `docs/I18N.md` - Sistema de internacionalização completo
- `docs/SEGMENT_CUSTOM_FIELDS.md` - Campos customizados por segmento
- `docs/FIELD_VALIDATION_MASKS.md` - Máscaras e validações por segmento/país
- `docs/IOS_CODE_SIGNING.md` - Assinatura iOS via fastlane match (bootstrap, renovacao, troubleshooting)
- `docs/AI_ORDER_ASSIST.md` - Assistente de IA na OS (`aiOrderAssist`, Gemini/Claude, ligar e desligar com `npm run ai`, cota mensal)
- `docs/ONBOARDING.md` - Primeiro acesso: Ramo → Seu negócio → Início (criação da empresa)
- `docs/PDF_GENERATION.md` - Geracao do PDF da OS (fotos, paginacao, download de imagens)
- `docs/VALUES_AND_BILLING_TOGGLE.md` - Opção "Valores e cobrança" por empresa (`Company.useFinancial`)
- `docs/SHARE_LINK.md` - Sistema de compartilhamento via magic link
- `docs/ACCOUNT_DELETION.md` - Exclusão de conta no servidor (`DELETE /v1/app/account` na função `accountApi`): regras de posse, idempotência, erros e limitações
- `docs/ASAAS_INTEGRATION.md` - Integração Asaas (cobrança na OS: endpoints, dados, webhook, E2E no sandbox e rollout do piloto)
- `docs/NFSE_ASAAS.md` - Nota fiscal de serviço pelo Asaas (flag `nfseEnabled`, regra do valor, uma nota por OS ou com várias OS, webhook `INVOICE_*`, checklist para ligar)
- `docs/APP_DESIGN_SYSTEM.md` - Padrão de design do app: cores (`AppColors`), tipografia, estrutura de tela e regras (vale sobre o UX_GUIDELINES em cor/estrutura)
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
