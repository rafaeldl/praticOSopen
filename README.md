# PraticOS

Sistema operacional prático para gestão.

## 📋 Índice
- [Documentação](#documentação)
- [Desenvolvimento](#desenvolvimento)
- [Firebase](#firebase)
- [Solução de Problemas](#solução-de-problemas)

## 📚 Documentação

A documentação completa do projeto foi movida para a pasta [`docs/`](docs/).

- **[Guia Completo de Deploy (Android & iOS)](docs/DEPLOYMENT.md)** - Instruções detalhadas sobre build, release, Fastlane e GitHub Actions.
- [Configuração de Conta Demo](docs/DEMO_ACCOUNT_SETUP.md)
- [Segredos do GitHub (Android)](docs/ANDROID_GITHUB_SECRETS.md)
- [Guia de Configuração Android](docs/ANDROID_SETUP_GUIDE.md)
- [Configuração Apple Sign In](docs/APPLE_SIGN_IN_SETUP.md)
- [Multi-Tenancy](docs/MULTI_TENANCY.md)
- [Diretrizes de UX](docs/UX_GUIDELINES.md)
- [Agentes IA](docs/AGENTS.md)

## 🚀 Desenvolvimento

### Geração de Código MobX
Para gerar os arquivos necessários do MobX, execute um dos comandos:

```bash
# Gerar uma vez
flutter packages pub run build_runner build

# Observar alterações e gerar automaticamente
flutter packages pub run build_runner watch
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
