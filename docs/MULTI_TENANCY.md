# Solução Multi-Tenant e Estrutura de Dados

Este documento descreve a arquitetura multi-tenant implementada no projeto PraticOS, detalhando o modelo de dados, o gerenciamento de estado e os fluxos de autenticação.

## 1. Visão Geral

O sistema utiliza uma abordagem de multi-tenancy lógica, onde os dados de diferentes organizações (empresas) coexistem nas mesmas coleções do Firestore, mas são segregados a nível de aplicação através de relacionamentos bidirecionais entre Usuários e Empresas.

## 2. Modelo de Dados

A estrutura de dados baseia-se em duas entidades principais: `User` (Usuário) e `Company` (Empresa), com um relacionamento N:N (Muitos para Muitos) gerenciado por objetos de ligação que armazenam metadados como o papel (role) do usuário.

### 2.1. Entidade `User`
Representa um usuário autenticado no sistema via Firebase Auth.
- **Coleção:** `users`
- **Campos Principais:**
  - `id`: UID do Firebase Auth.
  - `name`: Nome de exibição.
  - `email`: Endereço de email.
  - `companies`: Lista de objetos `CompanyRoleAggr` (Agregado de Empresa e Função).

#### Estrutura `CompanyRoleAggr`:
```dart
class CompanyRoleAggr {
  CompanyAggr? company; // Referência simplificada da empresa (id, nome)
  RolesType? role;      // Papel do usuário nesta empresa (admin, manager, user)
}
```

### 2.2. Entidade `Company`
Representa uma organização ou tenant.
- **Coleção:** `companies`
- **Campos Principais:**
  - `id`: Identificador único da empresa.
  - `name`: Razão social ou nome fantasia.
  - `users`: Lista de objetos `UserRoleAggr` (Agregado de Usuário e Função).

#### Estrutura `UserRoleAggr`:
```dart
class UserRoleAggr {
  UserAggr? user;   // Referência simplificada do usuário (id, nome)
  RolesType? role;  // Papel do usuário (admin, manager, user)
}
```

## 3. Gerenciamento de Estado e Lógica (MobX)

O controle de qual tenant está ativo e como os dados são acessados é feito através de Stores do MobX.

### 3.1. `AuthStore` (`lib/mobx/auth_store.dart`)
Responsável pela autenticação e inicialização da sessão do usuário.

- **Inicialização (`when` callback):**
  1.  Detecta o login do usuário.
  2.  Carrega o perfil completo do usuário (`UserStore`).
  3.  **Resolução do Tenant:**
      - Verifica se existe um `companyId` salvo anteriormente no `SharedPreferences`.
      - Se o ID salvo for válido e o usuário ainda pertencer àquela empresa, carrega-a.
      - Caso contrário, seleciona a primeira empresa da lista `companies` do usuário.
      - Se a lista estiver vazia (legado), busca por empresas onde o usuário é "dono" (`owner.id`).
  4.  Define `Global.companyAggr` com o tenant ativo.

- **Alternância de Tenant (`switchCompany`):**
  - Método que recebe um `companyId`, busca os dados da nova empresa e atualiza o estado global e o `SharedPreferences`.

### 3.2. `CompanyStore` (`lib/mobx/company_store.dart`)
Gerencia as operações relacionadas à entidade empresa e colaboradores.

- **Adicionar Colaborador (`addCollaborator`):**
  - Busca usuário por email.
  - Atualiza o documento `Company`: Adiciona o usuário à lista `users`.
  - Atualiza o documento `User`: Adiciona a empresa à lista `companies`.

- **Remover/Editar Colaborador:**
  - Métodos `removeCollaborator` e `updateCollaboratorRole` mantêm a consistência nas duas pontas do relacionamento.

## 4. Fluxo de Uso

1.  **Login:** O usuário loga com Google. O sistema identifica automaticamente a última empresa acessada ou a principal.
2.  **Dashboard:** Todas as operações (criar ordens, serviços, etc.) utilizam `Global.companyAggr.id` para filtrar ou associar dados ao tenant atual.
3.  **Troca de Empresa:**
    - No menu "Ajustes", se o usuário pertencer a mais de uma empresa, aparece a opção "Trocar Empresa".
    - Ao selecionar, o app recarrega o contexto com o novo tenant.
4.  **Gerenciar Equipe:**
    - Usuários com permissão podem acessar "Colaboradores" em "Ajustes".
    - Podem convidar novos membros por email e definir permissões (Admin, Manager, User).

## 5. Verificação de Vínculo e Custom Claims

O vínculo de um usuário com uma empresa é **sempre confirmado no servidor**, a partir dos dados da própria empresa. A lista `users/{uid}.companies` serve apenas para ordenação e exibição no app; ela não concede acesso por si só.

### 5.1. Fontes de verdade

`firebase/functions/src/services/membership.service.ts` (`verifyMembership`, `verifyUserMemberships`, `buildRolesClaim`) considera um vínculo válido quando:

1. O usuário é o dono da empresa (`companies/{cid}.owner.id`, ou o formato legado `owner` como string). Papel: `owner` ou `admin` conforme a entrada do usuário; caso contrário, `admin`.
2. O usuário está em `companies/{cid}.users[]` (`{user: {id, ...}, role}`). Papel: o dessa lista.

Qualquer outra entrada é ignorada (log apenas com identificadores). O documento `companies/{cid}/memberships/{uid}` é um índice para a interface (lista de colaboradores) e **não** é fonte de verificação. O servidor mantém esse índice em sincronia ao incluir, alterar o papel ou remover membros (`company.service.ts`).

### 5.2. Onde é usado

- **Custom claims** (`updateUserClaims`, trigger em `users/{uid}`): `roles = { [companyId]: role }` contém apenas vínculos verificados. As regras do Firestore em `companies/{cid}/**` usam `request.auth.token.roles[cid]`.
- **API do app** (`bearerAuth`, `resolveUserContext`, MCP): empresa e papel vêm da verificação; empresa não verificada → 403.
- **Convites** (`POST /v1/app/invites/:token/accept`): o servidor inclui o usuário em `companies/{cid}.users`, cria o documento de memberships e atualiza `users.companies`. Quando o e-mail do login difere do e-mail do convite, o aceite segue e é registrado um aviso (identificadores apenas).

### 5.3. Regras do Firestore relacionadas

- `companies/{cid}/memberships/{memberId}`: criação por admin da empresa, ou o próprio vínculo apenas no mesmo batch que cria a empresa (cadastro, `AuthService.signup`).
- `links/invites/tokens/{token}`: criação e gestão apenas por admin da empresa do convite, sem trocar a empresa; o convidado pode apenas alterar os campos de status (aceitar/recusar).
- Apps anteriores à v1.24.0 aceitavam convites gravando direto no Firestore; esse caminho não é mais permitido (o app atual usa a API).

### 5.4. Testes e scripts

Testes de regras (emulador do Firestore, projeto `demo-praticos`; requer **Java 21+**):

```bash
cd firebase/functions
# se o Java padrão for anterior ao 21, aponte para um JDK mais novo, ex. Homebrew:
export JAVA_HOME=/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home
npm run test:rules
```

Sem `FIRESTORE_EMULATOR_HOST`, a suíte de regras é ignorada em `npm test`. `RULES_FILE=<caminho>` permite testar outro arquivo de regras.

Scripts de manutenção (Application Default Credentials; projeto `praticos` ou `GCLOUD_PROJECT`; **dry-run por padrão**, `--apply` grava; saída só com prefixos de uid/cid):

```bash
cd firebase/functions
# 1. Inclui em companies/{cid}.users quem só tinha o documento de memberships
npm run memberships:migrate            # dry-run
npm run memberships:migrate -- --apply
# 2. Recalcula as claims a partir dos vínculos verificados e mostra as diferenças
npm run claims:recompute               # dry-run
npm run claims:recompute -- --apply
```

Ordem recomendada no deploy: rodar `memberships:migrate` antes de publicar as functions, e `claims:recompute` depois.

Para rodar contra o emulador: `FIRESTORE_EMULATOR_HOST=localhost:8080 FIREBASE_AUTH_EMULATOR_HOST=localhost:9099 GCLOUD_PROJECT=demo-praticos npm run claims:recompute`.
