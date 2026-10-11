# IOS_CODE_SIGNING.md

## Visão Geral

A assinatura de código iOS é gerenciada pelo **fastlane match**. Certificado de distribuição e provisioning profile ficam **criptografados** num repositório privado e são baixados pelo CI na hora do build.

Antes disso, o `.p12` e o `.mobileprovision` viviam como secrets em Base64 no repositório. Esse arranjo quebrava **todo ano**, sem aviso, quando o certificado da Apple expirava — foi o que aconteceu na v1.48.0 (ver #250).

## Arquitetura

```
Repo de certificados (privado, criptografado)
  rafaeldl/praticos-certificates
        ↓  clone via SSH (deploy key somente leitura)
        ↓  MATCH_PASSWORD descriptografa
fastlane match (sync_code_signing)
        ↓  setup_ci cria keychain temporário, match importa o certificado
build_app  →  .ipa assinado  →  TestFlight / App Store
```

| Componente | Arquivo |
|---|---|
| Configuração do match | `ios/fastlane/Matchfile` |
| Helper `sync_signing` | `ios/fastlane/Fastfile` |
| Bootstrap | `ios/scripts/bootstrap_match.sh` |
| Uso no CI | `.github/workflows/ios_release.yml` |

O `sync_signing` roda no **início** das lanes `beta` (TestFlight) e `release_store` (App Store) e devolve um profile por target, que alimenta o `update_code_signing_settings` (via `apply_signing`) e o `export_options` do `build_app` (via `export_profiles`).

### App e Share Extension

São dois bundle ids, cada um com o seu profile `appstore` no match:

| Target | Bundle id | Capabilities |
|---|---|---|
| `Runner` | `br.com.rafsoft.praticos` | Push, Sign in with Apple, **App Groups** |
| `ShareExtension` | `br.com.rafsoft.praticos.ShareExtension` | **App Groups** |

Os dois usam o App Group `group.br.com.rafsoft.praticos` (ver `docs/RECEIVE_SHARE.md`). Se faltar o profile de um deles, o `sync_signing` falha no começo da lane com a mensagem "Sem provisioning profile do match".

#### Setup da extensão (uma vez, por uma pessoa)

1. No [Apple Developer › Identifiers](https://developer.apple.com/account/resources/identifiers/list):
   - App Groups › **+** › `group.br.com.rafsoft.praticos`.
   - App ID `br.com.rafsoft.praticos` › ligar **App Groups** › Configure › marcar o grupo acima.
   - **+** App ID `br.com.rafsoft.praticos.ShareExtension` (tipo App, descrição "PraticOS Share Extension") › ligar **App Groups** › marcar o mesmo grupo.
2. Regerar os profiles (o do app muda porque ganhou App Groups; o da extensão é novo):

   ```bash
   cd ios && env -u CI bundle exec fastlane match appstore --force
   ```

   O `Matchfile` já lista os dois ids. Não precisa mexer em secrets: a deploy key e a passphrase são as mesmas.
3. Rodar o **Release iOS** e conferir no TestFlight que o PraticOS aparece em Compartilhar (Fotos e Arquivos).

### Falha rápida

A assinatura é resolvida antes de qualquer compilação, em duas camadas:

1. O step **Setup match access** do workflow falha em segundos, com mensagem explícita, se os secrets do match não existirem.
2. Na lane, o `sync_signing` roda **antes** do `flutter build ios` (~30 min). Um problema de certificado aparece no começo, não depois da compilação.

### Keychain no CI

O `sync_signing` chama `setup_ci` antes do match. Ele cria um keychain temporário para o certificado ser importado — sem isso, no runner macOS do GitHub, a importação trava ou falha. Fora do CI é no-op.

## Secrets necessarios

| Secret | O que é |
|---|---|
| `MATCH_PASSWORD` | Passphrase que criptografa/descriptografa o repo de certificados |
| `MATCH_GIT_PRIVATE_KEY` | Chave privada de uma **deploy key somente leitura** do `praticos-certificates` |
| `APP_STORE_CONNECT_API_KEY_ID` | Já existia |
| `APP_STORE_CONNECT_API_KEY_ISSUER_ID` | Já existia |
| `APP_STORE_CONNECT_API_KEY_PRIVATE_KEY` | Já existia |

### Por que deploy key e nao token

Um Personal Access Token fine-grained **expira** (no máximo em 1 ano) — seria trocar um vencimento silencioso por outro, que é justamente o problema que o match veio resolver. A deploy key:

- não expira;
- vale só para o `praticos-certificates`;
- é somente leitura (o CI nunca escreve no storage).

Os secrets `IOS_DIST_CERTIFICATE_BASE64`, `IOS_DIST_CERTIFICATE_PASSWORD` e `IOS_PROVISIONING_PROFILE_BASE64` **não são mais usados** e podem ser removidos depois que o primeiro release passar.

## Bootstrap (uma vez)

> Cria a chave privada de assinatura, a passphrase e os secrets. É feito por uma pessoa, na própria máquina — não por automação.

Pré-requisitos: `gh` autenticado, `bundle`, chave SSH pessoal com acesso ao GitHub (`ssh -T git@github.com`) e acesso à conta Apple.

Na raiz do projeto:

```bash
ios/scripts/bootstrap_match.sh
```

O script:

1. Confere os pré-requisitos e avisa se já existirem secrets `MATCH_*` ou conteúdo no repo de certificados.
2. Pede a passphrase duas vezes, sem ecoar. **Guarde num gerenciador de senhas** — se for perdida, é preciso revogar o certificado e recomeçar.
3. Roda `fastlane match appstore`, que pede login da Apple (Apple ID + 2FA), cria o certificado de distribuição e o provisioning profile, criptografa e dá push no `praticos-certificates`.
4. Gera uma deploy key ed25519, cadastra a pública no `praticos-certificates` **sem permissão de escrita** e grava a privada no secret `MATCH_GIT_PRIVATE_KEY`.
5. Grava `MATCH_PASSWORD`.

Se o `fastlane match` falhar, o script para **antes** de gravar qualquer secret. Nenhum valor secreto é impresso nem passado como argumento de linha de comando; a deploy key é gerada num diretório temporário removido ao final.

Depois, dispare o **Release iOS** na tag `-rc` corrente e confira o passo `Fastlane Beta`.

## Operacao no dia a dia

Nada a fazer. O match instala o que já existe no storage a cada build.

### Renovação anual

Quando o certificado se aproximar do vencimento, a renovação é local e **não mexe em nenhum secret** — é essa a diferença em relação ao arranjo anterior. O caminho usual é:

```bash
cd ios && bundle exec fastlane match nuke distribution
```

```bash
cd ios && env -u CI bundle exec fastlane match appstore
```

> ⚠️ `match nuke distribution` **revoga todos os certificados de distribuição da conta**, não só o do match. Antes de rodar, confira no [Apple Developer](https://developer.apple.com/account/resources/certificates/list) se existe algum outro em uso — hoje há um do tipo *Distribution Managed*, criado por API Key. Revogar um certificado de distribuição App Store não afeta apps já publicados na loja, mas quebra qualquer outro fluxo que dependa dele.

## Por que `readonly` no CI

O `Matchfile` define `readonly(ENV["CI"] == "true")`, e o `setup_ci` também força readonly.

A Apple limita o número de certificados de distribuição por conta. Se o CI pudesse criar credenciais, um erro de configuração geraria um certificado novo a cada build — com a chave privada gerada num runner efêmero e descartada em seguida — e estouraria o limite em poucas execuções. Em readonly o CI falha de forma explícita em vez de consumir slots.

## Troubleshooting

| Sintoma | Causa provável |
|---|---|
| Step `Setup match access` falha com "Secrets do fastlane match ausentes" | Bootstrap ainda não feito — rode `ios/scripts/bootstrap_match.sh` |
| `Error cloning certificates git repo` | Deploy key removida do `praticos-certificates` ou `MATCH_GIT_PRIVATE_KEY` inválido |
| `Could not decrypt` / `Invalid password` | `MATCH_PASSWORD` diferente do usado no bootstrap |
| `No code signing identity found` | Storage vazio ou sem certificado para o team `46AUA3GASK` |
| `Your certificate has expired` | Fazer a renovação anual acima |
| `Sem provisioning profile do match para ...ShareExtension` | Setup da extensão (acima) ainda não feito |
| `Provisioning profile ... doesn't support the App Groups capability` | Profile antigo do app: rodar o `match appstore --force` do setup da extensão |

## Inventario de acessos

Onde cada credencial de release está guardada (passphrase do match, deploy key, certificado, profile, keystore do Android) e quando cada uma vence fica documentado em `ACESSOS.md`, no repositório **privado** `rafaeldl/praticos-certificates`.

Fica lá de propósito: este repositório é público, e mesmo sem valores secretos um mapa de onde estão as credenciais não deve ser exposto.

## Referencias

- #250 — incidente do certificado expirado que motivou a migração
- [fastlane match](https://docs.fastlane.tools/actions/match/)
- [fastlane setup_ci](https://docs.fastlane.tools/actions/setup_ci/)
