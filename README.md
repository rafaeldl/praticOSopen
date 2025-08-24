# PraticOS

Sistema operacional prático para gestão.

## 📋 Índice
- [Desenvolvimento](#desenvolvimento)
- [Deploy iOS](#deploy-ios)
- [Deploy Android](#deploy-android)
- [Firebase](#firebase)
- [Solução de Problemas](#solução-de-problemas)

## 🚀 Desenvolvimento

### Geração de Código MobX
Para gerar os arquivos necessários do MobX, execute um dos comandos:

```bash
# Gerar uma vez
flutter packages pub run build_runner build

# Observar alterações e gerar automaticamente
flutter packages pub run build_runner watch
```

## 📱 Deploy iOS

### Preparação do Ambiente
Antes de fazer o deploy, configure as variáveis de ambiente necessárias para o TestFlight:

1. Acesse o [App Store Connect](https://appstoreconnect.apple.com/access/users)
2. Vá para "Keys" na seção "Users and Access"
3. Clique em "+" para gerar uma nova chave
4. Faça o download do arquivo .p8 e configure as variáveis:

```bash
export APPLE_API_KEY_ID="sua_key_id"
export APPLE_API_KEY_PATH="/caminho/para/AuthKey_KEYID.p8"
```

### Comandos de Deploy

#### Deploy Rápido
```bash
flutter build ios --release --no-codesign
cd ios && fastlane internal
```

#### Deploy Completo (com limpeza)
```bash
# Limpa caches e dados
rm -rf ~/Library/Developer/Xcode/DerivedData
rm -Rf $HOME/Library/Caches/CocoaPods
rm -Rf $FLUTTER_ROOT/.pub-cache

# Build e deploy
flutter clean
flutter build ios --release --no-codesign
cd ios
fastlane internal
fastlane deliver
```

### Limpeza Forçada (caso necessário)
Se encontrar problemas no build:
```bash
flutter clean
rm -rf ios/Flutter/Flutter.framework
rm ios/Podfile.lock
```

### Problema: Envio para a App Store só via Transporter
Se não conseguir enviar o app para a App Store pelo Xcode ou Fastlane, utilize o aplicativo [Transporter](https://apps.apple.com/br/app/transporter/id1450874784) da Apple.

Para gerar o arquivo IPA para upload:
```bash
flutter clean && flutter build ipa
```
Depois, abra o Transporter, faça login com sua conta Apple e envie o arquivo IPA gerado.

## 📱 Deploy Android

```bash
# Gerar app bundle
flutter build appbundle

# Deploy via fastlane
cd android && fastlane internal
```

## 🔥 Firebase

### Configuração de Índices do Firestore

```bash
# Login no Firebase
firebase login

# Configurar projeto
gcloud config set project <project_name>

# Exportar índices
firebase firestore:indexes > firestore.indexes.json

# Fazer deploy dos índices
firebase deploy --only firestore:indexes
```

## ⚠️ Solução de Problemas

### Erro: Flutter.framework Permission Denied
Se encontrar erro de permissão no Flutter.framework:
```
Flutter.framework: Permission denied
```
Solução disponível em: [Flutter Issue #39507](https://github.com/flutter/flutter/issues/39507#issuecomment-555715584)

### Erro: rsync no Build
Se encontrar erro de rsync durante o build:
```
rsync error: some files could not be transferred (code 23) Command PhaseScriptExecution failed with a nonzero exit code
```
Solução disponível em: [Stack Overflow](https://stackoverflow.com/questions/63533819/rsync-error-some-files-could-not-be-transferred-code-23-command-phasescriptex)

## 🧪 Conta de Teste para Revisão

Para fins de revisão pela App Store ou para testes gerais, utilize a seguinte conta que possui dados de exemplo e acesso completo:

- **Email:** `test@appstore.com`
- **Senha:** `y7revfrh`
