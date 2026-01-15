# Análise de Regras de Segurança e Plano de Correção

**Data:** 15/01/2026
**Status:** Análise concluída e Plano definido

Esta análise compara as regras de segurança do Firestore (`firestore.rules`) e a lógica de cliente (`AuthorizationService.dart`) com a especificação de perfis (`perfis_usuarios.md`).

## 🔍 Diagnóstico: Cliente vs. Servidor

A lógica de segurança no cliente (`lib/services/authorization_service.dart`) está **altamente alinhada** com a especificação, implementando verificações granulares de status, campos e transições.

No entanto, as regras de segurança do servidor (`firestore.rules`) estão **excessivamente permissivas**, confiando indevidamente que o cliente se comportará corretamente. Isso cria vulnerabilidades críticas se a API for acessada diretamente.

## 🚨 Vulnerabilidades Críticas Identificadas

### 1. Vazamento de Dados (Consultor)
*   **Risco:** Consultores podem ler **todas** as Ordens de Serviço da empresa.
*   **Regra Atual:** `allow read: if belongsToCompany(companyId);`
*   **Spec:** Deve ver apenas OS que criou (`createdBy.id == uid`).
*   **Correção:** Restringir a leitura na coleção `orders` para Consultores.

### 2. Deleção Indevida (Supervisor e Gerente)
*   **Risco:**
    *   **Supervisor:** Pode deletar OS em *qualquer* status (atualmente usa `canAssignOrders` que dá permissão total).
    *   **Gerente:** Não consegue deletar OS de orçamento (bloqueio indevido), mas deveria poder.
*   **Spec:** Ambos só podem deletar se `status == 'quote'`.
*   **Correção:** Remover Supervisor de `canAssignOrders` no delete e criar regra específica verificando `resource.data.status == 'quote'`.

### 3. Modificação de Dados Mestres (Técnico e Gerente)
*   **Risco:**
    *   **Técnico:** Pode alterar/deletar **Clientes**. (Regra usa `canManageOrders` que inclui Técnico).
    *   **Gerente:** Pode alterar/deletar **Dispositivos**. (Regra usa `canManageDevices` que inclui Gerente).
*   **Spec:** Técnico e Gerente devem ter acesso apenas de leitura nessas coleções.
*   **Correção:**
    *   Clientes: Criar `canManageCustomers` (Admin, Supervisor, Consultor).
    *   Dispositivos: Remover Gerente de `canManageDevices`.

### 4. Integridade de Dados Financeiros e Status
*   **Risco:** Regras de `update` não validam quais campos estão sendo alterados.
    *   Técnico pode alterar preços via API direta.
    *   Qualquer perfil pode forçar transições de status ilegais (ex: pular de 'quote' para 'done').
*   **Correção:** Embora complexo de implementar totalmente em rules sem aumentar custos, devemos adicionar proteções básicas de escrita para campos sensíveis (`price`, `total`) baseadas em role.

## 🛠 Plano de Implementação (Firestore Rules)

As seguintes alterações serão aplicadas ao `firebase/firestore.rules`:

### 1. Novas Funções Auxiliares
```javascript
// Substituir uso genérico de canManageOrders em Clientes
function canManageCustomers(companyId) {
  return belongsToCompany(companyId)
    && request.auth.token.roles[companyId] in ['admin', 'supervisor', 'consultant'];
}

// Remover Manager da gestão de dispositivos
function canManageDevices(companyId) {
  return belongsToCompany(companyId)
    && request.auth.token.roles[companyId] in ['admin', 'supervisor'];
}
```

### 2. Refatoração da Coleção `orders`

**Leitura (Read):**
```javascript
allow read: if belongsToCompany(companyId) && (
  !hasRole(companyId, 'consultant') || resource.data.createdBy.id == request.auth.uid
);
```

**Deleção (Delete):**
```javascript
allow delete: if belongsToCompany(companyId) && (
  // Admin: Sempre pode
  isCompanyAdmin(companyId)
  // Supervisor e Gerente: Apenas 'quote'
  || (
    (hasRole(companyId, 'supervisor') || hasRole(companyId, 'manager'))
    && resource.data.status == 'quote'
  )
  // Consultor e Técnico: Apenas se criador e 'quote'
  || (
    resource.data.createdBy.id == request.auth.uid
    && resource.data.status == 'quote'
    && (hasRole(companyId, 'consultant') || hasRole(companyId, 'technician'))
  )
);
```

### 3. Correção de Coleções Auxiliares
*   **Clientes (`/customers`):** Atualizar `write` para usar `canManageCustomers`.
*   **Dispositivos (`/devices`):** Atualizar `write` para usar o novo `canManageDevices` (sem gerente).

## ✅ Próximos Passos
1.  Aplicar alterações no arquivo `firebase/firestore.rules`.
2.  (Opcional) Implementar validação de campos no `update` de Orders para proteger dados financeiros.