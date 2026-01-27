# WEBSITE_STRUCTURE.md - Estrutura do Site Institucional

Documentacao tecnica do site institucional PraticOS construido com Eleventy (11ty).

## Visao Geral

O site institucional usa **Eleventy 2.0.1** como Static Site Generator (SSG) com templates **Nunjucks** para geracao de paginas HTML estaticas. O conteudo e **data-driven**, com dados armazenados em arquivos JSON separados dos templates.

### Stack

- **Eleventy 2.0.1**: Static Site Generator
- **Nunjucks**: Template engine
- **JSON**: Dados e conteudo estruturado
- **CSS Puro**: Sem preprocessadores
- **Firebase Hosting**: Deploy

### Principios

1. **Separacao de dados e apresentacao**: Conteudo em JSON, layout em templates
2. **Multi-idioma nativo**: Arquivos por idioma (pt, en, es) com dados localizados
3. **Componentes reutilizaveis**: Sistema de includes para DRY code
4. **Build estatico**: Output em HTML puro, sem dependencias runtime

## Estrutura de Diretorios

```
firebase/hosting/
├── .eleventy.js              # Configuracao Eleventy
├── package.json              # Dependencias npm
├── src/                      # FONTES - Editar aqui
│   ├── _data/               # Arquivos JSON de dados
│   │   ├── site.json        # Dados globais (nome, links, stats)
│   │   ├── navigation.json  # Menu de navegacao
│   │   ├── homepage.json    # Conteudo da homepage
│   │   ├── pricing.json     # Planos e precos
│   │   ├── faq.json         # Perguntas frequentes
│   │   ├── support.json     # Central de suporte
│   │   ├── legal.json       # Termos e privacidade
│   │   ├── docs.json        # Hub de documentacao
│   │   ├── docs/            # Dados por artigo de docs
│   │   │   ├── perfis.json
│   │   │   ├── financeiro.json
│   │   │   ├── procedimentos.json
│   │   │   └── icons.json
│   │   └── segments/        # Dados por segmento
│   │       ├── assistencia-celular.json
│   │       ├── automotivo.json
│   │       ├── refrigeracao.json
│   │       └── ...
│   ├── _includes/           # Templates reutilizaveis
│   │   ├── layouts/         # Layouts de pagina
│   │   │   ├── base.njk         # Layout base (html, head, body)
│   │   │   ├── homepage.njk     # Homepage
│   │   │   ├── segment.njk      # Paginas de segmento
│   │   │   ├── legal.njk        # Termos/Privacidade
│   │   │   ├── faq.njk          # FAQ
│   │   │   ├── support.njk      # Central de suporte
│   │   │   ├── pricing.njk      # Precos
│   │   │   ├── docs-hub.njk     # Hub de documentacao
│   │   │   └── docs-article.njk # Artigo de documentacao
│   │   ├── components/      # Componentes de UI
│   │   │   ├── hero.njk
│   │   │   ├── features-grid.njk
│   │   │   ├── features-segment.njk
│   │   │   ├── screenshots.njk
│   │   │   ├── pricing.njk
│   │   │   ├── download.njk
│   │   │   ├── contact.njk
│   │   │   └── docs/        # Componentes de documentacao
│   │   │       ├── section-renderer.njk
│   │   │       ├── info-card.njk
│   │   │       ├── warning-card.njk
│   │   │       ├── profiles-grid.njk
│   │   │       ├── permissions-grid.njk
│   │   │       ├── permissions-table.njk
│   │   │       ├── status-flow.njk
│   │   │       ├── status-cards.njk
│   │   │       ├── step-list.njk
│   │   │       └── ...
│   │   └── partials/        # Fragmentos comuns
│   │       ├── head.njk         # <head> tag
│   │       ├── navbar.njk       # Navegacao
│   │       ├── footer.njk       # Footer completo
│   │       ├── footer-simple.njk # Footer simples
│   │       ├── mobile-menu.njk  # Menu mobile
│   │       └── scripts.njk      # Scripts JS
│   ├── css/                 # Estilos
│   │   ├── segments.css     # Estilos de segmentos
│   │   ├── support.css      # Central de suporte
│   │   └── docs.css         # Documentacao
│   ├── assets/              # Assets estaticos
│   │   ├── images/          # Imagens gerais
│   │   └── screenshots/     # Screenshots do app
│   ├── style.css            # Estilos globais
│   ├── docs/                # Templates de documentacao
│   │   ├── index.njk        # Hub (pt)
│   │   ├── index-en.njk     # Hub (en)
│   │   ├── index-es.njk     # Hub (es)
│   │   ├── perfis.njk       # Artigo perfis (pt)
│   │   ├── perfis-en.njk    # Artigo perfis (en)
│   │   └── ...
│   ├── segmentos/           # Templates de segmentos
│   │   ├── assistencia-celular.njk
│   │   ├── assistencia-celular-en.njk
│   │   ├── automotivo.njk
│   │   └── ...
│   ├── index.njk            # Homepage (pt)
│   ├── index-en.njk         # Homepage (en)
│   ├── index-es.njk         # Homepage (es)
│   ├── privacy.njk          # Privacidade (pt)
│   ├── terms.njk            # Termos (pt)
│   ├── faq.njk              # FAQ (pt)
│   ├── support.njk          # Suporte (pt)
│   └── 404.njk              # Pagina de erro
└── public/                  # OUTPUT (gerado automaticamente)
    ├── index.html           # Homepage gerada
    ├── segmentos/           # Paginas de segmento geradas
    ├── docs/                # Documentacao gerada
    └── ...
```

**IMPORTANTE:** Nunca edite arquivos em `public/`. Eles sao sobrescritos no build.

## Comandos

```bash
cd firebase/hosting

# Build completo (gera public/)
npm run build

# Servidor de desenvolvimento com hot reload
npm run dev

# Watch mode sem servidor
npm run watch
```

## Arquitetura de Templates

### Hierarquia de Layouts

```
base.njk (estrutura HTML, head, body, navbar, footer)
    │
    ├── homepage.njk (hero, features, screenshots, pricing)
    │
    ├── segment.njk (hero, features especificas, pricing)
    │
    ├── legal.njk (termos, privacidade)
    │
    ├── faq.njk (accordions de FAQ)
    │
    ├── support.njk (central de ajuda)
    │
    ├── pricing.njk (tabela de precos)
    │
    ├── docs-hub.njk (index de documentacao)
    │
    └── docs-article.njk (artigo individual)
```

### Componentes Disponiveis

| Componente | Arquivo | Descricao |
|------------|---------|-----------|
| Hero | `hero.njk` | Banner principal com titulo e CTA |
| Features Grid | `features-grid.njk` | Grid de funcionalidades |
| Features Segment | `features-segment.njk` | Features especificas por segmento |
| Screenshots | `screenshots.njk` | Carrossel de screenshots |
| Pricing | `pricing.njk` | Tabela de planos |
| Download | `download.njk` | Botoes App Store/Play Store |
| Contact | `contact.njk` | Formulario/info de contato |

### Componentes de Documentacao

Os componentes em `components/docs/` renderizam secoes especificas:

| Componente | Uso |
|------------|-----|
| `section-renderer.njk` | Renderiza secoes baseado no tipo |
| `info-card.njk` | Card informativo azul |
| `warning-card.njk` | Card de alerta amarelo |
| `profiles-grid.njk` | Grid de perfis de usuario |
| `permissions-grid.njk` | Grid de permissoes |
| `permissions-table.njk` | Tabela comparativa |
| `status-flow.njk` | Diagrama de fluxo de status |
| `status-cards.njk` | Cards de status |
| `step-list.njk` | Lista de passos numerados |
| `validation-list.njk` | Lista de validacoes |
| `metrics-grid.njk` | Grid de metricas |
| `features-highlight.njk` | Destaque de funcionalidades |
| `faq-grid.njk` | Grid de FAQs |

## Sistema Multi-Idioma

### Arquivos por Idioma

Cada pagina tem 3 versoes:

```
page.njk        → Portugues (principal)
page-en.njk     → Ingles
page-es.njk     → Espanhol
```

### Dados Localizados

Arquivos JSON usam estrutura por idioma:

```json
{
  "pt": {
    "title": "Titulo em Portugues",
    "description": "Descricao em Portugues"
  },
  "en": {
    "title": "Title in English",
    "description": "Description in English"
  },
  "es": {
    "title": "Titulo en Espanol",
    "description": "Descripcion en Espanol"
  }
}
```

### Filter `localize`

Acessa dados do idioma corrente:

```njk
{% set data = homepage | localize(langCode) %}
{{ data.title }}
```

### Frontmatter de Idioma

```yaml
---
lang: pt-BR        # Atributo lang do HTML
langCode: pt       # Chave para acessar dados
langSwitch:        # Links para outros idiomas
  - code: PT
    href: page.html
    active: true
  - code: EN
    href: page-en.html
    active: false
  - code: ES
    href: page-es.html
    active: false
---
```

## Arquivos de Dados JSON

### site.json - Dados Globais

```json
{
  "name": "PraticOS",
  "email": "praticos@rafsoft.com.br",
  "appStore": "https://apps.apple.com/...",
  "playStore": "https://play.google.com/...",
  "stats": {
    "users": "500+",
    "orders": "10k+",
    "rating": "4.8"
  }
}
```

### navigation.json - Menu

```json
{
  "pt": {
    "items": [
      { "label": "Funcionalidades", "href": "#features" },
      { "label": "Precos", "href": "#pricing" }
    ]
  }
}
```

### segments/*.json - Dados por Segmento

```json
{
  "pt": {
    "title": "Assistencia de Celular",
    "heroTitle": "Gestao completa para",
    "heroHighlight": "Assistencias Tecnicas",
    "features": [...]
  }
}
```

### docs/*.json - Artigos de Documentacao

```json
{
  "pt": {
    "sections": [
      {
        "id": "visao-geral",
        "title": "Visao Geral",
        "intro": "Texto introdutorio...",
        "infoCard": { "title": "...", "content": "..." }
      },
      {
        "id": "perfis",
        "title": "Perfis Disponiveis",
        "profiles": [...]
      }
    ]
  }
}
```

## Frontmatter Padrao

### Paginas Gerais

```yaml
---
layout: layouts/homepage.njk
lang: pt-BR
langCode: pt
relPath: ""
title: "Titulo da Pagina"
description: "Descricao para SEO"
keywords: "palavras, chave"
ogTitle: "Titulo Open Graph"
ogDescription: "Descricao Open Graph"
permalink: page.html
langSwitch: [...]
---
```

### Paginas de Segmento

```yaml
---
layout: layouts/segment.njk
segmentSlug: assistencia-celular
segmentData: segments/assistencia-celular
---
```

### Artigos de Documentacao

```yaml
---
layout: layouts/docs-article.njk
docsData: perfis
heroTitle: "Perfis de"
heroTitleHighlight: "Usuario"
heroSubtitle: "Subtitulo"
sidebarTitle: "Nesta pagina"
sidebarNav:
  - id: visao-geral
    label: Visao Geral
  - id: perfis
    label: Perfis
breadcrumbRoot: "Documentacao"
breadcrumbCurrent: "Perfis"
docsIndexLink: ./
prevLink: null
nextLink:
  href: financeiro.html
  label: Proximo
  title: Financeiro
---
```

## Filtros Customizados

Definidos em `.eleventy.js`:

### `localize`

Extrai dados do idioma atual:

```njk
{% set data = homepage | localize(langCode) %}
```

### `relPath`

Calcula prefixo de caminho relativo baseado na URL:

```njk
<a href="{{ permalink | relPath }}index.html">Home</a>
```

## Como Criar Novas Paginas

### 1. Pagina Simples (Novo Tipo)

1. Criar layout em `src/_includes/layouts/novo-tipo.njk`
2. Criar dados em `src/_data/novo-tipo.json`
3. Criar templates:
   - `src/novo-tipo.njk` (pt)
   - `src/novo-tipo-en.njk` (en)
   - `src/novo-tipo-es.njk` (es)
4. Executar `npm run build`

### 2. Novo Segmento

1. Criar dados: `src/_data/segments/novo-segmento.json`
2. Criar templates:
   - `src/segmentos/novo-segmento.njk`
   - `src/segmentos/novo-segmento-en.njk`
   - `src/segmentos/novo-segmento-es.njk`
3. Atualizar `navigation.json` se necessario
4. Executar `npm run build`

### 3. Novo Artigo de Documentacao

1. Criar dados: `src/_data/docs/novo-artigo.json`
2. Criar templates:
   - `src/docs/novo-artigo.njk`
   - `src/docs/novo-artigo-en.njk`
   - `src/docs/novo-artigo-es.njk`
3. Atualizar `docs.json` para incluir no hub
4. Atualizar links prevLink/nextLink dos artigos adjacentes
5. Executar `npm run build`

## Estilos CSS

### Arquivos

| Arquivo | Escopo |
|---------|--------|
| `style.css` | Estilos globais, variaveis, componentes base |
| `css/segments.css` | Paginas de segmento |
| `css/support.css` | Central de suporte |
| `css/docs.css` | Paginas de documentacao |

### Tema Visual

- **Background**: `#0A0E17` (deep blue/black)
- **Accent**: Gradientes azul/roxo
- **Texto**: Branco com opacidades
- **Cards**: Glassmorphism com backdrop-filter
- **Fontes**: `Outfit` (headings), `DM Sans` (body)

### Variaveis CSS Principais

```css
:root {
  --bg-primary: #0A0E17;
  --bg-secondary: #0D1220;
  --text-primary: #FFFFFF;
  --text-secondary: rgba(255, 255, 255, 0.7);
  --accent-blue: #3B82F6;
  --accent-purple: #8B5CF6;
  --gradient-cta: linear-gradient(135deg, #3B82F6, #8B5CF6);
}
```

## Deploy

O deploy e feito via Firebase Hosting:

```bash
# Build local
cd firebase/hosting
npm run build

# Deploy (do diretorio raiz do projeto)
firebase deploy --only hosting
```

O CI/CD executa automaticamente:

1. `npm run build` para gerar `public/`
2. `firebase deploy` para publicar

## Troubleshooting

### Pagina nao aparece

- Verificar `permalink` no frontmatter
- Verificar se o build foi executado (`npm run build`)

### Dados nao carregam

- Verificar nome do arquivo JSON em `_data/`
- Verificar estrutura do JSON (chaves pt/en/es)
- Verificar uso do filter `localize`

### Estilos nao aplicam

- Verificar passthrough copy em `.eleventy.js`
- Verificar path relativo do CSS no `<head>`

### Erro de template

- Verificar sintaxe Nunjucks ({% %}, {{ }})
- Verificar includes (caminho correto)
- Verificar variaveis no frontmatter
