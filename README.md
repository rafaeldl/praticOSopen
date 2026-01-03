# PraticOS 🚀

Sistema operacional prático e intuitivo para gestão de ordens de serviço e clientes. Desenvolvido com **Flutter** e **Firebase**, focado em produtividade e automação.

![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-039BE5?style=for-the-badge&logo=Firebase&logoColor=white)
![Fastlane](https://img.shields.io/badge/fastlane-00F200?style=for-the-badge&logo=fastlane&logoColor=white)

---

## 📋 Índice
- [Funcionalidades](#-funcionalidades)
- [Documentação](#-documentação)
- [Desenvolvimento](#-desenvolvimento)
- [Automação e Deploy](#-automação-e-deploy)
- [Firebase](#-firebase)
- [Scripts Úteis](#-scripts-úteis)

---

## ✨ Funcionalidades
- 📝 Gestão completa de Ordens de Serviço.
- 👥 Cadastro e acompanhamento de Clientes.
- 📊 Dashboard com indicadores de performance.
- 🌗 Suporte a Modo Claro e Escuro (Material & Cupertino).
- 🏢 **Multi-Tenancy v1.0:** Suporte completo a múltiplas organizações com isolamento de dados.
- 🔐 Autenticação via Google, Apple e Email/Senha.

---

## 📚 Documentação

Toda a documentação técnica e de processos está centralizada para facilitar a manutenção.

- **[🚀 Guia de Deploy (Android & iOS)](docs/DEPLOYMENT.md)** - **Leia primeiro** para entender o fluxo de publicação.
- [🤖 Agentes IA](AGENTS.md) - Contexto e arquitetura para desenvolvimento assistido.
- [🔐 Configuração de Secrets](docs/ANDROID_GITHUB_SECRETS.md) - Guia para CI/CD no GitHub.
- [⚙️ Setup Android](docs/ANDROID_SETUP_GUIDE.md) - Configuração do ambiente de desenvolvimento.
- [🍏 Apple Sign In](docs/APPLE_SIGN_IN_SETUP.md) - Configuração do provedor de autenticação.
- [📐 Diretrizes de UX (App)](docs/UX_GUIDELINES.md) - Padrões visuais e de interação (iOS/Cupertino).
- [🌐 Diretrizes de UX (Web)](docs/WEB_UX_GUIDELINES.md) - Padrões para o site institucional.
- [👥 Conta Demo](docs/DEMO_ACCOUNT_SETUP.md) - Dados de acesso para teste/review.

---

## 🚀 Desenvolvimento

### Pré-requisitos
- Flutter SDK (versão especificada no `.fvmrc`)
- FVM (Flutter Version Manager) - Recomendado

### Geração de Código (MobX)
Este projeto utiliza MobX para gerência de estado. Sempre que houver alterações nas stores, execute:

```bash
# Gerar arquivos uma única vez
fvm flutter packages pub run build_runner build --delete-conflicting-outputs

# Observar alterações em tempo real
fvm flutter packages pub run build_runner watch
```

---

## 📦 Automação e Deploy

O projeto utiliza **Fastlane** para automatizar tarefas repetitivas.

- **Screenshots:** Captura automática de telas para todas as resoluções de lojas (Phone e Tablets).
- **CI/CD:** GitHub Actions configurado para deploy automático em trilhas internas (push) e produção (tags).

Para rodar localmente (exemplo Android):
```bash
cd android
bundle exec fastlane screenshots_all
bundle exec fastlane internal
```

---

## 🔥 Firebase

### Índices e Regras
Para manter o banco de dados otimizado, utilize o Firebase CLI:

```bash
# Exportar índices atuais
firebase firestore:indexes > firestore.indexes.json

# Deploy de regras e índices
firebase deploy --only firestore,storage
```

---

## 🛠 Scripts Úteis

Scripts de manutenção localizados em `firebase/scripts/`:

- `npm run refresh-claims`: Atualiza Custom Claims (permissões) de usuários.
- `npm run migrate`: Scripts de migração de dados (uso restrito).
- `setup-credentials.sh`: Auxilia na configuração de credenciais Admin SDK.