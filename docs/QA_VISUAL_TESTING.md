# QA Visual Testing Guide

Este documento descreve como executar testes visuais automatizados no PraticOS usando Maestro.

## Overview

O sistema de testes visuais captura screenshots automaticamente das telas principais do app, especialmente focando em:

1. **Tela de Planos** (PlansScreen) - Visualizacao dos planos de assinatura
2. **Feature Gate Warning** (80%) - Banner de aviso quando usuario esta proximo do limite
3. **Feature Gate Modal** (100%) - Modal quando usuario atinge o limite
4. **PDF Watermark** - Marca d'agua no PDF para plano Free

## Pre-requisitos

### macOS

1. **Xcode** (para iOS Simulator)
   ```bash
   xcode-select --install
   ```

2. **Android Studio** (para Android Emulator)
   - Instalar via: https://developer.android.com/studio
   - Configurar `ANDROID_HOME` no `~/.zshrc`:
     ```bash
     export ANDROID_HOME=$HOME/Library/Android/sdk
     export PATH=$PATH:$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools
     ```

3. **Flutter SDK**
   ```bash
   # Verificar instalacao
   flutter doctor
   ```

4. **Maestro** (instalado automaticamente pelo script)
   ```bash
   # Instalacao manual se necessario
   curl -Ls "https://get.maestro.mobile.dev" | bash
   ```

## Estrutura de Arquivos

```
.maestro/
├── config.yaml              # Configuracao global
├── flows/
│   ├── 01_login.yaml        # Login com conta demo
│   ├── 02_plans_screen.yaml # Tela de planos
│   ├── 03_feature_gate_warning.yaml  # Warning 80%
│   ├── 04_feature_gate_limit.yaml    # Modal 100%
│   ├── 05_pdf_watermark.yaml         # PDF com marca d'agua
│   └── logout.yaml          # Helper para logout
└── screenshots/             # Screenshots capturados

scripts/
├── start-emulator.sh        # Inicia emulador
└── run-visual-tests.sh      # Executa testes
```

## Quick Start

### 1. Iniciar Emulador

```bash
# iOS Simulator
./scripts/start-emulator.sh ios

# Android Emulator
./scripts/start-emulator.sh android
```

### 2. Executar Testes

```bash
# Todos os testes no iOS
./scripts/run-visual-tests.sh

# Todos os testes no Android
./scripts/run-visual-tests.sh --platform android

# Teste especifico
./scripts/run-visual-tests.sh --flow 02_plans_screen
```

### 3. Ver Screenshots

Os screenshots sao salvos em `.maestro/screenshots/`.

```bash
# Abrir pasta no Finder
open .maestro/screenshots/
```

## Fluxos de Teste

### 01_login.yaml

Realiza login com a conta demo configurada.

**Conta Demo:**
- Email: `demo-pt@praticos.com.br`
- Senha: `Demo@2024!`

### 02_plans_screen.yaml

Navega ate a tela de planos e captura:
- `02_plans_screen.png` - Topo da tela
- `02_plans_screen_bottom.png` - Parte inferior

### 03_feature_gate_warning.yaml

Busca e captura banners de warning (80% do limite):
- `03_feature_gate_warning_home.png`
- `03_feature_gate_warning_order.png`
- `03_feature_gate_warning_modal.png`

### 04_feature_gate_limit.yaml

Tenta acionar modais de limite (100%):
- `04_feature_gate_limit_modal.png`
- `04_feature_gate_limit_full.png`
- `04_feature_gate_limit_collaborators.png`

### 05_pdf_watermark.yaml

Gera PDF e captura marca d'agua:
- `05_pdf_watermark_preview.png`
- `05_pdf_watermark_page2.png`

## Uso pelo QA Engineer

### Validacao de PR

Ao receber um PR para review:

1. Fazer checkout da branch
2. Iniciar emulador
3. Executar testes visuais
4. Comparar screenshots com versao anterior
5. Reportar diferencas visuais

```bash
# Exemplo de fluxo completo
git checkout feat/subscription-billing
./scripts/start-emulator.sh ios
./scripts/run-visual-tests.sh
open .maestro/screenshots/
```

### Captura Manual com Maestro Studio

Para exploracao interativa:

```bash
maestro studio
```

Isso abre uma interface visual para criar e testar fluxos.

## Comandos Maestro Uteis

```bash
# Ver dispositivos conectados
maestro devices

# Testar fluxo especifico
maestro test .maestro/flows/02_plans_screen.yaml

# Testar com output detalhado
maestro test .maestro/flows/ --debug-output debug/

# Gravar novo fluxo
maestro record
```

## Troubleshooting

### "Maestro not found"

```bash
# Reinstalar Maestro
curl -Ls "https://get.maestro.mobile.dev" | bash
export PATH="$HOME/.maestro/bin:$PATH"
```

### "No iOS simulator running"

```bash
# Listar simuladores
xcrun simctl list devices

# Iniciar manualmente
./scripts/start-emulator.sh ios
```

### "No Android device connected"

```bash
# Verificar conexao
adb devices

# Se vazio, iniciar emulador
./scripts/start-emulator.sh android
```

### "Element not found"

O app pode usar IDs semanticos diferentes. Verifique:

1. Os IDs corretos usando Maestro Studio
2. Se o elemento esta visivel na tela
3. Se precisa scroll para revelar

### Timeout

Aumentar o timeout no flow:

```yaml
- waitForAnimationToEnd:
    timeout: 15000  # 15 segundos
```

## Integracao com CI (Futuro)

Para rodar em CI, adicionar ao workflow:

```yaml
# .github/workflows/visual-tests.yml
name: Visual Tests

on:
  pull_request:
    branches: [main]

jobs:
  visual-tests:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2

      - name: Install Maestro
        run: curl -Ls "https://get.maestro.mobile.dev" | bash

      - name: Build iOS
        run: flutter build ios --simulator

      - name: Run Visual Tests
        run: |
          xcrun simctl boot "iPhone 15"
          ./scripts/run-visual-tests.sh --platform ios

      - name: Upload Screenshots
        uses: actions/upload-artifact@v4
        with:
          name: screenshots
          path: .maestro/screenshots/
```

## Suporte

Para duvidas ou problemas:
- Consultar documentacao Maestro: https://maestro.mobile.dev/
- Abrir issue no projeto PraticOS
