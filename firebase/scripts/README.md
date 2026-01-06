# Scripts de Migração - PraticOS

Scripts Node.js para operações de migração e manutenção do Firebase.

## 🔐 Configuração de Credenciais

> **⚠️ IMPORTANTE:** O arquivo `google-services.json` é para o **app Flutter**, não para os scripts Node.js!
> 
> Os scripts precisam de um **Service Account JSON** diferente. Veja: [COMO_OBTER_CREDENCIAIS.md](./COMO_OBTER_CREDENCIAIS.md)

Os scripts precisam de credenciais do Firebase Admin SDK para funcionar. Existem 3 formas de configurar:

### Opção 1: Arquivo de Service Account (Recomendado)

1. **Obter o arquivo de Service Account:**
   - Acesse: https://console.firebase.google.com/project/praticos/settings/serviceaccounts/adminsdk
   - Clique em "Gerar nova chave privada"
   - Salve o arquivo JSON (ex: `praticos-service-account.json`)

2. **Configurar variável de ambiente:**
   ```bash
   export GOOGLE_APPLICATION_CREDENTIALS="/caminho/completo/para/service-account-key.json"
   npm run refresh-claims
   ```

3. **Ou passar como argumento:**
   ```bash
   npm run refresh-claims /caminho/completo/para/service-account-key.json
   ```

### Opção 2: Google Cloud CLI

Se você tem o `gcloud` instalado e configurado:

```bash
gcloud auth application-default login
npm run refresh-claims
```

### Opção 3: Firebase CLI (para desenvolvimento local)

```bash
firebase login
firebase use praticos
npm run refresh-claims
```

> 📖 **Guia Completo:** Veja [COMO_OBTER_CREDENCIAIS.md](./COMO_OBTER_CREDENCIAIS.md) para instruções detalhadas passo a passo.

## 📋 Scripts Disponíveis

### `seed-segments`
Popula a collection `segments` com os segmentos iniciais do sistema (HVAC, Automotivo, Celulares, etc.).

```bash
npm run seed-segments
# ou com arquivo de credenciais
npm run seed-segments /caminho/service-account-key.json
```

**O que faz:**
- Cria 6 segmentos: automotive, hvac, smartphones, computers, appliances, other
- Configura labels dinâmicos por segmento (ex: "Dispositivo" → "Veículo")
- Adiciona campos customizados específicos (ex: Ano, Quilometragem para automotive)
- Suporte a i18n (pt-BR e en-US)

**Nota:** Execute após configurar um novo ambiente ou para atualizar segmentos existentes. O script atualiza (merge) documentos existentes de forma segura.

### `refresh-claims`
Atualiza o campo `_claimsRefreshedAt` em todos os usuários para forçar o refresh de claims.

```bash
npm run refresh-claims
# ou com arquivo de credenciais
npm run refresh-claims /caminho/service-account-key.json
```

### `migrate`
Migra dados para a estrutura de subcollections por tenant.

```bash
npm run migrate
# ou com arquivo de credenciais
npm run migrate /caminho/service-account-key.json
```

### `rollback`
Reverte a migração, copiando dados de volta para a raiz.

```bash
npm run rollback
# ou com arquivo de credenciais
npm run rollback /caminho/service-account-key.json
```

## ⚠️ Importante

- **Nunca commite** arquivos de service account no repositório
- Adicione `service-account-key.json` ao `.gitignore`
- Use credenciais diferentes para desenvolvimento e produção
- Sempre teste em ambiente de desenvolvimento antes de executar em produção

## 🔧 Troubleshooting

### Erro: "Could not load the default credentials"

1. Verifique se a variável `GOOGLE_APPLICATION_CREDENTIALS` está configurada corretamente
2. Verifique se o caminho do arquivo está correto e o arquivo existe
3. Verifique se o arquivo JSON é válido
4. Tente usar uma das outras opções de autenticação acima

### Erro: "Permission denied"

- Verifique se o service account tem as permissões necessárias no Firebase
- Verifique se está usando o projeto correto do Firebase

