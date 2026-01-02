# Roteiro de Execução da Migração Multi-Tenant

Este roteiro detalha os passos para migrar da arquitetura legada (Field-Based) para a nova (Subcollections com Memberships).

---

## Arquitetura

### Estrutura Legada
```
/orders/{id}           → campo company.id para filtrar
/customers/{id}        → campo company.id para filtrar
/roles/{id}            → vincula user ↔ company
/users/{id}            → sem campo companies
```

### Estrutura Nova
```
/companies/{companyId}/orders/{id}
/companies/{companyId}/customers/{id}
/companies/{companyId}/memberships/{userId}   ← índice reverso
/users/{id}                                   ← companies: [{ company, role }]
```

### Custom Claims
```json
{
  "roles": {
    "companyId1": "admin",
    "companyId2": "user"
  }
}
```

---

## Pré-Requisitos

1. **Backup do Firestore:**
   ```bash
   gcloud firestore export gs://praticos.appspot.com/backups/pre-migration-$(date +%Y%m%d)
   ```

2. **Acesso:** Admin no Firebase Console e `gcloud` CLI configurado.

3. **Node.js:** v18+ instalado.

4. **Credenciais:** Service Account JSON para os scripts.
   - Obter em: Firebase Console → Project Settings → Service Accounts
   - Ou definir: `export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account.json"`

---

## Passo 1: Deploy do Backend

### 1.1 Cloud Functions
```bash
cd firebase/functions
npm install
firebase deploy --only functions
```

**Funções deployadas:**
- `updateUserClaims` - Sincroniza `user.companies` → Custom Claims
- `firestoreUpdateTenantOSNumber` - Numeração automática de OS por tenant

### 1.2 Índices do Firestore
```bash
firebase deploy --only firestore:indexes
```

### 1.3 Security Rules
```bash
firebase deploy --only firestore:rules
```

**Validação:**
- [ ] Functions aparecem no Firebase Console → Functions
- [ ] Índices em "Building" ou "Enabled" no Console → Firestore → Indexes

---

## Passo 2: Migração de Dados

### 2.1 Instalar dependências
```bash
cd firebase/scripts
npm install
```

### 2.2 Executar migração
```bash
npm run migrate
# Ou com credencial explícita:
npm run migrate /path/to/service-account.json
```

**O script executa:**
1. Copia collections (`orders`, `customers`, `devices`, `products`, `services`) para subcollections
2. Converte `roles` → `memberships` + popula `user.companies`

**Validação:**
- [ ] Console mostra "MIGRAÇÃO CONCLUÍDA" sem erros
- [ ] Firestore Console: `/companies/{id}/orders` contém documentos
- [ ] Firestore Console: `/companies/{id}/memberships` contém usuários
- [ ] Firestore Console: `/users/{id}` tem campo `companies` populado

---

## Passo 3: Atualizar Custom Claims

```bash
npm run refresh-claims
```

**O que faz:**
- Força a Cloud Function `updateUserClaims` a rodar para todos os usuários
- Popula `request.auth.token.roles` usado nas Security Rules

**Validação:**
- [ ] Firebase Console → Functions → Logs mostra "Claims updated successfully"
- [ ] Testar no app: usuário consegue acessar dados da empresa

---

## Passo 4: Publicar o App

### 4.1 Build
```bash
# Android
flutter build appbundle

# iOS
flutter build ipa
```

### 4.2 Publicar
- Google Play Console → Upload AAB
- App Store Connect → Upload IPA via Transporter

---

## Validação Pós-Migração

| Teste | Esperado |
|-------|----------|
| Login com usuário existente | Acessa dados normalmente |
| Criar nova OS | Salva em `/companies/{id}/orders` |
| Adicionar colaborador | Cria em `memberships` + atualiza `user.companies` |
| Alterar role de colaborador | Atualiza ambos atomicamente |
| Remover colaborador | Remove de ambos atomicamente |

---

## Plano de Rollback

### Quando usar
- Erros críticos impedem uso do app
- Dados corrompidos ou inacessíveis
- Claims não sincronizando corretamente

### Passos

#### 1. Reverter Dados
```bash
cd firebase/scripts
npm run rollback
```

**O script executa:**
1. Copia subcollections de volta para collections raiz
2. Converte `memberships` → `roles` (estrutura legada)
3. Remove campo `user.companies` dos usuários

#### 2. Limpar Claims
```bash
npm run refresh-claims
```
Após rollback, os claims ficarão vazios (user.companies foi removido).

#### 3. Reverter Backend
```bash
# Voltar para commit anterior
git checkout <commit-anterior>

# Redeploy
firebase deploy --only functions,firestore:rules
```

#### 4. Reverter App
- Publicar versão anterior do app nas lojas
- Ou: usar Remote Config para desativar features quebradas

---

## Limpeza Pós-Validação (Opcional)

Após confirmar que a migração está estável (recomendado: aguardar 1-2 semanas):

```bash
# Criar script de cleanup para remover dados legados:
# - /orders/{id} (raiz)
# - /customers/{id} (raiz)
# - /roles/{id} (raiz)
# - etc.
```

⚠️ **ATENÇÃO:** Só execute após ter certeza absoluta que não precisará de rollback.

---

## Troubleshooting

### Claims não atualizam
1. Verificar logs da Cloud Function `updateUserClaims`
2. Confirmar que `user.companies` está populado no Firestore
3. No app, forçar refresh: `FirebaseAuth.instance.currentUser?.getIdToken(true)`

### Permissão negada no Firestore
1. Verificar se Security Rules foram deployadas
2. Confirmar que usuário tem claim para a empresa: `request.auth.token.roles[companyId]`
3. Testar no Rules Playground do Firebase Console

### Script de migração falha
1. Verificar credenciais: `npm run verificar-credenciais`
2. Conferir se Service Account tem permissão de escrita no Firestore
3. Rodar novamente (script é idempotente)

---

## Comandos Úteis

```bash
# Verificar credenciais
npm run verificar-credenciais

# Migrar dados
npm run migrate

# Atualizar claims
npm run refresh-claims

# Rollback (emergência)
npm run rollback
```

---

**Fim do Roteiro.**
