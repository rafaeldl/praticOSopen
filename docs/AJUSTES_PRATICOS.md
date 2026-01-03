# Especificação de Melhorias e Evolução - PraticOS

**Versão:** 3.0
**Status:** Em Planejamento
**Objetivo:** Definir tecnicamente as funcionalidades listadas para o backlog, garantindo estrita aderência ao **Design System (Cupertino/HIG)** definido em `docs/UX_GUIDELINES.md` e à **Arquitetura (Multi-tenant/MobX)** definida em `AGENTS.md`.

---

## 1. Padronização de Ações em Listagem (Swipe Actions)
**ID:** AJ-01
**Prioridade:** Alta

*   **Contexto:** Atualmente, ações de editar/excluir estão inconsistentes (menus de contexto vs swipe).
*   **Especificação Funcional:** Remover opções dos menus (`...`) e padronizar o swipe em todas as listas (`Customer`, `Device`, `Service`, `Product`, `Order`).
*   **Diretrizes UX (`docs/UX_GUIDELINES.md` - Section 3):**
    *   **Widget:** Usar `Dismissible` (ou similar como `flutter_slidable` se configurado para iOS style).
    *   **Start-to-End (Direita):** **Editar**.
        *   Background: `CupertinoColors.systemBlue` (ou `systemOrange` se for "Correção").
        *   Ícone: `CupertinoIcons.pencil`.
    *   **End-to-Start (Esquerda):** **Excluir**.
        *   Background: `CupertinoColors.systemRed`.
        *   Ícone: `CupertinoIcons.trash`.
    *   **Confirmação:** Exibir `CupertinoAlertDialog` para confirmação destrutiva.
*   **Critérios de Aceite:**
    *   [ ] Todas as listagens principais suportam swipe actions.
    *   [ ] Menus de contexto limpos (sem editar/excluir).
    *   [ ] Cores respeitam o padrão do sistema (Light/Dark via `CupertinoColors`).

## 2. Foto de Perfil do Cliente
**ID:** AJ-02
**Prioridade:** Média

*   **Contexto:** Clientes sem avatar dificultam a identificação visual rápida.
*   **Especificação Funcional:** Adicionar upload de foto no cadastro de Cliente.
*   **Diretrizes Técnicas (`AGENTS.md` - Multi-tenancy):**
    *   **Storage Path:** `tenants/{companyId}/customers/{customerId}/profile.jpg`.
    *   **Model:** Atualizar `Customer` e `CustomerAggr` para incluir campo `photoUrl`.
*   **Diretrizes UX (`docs/UX_GUIDELINES.md` - Section 5):**
    *   **Posição:** Topo centralizado do `CupertinoListSection`.
    *   **Interação:** Toque no avatar abre `CupertinoActionSheet` (Câmera/Galeria/Cancelar).
    *   **Placeholder:** Círculo `CupertinoColors.systemGrey5` com ícone `CupertinoIcons.person_solid`.
*   **Critérios de Aceite:**
    *   [ ] Upload redimensiona imagem no client (max 800x800).
    *   [ ] Imagem visível na lista (avatar) e cabeçalho da OS.

## 3. Busca Global na Listagem de OS
**ID:** AJ-03
**Prioridade:** Alta

*   **Contexto:** Home Screen precisa de filtragem rápida.
*   **Especificação Funcional:** Campo de busca no topo da lista de OS.
*   **Diretrizes UX (`docs/UX_GUIDELINES.md` - Section 5):**
    *   **Componente:** `CupertinoSearchTextField`.
    *   **Comportamento:** Filtragem local em tempo real (com debounce).
*   **Diretrizes Técnicas:**
    *   **Store:** Implementar *computed* `filteredOrders` no `OrderStore` combinando filtros de texto e status.
*   **Critérios de Aceite:**
    *   [ ] Busca por ID (#123), Nome do Cliente e Placa/Serial.
    *   [ ] Debounce de 500ms implementado.

## 4. Automação de Status Financeiro (Orçamento -> Aprovado)
**ID:** AJ-04
**Prioridade:** Média

*   **Contexto:** Pagamento realizado deve refletir no status operacional.
*   **Especificação Funcional:** Trigger automático no front-end ao salvar pagamento.
*   **Regra de Negócio:**
    *   SE `order.status == OrderStatus.budget`
    *   E `order.paymentStatus` muda para `PaymentStatus.paid`
    *   ENTÃO `order.status` = `OrderStatus.approved`.
*   **Diretrizes Técnicas (`AGENTS.md` - MobX):**
    *   Implementar action `updatePaymentStatus` no `OrderStore` que contém essa lógica de negócio.
*   **Critérios de Aceite:**
    *   [ ] Feedback visual (Toast/SnackBar) informando a mudança de status.

## 5. Termos de Uso e Links Legais
**ID:** AJ-05
**Prioridade:** Baixa

*   **Contexto:** Compliance com App Store.
*   **Especificação Funcional:** Item "Termos de Uso" em Configurações.
*   **Diretrizes UX:**
    *   **Navegação:** `CupertinoListTile` com `chevron_right`.
    *   **Ação:** Abrir via `url_launcher` (mode: `externalApplication`).
*   **Critérios de Aceite:**
    *   [ ] Link funcional apontando para URL externa.

## 6. Convite de Colaborador e Criação de Usuário
**ID:** AJ-06
**Prioridade:** Alta

*   **Contexto:** Simplificar onboarding de funcionários.
*   **Especificação Funcional:** Cadastro de colaborador dispara criação de usuário Auth e email.
*   **Diretrizes Técnicas (`AGENTS.md` - Auth):**
    *   **Service:** Usar `AuthService.inviteUser(email, role, companyId)`.
    *   **Store:** `CollaboratorStore` deve orquestrar a chamada.
    *   **Backend:** Não criar senha no app. Usar fluxo de "Password Reset" ou "Email Link" do Firebase Auth.
*   **Critérios de Aceite:**
    *   [ ] Usuário criado no Firebase Auth e Firestore (dentro da subcollection `/companies/{id}/roles/`).
    *   [ ] Email de convite recebido.

## 7. Modo Offline e Sincronização
**ID:** AJ-07
**Prioridade:** Crítica

*   **Contexto:** Uso em campo sem internet.
*   **Especificação Funcional:** Persistência local e sincronização transparente.
*   **Diretrizes Técnicas (`AGENTS.md` - Repositories):**
    *   **Config:** `persistenceEnabled: true` no Firestore.
    *   **Repositories:** Garantir uso de `TenantRepository` ou `RepositoryV2` que suportam cache padrão do SDK.
    *   **Imagens:** Migrar `Image.network` para `CachedNetworkImage`.
*   **Critérios de Aceite:**
    *   [ ] App abre e exibe dados (OS, Clientes) em Modo Avião.
    *   [ ] Escritas offline sincronizam ao reconectar.

## 8. Refatoração de Categorias de Empresa
**ID:** AJ-08
**Prioridade:** Média

*   **Contexto:** Adaptação a nichos (Refrigeração, Eletrônica).
*   **Especificação Funcional:** Campos dinâmicos baseados em `company.category`.
*   **Diretrizes Técnicas:**
    *   **Model:** Expandir `CompanyCategory` (Enum).
    *   **UI:** `OrderForm` renderiza blocos de campos condicionalmente.
*   **Critérios de Aceite:**
    *   [ ] Categoria "Refrigeração" exibe campos BTUs/Gás.
    *   [ ] Categoria "Eletrônica" exibe Senha/Acessórios.

## 9. Autocomplete de Marcas e Modelos
**ID:** AJ-09
**Prioridade:** Baixa

*   **Contexto:** Facilidade de preenchimento.
*   **Especificação Funcional:** Sugestão de marcas/modelos usados anteriormente.
*   **Diretrizes UX:**
    *   Usar componente de `TypeAhead` ou `Autocomplete` estilizado como `CupertinoTextField`.
*   **Diretrizes Técnicas:**
    *   Ler coleção agregada `metadata/{companyId}/brands` (criada via Cloud Function ou mantida localmente).
*   **Critérios de Aceite:**
    *   [ ] Digitar "Sam" sugere "Samsung".

## 10. Pipeline de Etapas do Serviço
**ID:** AJ-10
**Prioridade:** Alta

*   **Contexto:** Status operacional detalhado.
*   **Especificação Funcional:** Novo campo `stage` na OS.
*   **Diretrizes Técnicas:**
    *   **Model:** Adicionar `String? stage` em `Order`.
*   **Diretrizes UX:**
    *   Exibir "Stepper" horizontal no topo do detalhe da OS.
*   **Critérios de Aceite:**
    *   [ ] Visualização clara da etapa atual.

## 11. Perfil de Acesso: Técnico (Restrição de Valores)
**ID:** AJ-11
**Prioridade:** Alta

*   **Contexto:** Privacidade financeira.
*   **Especificação Funcional:** Role `TECHNICIAN` bloqueia visualização de valores.
*   **Diretrizes Técnicas (`AGENTS.md` - Roles):**
    *   **Lógica:** `bool get canViewFinancials => !user.hasRole('TECHNICIAN')`.
    *   **UI:** Envolver widgets de preço em `Visibility(visible: canViewFinancials, ...)`.
*   **Critérios de Aceite:**
    *   [ ] Dashboard financeiro oculto para técnicos.
    *   [ ] Totais da OS ocultos para técnicos.

## 12. Tela de Novidades (Changelog)
**ID:** AJ-12
**Prioridade:** Baixa

*   **Contexto:** Comunicação de atualizações.
*   **Especificação Funcional:** Modal "O que há de novo".
*   **Diretrizes UX:**
    *   Estilo "Sheet" do iOS (modal card).
*   **Critérios de Aceite:**
    *   [ ] Exibido apenas na primeira abertura após update.

---

## Histórico de Itens Concluídos

*   [x] **Edição de Perfil de Usuário (AJ-18)**
*   [x] **Correção de Imagens de Entidades (AJ-19)**