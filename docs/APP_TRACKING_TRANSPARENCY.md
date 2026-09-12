# APP_TRACKING_TRANSPARENCY.md

## Visao Geral

O app declara rastreamento na App Store (atribuicao de campanhas Google Ads / Meta Ads) e
usa o Firebase Analytics com suporte a IDFA (`GoogleAppMeasurement/IdentitySupport`). Por
isso o iOS exige o alerta do **App Tracking Transparency (ATT)** antes de qualquer coleta
que possa rastrear o usuario.

## Arquitetura

| Peca | Papel |
|---|---|
| `lib/services/tracking_transparency_service.dart` | Pede a permissao e sincroniza o consentimento do Analytics |
| `lib/main.dart` | Chama `requestIfEligible()` no inicio do app, antes do login |
| `lib/screens/menu_navigation/navigation_controller.dart` | Chamada de reforco apos o login |
| `lib/screens/onboarding/whatsapp_onboarding_screen.dart` | Chamada de reforco no onboarding |
| `ios/Runner/Info-Release.plist` / `Info-Debug.plist` | `NSUserTrackingUsageDescription` (texto do alerta) |
| `pubspec.yaml` | pacote `app_tracking_transparency` |

## Regras de Negocio

1. **So iOS.** Em outras plataformas o servico nao faz nada.
2. **O sistema decide se o alerta aparece.** O servico so pede quando o status e
   `notDetermined`; o iOS mostra o alerta uma unica vez por instalacao.
3. **Esperar o app ficar ativo.** O iOS ignora o pedido feito antes do app estar ativo e
   nega em silencio, de forma permanente naquela instalacao. O servico checa o ciclo de
   vida a cada 200ms, por até ~5s.
4. **Adiar em vez de queimar o pedido.** Se o app nao ficar ativo nesse tempo, o pedido
   fica para a proxima abertura.
5. **Sem estado proprio.** Nao existe flag em `SharedPreferences`. Uma flag gravada antes
   do alerta aparecer foi a causa da rejeicao de 12/09/2026: uma tentativa engolida
   bloqueava o pedido para sempre.
6. **Consentimento do Analytics.** Apos a resposta, `setConsent` libera `ad_storage`,
   `ad_user_data` e `ad_personalization` somente com `authorized`. `analytics_storage`
   fica sempre ligado.

## Historico de App Review

**12/09/2026 — Guideline 2.1 (Information Needed), 1.49.3 (147), iPad Air M3 / iPadOS 27:**
"The app uses the AppTrackingTransparency framework, but we are unable to locate the App
Tracking Transparency permission request."

Causas no codigo: a flag em `SharedPreferences` era gravada antes do pedido, e o pedido
saia no primeiro frame da tela, antes do app estar ativo. As duas foram corrigidas.

## O que a Apple exige no reenvio

Um **video gravado em aparelho fisico**, anexado em App Store Connect > App Review
Information > Notes, mostrando:

1. o app aberto a partir de instalacao nova (ou apos resetar a permissao de rastreamento
   em Ajustes > Privacidade e Seguranca > Rastreamento);
2. o alerta do ATT aparecendo antes de qualquer coleta;
3. o fluxo seguinte ao alerta.

## Como testar

Em aparelho fisico (o alerta nao aparece no simulador):

```bash
fvm flutter run --release -d <device-id>
```

Para pedir de novo no mesmo aparelho, reinstale o app ou desligue e ligue o rastreamento
em Ajustes > Privacidade e Seguranca > Rastreamento.

## Alternativa: nao declarar rastreamento

Se a atribuicao de campanhas deixar de ser necessaria, o caminho mais simples e declarar
"nao rastreia" na privacidade do app (App Store Connect, papel Admin ou Titular), remover
o pacote `app_tracking_transparency`, o `NSUserTrackingUsageDescription` e trocar o
Analytics para a variante sem IDFA. O SKAdNetwork continua funcionando.
