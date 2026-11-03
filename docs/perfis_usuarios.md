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

#### Formulários/Procedimentos
- ✅ Preencher formulários
- ✅ Gerenciar templates de formulários
- ✅ Reabrir procedimentos concluídos

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
- ✅ Visualizar todas as OS
- ❌ Criar novas OS
- ✅ Editar OS (Permite ajustes fiscais/financeiros e correções)
- ❌ Atribuir técnicos
- ❌ Executar serviços
- ✅ Deletar OS (apenas quando status = 'Orçamento')

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

#### Formulários/Procedimentos
- ❌ Preencher formulários
- ❌ Gerenciar templates
- ✅ Reabrir procedimentos concluídos (se tiver acesso)

#### Administração
- ❌ Sem acesso administrativo

---

## 🧑‍🔧 Supervisor

**Descrição:** Responsável pela gestão operacional da equipe técnica. Coordena a distribuição de trabalho e acompanha a execução dos serviços.

### Permissões

#### Ordens de Serviço
- ✅ Visualizar todas as OS (sem valores financeiros)
- ✅ Criar novas OS
- ✅ Editar OS **apenas quando status = 'Orçamento'**
  - ✅ Adicionar/editar/remover serviços e produtos
  - ✅ Alterar cliente e dispositivo
  - ✅ Alterar data de entrega
- ⚠️ Edição limitada **após status 'Orçamento'**
  - ✅ Editar apenas observações/descrições de serviços e produtos
  - ❌ Não pode alterar valores, quantidades ou campos principais
- ✅ Atribuir/reatribuir técnicos (em qualquer status)
- ✅ Executar serviços
- ✅ Deletar OS (apenas quando status = 'Orçamento')

#### Dados Financeiros
- ❌ Visualizar valores e preços
- ❌ Visualizar faturamento
- ❌ Acessar relatórios financeiros
- ❌ Editar valores e preços
- ❌ Gerar PDF de OS (contém dados financeiros)
- ❌ Filtros de pagamento ocultos (A receber/Pago)

#### Relatórios
- ❌ Sem acesso a relatórios
- ❌ Dashboard oculto

#### Cadastros
- ✅ Gerenciar clientes
- ❌ Gerenciar produtos (sem ver preços)
- ❌ Gerenciar serviços (sem ver preços)
- ✅ Gerenciar dispositivos

#### Formulários/Procedimentos
- ✅ Preencher formulários
- ✅ Gerenciar templates de formulários
- ✅ Reabrir procedimentos concluídos

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
- ✅ Deletar OS que criou (apenas quando status = 'Orçamento')
- ✅ Indicar o técnico (Responsável) nas OS que criou; nunca nas de outra pessoa
- ❌ Executar serviços
- ❌ Visualizar OS de outros (Admin pode reatribuir em caso de férias/ausência)

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

#### Formulários/Procedimentos
- ✅ Preencher formulários
- ❌ Gerenciar templates
- ❌ Reabrir procedimentos concluídos

#### Administração
- ❌ Sem acesso administrativo

---

## 👷 Técnico

**Descrição:** Responsável pela execução dos serviços em campo. Acesso às Ordens de Serviço da empresa para execução e reporte.

### Permissões

#### Ordens de Serviço
- ✅ Visualizar as OS que criou e as atribuídas a ele (`assignedTo`); as listas filtram `createdBy.id` OU `assignedTo.id`
- ✅ Criar novas OS (Inicia em 'Orçamento' para precificação posterior)
- ✅ Editar OS **apenas quando status = 'Orçamento'**
  - ✅ Adicionar/editar/remover serviços e produtos
  - ✅ Alterar cliente e dispositivo
  - ✅ Alterar data de entrega
- ✅ Deletar OS que criou (apenas quando status = 'Orçamento')
- ⚠️ Edição limitada **após status 'Orçamento'**
  - ✅ Editar apenas observações/descrições de serviços e produtos
  - ❌ Não pode alterar valores, quantidades ou campos principais
- ❌ Atribuir técnicos
- ✅ Executar serviços (atualizar status, preencher formulários)

#### Dados Financeiros
- ❌ Visualizar valores e preços
- ❌ Visualizar faturamento
- ❌ Acessar relatórios financeiros
- ❌ Editar valores
- ❌ Gerar PDF de OS (contém dados financeiros)
- ❌ Filtros de pagamento ocultos (A receber/Pago)

#### Relatórios
- ❌ Sem acesso a relatórios
- ❌ Dashboard oculto

#### Cadastros
- ✅ Visualizar clientes (para contato)
- ❌ Gerenciar clientes
- ❌ Visualizar produtos (valores ocultos nas listas)
- ❌ Visualizar serviços (valores ocultos nas listas)
- ✅ Visualizar dispositivos (para execução)

#### Formulários/Procedimentos
- ✅ Preencher formulários e checklists
- ❌ Gerenciar templates
- ❌ Reabrir procedimentos concluídos

#### Fotos
- ✅ Anexar fotos às OS
- ✅ Visualizar fotos

#### Administração
- ❌ Sem acesso administrativo

---

## Restrições Baseadas em Status da OS

### Status 'Orçamento' (quote)

Quando uma OS está em status **'Orçamento'**, os perfis **Supervisor** e **Técnico** têm permissões completas de edição:

- ✅ Adicionar novos serviços e produtos
- ✅ Editar serviços e produtos existentes
- ✅ Remover serviços e produtos (swipe to delete)
- ✅ Adicionar novos procedimentos (formulários/checklists)
- ✅ Remover procedimentos (swipe to delete)
- ✅ Preencher procedimentos
- ✅ Alterar cliente e dispositivo
- ✅ Alterar data de entrega
- ✅ Adicionar fotos
- ❌ **Valores financeiros permanecem ocultos** (sem permissão viewPrices)

### Status Após Aprovação (approved, progress)

Após a OS sair do status **'Orçamento'**, as restrições se aplicam de forma diferente para cada perfil:

#### 🧑‍🔧 Supervisor PODE:
- ✅ Visualizar a OS (sem valores)
- ✅ Tocar em serviço/produto para editar **apenas a descrição/observações**
- ✅ **Adicionar novos procedimentos** (enquanto OS estiver ativa)
- ✅ **Remover procedimentos** (enquanto OS estiver ativa)
- ✅ Preencher procedimentos existentes
- ✅ Adicionar fotos
- ✅ Atribuir/reatribuir técnicos

#### 🧑‍🔧 Supervisor NÃO PODE:
- ❌ Adicionar novos serviços ou produtos
- ❌ Remover serviços ou produtos
- ❌ Editar valores ou quantidades
- ❌ Alterar cliente ou dispositivo
- ❌ Alterar data de entrega
- ❌ Gerar PDF da OS

#### 👷 Técnico PODE:
- ✅ Visualizar a OS (sem valores)
- ✅ Tocar em serviço/produto para editar **apenas a descrição/observações**
- ✅ Preencher procedimentos existentes
- ✅ Adicionar fotos

#### 👷 Técnico NÃO PODE:
- ❌ Adicionar novos serviços ou produtos
- ❌ Remover serviços ou produtos
- ❌ **Adicionar novos procedimentos** (apenas em status 'quote')
- ❌ **Remover procedimentos** (apenas em status 'quote')
- ❌ Editar valores ou quantidades
- ❌ Alterar cliente ou dispositivo
- ❌ Alterar data de entrega
- ❌ Atribuir técnicos
- ❌ Gerar PDF da OS

### Comportamento Visual

**Campos desabilitados:**
- Aparecem em cor cinza (tertiaryLabel)
- Não exibem o chevron de navegação (>)
- Não respondem a toques

**Botões ocultos:**
- Botão "Adicionar" de serviços/produtos desaparece para Supervisor e Técnico
- Botão "Adicionar" de procedimentos desaparece apenas para Técnico (Supervisor pode adicionar)
- Opção "Compartilhar PDF" removida do menu

**Swipe to delete:**
- Ação de deslizar para deletar não funciona em serviços e produtos
- Ação de deslizar para deletar em procedimentos: funciona para Supervisor, não funciona para Técnico

### Exceções

**Admin, Manager e Consultant:**
- ✅ Podem editar OS em **qualquer status**
- ✅ Não têm restrições baseadas em status
- ✅ Manager vê valores financeiros
- ✅ Consultant vê valores apenas das próprias OSs

---

## Restrições de Procedimentos (Formulários/Checklists)

### Procedimentos em Andamento (inProgress)

Enquanto um procedimento está em andamento:
- ✅ Todos os perfis com acesso podem preencher campos
- ✅ Todos podem adicionar e remover fotos
- ✅ Todos podem concluir o procedimento

### Procedimentos Concluídos (completed)

Quando um procedimento é marcado como **concluído**, ele entra em modo **somente leitura**:

#### Comportamento Visual:
- 🔒 Todos os campos ficam desabilitados
- 🔒 Campos de texto: `enabled: false`
- 🔒 Campos booleanos: opacidade reduzida (50%) + `AbsorbPointer`
- 🔒 Campos de seleção: chevron cinza, sem resposta a toques
- 🔒 Botão de câmera (adicionar foto): removido
- 🔒 Botão de lixeira (deletar foto): removido da galeria
- ✅ Banner verde "Procedimento concluído" exibido no topo

#### Quem pode reabrir procedimentos concluídos?

| Perfil | Pode Reabrir? |
|--------|---------------|
| Admin | ✅ Sim |
| Gerente | ✅ Sim |
| Supervisor | ✅ Sim |
| Consultor | ❌ Não |
| Técnico | ❌ Não |

#### Comportamento do botão "Reabrir":
- **Admin, Gerente, Supervisor**: Botão "Reabrir" visível na barra de navegação
- **Consultor, Técnico**: Botão não aparece; se tentarem acessar programaticamente, recebem diálogo de erro

#### Mensagem de Erro:
```
Título: "Sem Permissão"
Mensagem: "Apenas Administradores, Gerentes e Supervisores podem reabrir procedimentos concluídos."
```

---

## Fluxo de Status das OS

O PraticOS controla rigorosamente quais perfis podem alterar o status de uma OS e para quais status podem mudar, garantindo um fluxo operacional consistente e seguro.

### Estados Disponíveis

```
Orçamento (quote) → Aprovado (approved) → Em Andamento (progress) → Concluído (done)
         ↓
    Cancelado (canceled)
```

### Regras por Perfil

#### 👨‍💼 Administrador
- ✅ Pode alterar para **qualquer status** a qualquer momento
- ✅ Pode alterar status de OS **concluída** (done)

#### 💰 Gerente (Financeiro)
- ✅ Pode alterar para **qualquer status** a qualquer momento
- ✅ Pode alterar status de OS **concluída** (done)

#### 🧑‍💼 Consultor (Comercial)
Transições permitidas:
- ✅ `Orçamento` → `Aprovado` (aprovar proposta)
- ✅ `Orçamento` → `Cancelado` (cancelar orçamento)
- ❌ Não pode alterar para outros status
- ❌ Não pode reverter status após aprovação

#### 🧑‍🔧 Supervisor
Transições permitidas:
- ✅ `Orçamento` → `Aprovado`/`Em Andamento` (**apenas se for o criador da OS**)
- ✅ `Aprovado` → `Em Andamento`
- ✅ `Aprovado` → `Concluído` (conclusão direta)
- ✅ `Em Andamento` → `Concluído`
- ❌ Não pode aprovar orçamentos de terceiros
- ❌ Não pode reverter status
- ❌ Não pode alterar status concluído

#### 👷 Técnico
Transições permitidas:
- ✅ `Orçamento` → `Aprovado`/`Em Andamento` (**apenas se for o criador da OS**)
- ✅ `Aprovado` → `Em Andamento`
- ✅ `Aprovado` → `Concluído` (conclusão direta)
- ✅ `Em Andamento` → `Concluído`
- ❌ Não pode aprovar orçamentos de terceiros
- ❌ Não pode reverter status
- ❌ Não pode alterar status concluído

### Restrições por Status "Concluído"

**Admin e Gerente:**
- ✅ **Podem alterar** o status de OS concluídas
- ✅ Útil para corrigir erros ou reabrir OS quando necessário
- ⚠️ Usar com cautela para manter integridade do histórico

**Outros perfis (Consultor, Supervisor, Técnico):**
- ❌ **Não podem alterar** status de OS concluídas
- 🔒 Garante que não façam alterações retroativas sem supervisão
- 💡 Devem solicitar a um Admin ou Gerente se precisarem reabrir uma OS

### Comportamento na Interface

Quando o usuário tenta alterar o status:

1. **Action Sheet Dinâmico**: Exibe apenas os status disponíveis para o perfil atual
2. **Validação Dupla**: Verifica permissões antes de salvar a mudança
3. **Feedback Claro**:
   - Se não há status disponíveis: "Não é possível alterar o status desta OS com seu perfil atual."
   - Se tentativa inválida: "Você não tem permissão para alterar para este status."

### Exemplos Práticos

**Cenário 1 - Consultor gerencia orçamento:**
```
Status atual: Orçamento (quote)
Perfil: Consultor
Opções mostradas: [Aprovado, Cancelado]
```

**Cenário 2 - Técnico recebe OS aprovada:**
```
Status atual: Aprovado (approved)
Perfil: Técnico
Opções mostradas: [Em Andamento, Concluído]
```

**Cenário 3 - Técnico finalizando trabalho:**
```
Status atual: Em Andamento (progress)
Perfil: Técnico
Opções mostradas: [Concluído]
```

**Cenário 4 - Admin gerenciando OS:**
```
Status atual: Aprovado (approved)
Perfil: Administrador
Opções mostradas: [Orçamento, Em Andamento, Concluído, Cancelado]
(todos exceto o status atual)
```

**Cenário 5 - Admin/Gerente reabrindo OS concluída:**
```
Status atual: Concluído (done)
Perfil: Administrador ou Gerente
Opções mostradas: [Orçamento, Aprovado, Em Andamento, Cancelado]
(todos exceto 'Concluído')
```

**Cenário 6 - Outros perfis com OS concluída:**
```
Status atual: Concluído (done)
Perfil: Consultor, Supervisor ou Técnico
Opções mostradas: [nenhuma]
Mensagem: "Não é possível alterar o status desta OS com seu perfil atual."
```

---

## Matriz de Permissões

### Ordens de Serviço

| Permissão | Admin | Gerente | Supervisor | Consultor | Técnico |
|-----------|-------|---------|------------|-----------|---------|
| Ver todas as OS | ✅ | ✅ | ✅ | ❌ | ❌ |
| Ver OS atribuídas | ✅ | ✅ | ✅ | ❌ | ✅ |
| Ver OS próprias | ✅ | ✅ | ✅ | ✅ | ❌ |
| Criar OS | ✅ | ❌ | ✅ | ✅ | ✅ |
| Editar OS | ✅ | ✅ | ✅ | ✅* | ❌ |
| Atribuir técnicos | ✅ | ❌ | ✅ | ✅** | ❌ |
| Executar OS | ✅ | ❌ | ✅ | ❌ | ✅ |
| Deletar OS | ✅ | ✅* | ✅* | ✅* | ✅* |

** Consultor: só nas OS que criou (`assignOrder` com o acesso à OS limitado às próprias). Técnico não repassa a OS. Decisão do dono em 2026-11-03; as regras do Firestore ainda não restringem `assignedTo`.

*Gerente e Supervisor podem deletar apenas se status for 'Orçamento'. Consultor e Técnico podem deletar apenas OS que criaram, em status 'Orçamento'.

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
| Gerenciar produtos | ✅ | ❌ | ❌ | ❌ | ❌ |
| Ver produtos | ✅ | ✅ | ✅ | ✅ | ❌ |
| Gerenciar serviços | ✅ | ❌ | ❌ | ❌ | ❌ |
| Ver serviços | ✅ | ✅ | ✅ | ✅ | ❌ |
| Gerenciar dispositivos | ✅ | ✅ | ✅ | ❌ | ❌ |
| Ver dispositivos | ✅ | ✅ | ✅ | ✅ | ✅ |

### Formulários/Procedimentos

| Permissão | Admin | Gerente | Supervisor | Consultor | Técnico |
|-----------|-------|---------|------------|-----------|---------|
| Preencher procedimentos | ✅ | ❌ | ✅ | ✅ | ✅ |
| Gerenciar templates | ✅ | ❌ | ✅ | ❌ | ❌ |
| Reabrir concluídos | ✅ | ✅ | ✅ | ❌ | ❌ |

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

#### Verificar edição baseada em status
```dart
final auth = AuthorizationService.instance;
final canEdit = auth.canEditOrderMainFields(order);

// Em widgets
_buildListTile(
  context: context,
  title: 'Cliente',
  value: order.customer?.name,
  onTap: _selectCustomer,
  enabled: canEdit, // Desabilita se não pode editar
)
```

#### Ocultar botões condicionalmente
```dart
// Botão "Adicionar" só aparece se pode editar
trailing: canEditFields ? _buildAddButton(onTap: _addService) : null
```

#### Desabilitar swipe to delete
```dart
Widget _buildDismissibleItem({
  required Widget child,
  bool canDelete = true,
}) {
  if (!canDelete) {
    return child; // Sem Dismissible
  }
  return Dismissible(/* ... */);
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

#### Controlar fluxo de status
```dart
final auth = AuthorizationService.instance;

// Verificar se pode mudar para um status específico
if (auth.canChangeOrderStatus(order, 'approved')) {
  order.status = 'approved';
}

// Obter lista de status disponíveis para o perfil
final availableStatuses = auth.getAvailableStatuses(order);

// Mostrar apenas status permitidos em Action Sheet
showCupertinoModalPopup(
  context: context,
  builder: (context) => CupertinoActionSheet(
    title: const Text("Alterar Status"),
    actions: availableStatuses.map((key) {
      return CupertinoActionSheetAction(
        child: Text(config.getStatus(key)),
        onPressed: () {
          Navigator.pop(context);
          if (auth.canChangeOrderStatus(order, key)) {
            _store.setStatus(key);
          }
        },
      );
    }).toList(),
  ),
);
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

**P: Supervisor pode editar uma OS após ela ser aprovada?**
R: Apenas as observações/descrições dos serviços e produtos. Não pode alterar valores, quantidades, cliente, dispositivo ou data de entrega.

**P: Por que Supervisor e Técnico têm as mesmas restrições?**
R: Ambos são perfis operacionais sem acesso financeiro. A diferença é que Supervisor pode gerenciar todos os dispositivos e reabrir formulários, enquanto o Técnico tem foco na execução. Atualmente ambos veem todas as OS da empresa até que o sistema de atribuição restritiva seja ativado.

**P: Um Técnico pode aprovar sua própria OS?**
R: Sim. Se o Técnico (ou Supervisor) criar uma OS, ele pode avançar o status de "Orçamento" para "Aprovado" ou "Em Andamento" diretamente, permitindo autonomia para iniciar serviços urgentes cadastrados em campo.

**P: Um Consultor pode aprovar sua própria OS?**
R: Sim. Consultores podem alterar o status de suas próprias OSs de "Orçamento" para "Aprovado".

**P: Por que uma OS concluída não pode ter o status alterado?**
R: Para garantir integridade do histórico e evitar alterações retroativas em OSs finalizadas. Isso protege dados financeiros e operacionais. Apenas **Admin e Gerente** podem reverter este status se necessário.

**P: Um Técnico pode marcar uma OS como concluída diretamente?**
R: Sim, se a OS estiver no status "Aprovado", o Técnico pode marcá-la como "Concluída" diretamente, sem passar por "Em Andamento".

**P: Admin pode reverter o status de uma OS de 'Concluído' para 'Em Andamento'?**
R: Sim. Admin e Gerente são os únicos perfis que podem alterar o status de uma OS concluída, permitindo reabrir ou corrigir OSs quando necessário.

**P: Quem pode reabrir um procedimento (formulário/checklist) concluído?**
R: Apenas **Admin, Gerente e Supervisor** podem reabrir procedimentos concluídos. Consultor e Técnico não têm essa permissão - o botão "Reabrir" não aparece para eles.

**P: Por que procedimentos concluídos ficam em modo somente leitura?**
R: Para garantir a integridade dos dados coletados. Uma vez que o procedimento é marcado como concluído, assume-se que o trabalho foi finalizado e os dados representam o estado final. Apenas usuários com privilégios (Admin/Gerente/Supervisor) podem reabrir para correções quando necessário.

**P: Posso adicionar fotos em um procedimento concluído?**
R: Não. Após conclusão, o procedimento entra em modo somente leitura. Para adicionar fotos, um Admin, Gerente ou Supervisor deve reabrir o procedimento primeiro.

---

## Changelog - Implementações Recentes

### Janeiro 2026

#### Supervisor pode gerenciar procedimentos em OS ativa (09/01/2026)
- **Implementado:** Permissão diferenciada para Supervisor gerenciar procedimentos
- **Afeta:** Supervisor
- **Commit:** (aguardando)

**Mudanças:**
- Novo método `canManageOrderForms()` em AuthorizationService
- **Supervisor** pode adicionar/remover procedimentos enquanto OS estiver ativa (não concluída/cancelada)
- **Técnico** continua restrito: só pode gerenciar procedimentos em status 'quote'
- Admin, Manager, Consultant podem gerenciar em qualquer status

**Arquivos modificados:**
- `lib/services/authorization_service.dart` - Novo método `canManageOrderForms()`
- `lib/screens/order_form.dart` - Usa `canManageOrderForms` para seção de procedimentos

#### Modo Somente Leitura para Procedimentos Concluídos (09/01/2026)
- **Implementado:** Controle de edição e reabertura de procedimentos baseado em RBAC
- **Afeta:** Todos os perfis
- **Commit:** `3fab8bf` - feat: restrict form editing and reopening based on RBAC

**Mudanças - Procedimentos Concluídos:**
- Procedimentos com status `completed` entram em modo somente leitura
- Campos de texto desabilitados (`enabled: false`)
- Campos booleanos com opacidade reduzida e `AbsorbPointer`
- Campos de seleção sem resposta a toques, chevron cinza
- Botão de câmera (adicionar foto) removido
- Botão de lixeira (deletar foto) removido da galeria

**Mudanças - Reabertura:**
- Novo método `canReopenCompletedForms` em AuthorizationService
- **Admin, Gerente e Supervisor** podem reabrir procedimentos concluídos
- **Consultor e Técnico** não podem reabrir (botão oculto)
- Diálogo de erro ao tentar reabrir sem permissão

**Arquivos modificados:**
- `lib/services/authorization_service.dart` - Novo getter `canReopenCompletedForms`
- `lib/screens/forms/form_fill_screen.dart` - Modo leitura, botão reabrir condicional, widgets de input com `isReadOnly`

#### Controle de Fluxo de Status + Restrições de Procedimentos (09/01/2026)
- **Implementado:** Sistema de controle rigoroso de transições de status e restrições para procedimentos
- **Afeta:** Todos os perfis
- **Commits:** (aguardando)

**Mudanças - Fluxo de Status:**
- Novos métodos `canChangeOrderStatus()` e `getAvailableStatuses()` em AuthorizationService
- Action Sheet de status exibe apenas opções permitidas para o perfil
- Validação dupla antes de salvar mudança de status
- **Admin e Gerente** podem alterar qualquer status, inclusive reabrir OSs concluídas
- Consultor pode aprovar ou cancelar orçamentos (quote → approved/canceled)
- Supervisor e Técnico limitados a trabalhar com OSs aprovadas (approved → progress/done)
- Consultor, Supervisor e Técnico **não podem** alterar status de OSs concluídas
- Fix: UserStore interno inicializado automaticamente para garantir detecção de role

**Mudanças - Procedimentos:**
- Supervisor e Técnico só podem adicionar/remover procedimentos quando status = 'quote'
- Botão "Adicionar" de procedimentos oculto após aprovação
- Swipe to delete desabilitado em procedimentos após aprovação
- Preencher procedimentos existentes permitido em qualquer status

**Arquivos modificados:**
- `lib/services/authorization_service.dart` - Inicialização UserStore, métodos de status
- `lib/screens/order_form.dart` - Métodos `_selectStatus()`, `_trySetStatus()`, `_buildFormsSection()`, `_buildFormRow()`

#### Restrições Baseadas em Status (09/01/2026)
- **Implementado:** Sistema de edição condicional baseado no status da OS
- **Afeta:** Supervisor e Técnico
- **Commits:**
  - `bb3c7b9` - feat: restrict order editing for Supervisor/Technician to 'quote' status
  - `807438d` - feat: allow only description editing for services/products after 'quote'

**Mudanças:**
- Novo método `canEditOrderMainFields()` em AuthorizationService
- Campos de OS desabilitados quando status != 'quote'
- Botões "Adicionar" ocultos quando não pode editar
- Swipe to delete desabilitado quando não pode editar
- Telas de serviço/produto permitem apenas edição de descrição após aprovação

#### Ocultação Completa de Dados Financeiros (09/01/2026)
- **Implementado:** Remoção total de valores financeiros para Supervisor e Técnico
- **Commits:**
  - `3e258fb` - fix: hide financial values completely for Supervisor and Technician roles
  - `b1d8ab5` - fix: hide financial data in order list for restricted roles

**Mudanças:**
- Valores ocultos em listagens de serviços, produtos e OSs
- Opção "Compartilhar PDF" removida (contém dados financeiros)
- Filtros de pagamento ("A receber", "Pago") ocultos
- Total da OS oculto na listagem principal

#### Remoção de Permissões Financeiras (09/01/2026)
- **Implementado:** Ajuste de permissões do Supervisor
- **Commit:** `a6f91c3` - feat: restrict financial access for Supervisor and Technician roles

**Mudanças:**
- Supervisor sem acesso a:
  - `viewOperationalReports`
  - `viewDashboard`
  - `manageProducts` / `viewProducts`
  - `manageServices` / `viewServices`
- Mantido acesso a clientes, dispositivos e formulários