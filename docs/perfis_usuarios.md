# Perfis de Usuários - Sistema RBAC

O PraticOS utiliza um sistema de controle de acesso baseado em perfis (RBAC - Role-Based Access Control) para gerenciar as permissões dos colaboradores de cada empresa.

## Visão Geral dos Perfis

| Perfil | Ícone | Descrição | Foco Principal |
|--------|-------|-----------|----------------|
| Administrador | 👨‍💼 | Acesso total ao sistema | Gestão completa |
| Gerente | 💰 | Gestão financeira e relatórios | Financeiro |
| Supervisor | 🧑‍🔧 | Gestão operacional dos técnicos | Operacional |
| Consultor | 🧑‍💼 | Vendas e acompanhamento comercial | Comercial |
| Técnico | 👷 | Execução de serviços | Execução |

---

## 👨‍💼 Administrador

**Descrição:** Acesso total ao sistema. Responsável pela configuração da empresa e gestão de todos os recursos.

### Permissões

#### Ordens de Serviço
- ✅ Visualizar todas as OS da empresa
- ✅ Criar novas OS
- ✅ Editar qualquer OS
- ✅ Atribuir/reatribuir técnicos
- ✅ Executar serviços
- ✅ Deletar OS

#### Dados Financeiros
- ✅ Visualizar valores e preços
- ✅ Visualizar faturamento
- ✅ Acessar relatórios financeiros
- ✅ Editar valores e preços

#### Relatórios
- ✅ Relatórios operacionais
- ✅ Dashboard geral

#### Cadastros
- ✅ Gerenciar clientes
- ✅ Gerenciar produtos
- ✅ Gerenciar serviços
- ✅ Gerenciar dispositivos/equipamentos

#### Formulários
- ✅ Preencher formulários
- ✅ Gerenciar templates de formulários

#### Administração
- ✅ Gerenciar usuários e colaboradores
- ✅ Gerenciar perfis e permissões
- ✅ Configurar dados da empresa
- ✅ Configurar parâmetros globais

---

## 💰 Gerente (Financeiro)

**Descrição:** Responsável pela gestão financeira da empresa. Acesso completo a dados financeiros e relatórios, mas sem interferir na operação técnica.

### Permissões

#### Ordens de Serviço
- ✅ Visualizar todas as OS (somente leitura)
- ❌ Criar novas OS
- ❌ Editar OS
- ❌ Atribuir técnicos
- ❌ Executar serviços

#### Dados Financeiros
- ✅ Visualizar valores e preços
- ✅ Visualizar faturamento
- ✅ Acessar relatórios financeiros
- ✅ Editar valores e preços

#### Relatórios
- ✅ Relatórios operacionais
- ✅ Dashboard geral

#### Cadastros
- ✅ Visualizar clientes
- ✅ Visualizar produtos
- ✅ Visualizar serviços
- ✅ Visualizar dispositivos
- ❌ Gerenciar cadastros

#### Formulários
- ❌ Preencher formulários
- ❌ Gerenciar templates

#### Administração
- ❌ Sem acesso administrativo

---

## 🧑‍🔧 Supervisor

**Descrição:** Responsável pela gestão operacional da equipe técnica. Coordena a distribuição de trabalho e acompanha a execução dos serviços.

### Permissões

#### Ordens de Serviço
- ✅ Visualizar todas as OS
- ✅ Criar novas OS
- ✅ Editar qualquer OS
- ✅ Atribuir/reatribuir técnicos
- ✅ Executar serviços
- ✅ Deletar OS

#### Dados Financeiros
- ❌ Visualizar valores e preços
- ❌ Visualizar faturamento
- ❌ Acessar relatórios financeiros
- ❌ Editar valores e preços

#### Relatórios
- ✅ Relatórios operacionais
- ✅ Dashboard geral

#### Cadastros
- ✅ Gerenciar clientes
- ✅ Gerenciar produtos
- ✅ Gerenciar serviços
- ✅ Gerenciar dispositivos

#### Formulários
- ✅ Preencher formulários
- ✅ Gerenciar templates de formulários

#### Administração
- ❌ Sem acesso administrativo

---

## 🧑‍💼 Consultor (Vendedor)

**Descrição:** Perfil comercial focado em vendas e criação de orçamentos. Acesso limitado às suas próprias OS e dados de clientes.

### Permissões

#### Ordens de Serviço
- ✅ Visualizar apenas OS que criou
- ✅ Criar novas OS
- ✅ Editar suas próprias OS
- ❌ Atribuir técnicos
- ❌ Executar serviços
- ❌ Visualizar OS de outros

#### Dados Financeiros
- ✅ Visualizar valores e preços (para orçamentos)
- ❌ Visualizar faturamento geral
- ❌ Acessar relatórios financeiros
- ❌ Editar valores e preços

#### Relatórios
- ❌ Sem acesso a relatórios

#### Cadastros
- ✅ Gerenciar clientes
- ✅ Visualizar produtos
- ✅ Visualizar serviços
- ✅ Visualizar dispositivos

#### Formulários
- ✅ Preencher formulários
- ❌ Gerenciar templates

#### Administração
- ❌ Sem acesso administrativo

---

## 👷 Técnico

**Descrição:** Responsável pela execução dos serviços em campo. Acesso limitado apenas às OS que lhe foram atribuídas.

### Permissões

#### Ordens de Serviço
- ✅ Visualizar apenas OS atribuídas
- ❌ Criar novas OS
- ❌ Editar OS (exceto status e formulários)
- ❌ Atribuir técnicos
- ✅ Executar serviços (atualizar status, preencher formulários)

#### Dados Financeiros
- ❌ Visualizar valores e preços
- ❌ Visualizar faturamento
- ❌ Acessar relatórios financeiros
- ❌ Editar valores

#### Relatórios
- ❌ Sem acesso a relatórios

#### Cadastros
- ✅ Visualizar clientes (para contato)
- ❌ Gerenciar clientes
- ❌ Visualizar produtos
- ❌ Visualizar serviços
- ✅ Visualizar dispositivos (para execução)

#### Formulários
- ✅ Preencher formulários e checklists
- ❌ Gerenciar templates

#### Fotos
- ✅ Anexar fotos às OS
- ✅ Visualizar fotos

#### Administração
- ❌ Sem acesso administrativo

---

## Matriz de Permissões

### Ordens de Serviço

| Permissão | Admin | Gerente | Supervisor | Consultor | Técnico |
|-----------|-------|---------|------------|-----------|---------|
| Ver todas as OS | ✅ | ✅ | ✅ | ❌ | ❌ |
| Ver OS atribuídas | ✅ | ✅ | ✅ | ❌ | ✅ |
| Ver OS próprias | ✅ | ✅ | ✅ | ✅ | ❌ |
| Criar OS | ✅ | ❌ | ✅ | ✅ | ❌ |
| Editar OS | ✅ | ❌ | ✅ | ✅* | ❌ |
| Atribuir técnicos | ✅ | ❌ | ✅ | ❌ | ❌ |
| Executar OS | ✅ | ❌ | ✅ | ❌ | ✅ |
| Deletar OS | ✅ | ❌ | ✅ | ❌ | ❌ |

*Consultor pode editar apenas suas próprias OS

### Dados Financeiros

| Permissão | Admin | Gerente | Supervisor | Consultor | Técnico |
|-----------|-------|---------|------------|-----------|---------|
| Ver preços | ✅ | ✅ | ❌ | ✅ | ❌ |
| Ver faturamento | ✅ | ✅ | ❌ | ❌ | ❌ |
| Relatórios financeiros | ✅ | ✅ | ❌ | ❌ | ❌ |
| Editar preços | ✅ | ✅ | ❌ | ❌ | ❌ |

### Cadastros

| Permissão | Admin | Gerente | Supervisor | Consultor | Técnico |
|-----------|-------|---------|------------|-----------|---------|
| Gerenciar clientes | ✅ | ❌ | ✅ | ✅ | ❌ |
| Ver clientes | ✅ | ✅ | ✅ | ✅ | ✅ |
| Gerenciar produtos | ✅ | ❌ | ✅ | ❌ | ❌ |
| Ver produtos | ✅ | ✅ | ✅ | ✅ | ❌ |
| Gerenciar serviços | ✅ | ❌ | ✅ | ❌ | ❌ |
| Ver serviços | ✅ | ✅ | ✅ | ✅ | ❌ |
| Gerenciar dispositivos | ✅ | ❌ | ✅ | ❌ | ❌ |
| Ver dispositivos | ✅ | ✅ | ✅ | ✅ | ✅ |

### Administração

| Permissão | Admin | Gerente | Supervisor | Consultor | Técnico |
|-----------|-------|---------|------------|-----------|---------|
| Gerenciar usuários | ✅ | ❌ | ❌ | ❌ | ❌ |
| Gerenciar perfis | ✅ | ❌ | ❌ | ❌ | ❌ |
| Configurar empresa | ✅ | ❌ | ❌ | ❌ | ❌ |
| Gerenciar formulários | ✅ | ❌ | ✅ | ❌ | ❌ |

---

## Migração de Perfis Legados

O sistema automaticamente normaliza perfis antigos para os novos:

| Perfil Antigo | Novo Perfil |
|---------------|-------------|
| `manager` | `supervisor` |
| `user` | `tecnico` |

A normalização é feita tanto no backend (Cloud Functions) quanto no frontend (AuthorizationService).

---

## Implementação Técnica

### Arquivos Principais

| Arquivo | Descrição |
|---------|-----------|
| `lib/models/permission.dart` | Define `PermissionType` enum e `RolePermissions` class |
| `lib/services/authorization_service.dart` | Serviço centralizado de autorização |
| `lib/widgets/permission_widgets.dart` | Widgets de proteção de UI |
| `firebase/firestore.rules` | Regras de segurança do Firestore |
| `firebase/functions/claims.js` | Cloud Function para Custom Claims |

### Uso no Código

#### Verificar permissão simples
```dart
final auth = AuthorizationService.instance;
if (auth.hasPermission(PermissionType.viewPrices)) {
  // Mostrar preços
}
```

#### Proteger widget
```dart
PermissionGuard(
  permission: PermissionType.viewPrices,
  child: Text('R\$ ${order.total}'),
  fallback: Text('***'),
)
```

#### Proteger rota inteira
```dart
ProtectedRoute(
  permission: PermissionType.viewFinancialReports,
  child: FinancialDashboard(),
)
```

#### Filtrar lista por perfil
```dart
// No OrderStore
@computed
List<Order?> get filteredOrders {
  return _authService.filterOrdersByPermission(orders);
}
```

---

## Considerações de Segurança

1. **Validação em múltiplas camadas:**
   - Frontend: Widgets de proteção e filtros
   - Backend: Firestore Security Rules
   - Auth: Firebase Custom Claims

2. **Princípio do menor privilégio:**
   - Perfis têm apenas as permissões necessárias
   - Fallback para `tecnico` em caso de role desconhecido

3. **Isolamento por empresa:**
   - Usuário pode ter perfis diferentes em empresas diferentes
   - Claims estruturados por `companyId`

---

## FAQ

**P: Um usuário pode ter perfis diferentes em empresas diferentes?**
R: Sim. O sistema suporta multi-tenancy, onde um usuário pode ser Admin em uma empresa e Técnico em outra.

**P: O que acontece se um perfil não for reconhecido?**
R: O sistema normaliza para `tecnico` (menor privilégio) por segurança.

**P: Como adicionar um novo colaborador?**
R: Apenas Administradores podem adicionar colaboradores através de Ajustes > Colaboradores > Adicionar.

**P: Os valores financeiros ficam realmente ocultos para técnicos?**
R: Sim. A proteção é feita em múltiplas camadas: UI (widgets), lógica (filtros) e backend (security rules).
