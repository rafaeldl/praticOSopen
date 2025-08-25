# PraticOS - AGENTS.md

Este arquivo fornece um contexto sobre o projeto PraticOS para agentes de IA.

## Visão Geral do Projeto

O PraticOS é um aplicativo de gerenciamento de ordens de serviço (OS) construído com Flutter. Ele é projetado para ajudar empresas a gerenciar clientes, produtos, serviços, dispositivos e as próprias ordens de serviço de forma eficiente. O aplicativo também inclui um dashboard financeiro para visualização de métricas importantes.

## Arquitetura e Tecnologias

- **Framework:** Flutter
- **Linguagem:** Dart
- **Backend:** Firebase
  - **Autenticação:** Firebase Auth (com Google Sign-In)
  - **Banco de Dados:** Cloud Firestore
  - **Monitoramento de Erros:** Firebase Crashlytics
  - **Análise de Dados:** Firebase Analytics
- **Gerenciamento de Estado:** MobX
- **Plataformas Suportadas:** Android, iOS, Web

## Estrutura do Projeto

A estrutura do projeto segue as convenções do Flutter:

- `lib/`: Contém todo o código-fonte Dart.
  - `main.dart`: Ponto de entrada da aplicação, inicialização do Firebase e definição das rotas.
  - `models/`: Definições dos modelos de dados (ex: `order.dart`, `customer.dart`). Utiliza `json_serializable` para conversão de/para JSON.
  - `mobx/`: Contém os stores do MobX para gerenciamento de estado (ex: `auth_store.dart`, `order_store.dart`).
  - `repositories/`: Classes responsáveis pela comunicação com as fontes de dados (principalmente Firestore).
  - `screens/`: Widgets que representam as telas da aplicação.
  - `widgets/`: Widgets reutilizáveis.
- `firebase/`: Arquivos de configuração do Firebase.
- `assets/`: Imagens e outros recursos estáticos.
- `android/`, `ios/`, `web/`: Código específico de cada plataforma.

## Principais Funcionalidades

O aplicativo é organizado em torno dos seguintes módulos principais:

- **Autenticação:** Login de usuário.
- **Clientes:** Cadastro, edição e listagem de clientes.
- **Produtos:** Cadastro, edição e listagem de produtos.
- **Serviços:** Cadastro, edição e listagem de serviços.
- **Dispositivos:** Cadastro, edição e listagem de dispositivos associados a clientes.
- **Ordens de Serviço (OS):** Criação de OS, associação de clientes, adição de produtos e serviços, e gerenciamento de status.
- **Pagamentos:** Registro de pagamentos para as ordens de serviço.
- **Dashboard:** Visualização de dados financeiros básicos.

## Como Executar o Projeto

1.  **Configurar o Flutter:** Certifique-se de ter o Flutter SDK instalado.
2.  **Configurar o Firebase:** Crie um projeto no Firebase e adicione os arquivos de configuração (`google-services.json` para Android e `GoogleService-Info.plist` para iOS) nos locais apropriados.
3.  **Instalar dependências:** Execute `flutter pub get`.
4.  **Executar o build_runner:** Para gerar os arquivos do MobX e `json_serializable`, execute `flutter pub run build_runner build --delete-conflicting-outputs`.
5.  **Executar o aplicativo:** Execute `flutter run`.

## Considerações para IA

- O gerenciamento de estado é feito com MobX. Ao adicionar novas funcionalidades que necessitem de estado, crie ou atualize os `stores` correspondentes em `lib/mobx/`.
- A interação com o banco de dados é centralizada nos `repositories`. Utilize esses repositórios para buscar ou salvar dados no Firestore.
- Os modelos de dados em `lib/models/` são imutáveis e usam `json_serializable`. Lembre-se de executar o `build_runner` após qualquer alteração nesses arquivos.
- A navegação é feita usando rotas nomeadas definidas no `main.dart`.
