# 🔐 Como Obter Credenciais do Firebase Admin SDK

## ⚠️ Importante: Diferença entre Credenciais

### `google-services.json` (já existe no projeto)
- **Para:** Firebase Client SDK (app Flutter/Android)
- **Localização:** `android/app/google-services.json`
- **Uso:** Autenticação no app, acesso ao Firestore pelo app

### Service Account JSON (precisa ser gerado)
- **Para:** Firebase Admin SDK (scripts Node.js)
- **Localização:** Você escolhe onde salvar
- **Uso:** Scripts de migração, funções server-side, acesso administrativo

## 📋 Passo a Passo para Obter Service Account

### 1. Acesse o Console do Firebase

Abra este link diretamente (substitua `praticos` pelo seu project_id se diferente):
```
https://console.firebase.google.com/project/praticos/settings/serviceaccounts/adminsdk
```

Ou siga manualmente:
1. Acesse: https://console.firebase.google.com/
2. Selecione o projeto **praticos**
3. Vá em ⚙️ **Configurações do Projeto** (ícone de engrenagem)
4. Aba **Contas de Serviço**
5. Seção **Firebase Admin SDK**

### 2. Gere a Chave

1. Clique no botão **"Gerar nova chave privada"**
2. Uma caixa de diálogo aparecerá avisando sobre segurança
3. Clique em **"Gerar chave"**
4. Um arquivo JSON será baixado (ex: `praticos-firebase-adminsdk-xxxxx.json`)

### 3. Salve o Arquivo

**⚠️ IMPORTANTE:**
- **NUNCA** commite este arquivo no Git
- Salve em um local seguro (ex: `~/firebase-credentials/praticos-service-account.json`)
- Adicione ao `.gitignore` se salvar dentro do projeto

### 4. Configure o Script

**Opção A: Variável de Ambiente (Recomendado)**
```bash
export GOOGLE_APPLICATION_CREDENTIALS="/caminho/completo/para/praticos-service-account.json"
npm run refresh-claims
```

**Opção B: Passar como Argumento**
```bash
npm run refresh-claims /caminho/completo/para/praticos-service-account.json
```

**Opção C: Adicionar ao ~/.zshrc (Permanente)**
```bash
echo 'export GOOGLE_APPLICATION_CREDENTIALS="/caminho/completo/para/praticos-service-account.json"' >> ~/.zshrc
source ~/.zshrc
npm run refresh-claims
```

## 🔍 Verificar se Funcionou

Execute:
```bash
npm run refresh-claims
```

Se aparecer:
```
✓ Credenciais carregadas do arquivo: /caminho/...
✓ Projeto: praticos
```

Está funcionando! ✅

## 🆘 Problemas Comuns

### "Could not load the default credentials"
- Verifique se o caminho do arquivo está correto
- Verifique se o arquivo JSON é válido
- Tente usar o caminho absoluto completo

### "Permission denied"
- Verifique se o Service Account tem permissões no Firebase
- O Service Account precisa ter acesso ao projeto "praticos"

### "Project not found"
- Verifique se o project_id no arquivo JSON corresponde ao projeto Firebase
- O project_id deve ser "praticos" (conforme `google-services.json`)

## 🔗 Links Úteis

- Console Firebase: https://console.firebase.google.com/project/praticos
- Service Accounts: https://console.firebase.google.com/project/praticos/settings/serviceaccounts/adminsdk
- Documentação: https://firebase.google.com/docs/admin/setup

