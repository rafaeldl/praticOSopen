# Configuração do Login com Apple (Apple Sign In)

Para habilitar o login com Apple no seu aplicativo Flutter, é necessário realizar configurações no Portal de Desenvolvedores da Apple, no Console do Firebase e no projeto (Android e iOS).

## 1. Apple Developer Portal (https://developer.apple.com/account)

### Para iOS:
1.  Vá em **Certificates, Identifiers & Profiles** > **Identifiers**.
2.  Selecione o **App ID** do seu aplicativo.
3.  Na aba **Capabilities**, marque a opção **Sign In with Apple**.
4.  Clique em **Edit** se precisar configurar algo específico (geralmente o padrão é suficiente).
5.  Salve as alterações.

### Para Android (e Web):
O login da Apple no Android funciona via fluxo web, o que exige um **Service ID**.

1.  Vá em **Certificates, Identifiers & Profiles** > **Identifiers**.
2.  Clique no **+** para criar um novo identificador.
3.  Selecione **Service IDs** e clique em **Continue**.
4.  Insira uma descrição e um identificador (ex: `com.seuapp.signin`). Recomenda-se usar o reverso do domínio.
5.  Clique em **Continue** e depois **Register**.
6.  Clique no Service ID recém-criado para editá-lo.
7.  Habilite **Sign In with Apple** e clique em **Configure**.
8.  Em **Primary App ID**, selecione o App ID do seu aplicativo iOS.
9.  Em **Domains and Subdomains**, insira o domínio do seu projeto Firebase (ex: `seu-projeto.firebaseapp.com`) e quaisquer outros domínios que usarão o login.
10. Em **Return URLs**, adicione a URL de callback do Firebase:
    *   `https://seu-projeto.firebaseapp.com/__/auth/handler`
    *   (Substitua `seu-projeto` pelo ID do seu projeto Firebase).
11. Salve as alterações.

### Chave Privada (Private Key):
Você precisará de uma chave privada para configurar o Firebase.

1.  Vá em **Keys**.
2.  Clique no **+** para criar uma nova chave.
3.  Dê um nome e marque **Sign In with Apple**.
4.  Clique em **Configure** e selecione o Primary App ID.
5.  Baixe o arquivo `.p8` (guarde-o com segurança, você não poderá baixá-lo novamente).
6.  Anote o **Key ID**.
7.  Anote o **Team ID** (disponível no canto superior direito do portal).

## 2. Firebase Console (https://console.firebase.google.com)

1.  Vá para o seu projeto e selecione **Authentication**.
2.  Na aba **Sign-in method**, clique em **Add new provider** e selecione **Apple**.
3.  Habilite o provedor.
4.  **Service ID**: Insira o Service ID criado no passo anterior (para Android/Web).
5.  **OAuth Code Flow configuration** (Opcional, mas recomendado para Android):
    *   **Apple Team ID**: Seu Team ID.
    *   **Key ID**: O ID da chave criada.
    *   **Private Key**: O conteúdo do arquivo `.p8`.
6.  Salve.

## 3. Configuração no Projeto Flutter

### iOS (Xcode)
1.  Abra o projeto `ios/Runner.xcworkspace` no Xcode.
2.  Selecione o target **Runner**.
3.  Vá na aba **Signing & Capabilities**.
4.  Clique em **+ Capability** e adicione **Sign In with Apple**.

### Android
Não requer configuração adicional no código nativo, pois utiliza o fluxo web configurado via Firebase e Service ID. No entanto, certifique-se de que o SHA-1 e SHA-256 do seu app Android estejam cadastrados nas configurações do projeto no Firebase.

## 4. Notas Importantes
*   **Teste no iOS:** O Login com Apple só funciona em dispositivos reais ou no Simulador (iOS 13+).
*   **Teste no Android:** O Login com Apple no Android abrirá uma janela de navegador para autenticação.
*   **Revogação de Token:** O Firebase Auth gerencia a sessão, mas se o usuário revogar o acesso nas configurações da conta Apple, o app deve tratar isso adequadamente.
