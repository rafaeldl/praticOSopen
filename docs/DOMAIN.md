# Domínio praticos.app

## Visão Geral

Desde 2026-11 o PraticOS usa só `https://praticos.app`. Todo link que o sistema gera (link da OS `/q/{token}`, PDF, perfil público `/pro`, MCP, site, lojas) aponta para lá.

Os domínios antigos `praticos.web.app` e `praticos.firebaseapp.com` continuam no ar porque são o mesmo site do Firebase Hosting (site `praticos`). Eles só existem para levar quem chega por um link antigo até `praticos.app`, com o mesmo caminho e a mesma query: links já mandados no WhatsApp, PDFs impressos e o app antigo instalado, que segue gerando links `web.app` até atualizar.

## Arquitetura

Como os três domínios servem o mesmo site, um `redirects` no `firebase/firebase.json` vale para todos e entraria em loop em `praticos.app`. Por isso o redirecionamento olha o host e fica em cada parte:

| Parte | Caminhos | Como | Onde |
|---|---|---|---|
| Nuxt (Cloud Run `praticos-web`) | `/q/**`, `/pro/**`, `/admin/**` (GET/HEAD) | 301 no servidor, pelo `X-Forwarded-Host` que o Hosting manda; `Cache-Control: no-store` | `firebase/web/server/middleware/legacy-host.ts` |
| Site estático (Eleventy) | todas as páginas | script no começo do `<head>` (`location.replace`) | `firebase/hosting/src/_includes/partials/legacy-host.njk` |
| App web (`/web`) | `/web/**` | script no `index.html` de produção | `firebase/webapp/scripts/legacy-host-plugin.ts` |
| App web, endereço antigo (`/app`) | `/app`, `/app/**` | 301 no `redirects` do Hosting para `/web` (em qualquer domínio; não entra em loop porque o destino é outro caminho) | `firebase/firebase.json` |

O que **não** redireciona, de propósito:

- `/__/auth/*` e `/__/firebase/*`: são do Firebase. O app de celular ainda pode usar o handler de qualquer domínio.
- `/api/**` (Nuxt) e `/mcp/**` (função `api`): chamadas de máquina, inclusive POST. Um 301 quebraria o corpo do POST, então elas respondem em qualquer domínio.
- `/_nuxt/**`: arquivos do Nuxt.

## Regras de Negócio

- Todo link novo usa `https://praticos.app`. O padrão de `SHARE_BASE_URL` nas Functions é esse; em produção a variável não está definida.
- O redirect preserva caminho, query e hash.
- Busca: canonical, `og:url`, hreflang e sitemap saem de `site.baseUrl` (`firebase/hosting/src/_data/site.json`), que é `https://praticos.app`.
- Não apagar os domínios antigos do Hosting: links impressos e o app antigo dependem deles.

## Alternativa avaliada

Um segundo site no Hosting só com `redirects` (301 de verdade para tudo, inclusive páginas estáticas) exigiria mover `praticos.app` para um site novo, com novo certificado e tempo fora do ar, e ajustar o deploy. Como o canonical já aponta para `praticos.app` e o Google segue redirecionamento por script, ficou o desenho acima.

## Entrar com Apple no Android

O Android não tem Apple nativo. Antes, o app usava o fluxo web do pacote `sign_in_with_apple`, que manda a resposta da Apple (form_post) para o `redirectUri` e espera um servidor que devolva para o app (`intent://...`). O handler do Firebase (`/__/auth/handler`) não faz isso, então a aba nunca voltava, em qualquer domínio. Desde 2026-11-04 o Android usa `FirebaseAuth.signInWithProvider(AppleAuthProvider())` (`AuthRepository.usesFirebaseAppleFlow`), e o Firebase conduz a entrada pelo handler de `praticos.firebaseapp.com`, que nunca redireciona. O iPhone continua com a folha nativa da Apple.

A Apple aceita como retorno os três handlers (`praticos.app`, `praticos.web.app` e `praticos.firebaseapp.com`): conferido em 2026-11-04 abrindo a autorização com cada `redirect_uri` (um endereço fora da lista dá 403).
