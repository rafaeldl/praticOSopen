# Análise de Documentação Web (HTML) vs Especificação

**Data:** 15/01/2026
**Arquivo Analisado:** `firebase/hosting/public/docs/perfis.html`
**Referência:** `docs/perfis_usuarios.md`

Esta análise verifica se a documentação pública do site (`perfis.html`) está alinhada com a especificação técnica interna (`perfis_usuarios.md`) e com as regras implementadas.

## ✅ Conformidades Gerais

A documentação HTML apresenta uma estrutura muito fiel à especificação técnica:
1.  **Estrutura de Perfis:** Lista corretamente os 5 perfis (Admin, Gerente, Supervisor, Consultor, Técnico).
2.  **Permissões Principais:** Descreve corretamente os acessos macro de cada perfil.
3.  **Restrições Financeiras:** Destaca corretamente que Supervisor e Técnico não veem dados financeiros.
4.  **Regras de Status:** Seção "Regras Baseadas em Status da OS" está precisa e atualizada.

## ⚠️ Divergências Encontradas

### 1. Supervisor - Visualização de Produtos/Serviços
*   **HTML:** "❌ Gerenciar produtos (sem ver preços)" / "❌ Gerenciar serviços (sem ver preços)".
    *   Falta menção explícita à permissão de **Visualizar** para consulta.
*   **Spec/Code:** Identificamos que Supervisor PRECISA visualizar para adicionar itens à OS.
*   **Recomendação:** Ajustar texto para "Visualizar catálogo (sem ver preços)".

### 2. Gerente - Edição de OS
*   **HTML:** "✅ Editar OS (ajustes fiscais/financeiros)".
*   **Spec/Code:** Gerente tem permissão de edição completa (`editOrder`), não apenas fiscal.
*   **Status:** Aceitável como simplificação para usuário final, mas tecnicamente impreciso.

### 3. Matriz de Permissões (HTML Table)
*   **Gerenciar Dispositivos:**
    *   **HTML:** Marca "Gerente: ✅".
    *   **Spec/Correção:** Acabamos de definir que Gerente **NÃO** deve gerenciar dispositivos, apenas visualizar.
    *   **Ação:** Precisa ser corrigido no HTML para refletir a nova regra de segurança.

## 📋 Resumo das Correções Necessárias no HTML

| Seção | Perfil | Texto Atual | Correção Sugerida |
|-------|--------|-------------|-------------------|
| **Cadastros** | Supervisor | "Gerenciar produtos/serviços (sem ver preços)" | "Visualizar produtos/serviços (sem ver preços)" |
| **Cadastros** | Gerente | "Gerenciar dispositivos: ✅" | "Gerenciar dispositivos: ❌" (Apenas visualizar) |
| **Matriz** | Gerente | Coluna "Gerenciar dispositivos" marcada como Sim | Marcar como Não (❌) |

## Próximos Passos

1.  Aplicar as correções no arquivo `firebase/hosting/public/docs/perfis.html` para manter a documentação pública sincronizada com as regras de segurança reais.
