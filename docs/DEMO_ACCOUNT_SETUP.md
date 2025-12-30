# Configuração da Conta Demo - PraticOS

Este documento descreve como configurar a conta demo para geração de screenshots e revisão da Apple.

## Credenciais da Conta Demo

```
Email: demo@praticos.com.br
Senha: Demo@2024!
```

## Configuração (Apenas 2 passos!)

### Passo 1: Habilitar Login por Email/Senha no Firebase

1. Acesse o [Firebase Console](https://console.firebase.google.com/)
2. Selecione o projeto **praticos**
3. No menu lateral, vá em **Authentication** > **Sign-in method**
4. Clique em **Email/Password**
5. Ative a opção **Enable**
6. Clique em **Save**

### Passo 2: Criar o Usuário Demo

No Firebase Console:
1. Vá em **Authentication** > **Users**
2. Clique em **Add user**
3. Preencha:
   - Email: `demo@praticos.com.br`
   - Password: `Demo@2024!`
4. Clique em **Add user**

**Pronto!** Os dados de demonstração (empresa, clientes e ordens) são criados automaticamente quando o usuário demo faz o primeiro login.

## Como funciona o Seed Automático

O app possui um `DemoDataSeeder` (`lib/utils/demo_data_seeder.dart`) que:

1. Detecta quando o email `demo@praticos.com.br` faz login
2. Verifica se já existem dados para a conta demo
3. Se não existirem, cria automaticamente:
   - Empresa: "Assistência TechFix (Demo)"
   - 5 clientes com dados fictícios
   - 5 ordens de serviço com diferentes status

### Dados criados automaticamente:

**Clientes:**
- João Silva - (11) 99999-1234
- Maria Oliveira - (11) 98888-5678
- Empresa ABC Ltda - (11) 3333-4444
- Pedro Santos - (21) 97777-8888
- Ana Costa - (11) 96666-7777

**Ordens de Serviço:**
- OS #1001 - MacBook Pro - R$ 1.500 - Aprovado/A receber
- OS #1002 - iPhone 15 - R$ 450 - Em Andamento/A receber
- OS #1003 - Servidor Dell - R$ 2.800 - Orçamento
- OS #1004 - iPad Pro - R$ 890 - Concluído/Pago
- OS #1005 - iPhone 14 - R$ 320 - Aprovado/Pago

## Configuração para App Store Review

### Informações para App Store Connect

Ao submeter o app, forneça as credenciais de demo na seção **App Review Information**:

| Campo | Valor |
|-------|-------|
| Sign-in required | Yes |
| Demo Account Email | demo@praticos.com.br |
| Demo Account Password | Demo@2024! |
| Notes | Clique em "Entrar com email" na tela de login para acessar com as credenciais demo |

### Configuração do Fastlane (Appfile)

Adicione ao arquivo `ios/fastlane/Appfile`:

```ruby
# Credenciais para App Review
ENV["FASTLANE_APPLE_DEMO_ACCOUNT_EMAIL"] = "demo@praticos.com.br"
ENV["FASTLANE_APPLE_DEMO_ACCOUNT_PASSWORD"] = "Demo@2024!"
```

### Configuração do Deliver (metadata)

Crie o arquivo `ios/fastlane/metadata/review_information/demo_user.txt`:
```
demo@praticos.com.br
```

Crie o arquivo `ios/fastlane/metadata/review_information/demo_password.txt`:
```
Demo@2024!
```

Crie o arquivo `ios/fastlane/metadata/review_information/notes.txt`:
```
Para fazer login com a conta demo:
1. Na tela de login, toque em "Entrar com email"
2. Digite o email e senha fornecidos
3. Toque em "Entrar"

A conta demo possui dados de exemplo incluindo clientes e ordens de serviço.
```

## Gerando Screenshots Automaticamente

Após configurar a conta demo, execute:

```bash
cd ios
bundle exec fastlane screenshots
```

Os screenshots serão salvos em `ios/fastlane/screenshots/`.

## Verificação

Para verificar se tudo está funcionando:

1. Execute o app no simulador
2. Toque em "Entrar com email"
3. Use as credenciais demo
4. Verifique se os dados aparecem corretamente
