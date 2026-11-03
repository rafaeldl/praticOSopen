# WEB_APP.md

## Visão Geral

App web do PraticOS: ferramenta de mesa para as mesmas contas e dados do app. Vue 3 + Vite, SPA estática em `/app`, código em `firebase/webapp/`. A decisão está em `docs/web-app/ADR-001-web-architecture.md`, as regras de tela em `docs/WEB_APP_DESIGN.md`, e a referência visual é o protótipo da branch `claude/web-app-prototype-bb3bbf` (tema Campo). Quando protótipo e `WEB_APP_DESIGN.md` divergem, vale o protótipo.

Estado: só a base. Entrada com e-mail, casca, permissões, componentes base e esqueleto da lista de OS. O deploy em `/app` ainda não existe: faltam `firebase.json` e `firebase-hosting-deploy.yml`.

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

### Metas e guardas

| Guarda | Onde | Limite |
|---|---|---|
| JS da tela de entrada (brotli) | `scripts/check-budget.mjs` | 200 KB |
| JS até a lista, com Firestore | `scripts/check-budget.mjs` | 240 KB |
| Acessibilidade, LCP, CLS, TBT | `lighthouserc.json` | 100, 2,5 s, 0,1, 300 ms |
| axe em claro e escuro | `e2e/a11y.spec.ts` | 0 violações |
| Lista visível, p75 | `e2e/perf/list-visible.spec.ts` | meta 1,5 s, falha acima de 4 s |

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

- Entrada só com e-mail e senha. Google e Apple ainda não existem.
- Sem criação de empresa nem aceite de convite no web.
- Lista de OS é esqueleto: sem filtros, valores, paginação nem tempo real.
- Quem não vê valores ainda não tem lista: depende da projeção da API.
