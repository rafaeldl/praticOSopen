# ACCOUNT_DELETION.md

## Visão Geral

"Excluir Conta" (Mais → Conta) roda no servidor, numa única chamada. Antes o app apagava documento por documento, com uma lista fixa de subcoleções: levava minutos, deixava dados para trás (settings, charges, private…) e, se o app fechasse no meio, a empresa ficava meio apagada.

## Endpoint

`DELETE /v1/app/account` na função **`accountApi`** (`southamerica-east1`, 540 s, 512 MiB), separada da `api` (que segue com 60 s). Rota em `firebase/functions/src/routes/v1/account.routes.ts`, função exportada no fim de `src/index.ts`.

- URL: o app troca o `/api` final da URL base por `/accountApi` (`resolveAccountApiBaseUrl` em `lib/services/api_headers.dart`). Vale para produção, emulador e ngrok.
- Header: `Authorization: Bearer <Firebase ID token>`. Não usa `X-Company-Id`: a exclusão é por usuário.
- O token é verificado com `verifyIdToken(token, true)` (checa revogação). O `uid` vem só dele; o body é ignorado.

| Status | Código | Quando |
|---|---|---|
| 200 | — | `{ success: true, data: { deletedCompanies, leftCompanies } }` |
| 200 | — | `{ success: true, data: { alreadyDeleted: true } }`: o usuário do Auth já não existe (nova tentativa depois de um timeout). Não exige login recente |
| 401 | `UNAUTHORIZED` / `TOKEN_EXPIRED` | Sem token, token inválido, revogado ou expirado |
| 401 | `REQUIRES_RECENT_LOGIN` | `auth_time` do token com mais de 5 minutos |
| 409 | `COMPANY_HAS_MEMBERS` | Dono de empresa com outros membros (mensagem em pt) |
| 409 | `OWNERSHIP_MISMATCH` | O campo `owner` e o mapa privado de membros não batem (mensagem em pt pedindo para falar com o suporte) |
| 500 | `INTERNAL_ERROR` | Falha inesperada; pode tentar de novo |

## Regras

Lógica em `services/account-deletion.service.ts` (`decideCompany`, dependências injetáveis); acesso a dados em `account-deletion.deps.ts`.

1. Empresas consideradas: `users/{uid}.companies[]` **mais** a consulta `companies where owner.id == uid` (e `owner == uid`, formato antigo).
2. **Todas** são checadas antes de apagar qualquer coisa. Se alguma bloquear, nada é apagado.
3. Posse: o campo `owner` pode ser editado por admins (regras do Firestore), então só ele não basta. É dono quando `owner.id == uid` **e** o mapa servidor `companies/{id}/private/membership.members` não contradiz:
   - `members[uid]` ausente ou `'owner'`, e nenhum outro uid com `'owner'` no mapa.
   - Ausente é aceito porque empresas criadas pelo app não têm o dono no mapa (o cliente não escreve em `private/` e o seed `memberships:seed` pula donos); empresas do bot gravam `members[uid] = 'owner'`.
   - Divergência (ex.: admin que trocou o `owner` para si, ou mapa dizendo `owner` com o campo apontando para outro) → 409 `OWNERSHIP_MISMATCH`.
4. Dono com outro membro em `memberships/*`, no mapa privado ou no array `company.users` (empresas antigas) → 409 `COMPANY_HAS_MEMBERS`.
5. Dono único: apaga Storage com prefixo `tenants/{id}/` e `companies/{id}/` (`bucket.deleteFiles`) e depois `firestore.recursiveDelete(companies/{id})`.
6. Empresa de outro dono: só se o uid estiver de fato em `memberships/{uid}` ou no mapa privado (o `users.companies[]` pode ser forjado). Apaga a foto em `tenants/{id}/users/{uid}/` e sai com `removeMember` (membership, mapa privado, `users` da empresa, links do WhatsApp daquela empresa).
7. Apaga os links do WhatsApp do usuário, `users/{uid}` (recursivo) e por fim o usuário do Firebase Auth.

Logs só com uid, companyId e contagens.

## Idempotência

Cada passo pode ser repetido. Empresa que já não existe é pulada; Storage é apagado antes do Firestore e o documento da empresa sai por último no `recursiveDelete`, então uma nova tentativa ainda acha o dono. O Auth é apagado por último: se ele já não existe, a rota responde 200 `alreadyDeleted` sem exigir login recente.

## App

`AuthStore.deleteAccount()` → `AccountDeletionApiService.deleteAccount()` (timeout de 120 s). Depois do 200: limpa preferências/estado e aguarda `signOutGoogle()`, que faz o sign-out do Firebase mesmo se o do Google falhar (`AuthRepository.signOutAll`).

Erros mapeados pelo serviço:
- 401 `REQUIRES_RECENT_LOGIN` → `Exception('REQUIRES_RECENT_LOGIN')` (a tela reautentica e tenta de novo);
- 409 → `Exception(<mensagem em pt do servidor>)`, mostrada por `AccountDeletionFlow.formatError`;
- timeout do cliente → `ACCOUNT_DELETION_TIMEOUT` → `l10n.accountDeletionTakingLong` ("A exclusão pode levar alguns minutos. Tente de novo em instantes."). O servidor continua; a nova tentativa termina ou responde 200.

## Limitações conhecidas

Fora do escopo desta versão:
- **Cobranças abertas no Asaas** não são canceladas; a conexão some com a empresa, mas a conta e as cobranças continuam no Asaas.
- **Assinatura no RevenueCat/lojas** não é cancelada (o app avisa antes de excluir); o registro no RevenueCat fica.
- **`apiKeys`** da empresa (coleção raiz) e outros **links órfãos** fora de `links/whatsapp/numbers` não são apagados.
- **Reautenticação por e-mail/senha**: o fluxo de reautenticação do app cobre Google e Apple; quem usa e-mail/senha precisa sair e entrar de novo para ter login recente.
- Uma empresa só com o dono, mas com o mapa privado contradizendo o campo `owner`, fica bloqueada até o suporte corrigir os dados.
