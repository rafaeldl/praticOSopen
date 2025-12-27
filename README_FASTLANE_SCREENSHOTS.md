# Configuração de Screenshots Automáticos com Fastlane e Flutter

Este projeto foi configurado para gerar screenshots automaticamente usando o pacote `integration_test` do Flutter e enviá-los via Fastlane.

## Pré-requisitos

1.  Um simulador iOS rodando (para capturar screenshots de iOS).
2.  Flutter e Fastlane instalados e configurados.

## Como funciona

Diferente da abordagem nativa `snapshot` (que requer um alvo de Teste de UI no Xcode), esta configuração usa o `flutter drive` para rodar a aplicação em modo de teste e capturar a tela.

### Arquivos Criados:

*   `integration_test/screenshot_test.dart`: O teste que navega no app e chama `binding.takeScreenshot()`.
*   `test_driver/integration_test.dart`: O script "driver" que recebe os bytes do screenshot e salva no disco.
*   `ios/fastlane/Fastfile`: Contém a lane `screenshots` que orquestra o processo.

## Como rodar

Para gerar os screenshots e preparar o upload:

```bash
cd ios
fastlane screenshots
```

Isso irá:
1.  Rodar o teste de integração no simulador aberto.
2.  Salvar os screenshots na raiz do projeto.
3.  Mover os screenshots para `ios/fastlane/screenshots`.

## Personalização

*   **Autenticação:** O teste atual (`integration_test/screenshot_test.dart`) tira screenshot apenas da tela inicial (Login ou Home). Se precisar navegar por telas logadas, você deve implementar uma lógica de login no teste ou usar um mock de autenticação.
*   **Múltiplos Devices:** O script atual roda no device conectado. Para gerar para vários devices (iPad, iPhone Plus, etc), você deve abrir cada simulador e rodar o comando, ou criar um script que automatize a abertura de simuladores.

## Upload para App Store

A lane `screenshots` no `Fastfile` tem a etapa de upload (`deliver`) comentada por segurança. Após verificar os screenshots gerados em `ios/fastlane/screenshots`, você pode descomentar a parte final do `Fastfile` ou rodar:

```bash
fastlane deliver --screenshots_path fastlane/screenshots --skip_binary_upload --skip_metadata
```
