# Testes de perfis (RBAC)

## Visão Geral
Uma matriz perfil × ação garante que cada perfil faz o que pode e é barrado no que não pode, nas camadas que guardam os dados. Ela roda no CI (`Functions Check`) e reprova o PR quando uma permissão muda sem querer.

Atores testados: `owner`, `admin`, `supervisor`, `manager`, `consultant`, `technician`, admin de outra empresa (`otherCompany`), usuário sem empresa (`noCompany`) e anônimo.

## Arquitetura

| Camada | Fonte de verdade | Teste | Como roda |
|---|---|---|---|
| App | `lib/models/permission.dart` | `test/models/permission_matrix_test.dart` compara com `firebase/functions/src/__tests__/rbac/app-permissions.json` | `fvm flutter test` |
| App × regras | matriz + `app-permissions.json` | `rbac-app-consistency.test.ts` (offline) | `npm test` |
| Firestore | `firebase/firestore.rules` | `rbac-firestore.rules.test.ts`, gerado de `rbac/firestore-matrix.ts` | `npm run test:rbac` |
| Storage | `firebase/storage.rules` | `storage.rules.test.ts` | `npm run test:rbac` |
| API | `firebase/functions/src/routes/**` | `rbac-api.test.ts`, gerado de `rbac/api-matrix.ts` | `npm test` |

`test:rbac` sobe os emuladores de Firestore e Storage com `firebase/firebase.test.json` (portas 8180 e 9199, separadas do emulador de desenvolvimento). Precisa de JDK 21+.

## Regras de Negócio
- Cada caso da matriz diz quem **pode** (`allow`). Todos os outros atores precisam ser barrados.
- `permission` liga o caso à `PermissionType` do app: o teste de consistência falha se o app e as regras discordarem.
- `gap` registra uma diferença conhecida (um bug ou algo só escondido na tela). O teste afirma o comportamento **atual** e falha quando o gap deixa de existir, para que quem corrigir apague a anotação. Gap não é aprovação: cada um tem issue.
- No Storage, `allow` é o que a regra faz hoje e `shouldAllow` é o certo. Enquanto diferem, o caso aparece como `[GAP]`.

## Exemplos de Uso

```bash
cd firebase/functions
npm run test:rbac                       # Firestore + Storage + consistência
npx jest src/__tests__/rbac-api.test.ts # API
```

Adicionar uma ação: acrescentar um caso em `rbac/firestore-matrix.ts` (ou `api-matrix.ts`) com `allow` e, se for guardada no app, `permission`. Adicionar um perfil: incluir em `ROLE_ACTORS`/`ACTOR_INFO`, em `app-permissions.json` e rodar os testes; cada caso novo precisa dizer se o perfil pode.

Mutation check (prova que a suíte pega regressão): `RULES_FILE=<regras alteradas> firebase emulators:exec --only firestore --config ../firebase.test.json "npx jest src/__tests__/rbac-firestore.rules.test.ts"`. Na criação, 5 mutações (técnico no financeiro, gerente editando a empresa, todos lendo todas as OS, auto-adesão à equipe, técnico cadastrando cliente) deixaram de 2 a 9 testes vermelhos cada.

## O que não está coberto
- Jornadas na interface (Maestro) por perfil: precisam de contas por perfil no emulador e de runner macOS no CI.
- Link público `/q/{token}` no navegador.
