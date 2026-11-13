# APP_MINIMUM_VERSION.md

## Visão Geral

O app pode exigir uma versão mínima (bloqueia até atualizar) e recomendar uma versão (aviso que dá para fechar), separadas por iOS e Android. Tudo vem de um documento no Firestore, `config/appVersion`, lido quando o app abre e toda vez que volta para a frente.

**Só vale a partir da primeira versão que traz este código (a próxima depois da 1.109.0, chamada aqui de 1.110).** A 1.56.0 que está na loja e as RCs até a 1.109 não leem esse documento: não dá para forçá-las a atualizar por aqui. Ver "Versões antigas (1.56)".

## Arquitetura

| Arquivo | Papel |
|---|---|
| `lib/services/app_version_service.dart` | Lê `config/appVersion`, compara versões (`evaluateAppVersion`) e tem os links das lojas |
| `lib/widgets/app_version_gate.dart` | `AppVersionGate`: fica no `MaterialApp.builder` (acima do navegador, cobre todas as telas). Confere ao abrir e ao voltar ao app |
| `lib/screens/update_required_screen.dart` | Tela "Atualize o app para continuar", com um botão amarelo que abre a loja |
| `lib/services/api_headers.dart` | Manda `X-App-Version` (ex.: `1.110.0`) nas chamadas a `/v1/app/*` |
| `firebase/firestore.rules` (`match /config/appVersion`) | Leitura aberta (o app lê antes do login), escrita só pelo console/Admin SDK |

### Documento `config/appVersion`

```json
{
  "iosMinimum": "",
  "iosRecommended": "",
  "androidMinimum": "",
  "androidRecommended": ""
}
```

- Valor no formato `1.110.0` (o `version` do `pubspec.yaml`, sem o `+build`).
- Campo vazio, ausente ou inválido = verificação desligada. O documento pode nem existir: é o estado inicial.
- Erro de leitura (sem internet, regra) nunca bloqueia.

## Regras de Negócio

1. Versão instalada **menor** que `*Minimum`: o app inteiro vira a tela de atualizar. Não tem como fechar. Ao voltar da loja já atualizado, a tela some sozinha.
2. Versão instalada **menor** que `*Recommended` (e não abaixo do mínimo): aparece um alerta "Tem versão nova do PraticOS" com "Atualizar" e "Agora não". "Agora não" vale para aquela versão recomendada; só volta a aparecer quando a recomendada subir.
3. Mínimo vence o recomendado.
4. Igual ou maior: nada aparece.
5. Lojas: iOS `https://apps.apple.com/app/id1534604555`, Android `https://play.google.com/store/apps/details?id=br.com.rafsoft.praticos`.

## Como subir a versão mínima

1. Confirmar que a versão nova **já está publicada** na loja das duas plataformas (App Store aprovada e liberada, Play em 100%). Senão quem atualizar cai na versão antiga e fica preso na tela.
2. No console do Firebase (projeto `praticos`), Firestore, coleção `config`, documento `appVersion` (criar se não existir, com os 4 campos em texto).
3. Começar pelo recomendado (`iosRecommended`/`androidRecommended` = versão nova) e esperar uns dias.
4. Subir o mínimo (`iosMinimum`/`androidMinimum`). Vale na próxima vez que cada aparelho abrir ou voltar ao app.
5. Para desligar: apagar o valor (texto vazio).

Para conferir quantos ainda estão em versão antiga: Firebase Analytics / GA4, dimensão "App version".

## Versões antigas (1.56)

A 1.56.0 só lê a versão instalada para mostrar em Ajustes; não lê nenhum campo de versão mínima e não manda versão para o servidor. Então:

- **A trava só vale para quem já está na 1.110 ou mais.** Quem está na 1.56 precisa atualizar por conta própria (atualização automática da loja, aviso por WhatsApp/e-mail/push).
- **Para ligar `config/paidPlans` sem a 1.56 aplicar a tabela antiga**, o caminho é o servidor. Ideias (nenhuma implementada aqui):
  - A 1.56 aplica os limites que estiverem gravados em `companies/{id}.subscription.limits` (fotos por mês, checklists, pessoas) enquanto o plano estiver valendo, e só cai na tabela antiga dela quando esse campo não existe. O servidor pode gravar ali os números da tabela nova. Conferir antes se o app novo ignora esse campo ou lê os mesmos números.
  - O que a 1.56 não conhece (limite de OS etc.) ela não bloqueia: o bloqueio tem que estar nas Functions/regras, que valem para qualquer versão.
  - Chamadas a `/v1/app/*` sem `X-App-Version` vêm de versões até a 1.109. Um middleware pode responder `426 Upgrade Required` (ou só registrar) para essas, mas a 1.56 grava quase tudo direto no Firestore, então isso cobre pouco. Recusar sem cabeçalho é arriscado: derruba quem ainda não atualizou.
