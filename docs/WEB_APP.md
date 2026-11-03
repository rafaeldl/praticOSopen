# WEB_APP.md

## Visão Geral

App web do PraticOS: ferramenta de mesa para as mesmas contas e dados do app. Vue 3 + Vite, SPA estática em `/app`, código em `firebase/webapp/`. A decisão está em `docs/web-app/ADR-001-web-architecture.md`, as regras de tela em `docs/WEB_APP_DESIGN.md`, e a referência visual é o protótipo da branch `claude/web-app-prototype-bb3bbf` (tema Campo). Quando protótipo e `WEB_APP_DESIGN.md` divergem, vale o protótipo.

Estado: base pronta para publicar, fechada por lista de acesso. Tem entrada (Google, Apple, e-mail), convites, escolha de empresa, casca, permissões, componentes base e o esqueleto da lista de OS. O deploy em `/app` sai junto com o site.

Decisões fechadas: botão principal amarelo, densidade confortável, painel ao lado, IBM Plex Sans no texto, Outfit só no logo.

## Arquitetura

```
firebase/webapp/
├── scripts/gen.mjs        # contrato: permissões e textos → src/generated/
├── scripts/check-budget.mjs  # orçamento de tamanho, roda no build
├── src/
│   ├── i18n/              # t(), web_{pt,en,es}.json
│   ├── lib/               # firebase, api, session, permissions, format, segments…
│   ├── lib/rules/         # regras de OS cobertas pelos casos de contrato
│   ├── components/        # Layer, Combobox, MoneyInput, DateField, StatusLabel…
│   ├── views/             # casca e telas
│   ├── navigation.ts      # entradas do menu, com a permissão de cada uma
│   └── router.ts          # rotas e guarda
├── tests/                 # vitest
└── e2e/                   # Playwright + Emulator Suite
```

### Contrato gerado

`npm run gen` lê:

- `firebase/functions/src/__tests__/rbac/app-permissions.json`: matriz de permissões.
- `lib/l10n/app_{pt,en,es}.arb` e `src/i18n/web_{pt,en,es}.json`: textos. O ICU (placeholders e plurais) é compilado aqui, então não há parser no navegador.

Falha se os idiomas divergirem em chave ou parâmetro, se uma chave web não começar com `web.` ou se repetir uma chave do app.

A saída fica em `src/generated/`, **fora do git**. Motivo: são 1.800 textos em 3 idiomas que mudariam a cada alteração nos `.arb`, gerando conflito e ruído num repositório público, e a fonte já está versionada. `dev`, `build`, `test` e `typecheck` rodam o gerador antes.

Nos builds (`--prune`) só entram as chaves citadas no código, 5% do total, o que corta cerca de 30 KB do download. Por isso **`t()` sempre recebe a chave literal**. Montar a chave em tempo de execução (`` t(`status${x}`) ``) não passa no tipo e sumiria no build.

### Dados

| Operação | Caminho |
|---|---|
| Sessão, empresa, listas de quem vê valores | Firestore direto |
| Quem não tem `viewPrices` | Projeção da API (ainda não existe; a lista mostra aviso) |
| Dinheiro, status, itens | API, ver pré-requisitos no ADR |

Firebase é carregado sob demanda por `lib/firebase.ts`. A tela de entrada não baixa Firestore. Cache persistente fica desligado, porque o computador da oficina é compartilhado.

### Sessão e permissões

O papel vem do claim `roles` do token, a mesma fonte das regras do Firestore. O documento `users/{uid}` só dá nome e ordem das empresas. Se ele listar uma empresa que o token ainda não conhece, o token é renovado. `refreshClaims()` força isso depois de aceitar convite.

`owner` é lido como `admin` e papel desconhecido não recebe nada, como no servidor. Sem `useFinancial`, as permissões financeiras somem.

A tela só decide o que mostrar. Quem protege é o servidor e as regras.

### Entrada

Mesmas portas do app (`lib/screens/login.dart`): Google, Apple e "Já tenho conta com e-mail", com senha e "Esqueceu a senha?". Conta nova só por Google ou Apple, como no app. O app não tem entrada por link de e-mail, então o web também não tem.

Google e Apple abrem em popup. Se o navegador bloquear o popup, a entrada segue por redirect (`shouldRedirect` em `lib/session.ts`). Para o redirect funcionar no Safari, o `authDomain` precisa estar no mesmo site do app. Hoje ele é `praticos.firebaseapp.com`. Passar para `praticos.web.app` exige cadastrar `https://praticos.web.app/__/auth/handler` no cliente OAuth do Google e no Services ID da Apple, um passo manual nos consoles.

Quem trabalha em mais de uma empresa escolhe onde entrar (`/app/choose-company`). A escolha fica lembrada neste navegador e pode ser trocada no menu.

### Convites

Convites pendentes aparecem na tela "sem empresa" e em Configurações. A lista vem do Firestore (`links/invites/tokens`, pelo e-mail verificado). O aceite passa por `POST /v1/app/invites/:token/accept`. Depois o web espera o claim novo no token e entra na empresa.

**Limitação do servidor:** `/v1/app/invites` fica atrás de `bearerAuth`, que responde 403 para quem ainda não tem empresa. Por isso o primeiro convite de uma conta nova não é aceito pelo web. O app chama a mesma rota, então deve ter o mesmo problema. O teste está em `e2e/invites.spec.ts` como `fixme`. Quem já tem empresa aceita normalmente.

### Lista de acesso

O web abre só para contas liberadas. `GET /v1/app/web-access` (`firebase/functions/src/routes/v1/web-access.routes.ts`) lê `config/webApp`:

```json
{ "open": false, "allowedEmailHashes": ["<sha256 do e-mail em minúsculas>"] }
```

- Sem documento, sem e-mail ou com e-mail não verificado, o acesso é negado.
- `open: true` libera todo mundo.
- O cliente não lê nem grava `config/webApp` (regra do Firestore).
- A rota tem limite próprio por IP e guarda a leitura do documento por 30 s.

A SPA guarda um "sim" por 12 horas e confere de novo em segundo plano a cada 10 minutos. Um "não" fecha o app na hora. Quem não está na lista vê só a tela "ainda não foi liberado". Isso fecha as telas; os dados continuam protegidos pelas regras e pela API.

Para liberar alguém (nunca rode sem saber qual projeto):

```bash
cd firebase/functions
npm run webapp:access -- --email pessoa@exemplo.com --project <projeto>
npm run webapp:access -- --email pessoa@exemplo.com --remove --project <projeto>
npm run webapp:access -- --show --project <projeto>
npm run webapp:access -- --open --project <projeto>     # abre para todos
```

`--dry-run` mostra o que mudaria. Sem `--project`, o script recusa, exceto no emulador.

### Moeda e datas

`lib/format.ts` usa o **país da empresa**, não o idioma. Uma OS brasileira aberta em inglês continua em R$ e com vírgula. `parseMoney` lê o que foi digitado: `150` é 150, nunca 1,50.

### Histórico do navegador

Voltar fecha o que estiver aberto. O painel lateral usa `useRoutePanel`, com o id na URL. Quem chega por link recebe a lista atrás do painel, então o primeiro Voltar não sai do app. `Layer` empilha um parâmetro `layer` no histórico, e `guard` pergunta antes de fechar quando há texto digitado.

## Como rodar

Requer Node 22 e, para os emuladores, Java 21 ou mais novo. Na máquina do Rafael:

```bash
export PATH=/opt/homebrew/opt/openjdk@27/bin:$PATH JAVA_TOOL_OPTIONS=-Duser.language=en
```

```bash
cd firebase/webapp
npm ci
npm run gen          # contrato
npm test             # vitest, inclui docs/web-app/contract-cases
npm run typecheck
npm run build        # build com orçamento (falha acima do limite)
```

Desenvolvimento, sempre contra o emulador (`demo-praticos`):

```bash
(cd ../functions && npm ci && npm run build)   # uma vez
npm run emulators    # terminal 1: suíte + seed
npm run dev          # terminal 2: http://localhost:5180/app/
```

Usuários do seed: `e2e/fixtures.mjs`, um por papel mais um sem empresa, com a senha do emulador que está nesse arquivo. Nada disso existe fora do emulador.

Testes de ponta a ponta:

```bash
npm run e2e                      # build, emulador, seed, Playwright
PW_ARGS=e2e/auth npm run e2e     # um arquivo
E2E_ONLY=auth,firestore,storage npm run e2e   # sem Functions (mais rápido)
npm run e2e:perf                 # 10 mil OS, Fast 4G + CPU 4x
npm run lhci                     # Lighthouse (precisa de build:e2e)
```

`E2E_ORDERS=10000` gera a lista grande no seed. O emulador sobe com `firebase/firebase.e2e.json`, em portas próprias, para não colidir com `firebase.test.json`. Segredos das Functions são falsos, criados só durante a execução.

A rota `/app/dev/components` mostra os componentes base. Existe só nos builds de emulador.

### Deploy

`firebase-hosting-deploy.yml` compila o site e, em seguida, a SPA (`npm run build:hosting`), que vai para `firebase/hosting/public/app`. O workflow dispara também com mudanças em `firebase/webapp/**`.

`firebase/firebase.json`:

| Caminho | O que faz |
|---|---|
| `/app/**` | rewrite para `/app/index.html`, antes dos outros rewrites |
| `/app/assets/**` | `Cache-Control: public, max-age=31536000, immutable` |
| rotas do app e `index.html` | `Cache-Control: no-cache` |
| `/app/**` | CSP, `X-Content-Type-Options: nosniff`, `Referrer-Policy`, `X-Frame-Options: DENY` |

A CSP libera os dois scripts inline do `index.html` por hash. Se um deles mudar, `npm run build` falha (`scripts/check-csp.mjs`) e mostra o hash novo para colar em `firebase.json`.

A configuração de produção fica em `.env.production`: só valores públicos, os mesmos do `firebase/web`.

`npm run check:hosting` sobe o emulador de Hosting com o `firebase.json` real e confere:

- `/app/orders/x` serve a SPA, com os cabeçalhos certos;
- os assets vêm com cache imutável;
- a tela de entrada abre sem bloqueio da CSP;
- o site, `/pricing` e `/robots.txt` continuam iguais.

`/q`, `/pro`, `/admin` e `/mcp` vão para o Cloud Run ou para as Functions. O script confere esses caminhos pela configuração, sem fazer requisição.

### Desempenho da lista

Fast 4G, CPU 4x, 10 mil OS, p75 de 7 rodadas, `npm run e2e:perf`. Cada passo é uma marca (`performance.mark`):

| Caminho tentado | 1ª visita | Volta |
|---|---|---|
| Base: sessão em série, servida sem compressão | 2.603 ms | 2.208 ms |
| Servida com brotli, como o Hosting | 2.104 ms | 1.362 ms |
| Usuário e empresa em paralelo, consulta junto com o token, modulepreload, 1ª página de 30 | 1.324 ms | 880 ms |
| Mais cache persistente do Firestore, lendo da rede | 1.375 ms | 949 ms |
| Mais leitura do disco primeiro na volta | **1.400 ms** | **519 ms** |

Na 1ª visita, o tempo se divide assim:

- até `session:auth`: cerca de 830 ms, entre download, execução com CPU 4x e início do Auth;
- usuário, empresa e lista no Firestore: cerca de 520 ms, quase todo em idas e voltas da conexão.

O teste falha acima de 1,5 s. O cache persistente é apagado ao sair (`clearFirestoreCache`), porque o computador é compartilhado. O teste roda sem o emulador de Functions e usa o "sim" da lista de acesso guardado, como numa visita depois da primeira.

### Metas e guardas

| Guarda | Onde | Limite |
|---|---|---|
| JS da tela de entrada (brotli) | `scripts/check-budget.mjs` | 200 KB |
| JS até a lista, com Firestore | `scripts/check-budget.mjs` | 240 KB |
| Acessibilidade, LCP, CLS, TBT | `lighthouserc.json` | 100, 2,5 s, 0,1, 300 ms |
| axe em claro e escuro | `e2e/a11y.spec.ts` | 0 violações |
| Lista visível, p75, 1ª visita | `e2e/perf/list-visible.spec.ts` | 1,5 s |
| Scripts inline com hash na CSP | `scripts/check-csp.mjs` | todos |
| `/app` no emulador de Hosting | `scripts/check-hosting.mjs` | todos os itens |

CI: `.github/workflows/webapp_check.yml`, em PR que toque o web, os casos de contrato, os `.arb` ou a matriz de permissões.

## Como adicionar uma tela

1. Crie `src/views/MinhaView.vue`, começando por `PageHead`, com a resposta da tela no título.
2. Em `src/navigation.ts`, adicione a entrada com `access: { kind: 'member', anyOf: [...] }`. Se a tela não entra no menu, crie a rota em `src/router.ts`.
3. **Toda rota declara `meta.access`.** Sem isso a guarda nega, e `tests/access.test.ts` falha.
4. Em `src/router.ts`, aponte `component` para a nova view, com `import()`.
5. Textos: reuse as chaves do app quando o sentido for igual. Texto só do web vai nos três `src/i18n/web_*.json`, com prefixo `web.`.
6. Rótulo que muda por ramo usa `resolveLabel` de `lib/segments.ts`.
7. Dinheiro e datas sempre por `lib/format.ts`, com `session.company?.country`.
8. Cores só pelos tokens. Status com `StatusLabel`.
9. Atalho: `registerShortcut`. Comando da paleta: `registerCommand`. Remova os dois ao desmontar.
10. Cubra vazio, erro e carregando com `EmptyState`, `ErrorState` e `LoadingState`. Erro de API: `t(errorMessageKey(error))`, nunca o texto cru.
11. Adicione a tela a `e2e/a11y.spec.ts` e `e2e/guard.spec.ts`, e atualize `docs/web-app/parity-matrix.yaml`.

## Limitações

- Sem criação de empresa no web.
- Conta nova não aceita o primeiro convite (limitação do servidor, ver Convites).
- Lista de OS é esqueleto: sem filtros, valores, paginação nem tempo real.
- Quem não vê valores ainda não tem lista: depende da projeção da API.
