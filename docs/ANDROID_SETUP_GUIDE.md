# Guia de Configuração Android (Deploy & CI/CD)

Este guia descreve como obter os arquivos necessários para o deploy automatizado e como configurar o ambiente de integração contínua (GitHub Actions).

## 1. Arquivos Necessários (Locais)

Estes arquivos devem ser colocados nas pastas indicadas e **NUNCA** devem ser commitados no Git (já estão no `.gitignore`).

### A. Keystore de Assinatura (`android/app/rafsoft.keystore`)
*   **O que é:** Arquivo que assina o APK/Bundle para a loja.
*   **Como obter:** Se você já tem uma, basta copiar para a pasta. Se não tem, deve ser gerada via `keytool`.

### B. Google Services (`android/app/google-services.json`)
*   **O que é:** Conecta o app ao Firebase (Auth, Firestore, Analytics).
*   **Como obter:**
    1. Acesse o [Console do Firebase](https://console.firebase.google.com/).
    2. Vá em **Configurações do Projeto** > **Geral**.
    3. Em "Seus Aplicativos", selecione o app Android e baixe o arquivo.

### C. Credenciais da Play Store (`android/fastlane/play_store_credentials.json`)
*   **O que é:** Permite que o Fastlane faça upload para o Google Play Console.
*   **Como obter:**
    1. No [Google Cloud Console](https://console.cloud.google.com/), crie uma **Conta de Serviço**.
    2. Gere uma chave em formato **JSON** para essa conta.
    3. No [Google Play Console](https://play.google.com/console), vá em **Usuários e Permissões** e convide o e-mail da conta de serviço com permissões de administrador (ou permissões de edição de releases).

---

## 2. Configuração de Secrets no GitHub

Para o GitHub Actions funcionar, precisamos converter esses arquivos para Base64 e salvá-los como Secrets do repositório.

### Comandos para gerar e subir via GH CLI:

```bash
# 1. Keystore
base64 -i android/app/rafsoft.keystore | gh secret set ANDROID_KEYSTORE_BASE64

# 2. Google Services
base64 -i android/app/google-services.json | gh secret set ANDROID_GOOGLE_SERVICES_JSON_BASE64

# 3. Play Store Credentials
base64 -i android/fastlane/play_store_credentials.json | gh secret set ANDROID_PLAY_STORE_CREDENTIALS_BASE64
```

---

## 3. Fluxo de Trabalho (Workflows)

*   **Push na `master`:** Aciona o deploy para o track **Interno** da Google Play.
*   **Criação de Tag (`v*`):** Promove a versão que está no track Interno para **Produção**.
