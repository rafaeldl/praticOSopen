# IOS_CODE_SIGNING.md

## Visão Geral

A assinatura de código iOS é gerenciada pelo **fastlane match**. Certificado de distribuição e provisioning profile ficam **criptografados** num repositório privado e são baixados pelo CI na hora do build.

Antes disso, o `.p12` e o `.mobileprovision` viviam como secrets em Base64 no repositório. Esse arranjo quebrava **todo ano**, sem aviso, quando o certificado da Apple expirava — foi o que aconteceu na v1.48.0 (ver #250).

## Arquitetura

```
Repo de certificados (privado, criptografado)
  rafaeldl/praticos-certificates
        ↓  MATCH_PASSWORD descriptografa
fastlane match (sync_code_signing)
        ↓  instala no keychain do runner
build_app  →  .ipa assinado  →  TestFlight / App Store
```

| Componente | Arquivo |
|---|---|
| Configuração do match | `ios/fastlane/Matchfile` |
| Helper `sync_signing` | `ios/fastlane/Fastfile` |
| Uso no CI | `.github/workflows/ios_release.yml` |

O `sync_signing` roda dentro das lanes `beta` (TestFlight) e `release_store` (App Store) e devolve o nome do profile, que alimenta o `update_code_signing_settings` e o `export_options` do `build_app`.

## Secrets necessarios

| Secret | O que é |
|---|---|
| `MATCH_PASSWORD` | Passphrase que criptografa/descriptografa o repo de certificados |
| `MATCH_GIT_BASIC_AUTHORIZATION` | Base64 de `usuario:token_github` com acesso de leitura ao repo de certificados |
| `APP_STORE_CONNECT_API_KEY_ID` | Já existia |
| `APP_STORE_CONNECT_API_KEY_ISSUER_ID` | Já existia |
| `APP_STORE_CONNECT_API_KEY_PRIVATE_KEY` | Já existia |

Os secrets `IOS_DIST_CERTIFICATE_BASE64`, `IOS_DIST_CERTIFICATE_PASSWORD` e `IOS_PROVISIONING_PROFILE_BASE64` **não são mais usados** e podem ser removidos depois que o primeiro release passar.

## Bootstrap (uma vez)

> Estes passos criam a chave privada de assinatura e a passphrase. São feitos por uma pessoa, na própria máquina — não por automação.

**1. Escolher a passphrase**

Guarde num gerenciador de senhas. Se ela for perdida, o conteúdo do repo de certificados vira lixo e é preciso recomeçar (revogando o certificado na Apple).

**2. Gerar certificado e profile**

Na raiz do projeto:

```bash
cd ios && bundle exec fastlane match appstore
```

Isso vai:
- pedir a passphrase (a que você escolheu no passo 1);
- criar um **Apple Distribution certificate** na conta (a chave privada é gerada localmente);
- criar o provisioning profile App Store para `br.com.rafsoft.praticos`;
- criptografar os dois e dar push no `rafaeldl/praticos-certificates`;
- instalar tudo no keychain local.

Se pedir login da Apple, use a App Store Connect API Key exportando `APP_STORE_CONNECT_API_KEY_*` antes de rodar.

**3. Criar o token de leitura do repo de certificados**

Um Personal Access Token (fine-grained) com **Contents: Read** apenas em `praticos-certificates`. Depois:

```bash
echo -n "rafaeldl:SEU_TOKEN" | base64
```

**4. Gravar os secrets**

```bash
gh secret set MATCH_PASSWORD
```

```bash
gh secret set MATCH_GIT_BASIC_AUTHORIZATION
```

**5. Disparar o Release iOS** na tag `-rc` corrente e conferir o passo `Fastlane Beta`.

## Operacao no dia a dia

Nada a fazer. O match instala o que já existe no storage a cada build.

**Renovação anual:** quando o certificado se aproximar do vencimento, rode uma vez, localmente:

```bash
cd ios && bundle exec fastlane match nuke distribution
```

```bash
cd ios && bundle exec fastlane match appstore
```

O CI passa a usar o novo automaticamente — **sem mexer em secret nenhum**. É essa a diferença em relação ao arranjo anterior.

## Por que `readonly` no CI

O `Matchfile` define `readonly(ENV["CI"] == "true")`.

A Apple limita o número de certificados de distribuição por conta (2 ou 3). Se o CI pudesse criar credenciais, um erro de configuração geraria certificado novo a cada build e estouraria o limite em poucas execuções — e certificado revogado invalida builds já publicados. Em readonly, o CI falha de forma explícita ("no code signing identity found") em vez de causar dano.

## Troubleshooting

| Sintoma | Causa provável |
|---|---|
| `Could not decrypt` | `MATCH_PASSWORD` errado ou ausente |
| `Authentication failed` no clone | `MATCH_GIT_BASIC_AUTHORIZATION` inválido/expirado, ou token sem acesso ao repo |
| `No code signing identity found` no CI | Storage vazio — falta rodar o bootstrap (passo 2) |
| `Your certificate has expired` | Rodar a renovação anual acima |

## Referencias

- #250 — incidente do certificado expirado que motivou a migração
- [fastlane match](https://docs.fastlane.tools/actions/match/)
