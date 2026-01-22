# TESTING.md - Testing & Screenshot Infrastructure

Documentação completa da infraestrutura de testes e geração de screenshots do PraticOS.

## Visão Geral

O sistema de testes do PraticOS foi projetado para:
- **Validar funcionalidades** através de testes de integração automatizados
- **Gerar screenshots** para App Store (iOS) e Google Play (Android)
- **Suportar múltiplos idiomas** (pt-BR, en-US, es-ES)
- **Testar múltiplos dispositivos** (iPhones, tablets Android)

---

## Arquitetura de Testes

### Estrutura de Diretórios

```
integration_test/
├── screenshot_test.dart       # Teste principal (7 screenshots)

test_driver/
├── integration_test.dart      # Driver para captura de screenshots

ios/fastlane/
├── Fastfile                   # Lanes iOS para screenshots
└── screenshots/
    ├── pt-BR/                 # Screenshots português
    ├── en-US/                 # Screenshots inglês
    └── es-ES/                 # Screenshots espanhol

android/fastlane/
├── Fastfile                   # Lanes Android para screenshots
└── metadata/android/
    ├── pt-BR/images/
    ├── en-US/images/
    └── es-ES/images/
```

### Fluxo de Teste

```
1. Fastlane Lane (iOS/Android)
        ↓
2. Define TEST_LOCALE (pt-BR, en-US, es-ES)
        ↓
3. Executa Flutter Driver Test
        ↓
4. screenshot_test.dart (navegação + captura)
        ↓
5. integration_test.dart (salva screenshots por idioma)
        ↓
6. Screenshots salvos em ios/fastlane/screenshots/{locale}/
   ou android/fastlane/metadata/android/{locale}/images/
```

---

## Screenshots Capturados (7 telas)

| # | Nome | Descrição | Key Features |
|---|------|-----------|--------------|
| 1 | **Login** | Tela de autenticação | Logo, opção de email |
| 2 | **Home** | Lista de ordens de serviço | Status dots, cards de OS |
| 3 | **Order Detail** | Detalhes de uma OS | Fotos, produtos, serviços |
| 4 | **Order Form** | Criação de nova OS | Formulário customizado por segmento |
| 5 | **Dynamic Forms** | Checklist/vistoria | Formulários dinâmicos (diferencial) |
| 6 | **Collaborators** | Gestão de equipe | Multi-tenancy, roles/permissions |
| 7 | **Dashboard** | Métricas financeiras | Gráficos de receita anual |

---

## Comandos de Teste

### iOS

#### Gerar screenshots para um idioma e dispositivo específico
```bash
cd ios
bundle exec fastlane screenshots locale:"pt-BR" device:"iPhone 16e"
```

#### Gerar screenshots para TODOS idiomas e dispositivos
```bash
cd ios
bundle exec fastlane screenshots_all
# Default: modo PARALELO (mais rápido)
```
**Resultado:** 42 screenshots (3 idiomas × 2 dispositivos × 7 telas)

#### Modo sequencial (se tiver problemas com paralelo)
```bash
cd ios
bundle exec fastlane screenshots_all parallel:false
```

#### Apenas pt-BR (backwards compatibility)
```bash
cd ios
bundle exec fastlane screenshots_pt_br
```

#### Com force logout
```bash
cd ios
bundle exec fastlane screenshots_all force_logout:true
```

### Android

#### Gerar screenshots para um idioma e dispositivo específico
```bash
cd android
bundle exec fastlane screenshots locale:"pt-BR" device:"emulator-5554"
```

#### Gerar screenshots para TODOS idiomas e dispositivos
```bash
cd android
bundle exec fastlane screenshots_all
# Default: modo PARALELO (mais rápido)
```
**Resultado:** 63 screenshots (3 idiomas × 3 tipos de dispositivo × 7 telas)

**Requisito:** 3 emuladores rodando simultaneamente:
- `emulator-5554` - Phone (padrão)
- `emulator-5556` - Tablet 7"
- `emulator-5558` - Tablet 10"

#### Modo sequencial (se tiver problemas com paralelo)
```bash
cd android
bundle exec fastlane screenshots_all parallel:false
```

#### Apenas pt-BR (backwards compatibility)
```bash
cd android
bundle exec fastlane screenshots_pt_br
```

#### Customizar IDs dos emuladores
```bash
cd android
bundle exec fastlane screenshots_all \
  phone_device:"emulator-5554" \
  tablet7_device:"emulator-5560" \
  tablet10_device:"emulator-5562"
```

---

## Testes Diretos via Flutter Drive

Para desenvolvimento/debug, você pode executar os testes diretamente:

### iOS
```bash
# pt-BR
fvm flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshot_test.dart \
  --dart-define=TEST_LOCALE=pt-BR \
  -d "iPhone 16e"

# en-US
fvm flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshot_test.dart \
  --dart-define=TEST_LOCALE=en-US \
  -d "iPhone 16e"
```

### Android
```bash
# pt-BR
fvm flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshot_test.dart \
  --dart-define=TEST_LOCALE=pt-BR \
  -d emulator-5554

# en-US (com force logout)
fvm flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshot_test.dart \
  --dart-define=TEST_LOCALE=en-US \
  --dart-define=FORCE_LOGOUT=true \
  -d emulator-5554
```

---

## Configuração de Idioma

### Como Funciona

1. **Variável de Ambiente `TEST_LOCALE`**
   - Define o idioma do teste (pt-BR, en-US, es-ES)
   - Passado via `--dart-define=TEST_LOCALE=xxx`

2. **Detecção no Teste**
   ```dart
   const locale = String.fromEnvironment('TEST_LOCALE', defaultValue: 'pt-BR');
   ```

3. **Organização de Screenshots**
   - iOS: `ios/fastlane/screenshots/{locale}/`
   - Android: `android/fastlane/metadata/android/{locale}/images/`

### Suporte Multi-idioma no Código

O teste usa helpers para detectar textos em diferentes idiomas:

```dart
String _findTextByLocale(String locale, String key) {
  final texts = {
    'collaborators': {
      'pt-BR': 'Colaboradores',
      'en-US': 'Collaborators',
      'es-ES': 'Colaboradores',
    },
    'year': {
      'pt-BR': 'Ano',
      'en-US': 'Year',
      'es-ES': 'Año',
    },
  };
  return texts[key]?[locale] ?? texts[key]?['pt-BR'] ?? key;
}
```

**Para adicionar novos textos localizados:**
1. Edite o mapa `texts` em `screenshot_test.dart`
2. Adicione as traduções para pt-BR, en-US, es-ES
3. Use `_findTextByLocale(locale, 'chave')` no teste

---

## Conta de Teste (Demo)

**Credenciais:**
- Email: `demo@praticos.com.br`
- Senha: `Demo@2024!`
- Segmento: **Mecânica** (mesmo para todos idiomas)

**Dados Pré-populados:**
- 5+ ordens de serviço
- 3+ clientes
- 2+ colaboradores
- Formulários dinâmicos configurados
- Dashboard com métricas de 2025

---

## Troubleshooting

### iOS: "No device found"
```bash
# Listar simuladores disponíveis
xcrun simctl list devices

# Exemplo de saída:
# iPhone 16e (XXXX-XXXX) (Booted)
# iPhone 17 (YYYY-YYYY) (Shutdown)

# Iniciar um simulador
open -a Simulator
xcrun simctl boot "iPhone 16e"
```

### Android: "No emulator found"
```bash
# Listar emuladores
emulator -list-avds

# Iniciar emulador
emulator -avd Pixel_7_API_34 &
emulator -avd Pixel_Tablet_API_34 &

# Verificar dispositivos conectados
adb devices
```

### Erro: "Unable to find collaborators button"
- Verifique se a conta demo tem permissões de admin/owner
- Certifique-se de que `CollaboratorStore` carregou dados
- Aumente o delay de espera em `screenshot_test.dart`

### Screenshots cortados/incompletos
- Aumente os delays (`await Future.delayed`) antes de capturar
- Verifique se `await tester.pumpAndSettle()` é chamado
- Para Android, confirme que `convertFlutterSurfaceToImage()` foi executado

### Falha no login
- Verifique credenciais da conta demo
- Confirme que Firebase está configurado corretamente
- Aumente o timeout de login (linha 108-117 de `screenshot_test.dart`)

---

## CI/CD Integration

### GitHub Actions (futuro)

Exemplo de workflow para gerar screenshots automaticamente:

```yaml
name: Generate Screenshots

on:
  workflow_dispatch:
    inputs:
      locale:
        description: 'Locale (pt-BR, en-US, es-ES, all)'
        required: true
        default: 'all'

jobs:
  ios-screenshots:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
      - name: Generate iOS Screenshots
        run: |
          cd ios
          bundle exec fastlane screenshots_all
      - name: Upload Screenshots
        uses: actions/upload-artifact@v4
        with:
          name: ios-screenshots
          path: ios/fastlane/screenshots/
```

---

## Manutenção e Atualização

### Adicionar Novo Screenshot

1. **Editar `screenshot_test.dart`:**
   ```dart
   // Adicionar novo passo de navegação
   print('📸 Navigating to New Screen...');
   // ... navegação ...
   await binding.takeScreenshot('8_new_screen');
   ```

2. **Atualizar `integration_test.dart` (mapeamento iOS):**
   ```dart
   final Map<String, String> iosNameMapping = {
     // ... existentes ...
     '8_new_screen': '07_NewScreen',
   };
   ```

3. **Atualizar documentação** (este arquivo)

### Adicionar Novo Idioma

1. **Adicionar locale no `main.dart`:**
   ```dart
   supportedLocales: const [
     Locale('pt', 'BR'),
     Locale('en', 'US'),
     Locale('es', 'ES'),
     Locale('fr', 'FR'), // Novo
   ],
   ```

2. **Criar arquivos `.arb` para o idioma:**
   ```bash
   cp lib/l10n/app_pt.arb lib/l10n/app_fr.arb
   # Traduzir conteúdo
   fvm flutter gen-l10n
   ```

3. **Atualizar Fastfile (iOS e Android):**
   ```ruby
   locales = ["pt-BR", "en-US", "es-ES", "fr-FR"]
   ```

4. **Criar pastas de screenshots:**
   ```bash
   mkdir -p ios/fastlane/screenshots/fr-FR
   mkdir -p android/fastlane/metadata/android/fr-FR/images
   ```

---

## Boas Práticas

### ✅ DO

- **Sempre usar `await tester.pumpAndSettle()`** após navegações
- **Adicionar delays após Firebase queries** (mínimo 2s)
- **Testar com dados reais** da conta demo
- **Manter mapeamento de nomes atualizado** no driver
- **Versionar screenshots** no Git (apenas pt-BR)

### ❌ DON'T

- Não commitar screenshots de todos idiomas (muito pesado)
- Não usar hardcoded strings (sempre via i18n)
- Não assumir ordem de elementos na UI
- Não pular `convertFlutterSurfaceToImage()` no Android
- Não usar `find.text()` direto (usar helpers com fallbacks)

---

## Métricas de Teste

### Tempo Estimado de Execução

| Plataforma | Modo | Dispositivos | Idiomas | Tempo |
|------------|------|--------------|---------|-------|
| iOS | Single | 1 dispositivo | 1 idioma | ~3.5 min |
| iOS | Sequential | 2 dispositivos | 3 idiomas | ~21 min |
| iOS | **Parallel** ⚡ | 2 dispositivos | 3 idiomas | **~11 min** |
| Android | Single | 1 dispositivo | 1 idioma | ~4 min |
| Android | Sequential | 3 dispositivos | 3 idiomas | ~36 min |
| Android | **Parallel** ⚡ | 3 dispositivos | 3 idiomas | **~12 min** |

**Parallel Mode:** Roda múltiplos dispositivos simultaneamente (requer mais RAM/CPU).

### Tamanho dos Screenshots

- **iOS**: ~300-500 KB por screenshot (PNG)
- **Android**: ~200-400 KB por screenshot (PNG)
- **Total (todos idiomas)**: ~22 MB (iOS) + ~18 MB (Android)

---

## Referências

- [Flutter Integration Testing](https://docs.flutter.dev/testing/integration-tests)
- [Fastlane Screenshots](https://docs.fastlane.tools/actions/screenshot/)
- [App Store Screenshot Specifications](https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications)
- [Google Play Screenshot Guidelines](https://support.google.com/googleplay/android-developer/answer/9866151)

---

## Testes CRUD de Integração

### Visão Geral

O sistema possui testes automatizados de integração que validam operações CRUD (Create, Read, Update, Delete) para as principais entidades:

| Entidade | Arquivo de Teste | Operações |
|----------|------------------|-----------|
| Device | `crud_integration_test.dart` | Create, Update, Delete |
| Service | `crud_integration_test.dart` | Create, Update, Delete |
| Product | `crud_integration_test.dart` | Create, Update, Delete |
| Form | `crud_integration_test.dart` | Create, Update, Delete |

**Total:** 12 testes

### Comando para Executar

```bash
fvm flutter test integration_test/crud_integration_test.dart --dart-define=TEST_LOCALE=pt-BR
```

---

### Convenção de Semantic Identifiers

Os testes usam **Semantic Identifiers** para localizar e interagir com widgets de forma confiável, independente de mudanças na UI.

#### Padrão de Nomenclatura

```
{contexto}_{tipo}_{identificador}
```

**Exemplos:**
- `device_list_add_button` - Botão adicionar na lista de devices
- `device_form_save_button` - Botão salvar no form de device
- `device_item_{id}` - Item específico na lista (usa ID real)
- `tab_settings` - Tab de configurações

#### Tabela de Semantic Identifiers por Tela

**Telas de Lista:**
| Identifier | Descrição |
|------------|-----------|
| `{entity}_list_add_button` | Botão de adicionar |
| `{entity}_item_{id}` | Item na lista (usa ID da entidade) |

**Telas de Formulário:**
| Identifier | Descrição |
|------------|-----------|
| `{entity}_form_save_button` | Botão salvar |
| `{entity}_form_name_field` | Campo nome |
| `{entity}_form_value_field` | Campo valor |

**Picker de Valores Acumulados:**
| Identifier | Descrição |
|------------|-----------|
| `accumulated_value_search_field` | Campo de busca |
| `accumulated_value_item_{index}` | Item na lista |
| `accumulated_value_add_button` | Botão adicionar novo valor |

**Menu de Configurações:**
| Identifier | Descrição |
|------------|-----------|
| `tab_settings` | Tab de configurações |
| `settings_menu_devices` | Menu Equipamentos |
| `settings_menu_services` | Menu Serviços |
| `settings_menu_products` | Menu Produtos |
| `settings_menu_forms` | Menu Procedimentos |

---

### Helper Functions

O arquivo de teste inclui funções auxiliares para interação via Semantics:

#### `_findBySemantic(tester, identifier)`
Localiza um widget pelo seu semantic identifier.

```dart
final widget = await _findBySemantic(tester, 'device_list_add_button');
```

#### `_tapSemantic(tester, identifier)`
Clica em um widget pelo seu semantic identifier.

```dart
await _tapSemantic(tester, 'device_form_save_button');
```

#### `_enterTextInSemantic(tester, identifier, text)`
Preenche um campo de texto identificado por Semantics.

```dart
await _enterTextInSemantic(tester, 'service_form_name_field', 'Meu Serviço');
```

#### `_findFirstEntityId(tester, entityType)`
Encontra o ID da primeira entidade na lista.

```dart
final deviceId = await _findFirstEntityId(tester, 'device');
// Retorna: "abc123" (ID real do Firebase)
```

#### `_selectOrCreateAccumulatedValue(tester, value)`
Seleciona ou cria um valor no picker de campos acumulativos.

```dart
await _selectOrCreateAccumulatedValue(tester, 'Nova Categoria');
```

---

### Como Adicionar Semantic Identifier a um Widget

1. **Wrap o widget com `Semantics`:**

```dart
Semantics(
  identifier: 'meu_componente_tipo',
  child: CupertinoButton(
    onPressed: _minhaAcao,
    child: Text('Meu Botão'),
  ),
)
```

2. **Para itens de lista, use o ID real:**

```dart
// ✅ CORRETO - ID estável
Semantics(
  identifier: 'device_item_${device.id}',
  child: _buildDeviceCard(device),
)

// ❌ ERRADO - Index muda com ordenação
Semantics(
  identifier: 'device_item_$index',
  child: _buildDeviceCard(device),
)
```

---

### Como Criar Novo Teste CRUD

1. **Seguir o padrão existente:**

```dart
testWidgets('Create {entity}', (WidgetTester tester) async {
  // 1. Inicializar app
  await _initializeApp(tester);

  // 2. Login
  await _performLogin(tester, locale);

  // 3. Navegar para lista
  await _navigateToMenu(tester, 'Menu Label');

  // 4. Clicar em adicionar
  await _tapSemantic(tester, '{entity}_list_add_button');

  // 5. Preencher formulário
  await _enterTextInSemantic(tester, '{entity}_form_name_field', 'Test');

  // 6. Salvar
  await _tapSemantic(tester, '{entity}_form_save_button');

  // 7. Verificar
  final id = await _findFirstEntityId(tester, '{entity}');
  expect(id, isNotNull);
});
```

2. **Adicionar semantic identifiers necessários nas telas**

3. **Rodar e iterar até passar**

---

### Boas Práticas para Testes CRUD

#### ✅ DO
- Use `await tester.pumpAndSettle()` após cada interação
- Use `await Future.delayed()` para aguardar Firebase
- Use `FocusManager.instance.primaryFocus?.unfocus()` para fechar teclado
- Use IDs reais em `{entity}_item_{id}` para estabilidade
- Verifique null antes de interagir com widgets

#### ❌ DON'T
- Não use `find.text()` diretamente (frágil com i18n)
- Não use index para identificar items de lista
- Não assuma ordem de elementos
- Não pule verificações de null

---

## Changelog

### v1.2.0 (2026-01-13)
- ⚡ **Paralelização**: Modo paralelo por padrão (reduz tempo de 21min → 11min no iOS)
- 🔄 **Auto-reset**: Simuladores iOS resetados automaticamente antes de cada teste
- 🎯 **Clean state**: Garante que testes sempre começam na tela de login
- 📝 Documentação atualizada com novos tempos e comandos

### v1.1.0 (2026-01-13)
- ✨ Adicionado suporte multi-idioma (pt-BR, en-US, es-ES)
- ✨ Novos screenshots: Order Form, Dynamic Forms, Collaborators
- 🔄 Substituído Customers/Settings por novas funcionalidades
- 📝 Documentação completa criada

### v1.0.0 (2025-XX-XX)
- 🎉 Release inicial com 7 screenshots em pt-BR
- ✅ Suporte iOS (iPhone 16e, iPhone 17)
- ✅ Suporte Android (Phone, 7", 10")
