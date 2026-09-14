# AGENTS.md - Guia para Agentes de IA

> **Aviso Importante:** Todas as instruções, diretrizes de arquitetura, padrões de código, convenções de commits, internacionalização (i18n), multi-tenancy e comandos essenciais do projeto **PraticOS** estão centralizados e mantidos em [`CLAUDE.md`](./CLAUDE.md).
>
> **Consulte sempre [`CLAUDE.md`](./CLAUDE.md) como a fonte única da verdade.**

---

## Como Operar no Repositório

Ao atuar em qualquer tarefa ou sessão neste projeto, siga estritamente as regras documentadas em [`CLAUDE.md`](./CLAUDE.md):

1. **Inglês no Código (Crítico):** Código, tipos, enums, propriedades, métodos, constantes, chaves de JSON e valores no banco de dados devem ser **sempre em inglês**. Strings visíveis na UI em português e localizadas via i18n.
2. **Internacionalização (i18n):** Nunca use strings hardcoded na interface. Sempre utilize `context.l10n` e mantenha os três arquivos `.arb` (`pt`, `en`, `es`) sincronizados.
3. **FormatService:** Sempre formate moedas, datas e números através do `FormatService`.
4. **Multi-Tenancy:** Todo modelo de dados herda de `BaseAuditCompany` e as consultas em repositories devem respeitar o escopo da empresa (`companyId`).
5. **Conventional Commits:** Todas as mensagens de commit devem seguir o formato padronizado (`feat:`, `fix:`, `refactor:`, etc.), pois o CI gera versionamento e tags automáticas a partir deles.
6. **Branches e Issues:**
   - Sempre crie uma branch descritiva (`tipo/descricao-curta`) a partir da `master`.
   - As issues no GitHub devem ser descritas em português com acentuação correta.
7. **Documentação:** Qualquer nova funcionalidade ou alteração arquitetural exige documentação técnica em `docs/` e documentação pública quando visível ao usuário.

Para detalhes aprofundados, tabela de comandos, arquitetura de pastas e referências completas, consulte [`CLAUDE.md`](./CLAUDE.md).
