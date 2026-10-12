# ACCOUNT_DELETION.md

## Visão Geral

"Excluir Conta" (Mais → Conta) roda no servidor, numa única chamada. Antes o app apagava documento por documento, com uma lista fixa de subcoleções: levava minutos, deixava dados para trás (settings, charges, private…) e, se o app fechasse no meio, a empresa ficava meio apagada.

## Endpoint

`DELETE /v1/app/account` na função `api` (`firebase/functions/src/routes/v1/account.routes.ts`).

- Header: `Authorization: Bearer <Firebase ID token>`. Não usa `X-Company-Id`: a exclusão é por usuário, então a rota verifica o token sozinha (sem `bearerAuth`/`resolveCompanyContext`, que exigem empresa).
- O `uid` vem só do token verificado; o body é ignorado.

| Status | Código | Quando |
|---|---|---|
| 200 | — | `{ success: true, data: { deletedCompanies, leftCompanies } }` |
| 401 | `UNAUTHORIZED` / `TOKEN_EXPIRED` | Sem token ou token inválido/expirado |
| 401 | `REQUIRES_RECENT_LOGIN` | `auth_time` do token com mais de 5 minutos |
| 409 | `COMPANY_HAS_MEMBERS` | Dono de empresa com outros membros (mensagem em pt) |
| 500 | `INTERNAL_ERROR` | Falha inesperada; pode tentar de novo |

## Regras

Lógica em `services/account-deletion.service.ts` (dependências injetáveis; produção em `account-deletion.deps.ts`).

1. Lê `users/{uid}.companies`. **Todas** as empresas são checadas antes de apagar qualquer coisa:
   - `companies/{id}.owner.id == uid` e existe outro membro (`memberships/*` ou `private/membership.members`) → 409, nada é apagado.
2. Empresa em que é dono único: apaga Storage com prefixo `tenants/{id}/` e `companies/{id}/` (`bucket.deleteFiles`) e depois `firestore.recursiveDelete(companies/{id})` (todas as subcoleções, sem lista fixa).
3. Empresa de outro dono: sai dela com `removeMember` (membership, mapa privado de membros, `users` da empresa e links do WhatsApp daquela empresa).
4. Apaga os links do WhatsApp do usuário, `users/{uid}` (recursivo) e por fim o usuário do Firebase Auth.

Logs só com uid, companyId e contagens.

## Idempotência

Cada passo pode ser repetido. Empresa que já não existe é pulada; Storage é apagado antes do Firestore e o documento da empresa sai por último no `recursiveDelete`, então uma nova tentativa ainda acha o dono. Sem `users/{uid}` e sem usuário no Auth, a resposta é 200.

## App

`AuthStore.deleteAccount()` → `AccountDeletionApiService.deleteAccount()` (timeout de 120 s). Depois do 200: limpa preferências/estado e faz `signOutGoogle()` (Google + Firebase). O serviço converte 401 `REQUIRES_RECENT_LOGIN` em `Exception('REQUIRES_RECENT_LOGIN')` (a tela reautentica e tenta de novo) e 409 em `Exception(<mensagem em pt>)`, que `AccountDeletionFlow.formatError` já mostra.

## Timeout da função

A função `api` passou de 60 s para 300 s de timeout (256 MiB), para caber a exclusão de uma empresa grande numa requisição. Se o app desistir aos 120 s e o servidor terminar depois, a próxima tentativa responde 200 (idempotente).
