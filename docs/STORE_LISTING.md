# STORE_LISTING.md

## Visão Geral

Ficha do app na App Store e no Google Play: textos, prints e dados da revisão.
Desde a 1.88 o app se apresenta como ferramenta pessoal de profissionais e
pequenos negócios de serviço (regra 3.1.1 da Apple), sem "cadastro de empresa"
nem "gestão de equipe" como foco, e tudo que é pago passa pelo IAP.

## Onde fica cada coisa

| O quê | iOS | Android |
|---|---|---|
| Textos (nome, subtítulo, descrição, palavras-chave, promocional, novidades) | `ios/fastlane/metadata/<locale>/` | `android/fastlane/metadata/android/<locale>/` |
| Prints claros (vão para a loja) | `ios/fastlane/screenshots/<locale>/` | `android/fastlane/metadata/android/<locale>/images/phoneScreenshots/` |
| Prints escuros (só para o site) | `ios/fastlane/screenshots_dark/<locale>/` | — |
| Dados da revisão (conta demo, notas) | `ios/fastlane/metadata/review_information/` | — |

Locales: `pt-BR`, `en-US`, `es-ES`.

## Prints

Telas, na ordem da loja:

| Arquivo | Tela |
|---|---|
| `01_home` | Início com as OS em aberto |
| `02_order` | OS em andamento: cliente, situação, próximo passo, fotos e barra Foto/Falar |
| `03_new_order` | Nova OS com o assistente (Foto/Falar) |
| `04_agenda` | Agenda do dia |
| `05_financial` | Financeiro: quem falta pagar |
| `06_checklist` | Checklist de entrada do veículo com fotos |
| `07_customer` | Cliente com veículos e últimas OS |

Tamanhos:
- **App Store**: só iPhone 6,9" (iPhone 17 Pro Max, 1320×2868). O App Store
  Connect reduz para os iPhones menores. O app é só iPhone no Release
  (`TARGETED_DEVICE_FAMILY = 1`), então não precisa de iPad.
- **Google Play**: celular (Pixel 7). Tablets são opcionais.

### Como gerar

1. Recriar os dados das contas demo **no mesmo dia** dos prints (as datas são
   relativas a hoje):
   ```bash
   cd firebase/scripts
   node seed_demo_store_data.js            # simulação
   node seed_demo_store_data.js --apply    # grava
   ```
2. Rodar os prints:
   ```bash
   cd ios
   bundle exec fastlane screenshots locale:pt-BR brightness:light force_logout:true
   bundle exec fastlane screenshots locale:pt-BR brightness:dark force_logout:true
   ```
   ```bash
   cd android
   bundle exec fastlane screenshots avd:Pixel_7 locale:pt-BR force_logout:true
   ```

O teste é `integration_test/screenshot_test.dart`. Ele entra com a conta demo
do idioma e aponta para a API de produção (`API_BASE_URL`), senão o assistente
fica desligado e o "Falar" some.

### Dados demo

`firebase/scripts/seed_demo_store_data.js` mexe só nas três empresas demo
(`docs/DEMO_ACCOUNTS.md`): apaga OS, clientes, veículos e fotos delas e grava
6 clientes, 6 veículos e 8 OS fictícias em todas as situações, um checklist
com fotos e uma avaliação. Também troca o nome do usuário demo por um nome
fictício e liga a IA nessas empresas.

As fotos são de domínio público (Wikimedia Commons), sem pessoas e sem placa:
`firebase/scripts/demo_store_photos/` (créditos em `CREDITS.md`).

Nunca usar dados de clientes reais nem a conta pessoal de ninguém.

## Revisão da Apple

- Conta: `demo-pt@praticos.com.br` (a mesma dos prints), no plano **Free**,
  para o revisor bater no limite e chegar ao IAP.
- `notes.txt` explica a regra 3.1.1, onde fica o paywall e o que a conta tem.

## Enviar às lojas (sem publicar)

Sempre mostrar o que vai subir e pedir confirmação antes.

```bash
cd ios
bundle exec fastlane store_listing
```

O lane entra com a chave da API (`APP_STORE_CONNECT_API_KEY_*`, as mesmas dos
builds); o `deliver` direto tenta Apple ID e senha. Só textos:
`store_listing skip_screenshots:true`. O vídeo de prévia não sobe pelo
fastlane: enviar na App Store Connect (iPhone 6,9", pt-BR), arquivo em
`ios/fastlane/app_previews/`.

No Play a ficha não fica presa a uma versão e entra no ar depois da análise do
Google. Só subir quando a versão de produção já tiver o que a ficha mostra.

```bash
cd android
bundle exec fastlane supply --skip_upload_apk true --skip_upload_aab true --skip_upload_changelogs false --track production --version_code <atual>
```

O `Deliverfile` já trava `submit_for_review false`, `skip_binary_upload true` e
`overwrite_screenshots true` (troca os prints em vez de somar).

## Regras dos textos

- "Para profissionais e pequenos negócios de serviço"; sem "cadastre sua
  empresa" nem equipe como foco (no iOS a descrição não fala de equipe).
- Nada de números inventados (usuários, notas).
- Nada de compra fora do app.
- Não anunciar o que vem desligado por padrão: Pix/boleto (Asaas) e nota
  fiscal. O assistente de IA está ligado para todos desde 2026-10-17 e é o
  destaque da ficha; se ele for desligado, tirar dos textos, prints e vídeo.
- Nomes de abas e botões iguais aos do app em cada idioma.
