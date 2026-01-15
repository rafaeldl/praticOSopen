# Análise de Permissões (Dart Model)

**Data:** 15/01/2026
**Arquivo Analisado:** `lib/models/permission.dart`
**Referência:** `docs/perfis_usuarios.md`

Esta análise verifica se as definições de permissões no código Flutter (`RolePermissions`) correspondem à especificação de perfis e sugere melhorias de texto para a UI.

## ✅ Conformidades

1.  **Administrador:** Conjunto completo de permissões.
2.  **Consultor:**
    *   Acesso correto a dados financeiros (apenas visualização de preços).
    *   Gestão de Clientes permitida.
    *   Visualização de OS próprias.
3.  **Técnico:**
    *   Sem acesso financeiro.
    *   Sem permissão de gestão de clientes (apenas visualização).
    *   Execução de OS permitida.

## ⚠️ Discrepâncias Identificadas

### 1. Gerente (Manager) - Gestão de Dispositivos
*   **Especificação:** "❌ Gerenciar cadastros" (apenas visualizar clientes, produtos, serviços, dispositivos).
*   **Código Atual:** Inclui `PermissionType.manageDevices`.
*   **Correção Necessária:** Remover `manageDevices`. Manter apenas `viewDevices`.

### 2. Supervisor - Visualização de Produtos e Serviços
*   **Especificação:** Matriz de Permissões indica "Ver produtos: ✅" e "Ver serviços: ✅".
*   **Código Atual:** Conjunto `_supervisorPermissions` **não** inclui `viewProducts` nem `viewServices`.
*   **Impacto:** Supervisor pode não conseguir visualizar o catálogo para adicionar itens à OS, ou acessar a lista de consulta.
*   **Correção Necessária:** Adicionar `viewProducts` e `viewServices`.

## 📋 Resumo das Alterações Técnicas

| Perfil | Permissão | Ação | Justificativa |
|--------|-----------|------|---------------|
| **Manager** | `manageDevices` | **Remover** | Gerente financeiro não deve alterar cadastro técnico de equipamentos. |
| **Supervisor** | `viewProducts` | **Adicionar** | Supervisor precisa consultar catálogo (mesmo sem ver preços/custos, controlado por `viewPrices`). |
| **Supervisor** | `viewServices` | **Adicionar** | Supervisor precisa consultar catálogo de serviços. |

## 🗣️ Melhorias de Texto para UI (Seleção de Perfil)

Sugestão de descrições mais claras e explicativas para serem exibidas na tela de seleção de perfil (método `getRoleDescriptionLocalized`).

| Perfil | Título Sugerido | Descrição Explicativa (Para UI) |
|---|---|---|
| **Administrador** | Administrador | Acesso total. Configura a empresa, gerencia usuários e acessa todos os dados. |
| **Gerente** | Gerente Financeiro | Foco em resultados. Visualiza faturamento e custos, mas não executa serviços. |
| **Supervisor** | Supervisor Operacional | Coordena equipes e equipamentos. Não visualiza valores financeiros. |
| **Consultor** | Consultor de Vendas | Cria orçamentos. Vê preços, mas acessa apenas suas próprias Ordens de Serviço. |
| **Técnico** | Técnico de Campo | Executa serviços. Não vê preços e tem edição limitada após aprovação da OS. |

## Próximos Passos

1.  Atualizar `lib/models/permission.dart` aplicando as correções técnicas.
2.  Atualizar os textos retornados por `getRoleDescription` (ou arquivos de tradução) com as novas descrições sugeridas.