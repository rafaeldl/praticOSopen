# Growth: Diretório de Empresas (Business Directory)

## Visão Geral

Criar um diretório público de empresas cadastradas no PraticOS, onde cada empresa que opta por visibilidade pública ganha uma landing page otimizada para SEO. Este diretório é a **base do marketplace futuro** documentado em `docs/OPPORTUNITIES_MARKETPLACE.md` — os perfis públicos (`isPublicProfile`, `publicSlug`) evoluem naturalmente para `ProviderProfile` com categorias, rating e portfolio.

**Motivação:**
1. **SEO orgânico** — Cada perfil público é uma página indexável ("oficina mecânica em Florianópolis"), gerando tráfego gratuito
2. **Social proof** — Empresas reais usando PraticOS atraem novas empresas
3. **Base para marketplace** — Estrutura de dados reutilizada quando a aba de Oportunidades for implementada
4. **Valor para o cliente** — Empresa ganha uma vitrine online gratuita com rating

**Estimativa de implementação:** ~1-2 semanas

## Campos Estruturados de Endereço

### Problema atual

O Company model tem apenas um campo `address` (string livre):

**Arquivo:** `lib/models/company.dart` (linha 13)
```dart
class Company extends BaseAudit {
  String? name;
  String? email;
  String? address;  // "Rua X, 123, Florianópolis - SC" — não estruturado
  // ...
}
```

**Arquivo:** `firebase/functions/src/models/types.ts` (linha 333)
```typescript
export interface Company {
  // ...
  address?: string;  // Mesmo: string livre
  // ...
}
```

### Solução: Adicionar campos estruturados

Manter `address` para compatibilidade (endereço completo livre) e adicionar campos estruturados:

**Dart — `lib/models/company.dart`:**
```dart
class Company extends BaseAudit {
  // ... campos existentes
  String? address;          // Endereço completo (livre, legado)
  String? city;             // Cidade (ex: "Florianópolis")
  String? state;            // Estado/UF (ex: "SC")
  String? zipCode;          // CEP/Postal code (ex: "88000-000")
  // ...
}
```

**TypeScript — `firebase/functions/src/models/types.ts`:**
```typescript
export interface Company {
  // ... campos existentes
  address?: string;          // Full address (free text, legacy)
  city?: string;             // City
  state?: string;            // State/Province
  zipCode?: string;          // Postal code
  // ...
}
```

> **Nota:** Após alterar model Dart, executar `fvm flutter pub run build_runner build --delete-conflicting-outputs`.

### Migração de dados existentes

Criar Cloud Function one-shot para parsear o campo `address` existente e extrair `city`/`state`:

**Arquivo a criar:** `firebase/functions/src/scripts/migrate-company-address.ts`

```typescript
/**
 * One-shot migration: parse existing company.address into city/state
 *
 * Heurística para endereços BR:
 * - Padrão: "... , Cidade - UF" ou "... , Cidade/UF"
 * - Regex: /,\s*([^,]+?)\s*[-\/]\s*([A-Z]{2})\s*$/
 *
 * Execução: npx ts-node src/scripts/migrate-company-address.ts
 */
```

A migração deve:
1. Ler todos os docs de `/companies/`
2. Para cada um com `address` mas sem `city`/`state`, tentar parsear
3. Atualizar apenas se o parse for bem-sucedido
4. Logar empresas que não puderam ser parseadas (para revisão manual)

## Opt-in e Perfil Público

### Novos campos no Company model

```typescript
// TypeScript
export interface Company {
  // ... campos existentes + city/state/zipCode
  isPublicProfile?: boolean;       // Opt-in para perfil público (default: false)
  publicSlug?: string;             // URL-friendly identifier (ex: "oficina-do-joao-florianopolis")
  publicDescription?: string;      // Descrição para o perfil público (max 500 chars)
  publicPhone?: string;            // Telefone público (pode ser diferente do phone interno)
  publicEmail?: string;            // Email público
  averageRating?: number;          // Média de ratings (0-5, calculado por Cloud Function)
  totalRatings?: number;           // Total de avaliações recebidas
}
```

```dart
// Dart
class Company extends BaseAudit {
  // ... campos existentes + city/state/zipCode
  bool? isPublicProfile;
  String? publicSlug;
  String? publicDescription;
  String? publicPhone;
  String? publicEmail;
  double? averageRating;
  int? totalRatings;
}
```

### Geração do slug

O `publicSlug` é gerado automaticamente ao ativar o perfil público:

```typescript
function generateSlug(companyName: string, city?: string): string {
  const base = [companyName, city]
    .filter(Boolean)
    .join(' ')
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')  // Remove acentos
    .replace(/[^a-z0-9]+/g, '-')      // Substitui não-alfanuméricos por hífens
    .replace(/^-|-$/g, '');            // Remove hífens nas pontas

  return base || 'empresa';
}
```

Se o slug já existir, adicionar sufixo numérico (`oficina-do-joao-florianopolis-2`).

## Rating Agregado

### Cloud Function Trigger

Quando uma OS recebe um rating (via página de rastreamento), recalcular a média da empresa:

**Arquivo a criar:** `firebase/functions/src/triggers/rating-aggregation.ts`

```typescript
/**
 * Firestore trigger: onWrite /companies/{companyId}/orders/{orderId}
 *
 * Quando order.rating muda:
 * 1. Buscar todas as orders da empresa com rating.score
 * 2. Calcular média e total
 * 3. Atualizar company.averageRating e company.totalRatings
 */

import * as functions from 'firebase-functions';
import { db, getTenantCollection } from '../services/firestore.service';

export const onOrderRatingChanged = functions
  .region('southamerica-east1')
  .firestore.document('companies/{companyId}/orders/{orderId}')
  .onWrite(async (change, context) => {
    const { companyId } = context.params;
    const before = change.before.data();
    const after = change.after.data();

    // Only trigger if rating changed
    if (before?.rating?.score === after?.rating?.score) return;
    if (!after?.rating?.score) return;

    // Query all rated orders for this company
    const snapshot = await getTenantCollection(companyId, 'orders')
      .where('rating.score', '>', 0)
      .get();

    let totalScore = 0;
    let totalRatings = 0;

    snapshot.forEach(doc => {
      const order = doc.data();
      if (order.rating?.score) {
        totalScore += order.rating.score;
        totalRatings++;
      }
    });

    const averageRating = totalRatings > 0
      ? Math.round((totalScore / totalRatings) * 10) / 10  // 1 casa decimal
      : 0;

    // Update company doc
    await db.collection('companies').doc(companyId).update({
      averageRating,
      totalRatings,
    });
  });
```

## API Pública

### Novos endpoints

**Arquivo a criar:** `firebase/functions/src/routes/public/directory.routes.ts`

```typescript
const router: Router = Router();

/**
 * GET /public/directory
 * Lista empresas com perfil público
 *
 * Query params:
 * - city: string (filtro por cidade)
 * - state: string (filtro por estado)
 * - segment: string (filtro por segmento)
 * - q: string (busca por nome)
 * - page: number (paginação, default 1)
 * - limit: number (default 20, max 50)
 * - sort: 'rating' | 'name' | 'recent' (default 'rating')
 *
 * Response: {
 *   success: true,
 *   data: {
 *     companies: DirectoryCompany[],
 *     total: number,
 *     page: number,
 *     totalPages: number
 *   }
 * }
 */
router.get('/', async (req, res) => { ... });

/**
 * GET /public/directory/:slug
 * Perfil público de uma empresa
 *
 * Response: {
 *   success: true,
 *   data: {
 *     company: DirectoryCompanyDetail
 *   }
 * }
 */
router.get('/:slug', async (req, res) => { ... });

export default router;
```

### Tipos de response

```typescript
export interface DirectoryCompany {
  slug: string;
  name: string;
  city?: string;
  state?: string;
  country?: string;
  segment?: string;
  subspecialties?: string[];
  averageRating?: number;
  totalRatings?: number;
  logo?: string;
  publicDescription?: string;
}

export interface DirectoryCompanyDetail extends DirectoryCompany {
  publicPhone?: string;
  publicEmail?: string;
  address?: string;
  site?: string;
  // Não expor: owner, users, email interno, phone interno
}
```

### Registrar rotas

No arquivo onde as rotas públicas são montadas:

```typescript
import directoryRoutes from './directory.routes';
router.use('/directory', directoryRoutes);
```

## Páginas Web Dinâmicas

### Estrutura de arquivos

```
firebase/hosting/src/
├── directory/
│   ├── index.njk          # Hub do diretório (listagem com busca)
│   └── profile.njk        # Perfil individual (renderizado via JS, mesma abordagem de /q/{token})
```

> **Nota:** O perfil individual pode usar a mesma abordagem da página de rastreamento de OS (`/order/index.njk` + `order-view.js`): uma página HTML estática que carrega dados via API JS-side. Isso evita a necessidade de SSR.

### Hub do diretório: `directory/index.njk`

```
┌──────────────────────────────────────────────────┐
│  Encontre Profissionais na sua Região             │
│                                                    │
│  🔍 [Buscar por nome ou serviço...]              │
│                                                    │
│  Filtros: [Cidade ▼] [Segmento ▼] [Ordenar ▼]   │
│                                                    │
│  ┌────────────────┐  ┌────────────────┐           │
│  │ ⭐ 4.8 (23)    │  │ ⭐ 4.5 (12)    │           │
│  │ Oficina do João│  │ TechFix        │           │
│  │ Mecânica       │  │ Eletrônica     │           │
│  │ Florianópolis  │  │ São Paulo      │           │
│  └────────────────┘  └────────────────┘           │
│                                                    │
│  [Carregar mais...]                               │
└──────────────────────────────────────────────────┘
```

### Perfil da empresa: `directory/profile.njk` (acessível via `/d/{slug}`)

```
┌──────────────────────────────────────────────────┐
│  [Logo]  Oficina do João                          │
│  ⭐ 4.8 (23 avaliações)                          │
│  📍 Florianópolis - SC                           │
│  🔧 Mecânica Automotiva                          │
│                                                    │
│  Sobre                                            │
│  "Especialista em manutenção preventiva e         │
│   reparos automotivos desde 2015."                │
│                                                    │
│  Contato                                          │
│  📞 (48) 99999-9999                              │
│  ✉️ contato@oficina.com                          │
│  🌐 www.oficina.com                              │
│                                                    │
│  ┌──────────────────────────────────────┐         │
│  │  💬 Agendar pelo WhatsApp            │         │
│  └──────────────────────────────────────┘         │
│                                                    │
│  Powered by PraticOS                              │
└──────────────────────────────────────────────────┘
```

### CSS

**Arquivo a criar:** `firebase/hosting/src/css/directory.css`

Seguir o design system existente (dark premium theme, CSS vars, mesmas fontes Outfit/DM Sans).

### JavaScript

**Arquivo a criar:** `firebase/hosting/src/js/directory.js` (hub) + `firebase/hosting/src/js/directory-profile.js` (perfil)

Mesma abordagem de `order-view.js`: IIFE, fetch da API pública, render dinâmico, i18n inline (pt/en/es).

## SEO

### JSON-LD Schema (LocalBusiness)

Cada perfil de empresa deve incluir schema markup para Google:

```html
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "LocalBusiness",
  "name": "Oficina do João",
  "description": "Especialista em manutenção preventiva e reparos automotivos.",
  "address": {
    "@type": "PostalAddress",
    "addressLocality": "Florianópolis",
    "addressRegion": "SC",
    "addressCountry": "BR"
  },
  "telephone": "+5548999999999",
  "aggregateRating": {
    "@type": "AggregateRating",
    "ratingValue": "4.8",
    "reviewCount": "23"
  },
  "url": "https://praticos.web.app/d/oficina-do-joao-florianopolis"
}
</script>
```

### Meta tags dinâmicas

O perfil individual deve ter meta tags únicas (title, description, og:*) geradas pelo JS com base nos dados da API. Usar abordagem semelhante ao `order-view.js` que já atualiza `document.title`.

### Sitemap

Criar endpoint ou Cloud Function que gera `/sitemap-directory.xml` com todos os perfis públicos:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemapindex.org/schemas/sitemap/0.9">
  <url>
    <loc>https://praticos.web.app/d/oficina-do-joao-florianopolis</loc>
    <lastmod>2026-02-20</lastmod>
    <changefreq>weekly</changefreq>
  </url>
  <!-- ... -->
</urlset>
```

Adicionar referência no `robots.txt`:
```
Sitemap: https://praticos.web.app/sitemap-directory.xml
```

## Conexão com o Marketplace Futuro

O modelo `ProviderProfile` definido em `docs/OPPORTUNITIES_MARKETPLACE.md` (linha 154) estende naturalmente o perfil público:

```
OPPORTUNITIES_MARKETPLACE.md:
ProviderProfile
├── userId: string
├── companyId: string
├── name: string
├── categories: [string]          ← já temos subspecialties
├── location: city/state          ← já temos city/state
├── rating: double                ← já temos averageRating
├── completedJobs: int            ← pode ser calculado das OS done
├── portfolio: [PortfolioItem]    ← pode vir das OS com fotos
└── active: bool                  ← equivale a isPublicProfile
```

**Campos do diretório que mapeiam para o marketplace:**

| Campo Directory | Campo Marketplace (ProviderProfile) |
|----------------|--------------------------------------|
| `isPublicProfile` | `active` |
| `publicSlug` | URL do perfil |
| `city`, `state` | `location` |
| `subspecialties` | `categories` |
| `averageRating` | `rating` |
| `totalRatings` | `completedJobs` (aproximação) |
| `publicDescription` | Descrição do perfil |

Quando o marketplace for implementado, o `ProviderProfile` pode ser criado automaticamente para empresas com `isPublicProfile: true`, reutilizando todos os dados já existentes.

## Tela de Configuração no App

### Toggle em "Sua empresa" (MyCompanySettings)

**Arquivo:** `lib/screens/menu_navigation/more/company_editors.dart`

Adicionar seção "Perfil Público" ao formulário de empresa:

```dart
// Dentro do formulário, após os campos existentes:

CupertinoListSection.insetGrouped(
  header: Text(context.l10n.publicProfile),
  children: [
    // Toggle para ativar perfil público
    CupertinoFormRow(
      prefix: Text(context.l10n.enablePublicProfile),
      child: CupertinoSwitch(
        value: _company?.isPublicProfile ?? false,
        onChanged: (value) {
          setState(() {
            _company?.isPublicProfile = value;
          });
        },
      ),
    ),

    // Campos visíveis apenas quando toggle está ativo
    if (_company?.isPublicProfile == true) ...[
      // Descrição pública
      CupertinoFormRow(
        prefix: Text(context.l10n.publicDescription),
        child: CupertinoTextField(
          placeholder: context.l10n.publicDescriptionPlaceholder,
          maxLines: 3,
          maxLength: 500,
          controller: _publicDescriptionController,
        ),
      ),

      // Telefone público (pré-preenchido com phone da empresa)
      CupertinoFormRow(
        prefix: Text(context.l10n.publicPhone),
        child: CupertinoTextField(
          controller: _publicPhoneController,
          keyboardType: TextInputType.phone,
        ),
      ),

      // Email público (pré-preenchido com email da empresa)
      CupertinoFormRow(
        prefix: Text(context.l10n.publicEmail),
        child: CupertinoTextField(
          controller: _publicEmailController,
          keyboardType: TextInputType.emailAddress,
        ),
      ),

      // Preview do slug (read-only)
      CupertinoFormRow(
        prefix: Text(context.l10n.profileUrl),
        child: Text(
          'praticos.web.app/d/${_company?.publicSlug ?? "..."}',
          style: TextStyle(
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        ),
      ),
    ],
  ],
),
```

### Campos de cidade/estado no formulário

Adicionar campos `city`, `state`, `zipCode` ao formulário existente, na seção de endereço:

```dart
// Após o campo address existente:

CupertinoFormRow(
  prefix: Text(context.l10n.city),
  child: CupertinoTextField(
    controller: _cityController,
    placeholder: context.l10n.cityPlaceholder,
  ),
),

CupertinoFormRow(
  prefix: Text(context.l10n.state),
  child: CupertinoTextField(
    controller: _stateController,
    placeholder: context.l10n.statePlaceholder,
  ),
),

CupertinoFormRow(
  prefix: Text(context.l10n.zipCode),
  child: CupertinoTextField(
    controller: _zipCodeController,
    placeholder: context.l10n.zipCodePlaceholder,
    keyboardType: TextInputType.number,
  ),
),
```

### Campos no onboarding (bot)

O fluxo de auto-cadastro via bot (`registration.md`) pode coletar cidade/estado após o segmento:

```markdown
## AUTO-CADASTRO (atualizado)

1. POST /bot/registration/start → perguntar nome da empresa
2. POST /bot/registration/update {"companyName":"NOME"} → mostrar segmentos
3. POST /bot/registration/update {"segmentId":"ID"} → mostrar especialidades
4. POST /bot/registration/update {"subspecialties":["id1"]} → perguntar cidade
5. POST /bot/registration/update {"city":"Cidade", "state":"UF"} → perguntar dados exemplo
6. POST /bot/registration/update {"includeBootstrap":true} → resumo
7. POST /bot/registration/complete
```

> **Nota:** Cidade/estado no onboarding é opcional — pode ser adicionado gradualmente. O campo `city`/`state` pode ser preenchido depois pelo app.

## Chaves i18n a Adicionar

### Arquivos `.arb` (Flutter)

**`lib/l10n/app_pt.arb`:**
```json
{
  "city": "Cidade",
  "cityPlaceholder": "Ex: Florianópolis",
  "state": "Estado",
  "statePlaceholder": "Ex: SC",
  "zipCode": "CEP",
  "zipCodePlaceholder": "Ex: 88000-000",
  "publicProfile": "Perfil Público",
  "enablePublicProfile": "Ativar perfil público",
  "publicDescription": "Descrição",
  "publicDescriptionPlaceholder": "Descreva seu negócio para clientes...",
  "publicPhone": "Telefone público",
  "publicEmail": "Email público",
  "profileUrl": "URL do perfil"
}
```

**`lib/l10n/app_en.arb`:**
```json
{
  "city": "City",
  "cityPlaceholder": "E.g.: Miami",
  "state": "State",
  "statePlaceholder": "E.g.: FL",
  "zipCode": "ZIP Code",
  "zipCodePlaceholder": "E.g.: 33101",
  "publicProfile": "Public Profile",
  "enablePublicProfile": "Enable public profile",
  "publicDescription": "Description",
  "publicDescriptionPlaceholder": "Describe your business for clients...",
  "publicPhone": "Public phone",
  "publicEmail": "Public email",
  "profileUrl": "Profile URL"
}
```

**`lib/l10n/app_es.arb`:**
```json
{
  "city": "Ciudad",
  "cityPlaceholder": "Ej.: Buenos Aires",
  "state": "Provincia",
  "statePlaceholder": "Ej.: BA",
  "zipCode": "Código postal",
  "zipCodePlaceholder": "Ej.: C1000",
  "publicProfile": "Perfil Público",
  "enablePublicProfile": "Activar perfil público",
  "publicDescription": "Descripción",
  "publicDescriptionPlaceholder": "Describe tu negocio para clientes...",
  "publicPhone": "Teléfono público",
  "publicEmail": "Email público",
  "profileUrl": "URL del perfil"
}
```

> Após adicionar, executar `fvm flutter gen-l10n`.

## Arquivos a Criar

| Arquivo | Descrição |
|---------|-----------|
| `firebase/functions/src/routes/public/directory.routes.ts` | Endpoints da API pública do diretório |
| `firebase/functions/src/triggers/rating-aggregation.ts` | Cloud Function trigger para calcular rating médio |
| `firebase/functions/src/scripts/migrate-company-address.ts` | Script de migração one-shot para parsear endereços |
| `firebase/hosting/src/directory/index.njk` | Página hub do diretório |
| `firebase/hosting/src/directory/profile.njk` | Página de perfil individual |
| `firebase/hosting/src/css/directory.css` | Estilos do diretório |
| `firebase/hosting/src/js/directory.js` | JS para o hub (busca, filtros, listagem) |
| `firebase/hosting/src/js/directory-profile.js` | JS para o perfil (fetch API, render, JSON-LD) |

## Arquivos a Modificar

| Arquivo | Alteração |
|---------|-----------|
| `lib/models/company.dart` | Adicionar: `city`, `state`, `zipCode`, `isPublicProfile`, `publicSlug`, `publicDescription`, `publicPhone`, `publicEmail`, `averageRating`, `totalRatings` |
| `firebase/functions/src/models/types.ts` | Adicionar mesmos campos à interface `Company` |
| `lib/screens/menu_navigation/more/company_editors.dart` | Adicionar seção "Perfil Público" + campos cidade/estado |
| `lib/l10n/app_pt.arb` | Adicionar chaves i18n (city, state, zipCode, publicProfile, etc.) |
| `lib/l10n/app_en.arb` | Adicionar chaves i18n em inglês |
| `lib/l10n/app_es.arb` | Adicionar chaves i18n em espanhol |
| `firebase/functions/src/services/company.service.ts` | Adicionar `city`, `state`, `zipCode` ao `UpdateCompanyInput` (linha 32) |
| `backend/bot/workspace/skills/praticos/references/registration.md` | Adicionar passo de coleta cidade/estado (opcional) |
| Rota pública index (onde rotas são montadas) | Registrar `directory.routes.ts` |
| `firebase/hosting/.eleventy.js` | Configurar rota `/d/{slug}` se necessário |
| `firebase.json` (hosting rewrites) | Adicionar rewrite para `/d/**` → `directory/profile.njk` |

**Total: 8 arquivos criados, 11 arquivos modificados.**

## Fluxo Completo

```
Empresa ativa perfil público no app ("Nome, logo e contato", CompanyDataScreen)
    │
    ├── isPublicProfile = true
    ├── publicSlug gerado automaticamente
    ├── publicDescription preenchida
    │
    ▼
Rating trigger calcula averageRating
    │
    ▼
API /public/directory lista empresas públicas
    │
    ├── Filtros: cidade, estado, segmento
    ├── Ordenação: rating, nome, recente
    │
    ▼
Página /d/{slug} mostra perfil individual
    │
    ├── JSON-LD LocalBusiness (SEO)
    ├── Meta tags dinâmicas
    ├── Botão "Agendar pelo WhatsApp"
    │
    ▼
Google indexa → busca orgânica "mecânico em florianópolis"
    │
    ▼
Visitante vê perfil → clica WhatsApp → vira cliente da empresa
    │
    ▼
Empresa cria OS → cliente recebe link /q/{token} → vê CTA (Fase 1) → novo ciclo
```

## Critérios de Verificação

### Campos estruturados
- [ ] Company model (Dart + TypeScript) tem `city`, `state`, `zipCode`
- [ ] `build_runner` e `gen-l10n` executam sem erros
- [ ] CompanyDataScreen mostra campos de cidade/estado
- [ ] Script de migração parseia corretamente endereços no padrão "..., Cidade - UF"

### Perfil público
- [ ] Toggle "Ativar perfil público" em "Sua empresa" funciona
- [ ] `publicSlug` é gerado automaticamente ao ativar (baseado em nome + cidade)
- [ ] Campos de descrição, telefone e email públicos aparecem quando toggle está ativo
- [ ] Slugs são únicos (duplicatas recebem sufixo numérico)

### Rating
- [ ] Cloud Function trigger recalcula `averageRating`/`totalRatings` quando OS recebe rating
- [ ] Valores são corretos (média aritmética com 1 casa decimal)

### API pública
- [ ] `GET /public/directory` retorna lista de empresas com `isPublicProfile: true`
- [ ] Filtros por city, state, segment funcionam
- [ ] Paginação funciona (page, limit, total)
- [ ] `GET /public/directory/{slug}` retorna detalhes da empresa
- [ ] Dados sensíveis não são expostos (owner, users, email/phone internos)

### Páginas web
- [ ] `/directory/` mostra hub com busca e filtros
- [ ] `/d/{slug}` mostra perfil individual com dados da API
- [ ] JSON-LD `LocalBusiness` schema está presente no HTML
- [ ] Meta tags (title, description, og:*) são preenchidas dinamicamente
- [ ] Design segue dark premium theme com CSS vars do design system
- [ ] Responsivo: funciona em mobile e desktop
- [ ] Build do Eleventy: `cd firebase/hosting && npm run build` roda sem erros

### SEO
- [ ] Sitemap `/sitemap-directory.xml` lista todos os perfis públicos
- [ ] `robots.txt` referencia o sitemap
- [ ] Páginas de perfil são indexáveis (sem `noindex`)
