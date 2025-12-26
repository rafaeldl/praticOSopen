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
