# Web app — resumo de segurança (multi-tenancy)

Teste de isolamento entre empresas para o cliente web, autorizado pelo dono do
produto sobre o próprio código. Só revisão estática e emulador local; sem acesso
a produção e sem alterar regras, Storage ou o contrato da API. Detalhes
exploráveis e dados identificáveis ficam fora deste repositório (público).

## Modelo de ameaça

Um cliente web usa o mesmo backend por navegador, com usuários autenticados que
controlam todo o JavaScript. A pergunta central: um usuário conseguiria ler ou
alterar dados de outra empresa, ou agir acima do seu papel?

Base do isolamento: o vínculo usuário→empresa é sempre confirmado no servidor, a
partir de dados que só o Admin SDK grava (`companies/{cid}.owner` e
`companies/{cid}/private/membership`). O custom claim `roles` é derivado apenas
desses vínculos verificados, e as regras do Firestore e do Storage decidem o
acesso por ele.

## Superfícies testadas

- Firestore direto pelo cliente (custom claims `roles`).
- Cloud Storage (`tenants/{companyId}/**`, `companies/{companyId}/**`).
- API Cloud Functions: `v1/app` (app/web, bearer), `v1` (integração), `public`
  (magic link), `user`, `bot`, `mcp`.
- Nuxt SSR (`firebase/web/server`): `/q/{token}`, perfil público `/pro`, admin.
- Magic links `/q/{token}` (tokens de compartilhamento de OS).
- Campos denormalizados, escrita de campos protegidos (owner, plano/assinatura,
  `useFinancial`, `nfseEnabled`), auto-concessão de membership, tokens de
  convite/compartilhamento, CORS e rate limiting.

## Matriz de papéis que o web deve obedecer

Papéis: `owner` (superconjunto de `admin`), `admin`, `manager`, `supervisor`,
`consultant`, `technician`.

| Capacidade | owner/admin | manager | supervisor | consultant | technician |
|---|---|---|---|---|---|
| Ver/editar dados da empresa | sim | não | não | não | não |
| Gerenciar colaboradores (papéis) | sim | não | não | não | não |
| Ver todas as OS | sim | sim | sim | só as próprias | só as próprias |
| Criar/editar OS | sim | editar | sim | próprias | próprias |
| Apagar OS | sim | só `quote` | só `quote` | próprias `quote` | próprias `quote` |
| Ver/editar financeiro | sim | sim | não | não | não |
| Receber pagamento | sim | sim | não | próprias | não |
| Cobrança/NFS-e (Asaas) | sim | sim (cobrança) | não | não | não |
| Gerenciar clientes | sim | não | sim | sim | não |
| Gerenciar aparelhos | sim | não | sim | não | não |
| Produtos/serviços (catálogo) | sim | não | não | não | não |
| Conexão Asaas / integrações / NFS-e setup | sim | não | não | não | não |
| Dados do servidor (`private/**`), plano, flags | ninguém pelo cliente | | | | |

Regras transversais, válidas para qualquer papel: nenhum acesso a dados de outra
empresa; nenhum acesso a `companies/{cid}/private/**`; cliente não grava plano de
assinatura pago; escrita de cobranças/NFS-e/notificações só pelo servidor;
anônimo só acessa OS por magic link válido.

## Resultado

- Nenhuma quebra de isolamento **entre empresas** encontrada, nem escalonamento para outra empresa.
- **Dentro da mesma empresa** há restrições por perfil aplicadas só pelo cliente. O web não pode depender delas: dinheiro, status e valores passam pela API. Precisam de correção própria, com aprovação.
- Suíte de regras existente verde (Firestore e Storage).
- Teste novo de isolamento web adicionado (`firebase/functions/src/__tests__/web-isolation.rules.test.ts`,
  38 casos), cobrindo o acesso cruzado a outra empresa e a escrita de campos
  protegidos — todos passam contra as regras atuais.

### Achados

Contagens e reprodução ficam no registro privado. Há achados de severidade alta dentro da mesma empresa, fora do teste entre empresas, e o relatório de descoberta os trata como pré-requisito do web.

_Rodar:_ `cd firebase/functions && npm run test:rules` (requer Java 21+).

## Exposição real (revisão de 31/10)

A severidade dos achados dentro da empresa não muda, mas a exposição hoje é pequena: 738 de 753 membros reais são `admin`, 11 têm papel restrito, e cobrança Asaas e nota fiscal não têm uso real. A correção precisa vir antes de ampliar esses recursos, de abrir papéis no web ou de incentivar equipes.
