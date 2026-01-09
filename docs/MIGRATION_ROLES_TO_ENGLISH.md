# Migração de Roles para Inglês

## 📋 Visão Geral

Este documento descreve a migração dos perfis de usuário (roles) de nomes em português para inglês, seguindo as boas práticas de desenvolvimento e facilitando a manutenção futura do código.

## 🎯 Objetivos

1. **Padronização**: Código, tipos e constantes sempre em inglês
2. **Manutenibilidade**: Facilita colaboração com desenvolvedores internacionais
3. **Internacionalização**: Preparação para suporte multi-idioma
4. **Boas Práticas**: Seguir convenções da indústria

## 🔄 Mapeamento de Roles

| Antigo (Português) | Novo (Inglês) | Descrição |
|-------------------|---------------|-----------|
| `gerente` | `manager` | Gestão financeira |
| `supervisor` | `supervisor` | Gestão operacional (sem mudança) |
| `consultor` | `consultant` | Perfil comercial/vendas |
| `tecnico` | `technician` | Execução técnica |
| `admin` | `admin` | Administrador (sem mudança) |

## 📦 Arquivos Modificados

### 1. Modelos (`lib/models/`)

#### `user_role.dart`
- **Enum `RolesType`**: Adicionados novos valores em inglês
- **Legacy roles**: Antigos nomes marcados como `@Deprecated`
- **Compatibilidade**: Mantidos para não quebrar código existente

```dart
enum RolesType {
  admin,
  manager,       // Novo
  supervisor,
  consultant,    // Novo
  technician,    // Novo

  // Legacy (deprecated)
  @Deprecated('Use manager instead')
  gerente,
  @Deprecated('Use consultant instead')
  consultor,
  @Deprecated('Use technician instead')
  tecnico,
}
```

#### `permission.dart`
- **Função `_normalizeRole`**: Atualizada para mapear roles legados
- **Permissões**: Renomeadas de `_gerentePermissions` para `_managerPermissions`, etc.
- **Métodos públicos**: Mantidas labels em português para UI

### 2. Serviços (`lib/services/`)

#### `authorization_service.dart`
- **Normalização**: `normalizedRole` agora mapeia português→inglês
- **Getters**:
  - Novos: `isManager`, `isConsultant`, `isTechnician`
  - Antigos removidos: `isGerente`, `isConsultor`, `isTecnico`
- **Lógica de acesso**: Atualizada para usar novos nomes

### 3. Firebase Backend

#### `firebase/firestore.rules`
- **Documentação**: Atualizada para inglês
- **Funções**: Mantidas com suporte a ambos (novo e legado)
- **Compatibilidade**: Regras aceitam tanto `manager` quanto `gerente`

Exemplo:
```javascript
function canViewFinancial(companyId) {
  return belongsToCompany(companyId)
    && request.auth.token.roles[companyId] in ['admin', 'manager', 'gerente'];
}
```

#### `firebase/functions/claims.js`
- **Mapeamento automático**: Converte roles legados ao salvar claims
- **ROLE_MAPPINGS**: Define conversão português→inglês
- **Transparente**: Aplicativos antigos continuam funcionando

```javascript
const ROLE_MAPPINGS = {
  'gerente': 'manager',
  'consultor': 'consultant',
  'tecnico': 'technician',
};
```

## 🚀 Processo de Migração

### Fase 1: Preparação (✅ Concluída)

1. ✅ Adicionar novos enum values em inglês
2. ✅ Marcar antigos como `@Deprecated`
3. ✅ Atualizar lógica de normalização
4. ✅ Atualizar Firebase Rules e Functions
5. ✅ Executar `build_runner` para regenerar código

### Fase 2: Migração de Dados (⏳ Pendente)

**Script**: `firebase/scripts/migrate_roles_to_english.js`

```bash
# Teste primeiro (dry-run)
node firebase/scripts/migrate_roles_to_english.js --dry-run

# Execute a migração
node firebase/scripts/migrate_roles_to_english.js

# Atualiza custom claims
cd firebase && npm run refresh-claims
```

**O script atualiza:**
- `/users/{userId}` - campo `companies[].role`
- `/companies/{companyId}/memberships/{userId}` - campo `role`

### Fase 3: Limpeza (📅 Futuro)

Após confirmar que todos os dados foram migrados e o app está estável:

1. Remover enum values deprecated
2. Remover compatibilidade das Firebase Rules
3. Simplificar função de normalização
4. Atualizar documentação

## 🔍 Verificação

### Checklist de Validação

- [x] Enum com novos valores em inglês
- [x] Roles antigos marcados como deprecated
- [x] AuthorizationService atualizado
- [x] Firebase Rules com suporte a ambos
- [x] Cloud Functions mapeando automaticamente
- [x] Build_runner executado com sucesso
- [ ] Script de migração testado (dry-run)
- [ ] Script de migração executado
- [ ] Custom claims atualizadas
- [ ] Testes de integração passando
- [ ] Deploy em ambiente de staging
- [ ] Validação com usuários reais

## 📱 Impacto no Usuário

### ✅ Nenhum Impacto Visível

- **UI**: Mantém labels em português
- **Dados**: Migrados automaticamente
- **Funcionalidade**: Zero downtime
- **Compatibilidade**: Apps antigos continuam funcionando

### Exemplo de UI

```dart
// Código interno usa inglês
if (auth.isManager) {
  // Lógica...
}

// UI mostra português
Text(RolePermissions.getRoleLabel(role)) // "Gerente"
```

## 🛠️ Troubleshooting

### Problema: Usuário sem acesso após migração

**Causa**: Custom claims não atualizadas

**Solução**:
```bash
cd firebase
npm run refresh-claims
```

### Problema: Firebase Rules negando acesso

**Causa**: Rules não reconhecem novo role

**Solução**: Verificar se as rules incluem suporte a ambos:
```javascript
// ✅ Correto
roles[companyId] in ['admin', 'manager', 'gerente']

// ❌ Errado
roles[companyId] == 'gerente' // Só aceita legado
```

### Problema: Erros de compilação

**Causa**: Build artifacts desatualizados

**Solução**:
```bash
fvm flutter pub run build_runner clean
fvm flutter pub run build_runner build --delete-conflicting-outputs
```

## 📚 Referências

- [CLAUDE.md](../CLAUDE.md) - Diretrizes gerais do projeto
- [AGENTS.md](../AGENTS.md) - Guia para agentes de IA
- [perfis_usuarios.md](./perfis_usuarios.md) - Documentação de perfis

## 🎓 Lições Aprendidas

1. **Migração Gradual**: Manter compatibilidade evita breaking changes
2. **Normalização Automática**: Cloud Functions facilitam transição
3. **Deprecation Warnings**: Alertam desenvolvedores sobre mudanças
4. **Scripts de Migração**: Automatizam atualização de dados
5. **Testes Extensivos**: Validam antes de produção

## ✨ Próximos Passos

1. **Executar migração de dados** em ambiente de staging
2. **Validar** com usuários beta
3. **Monitorar** logs de erro
4. **Deploy gradual** em produção
5. **Remover código legado** após período de estabilização (3-6 meses)

---

**Última atualização**: 2026-01-09
**Responsável**: Claude Code
**Status**: ✅ Código atualizado | ⏳ Aguardando migração de dados
