# CI_BUDGET.md

## Visão Geral

Como o GitHub Actions está organizado para caber nos **2.000 minutos/mês do plano Free** quando o repositório virar privado. Repositório público não paga Actions; privado paga, e minuto de macOS conta como 10.

A mudança foi feita em duas etapas:

1. **Etapa 1 (repositório ainda público):** enxugar as pipelines e trazer as checagens para a máquina local (hook de `pre-push`). Medir o consumo por uma ou duas semanas.
2. **Etapa 2:** limite de gasto em US$ 0 no Billing, runner self-hosted no Mac para os jobs de iOS, e só então tornar o repositório privado.

## Diagnóstico (out/2026, 30 dias)

| Workflow | Máquina | Minutos/mês | Erros reais pegos |
|---|---|---|---|
| iOS Build Check (todo PR) | macOS | 5.850 | 0 (3 falhas de cache/CocoaPods) |
| Release iOS (94 RCs) | macOS | 3.446 | — (30 builds cancelados pelo merge seguinte, ~680 min) |
| Android Build Check | Linux | 1.773 | 1 (plugin novo com JVM/Kotlin incompatível) |
| Code Quality (push em todo branch) | Linux | 1.295 | 5 |
| Release Android | Linux | 1.054 | — |
| Functions Check | Linux | 659 | 7 |
| Web App Check | Linux | 218 | ~18 |
| Deploys (Functions, Hosting, regras, Cloud Run) | Linux | ~300 | — |

Equivalente a ~98.000 minutos/mês, ou ~US$ 600/mês se fosse privado. 95% do custo era macOS, e os builds caros quase não pegavam erro: quem pega são analyze e testes.

## Arquitetura (depois da Etapa 1)

| O quê | Quando roda | Onde |
|---|---|---|
| Hook `pre-push` (analyze, testes, lint, typecheck) | Todo `git push` | Mac local |
| Code Quality, Functions Check, Web App Check, Parity Check, Web Check | Pull request (por pasta) | GitHub, Linux |
| Android Build Check | PR que muda `android/**`, `pubspec.*` ou `.fvmrc` | GitHub, Linux |
| iOS Build Check | Só manual (`workflow_dispatch`) | GitHub, macOS |
| Deploys (Functions, Hosting, regras, Cloud Run) | Push na `master` (por pasta), como antes | GitHub, Linux |
| Auto Version → Release Android + Release iOS | Só manual | GitHub (iOS em macOS até a Etapa 2) |
| Promote Release | Só manual | GitHub |
| Rules Drift | Diário | GitHub, Linux |

Os deploys continuam automáticos no merge de propósito: o backend precisa sair antes do app (o RC usa o mesmo Firebase de produção), e correções de site/regras não devem esperar uma versão do app.

Vários merges seguidos não enfileiram um deploy por merge: Functions, Hosting e Cloud Run usam `concurrency` com `cancel-in-progress: true`, então um push novo cancela o deploy em andamento e os pendentes, e só o último commit publica tudo. As regras ficam de fora de propósito (`cancel-in-progress: false`), para não cancelar uma publicação de regras pela metade.

## Hook de pre-push

Arquivo versionado em `.githooks/pre-push`. Instalar uma vez por clone:

```bash
scripts/install-git-hooks.sh
```

O script cria um link na pasta de hooks comum do git, então vale para todas as worktrees e não mexe em outros hooks (como o `post-commit`).

O hook olha os arquivos alterados pelos commits do push e roda só o que foi tocado:

| Se mudou | Roda |
|---|---|
| `lib/`, `test/`, `pubspec.*`, `.fvmrc`, `docs/web-app/contract-cases/` | `fvm flutter analyze` + `fvm flutter test` |
| `firebase/functions/`, `docs/web-app/contract-cases/` | `npm run lint` + `npm run typecheck` + `jest` (sem credenciais do gcloud, igual ao CI) |
| `firebase/webapp/`, `docs/web-app/contract-cases/`, `lib/l10n/*.arb` | `npm run typecheck` + `npm test` |

Regras:
- Branch nova é comparada com o ponto em que saiu da `origin/master`.
- Roda sobre a cópia de trabalho: mudanças não commitadas também contam.
- Instala `node_modules` com `npm ci` se faltar (worktrees novas).
- E2E do web app, regras do Firestore e paridade ficam só no CI (precisam de emuladores ou são baratos lá).

## Web App Check

Em nov/2026 levava 20 min por execução, 15 deles nos 700 testes E2E (3 navegadores numa máquina de 4 núcleos). Os testes de axe somavam ~1/4 do tempo e os de receber/cobrar ~1/5.

- Um push novo no mesmo PR cancela a execução anterior (também no Code Quality e no Functions Check).
- Três jobs em paralelo: um rápido (gen, typecheck, testes, build, Lighthouse, Hosting) e o E2E dividido em dois (`--shard=1/2` e `2/2`). A espera cai pela metade; os minutos ficam parecidos.
- Axe no tema escuro (34 testes) só quando o PR mexe em estilos (`src/styles/`, `src/lib/prefs.ts`, tokens do site).
- Atenção ao tornar privado: lá a máquina padrão tem 2 núcleos, e o E2E fica mais lento.

## Functions Check

Em nov/2026 o "Lint + Test" levava 8 a 13 min: o `ts-jest` checava os tipos de cada arquivo de teste. Agora o Jest só transpila (`isolatedModules`) e os tipos de fontes e testes são checados num passo próprio (`npm run typecheck`, com `tsconfig.test.json`, ~5 s). Na máquina local o Jest caiu de 196 s para 34 s.
- Para pular numa emergência: `git push --no-verify` ou `SKIP_PREPUSH=1 git push`.

## Etapa 2 (pendente)

1. Medir o consumo de uma ou duas semanas no fluxo novo (API `actions/runs` + `jobs`) e confirmar Linux abaixo de 2.000 min/mês.
2. Billing → Budgets: limite de US$ 0 para Actions (as execuções param em vez de cobrar).
3. Registrar o Mac como runner self-hosted (labels `self-hosted, macOS`).
4. Trocar `runs-on` do `ios_release.yml` e do job de iOS do `promote-release.yml` para o runner self-hosted; testar um RC.
5. Tornar o repositório privado.

Atenção: com o runner self-hosted, o RC de iOS só sai com o Mac ligado. Um job sem runner fica na fila e falha depois de 24 horas.
