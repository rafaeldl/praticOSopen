# Public Profile / Mini-site do Profissional

> **Status:** Brainstorm / Ideação
> **Última atualização:** 2026-02-28
> **Relacionado:** [TOOLS_MARKETPLACE.md](./TOOLS_MARKETPLACE.md)

## Visão Geral

Gerar automaticamente uma página pública para cada profissional/empresa do PraticOS, criando presença digital sem esforço. O perfil se constrói a partir do uso do app no dia a dia.

**URL:** `praticos.web.app/pro/{slug}`
Ex: `praticos.web.app/pro/joao-refrigeracao-sp`

---

## O Problema

O profissional técnico hoje:

- Não tem site (caro, complicado de manter)
- Presença digital = WhatsApp + talvez um Instagram mal atualizado
- Quando cliente pede indicação, o amigo manda "o número do João" e pronto
- Sem portfólio, sem avaliações públicas, sem diferenciação
- Perde cliente pra quem "parece mais profissional" online

---

## A Solução

O profissional **já usa o PraticOS no dia a dia**. O perfil se constrói sozinho a partir dos dados que ele já gera:

| Dado que já existe no PraticOS | Vira no perfil público |
|-------------------------------|----------------------|
| Fotos das OS | Portfólio (profissional escolhe quais publicar) |
| Serviços cadastrados | Catálogo de serviços com faixa de preço |
| Avaliações de clientes | Depoimentos públicos com nota |
| Dados da empresa | Nome, logo, endereço, horário |
| Segmento da empresa | Categorização automática |
| Volume de OS concluídas | Selo de experiência ("350+ serviços realizados") |
| Tempo médio de resposta | Indicador de agilidade ("Responde em até 2h") |
| Área de atendimento | Mapa com raio de cobertura |

**O profissional não precisa "criar" o perfil.** Ele já existe. Só precisa ativar e escolher o que mostrar.

---

## Estrutura do Perfil

### Seções da Página

```
┌─────────────────────────────────────────────┐
│  [Logo]  João Refrigeração           ✓ Verificado  │
│  Refrigeração e Ar Condicionado                     │
│  📍 Campinas, SP                                    │
├─────────────────────────────────────────────┤
│                                                     │
│  350+ serviços    ★ 4.8 (120 avaliações)    ~2h     │
│  realizados        nota média             resposta  │
│                                                     │
├─────────────────────────────────────────────┤
│                                                     │
│  SOBRE                                              │
│  Técnico em refrigeração há 12 anos.                │
│  Especialista em split, cassete e VRF.              │
│  Atendimento residencial e comercial.               │
│                                                     │
├─────────────────────────────────────────────┤
│                                                     │
│  SERVIÇOS                                           │
│  ┌──────────────────────┬────────────┐              │
│  │ Instalação split     │ R$ 350-500 │              │
│  │ Manutenção prevent.  │ R$ 150-200 │              │
│  │ Carga de gás         │ R$ 250-400 │              │
│  │ Higienização         │ R$ 120-180 │              │
│  └──────────────────────┴────────────┘              │
│                                                     │
├─────────────────────────────────────────────┤
│                                                     │
│  PORTFÓLIO                                          │
│  [foto] [foto] [foto] [foto]                        │
│  [foto] [foto] [foto] [foto]                        │
│                                                     │
├─────────────────────────────────────────────┤
│                                                     │
│  AVALIAÇÕES                                         │
│  ★★★★★ "Excelente profissional, pontual..."        │
│  — Maria S. · há 2 semanas                          │
│                                                     │
│  ★★★★★ "Resolveu o problema rápido..."             │
│  — Carlos R. · há 1 mês                             │
│                                                     │
├─────────────────────────────────────────────┤
│                                                     │
│  CERTIFICAÇÕES                                      │
│  [badge] Instalador certificado Elgin               │
│  [badge] 100+ serviços concluídos                   │
│                                                     │
├─────────────────────────────────────────────┤
│                                                     │
│  LOCALIZAÇÃO                                        │
│  [Mapa com área de atendimento]                     │
│  Atende: Campinas, Valinhos, Sumaré                 │
│                                                     │
├─────────────────────────────────────────────┤
│                                                     │
│  [ 💬 WhatsApp ]  [ 📞 Ligar ]  [ 📅 Agendar ]    │
│                                                     │
│  Powered by PraticOS                                │
│                                                     │
└─────────────────────────────────────────────┘
```

### Controle de Privacidade

O profissional decide o que é público (opt-in por campo):

| Campo | Padrão | Controle |
|-------|--------|----------|
| Nome da empresa | Público | Obrigatório |
| Segmento | Público | Obrigatório |
| Cidade / Região | Público | Obrigatório |
| Endereço completo | Oculto | Opt-in |
| Telefone | Oculto | Opt-in (ou só via botão) |
| WhatsApp | Oculto | Opt-in (ou só via botão) |
| Serviços e preços | Público | Pode ocultar preço |
| Fotos do portfólio | Oculto | Seleção manual por foto |
| Avaliações | Público | Pode ocultar individuais |
| Volume de OS | Público | Opt-out |
| Tempo de resposta | Público | Opt-out |

**Regra fundamental:** Nenhum dado de cliente final é exposto. Fotos do portfólio são selecionadas manualmente pelo profissional.

---

## Níveis de Perfil

| | **Básico (grátis)** | **Pro (assinante PraticOS)** |
|---|---|---|
| Página pública | Sim | Sim |
| URL | `/pro/{id}` | `/pro/{slug-customizado}` |
| Portfólio | Até 10 fotos | Ilimitado |
| Avaliações | Exibe | Exibe + respostas públicas |
| Serviços | Lista simples | Lista com faixa de preço |
| SEO | Básico (indexável) | Otimizado (meta tags, schema.org, sitemap) |
| Analytics | Nº de visualizações | Visualizações + cliques + origem do tráfego |
| Agendamento online | Não | Sim (integrado com agenda do app) |
| QR Code | Básico | Kit completo (adesivo vitrine, cartão) |
| Destaque em buscas | Não | Sim (aparece primeiro na busca do PraticOS) |
| Domínio customizado | Não | Futuro (joaorefrigeracao.com.br → perfil) |

---

## Mecânica Viral

### Camada 1 - O profissional compartilha

O profissional tem incentivo direto pra divulgar seu perfil:

- **Instagram** → link na bio
- **WhatsApp** → status, mensagem automática pós-serviço
- **Cartão de visita** → QR code que leva ao perfil
- **Vitrine / Veículo** → adesivo com QR code
- **Google Meu Negócio** → link do perfil como site
- **Facebook** → link na página da empresa

Material pronto fornecido pelo PraticOS:
- QR code gerado automaticamente
- Imagem pra status do WhatsApp
- Adesivo de vitrine em PDF pra imprimir
- Post template pra redes sociais

### Camada 2 - O cliente compartilha

O cliente se torna canal de divulgação:

- Amigo pede indicação → manda o link do perfil (não só o telefone)
- Avaliação pública tem botão "compartilhar esta avaliação"
- Pós-serviço: "Gostou do serviço? Compartilhe meu perfil" (mensagem automática)
- Cliente que avalia ganha incentivo (desconto no próximo serviço, por exemplo)

### Camada 3 - SEO orgânico

Cada perfil é uma página indexável pelo Google:

- "Técnico de refrigeração em Campinas" → perfil do PraticOS aparece
- Quanto mais perfis ativos, mais presença do PraticOS nos resultados de busca
- Long tail keywords: "conserto ar condicionado split zona sul SP"
- Schema.org LocalBusiness + Service → rich snippets no Google
- Avaliações aparecem como estrelas nos resultados de busca

**Escala:** 1.000 profissionais ativos = 1.000 páginas indexadas, cada uma atacando keywords locais diferentes. Efeito SEO composto.

### Camada 4 - Profissional atrai profissional

O efeito mais poderoso:

- Técnico vê perfil de colega e quer um igual
- "Como você fez essa página?" → "É do PraticOS, o app que eu uso"
- Aquisição zero-custo, com prova social embutida
- Profissional que indica ganha destaque no próprio perfil ("Indicado por João Refrigeração")

---

## Conexão com o Ecossistema

O perfil público potencializa todas as outras ideias do [TOOLS_MARKETPLACE.md](./TOOLS_MARKETPLACE.md):

| Feature | Como aparece no perfil |
|---------|----------------------|
| **Marketplace** | "Peças fornecidas por [Parceiro]" → fornecedor ganha visibilidade |
| **Certificação** | Badges de marca/fabricante exibidos com destaque |
| **Garantia digital** | Selo "Serviços com garantia PraticOS" |
| **Comunidade** | "Indicado por 15 profissionais" → prova social entre pares |
| **Benchmark** | "Preços na média do mercado" → selo de confiança |
| **Manutenção preventiva** | Seção "Planos de manutenção disponíveis" |
| **Capacitação** | Cursos concluídos e certificações listadas |
| **Compra coletiva** | "Membro do grupo de compras [Região]" |

---

## Fluxo de Ativação

```
Profissional já usa o PraticOS
    ↓
Notificação: "Seu perfil público está pronto! Revise e ative"
    ↓
Tela de preview no app (vê como vai ficar)
    ↓
Escolhe o que mostrar (serviços, fotos, preços)
    ↓
Ativa → perfil vai ao ar em praticos.web.app/pro/{slug}
    ↓
Recebe kit de divulgação (QR code, adesivo, posts)
    ↓
Compartilha → clientes acessam → mais visibilidade
    ↓
Dashboard no app: "Seu perfil teve 45 visitas esta semana"
```

### Gatilhos pra ativação

- **Onboarding:** Após cadastrar a empresa e primeiros serviços, sugerir ativação
- **Marco de OS:** "Você completou 50 serviços! Ative seu perfil e mostre sua experiência"
- **Primeira avaliação:** "Seu cliente te avaliou com 5 estrelas! Publique no seu perfil"
- **Foto de qualidade:** "Essa foto ficou ótima! Quer adicionar ao seu portfólio público?"

---

## Métricas de Sucesso

### Para o profissional (dashboard no app)

- Visualizações do perfil (total e por período)
- Cliques em WhatsApp / Ligar / Agendar
- Origem do tráfego (Google, Instagram, WhatsApp, direto)
- Posição em buscas locais
- Avaliações recebidas

### Para o PraticOS (métricas internas)

- % de empresas com perfil ativo
- Visualizações totais de perfis
- Tráfego orgânico vindo do Google (SEO)
- Conversão: visitante do perfil → download do app (cliente final)
- Conversão: visitante do perfil → novo profissional cadastrado (viral)
- Perfis compartilhados por mês

---

## Arquitetura Técnica

### Stack: Nuxt.js (Vue) no Cloud Run

**Decisão:** Usar **Nuxt.js** como framework web, rodando no **Cloud Run** em `southamerica-east1`, com **Firebase Hosting** como CDN na frente.

**Por que Nuxt.js (Vue) e não Next.js (React):**

- Sintaxe de template é HTML-like, próxima do Nunjucks que já usamos no site institucional
- Single File Components (`.vue`) mantêm template, lógica e estilos no mesmo arquivo
- Reatividade do Vue é parecida com MobX (usado no Flutter)
- Auto-imports de componentes e composables reduzem boilerplate
- SEO built-in (`useSeoMeta`, `useHead`) sem configuração extra
- Curva de aprendizado mais suave pra time Flutter

**Por que Cloud Run e não Cloud Functions:**

- Cloud Run disponível em `southamerica-east1` (Firebase App Hosting não está no Brasil)
- Suporta SSR completo com ISR (Incremental Static Regeneration)
- Scale to zero (custo eficiente com pouco tráfego)
- Sem cold start problemático (min-instances configurável)
- Mesmo billing GCP, mesmo projeto Firebase

### Fluxo de request

```
Usuário acessa: praticos.web.app/pro/joao-refrigeracao
    ↓
Firebase Hosting (CDN) → verifica cache
    ↓ cache miss
Rewrite para Cloud Run (southamerica-east1)
    ↓
Nuxt.js SSR
    ↓
Lê Firestore (company, services, reviews, photos)
    ↓
Renderiza HTML completo (meta tags, Schema.org, Open Graph)
    ↓
Retorna com cache headers → CDN cacheia
    ↓
Próximos acessos: servido direto do CDN
```

### Infraestrutura existente (reaproveitada)

| Componente | Status | Onde |
|-----------|--------|------|
| Firebase Hosting com rewrites | Existe | `firebase/firebase.json` |
| Cloud Functions com Express.js | Existe | `firebase/functions/` |
| Firestore com dados de empresas | Existe | `/companies/{companyId}/` |
| Firebase Storage (fotos) | Existe | `tenants/{companyId}/` |
| Share links funcionando | Existe | `praticos.web.app/q/{token}` |
| LGPD masking utilities | Existe | Cloud Functions |

### Estrutura do projeto Nuxt

```
firebase/web/                           # Novo projeto Nuxt.js
├── pages/
│   └── pro/
│       └── [slug].vue                  # /pro/joao-refrigeracao (SSR)
├── components/
│   └── profile/
│       ├── Header.vue                  # Logo, nome, segmento, verificado
│       ├── StatsBar.vue                # Métricas (serviços, nota, resposta)
│       ├── ServicesList.vue            # Serviços com faixa de preço
│       ├── PortfolioGrid.vue           # Grid de fotos do portfólio
│       ├── ReviewCard.vue              # Card de avaliação individual
│       ├── ReviewsSection.vue          # Seção de avaliações
│       └── CTAFooter.vue              # Botões WhatsApp / Ligar / Agendar
├── server/
│   ├── api/
│   │   └── profile/
│   │       ├── [slug].get.ts           # GET /api/profile/:slug
│   │       ├── [id]/
│   │       │   ├── services.get.ts     # GET /api/profile/:id/services
│   │       │   ├── reviews.get.ts      # GET /api/profile/:id/reviews
│   │       │   └── photos.get.ts       # GET /api/profile/:id/photos
│   └── utils/
│       ├── firebase.ts                 # Firebase Admin SDK init
│       └── profile-service.ts          # Queries Firestore
├── assets/
│   └── css/
│       └── profile.css                 # Estilos do perfil
├── public/
│   └── assets/
│       └── default-profile.png         # Fallback de logo
├── Dockerfile
├── nuxt.config.ts
└── package.json
```

### Página do perfil (`pages/pro/[slug].vue`)

```vue
<template>
  <main v-if="company">
    <ProfileHeader :company="company" />
    <ProfileStatsBar :stats="stats" />

    <section v-if="company.bio" class="about">
      <h2>Sobre</h2>
      <p>{{ company.bio }}</p>
    </section>

    <ProfileServicesList v-if="services?.length" :services="services" />
    <ProfilePortfolioGrid v-if="photos?.length" :photos="photos" />
    <ProfileReviewsSection v-if="reviews?.length" :reviews="reviews" />
    <ProfileCTAFooter :company="company" />
  </main>
</template>

<script setup lang="ts">
const route = useRoute()

const { data: company } = await useFetch(`/api/profile/${route.params.slug}`)

if (!company.value) {
  throw createError({ statusCode: 404, message: 'Perfil não encontrado' })
}

const [
  { data: services },
  { data: reviews },
  { data: photos },
] = await Promise.all([
  useFetch(`/api/profile/${company.value.id}/services`),
  useFetch(`/api/profile/${company.value.id}/reviews`),
  useFetch(`/api/profile/${company.value.id}/photos`),
])

const stats = computed(() => ({
  totalOrders: company.value.orderCount || 0,
  avgRating: reviews.value?.length
    ? (reviews.value.reduce((sum, r) => sum + r.rating, 0) / reviews.value.length).toFixed(1)
    : '0',
  reviewCount: reviews.value?.length || 0,
}))

// SEO - meta tags geradas no servidor
useSeoMeta({
  title: `${company.value.name} - ${company.value.segment} | PraticOS`,
  description: company.value.bio || `${company.value.name} em ${company.value.city}`,
  ogTitle: `${company.value.name} - ${company.value.segment}`,
  ogDescription: `${stats.value.totalOrders}+ serviços | ★${stats.value.avgRating}`,
  ogImage: company.value.logoUrl,
  ogType: 'business.business',
})

// Schema.org - rich results no Google
useHead({
  script: [{
    type: 'application/ld+json',
    innerHTML: JSON.stringify({
      '@context': 'https://schema.org',
      '@type': 'LocalBusiness',
      name: company.value.name,
      description: company.value.bio,
      image: company.value.logoUrl,
      address: {
        '@type': 'PostalAddress',
        addressLocality: company.value.city,
        addressRegion: company.value.state,
        addressCountry: 'BR',
      },
      aggregateRating: stats.value.reviewCount > 0 ? {
        '@type': 'AggregateRating',
        ratingValue: stats.value.avgRating,
        reviewCount: stats.value.reviewCount,
      } : undefined,
    }),
  }],
})
</script>
```

### Componente de exemplo (`components/profile/ReviewCard.vue`)

```vue
<template>
  <div class="review-card">
    <div class="stars">
      <span v-for="i in rating" class="star filled">★</span>
      <span v-for="i in (5 - rating)" class="star">☆</span>
    </div>
    <p class="comment">"{{ comment }}"</p>
    <span class="author">— {{ customerName }} · {{ date }}</span>
  </div>
</template>

<script setup lang="ts">
defineProps<{
  rating: number
  comment: string
  customerName: string
  date: string
}>()
</script>

<style scoped>
.review-card {
  padding: 1rem;
  border-bottom: 1px solid #eee;
}
.stars .filled { color: #f5a623; }
.comment { font-style: italic; margin: 0.5rem 0; }
.author { color: #888; font-size: 0.85rem; }
</style>
```

### Server API route (`server/api/profile/[slug].get.ts`)

```typescript
import { getFirestore } from 'firebase-admin/firestore'
import { initFirebase } from '~/server/utils/firebase'

export default defineEventHandler(async (event) => {
  initFirebase()
  const slug = getRouterParam(event, 'slug')
  const db = getFirestore()

  const snapshot = await db
    .collectionGroup('publicProfile')
    .where('slug', '==', slug)
    .where('active', '==', true)
    .limit(1)
    .get()

  if (snapshot.empty) {
    throw createError({ statusCode: 404 })
  }

  const doc = snapshot.docs[0]
  const companyId = doc.ref.parent.parent?.id

  // Buscar dados complementares da empresa
  const companyDoc = await db.doc(`companies/${companyId}`).get()
  const companyData = companyDoc.data()

  return {
    id: companyId,
    name: companyData?.name,
    segment: companyData?.segment,
    city: companyData?.address?.city,
    state: companyData?.address?.state,
    logoUrl: companyData?.logoUrl,
    ...doc.data(),
  }
})
```

### Deploy

**Firebase Hosting rewrite (`firebase.json`):**

```json
{
  "hosting": {
    "rewrites": [
      { "source": "/q/**", "destination": "/order/index.html" },
      {
        "source": "/pro/**",
        "run": {
          "serviceId": "praticos-web",
          "region": "southamerica-east1"
        }
      }
    ]
  }
}
```

**Dockerfile:**

```dockerfile
FROM node:22-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:22-alpine AS runner
WORKDIR /app
COPY --from=builder /app/.output ./
EXPOSE 3000
CMD ["node", "server/index.mjs"]
```

**Comando de deploy:**

```bash
cd firebase/web
gcloud run deploy praticos-web \
  --source . \
  --region southamerica-east1 \
  --allow-unauthenticated \
  --min-instances 0 \
  --max-instances 10
```

### Performance e Cache

| Cenário | Tempo de resposta |
|---------|------------------|
| Cache hit (CDN Firebase) | ~50ms |
| Cache miss (Cloud Run quente) | ~200-400ms |
| Cold start (Cloud Run frio) | ~1-2s (primeira vez após inatividade) |

Estratégia de cache:
- **ISR no Nuxt:** `routeRules` com `swr: 3600` (revalida a cada 1h)
- **CDN do Firebase:** cacheia resposta do Cloud Run
- **Invalidação:** quando perfil é atualizado no app, chama API de revalidação

### Escala futura

O projeto Nuxt em `firebase/web/` não serve só pro perfil público. Futuramente pode hospedar:

```
firebase/web/
├── pages/
│   ├── pro/[slug].vue              # Perfil público (fase atual)
│   ├── marketplace/                # Marketplace de fornecedores (futuro)
│   │   ├── index.vue               # Busca de fornecedores
│   │   └── [supplierId].vue        # Perfil do fornecedor
│   ├── portal/                     # Portal do cliente final (futuro)
│   │   └── [token].vue             # Acompanhamento de OS (substitui order-view.js)
│   └── q/[token].vue               # Share link migrado (futuro, substitui HTML atual)
```

---

### Estrutura Firestore

```
/companies/{companyId}/publicProfile    # Dados públicos (subdocumento)
  - active: boolean                     # Perfil ativo?
  - slug: string                        # URL amigável
  - bio: string                         # Descrição livre
  - showAddress: boolean                # Controles de privacidade
  - showPhone: boolean
  - showWhatsapp: boolean
  - showPrices: boolean
  - portfolioPhotos: string[]           # URLs das fotos selecionadas
  - hiddenReviews: string[]             # IDs de avaliações ocultas
  - activatedAt: timestamp
  - viewCount: number                   # Contador simples

/companies/{companyId}/profileMetrics/{period}  # Analytics
  - views: number
  - whatsappClicks: number
  - phoneClicks: number
  - bookingClicks: number
  - sources: { google: N, instagram: N, whatsapp: N, direct: N }
  - period: '2026-02'
```

### Integração no App Flutter

```
Configurações da Empresa (existente)
└── Perfil Público ← NOVO
    ├── Preview do perfil
    ├── Controles de privacidade (toggles)
    ├── Seleção de fotos pro portfólio
    ├── Edição do "Sobre"
    ├── QR Code e materiais de divulgação
    └── Dashboard de métricas
```

---

## Inspirações e Referências

| Referência | O que aproveitar |
|-----------|-----------------|
| **Google Meu Negócio** | Perfil local com avaliações, horário, mapa. Referência de SEO local |
| **Behance / Dribbble** | Portfólio visual. Conceito de "mostrar seu trabalho" |
| **Linktree** | Simplicidade do link único compartilhável |
| **iFood (página do restaurante)** | Perfil com avaliações, cardápio, pedido direto |
| **Houzz (perfil do profissional)** | Portfólio de projetos + avaliações no nicho de construção |
| **Thumbtack** | Perfil de profissional com badges, avaliações e contratação direta |

---

## Decisões Pendentes

| # | Decisão | Opções | Impacto |
|---|---------|--------|---------|
| 1 | ~~Tecnologia de renderização~~ | ~~SSR (Cloud Functions) / Pre-rendering / SPA~~ | **Decidido: Nuxt.js SSR no Cloud Run** |
| 2 | Domínio | Subpath (`praticos.web.app/pro/`) / Subdomínio (`pro.praticos.com.br`) | Define branding e SEO |
| 3 | Agendamento online | Simples (abre WhatsApp com mensagem) / Completo (agenda integrada) | Define complexidade da v1 |
| 4 | Moderação de conteúdo | Manual / Automática / Híbrida | Define operação e qualidade |
| 5 | Perfil gratuito vs. pago | Totalmente grátis / Freemium (básico grátis + pro pago) | Define modelo de negócio |
| 6 | Escopo da v1 | Página estática simples / Página interativa com agendamento | Define velocidade de lançamento |
