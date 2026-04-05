# Guia de Teste Local do Billing

**Data:** 2026-04-05
**Autor:** CTO Agent
**Relacionado:** PRA-41

---

## 1. Visao Geral

Este documento descreve como testar toda a implementacao de billing/subscriptions **localmente em emuladores** antes de subir para o Release Candidate (RC).

### O que pode ser testado localmente?
| Componente | Testavel Local? | Como |
|------------|-----------------|------|
| UI/UX das telas de planos | Sim | Emulador |
| Feature Gates (limites) | Sim | Emulador + mock |
| Marca d'agua PDF | Sim | Emulador |
| Fluxo de navegacao | Sim | Emulador |
| Compra real (IAP) | **Nao** | Sandbox das lojas |
| Webhook RevenueCat | **Nao** | Ambiente de staging |

### Limitacoes dos Emuladores
- **Emuladores nao suportam compras reais** - tanto iOS Simulator quanto Android Emulator nao executam transacoes IAP
- Para testar compras reais: usar sandbox testers em dispositivos fisicos (TestFlight/Internal Testing)

---

## 2. Requisitos

### 2.1 Ferramentas Necessarias

```bash
# Flutter
flutter doctor

# Maestro (opcional, para testes automatizados)
brew install mobile-dev-inc/tap/maestro
maestro --version

# Emuladores
xcrun simctl list devices  # iOS
emulator -list-avds        # Android
```

### 2.2 Configuracao do Projeto

```bash
# Clonar e preparar
cd ~/Projetos/praticOSopen
git checkout feat/subscription-billing
flutter pub get
flutter analyze  # Deve mostrar 0 issues
```

---

## 3. Teste Manual no Emulador

### 3.1 Iniciar o App

**iOS Simulator:**
```bash
# Listar simuladores
xcrun simctl list devices | grep "iPhone"

# Iniciar simulador (ex: iPhone 15 Pro)
open -a Simulator

# Rodar o app
flutter run -d "iPhone 15 Pro"
```

**Android Emulator:**
```bash
# Listar AVDs
emulator -list-avds

# Iniciar emulator
emulator -avd Pixel_7_API_34 &

# Rodar o app
flutter run -d emulator-5554
```

### 3.2 Cenarios de Teste Manual

#### Cenario 1: Visualizar Tela de Planos
1. Fazer login com conta demo: `demo-pt@praticos.com.br` / `Demo@2024!`
2. Ir em Menu > Configuracoes
3. Tocar em "Planos e Assinatura"
4. **Verificar:**
   - [ ] Plano atual exibido corretamente (Free)
   - [ ] 4 cards de planos visiveis
   - [ ] Precos corretos: Gratis, R$59, R$119, R$249
   - [ ] Botao "Restaurar" no header
   - [ ] FAQs no footer

#### Cenario 2: Simular Compra (UI apenas)
1. Na tela de planos, tocar em "Assinar Pro"
2. **Verificar:**
   - [ ] Botao mostra loading indicator
   - [ ] Dialog de erro aparece ("Plano nao disponivel" - esperado em emulador)

#### Cenario 3: Feature Gate - Warning 80%
1. Modificar `SubscriptionUsage` para simular 80%+ do limite
2. Tentar adicionar foto em uma OS
3. **Verificar:**
   - [ ] Banner amarelo aparece com aviso
   - [ ] Mostra uso atual e limite

#### Cenario 4: Feature Gate - Limite 100%
1. Modificar `SubscriptionUsage` para simular 100% do limite
2. Tentar adicionar foto em uma OS
3. **Verificar:**
   - [ ] Modal de limite aparece
   - [ ] Botao "Ver Planos" navega corretamente
   - [ ] Operacao e bloqueada

#### Cenario 5: PDF com Marca D'agua (Free)
1. Criar uma OS com fotos
2. Gerar PDF da OS
3. **Verificar:**
   - [ ] PDF gerado contem marca d'agua "PraticOS Free"

---

## 4. Testes com Mock de Subscription

Para testar feature gates sem depender do RevenueCat, podemos criar um mock local.

### 4.1 Criar Mock Provider

Adicione em `lib/debug/mock_subscription_provider.dart`:

```dart
import 'package:praticos/models/subscription.dart';

/// Mock provider para testes locais de feature gates.
/// Usar apenas em DEBUG mode.
class MockSubscriptionProvider {
  static Subscription createMockSubscription({
    SubscriptionPlan plan = SubscriptionPlan.free,
    int photosUsed = 0,
    int formsUsed = 0,
    int collabsUsed = 0,
  }) {
    return Subscription(
      plan: plan,
      status: SubscriptionStatus.active,
      usage: SubscriptionUsage(
        photosThisMonth: photosUsed,
        formTemplates: formsUsed,
        collaborators: collabsUsed,
      ),
    );
  }

  /// Simula Free no limite de fotos (30/30)
  static Subscription freeAtPhotoLimit() =>
      createMockSubscription(photosUsed: 30);

  /// Simula Free proximo do limite (25/30 = 83%)
  static Subscription freeNearPhotoLimit() =>
      createMockSubscription(photosUsed: 25);

  /// Simula Pro ativo
  static Subscription proActive() =>
      createMockSubscription(plan: SubscriptionPlan.pro, photosUsed: 100);

  /// Simula Business ativo
  static Subscription businessActive() =>
      createMockSubscription(plan: SubscriptionPlan.business);
}
```

### 4.2 Usar Mock em Debug Mode

Em `lib/main.dart`, adicione flag de debug:

```dart
// Em DEBUG, usar mock subscription para testes
if (kDebugMode && const bool.fromEnvironment('USE_MOCK_SUBSCRIPTION')) {
  final mockSub = MockSubscriptionProvider.freeNearPhotoLimit();
  Global.subscription = mockSub;
}
```

Rodar com mock:
```bash
flutter run --dart-define=USE_MOCK_SUBSCRIPTION=true
```

---

## 5. Testes Automatizados com Maestro

O projeto ja tem fluxos Maestro configurados em `.maestro/flows/`.

### 5.1 Executar Testes

```bash
# Iniciar emulador primeiro
./scripts/start-emulator.sh ios

# Rodar todos os testes
./scripts/run-visual-tests.sh

# Ou rodar teste especifico
maestro test .maestro/flows/02_plans_screen.yaml
```

### 5.2 Fluxos Disponiveis

| Fluxo | Descricao |
|-------|-----------|
| `01_login.yaml` | Login com conta demo |
| `02_plans_screen.yaml` | Captura tela de planos |
| `03_feature_gate_warning.yaml` | Captura warning 80% |
| `04_feature_gate_limit.yaml` | Captura modal 100% |
| `05_pdf_watermark.yaml` | Captura PDF com marca d'agua |
| `logout.yaml` | Helper para logout |

### 5.3 Ver Screenshots

```bash
open .maestro/screenshots/
```

---

## 6. Verificacao Pre-RC

Antes de criar o RC, execute este checklist:

### 6.1 Build Verification
```bash
# Analise estatica
flutter analyze
# Esperado: 0 issues

# Testes unitarios
flutter test
# Esperado: All tests passed

# Build Android
flutter build apk --debug
# Esperado: Build successful

# Build iOS
flutter build ios --debug --no-codesign
# Esperado: Build successful
```

### 6.2 Manual QA Checklist

#### Telas e Navegacao
- [ ] Tela de Planos renderiza corretamente
- [ ] Scroll funciona nos cards
- [ ] Dark mode funciona
- [ ] Navegacao de volta funciona
- [ ] Deep link `/subscription/plans` funciona

#### Feature Gates
- [ ] FeatureGateWarning aparece em 80%+ uso
- [ ] FeatureGateLimitModal aparece em 100% uso
- [ ] Botao "Ver Planos" navega corretamente
- [ ] Operacao bloqueada quando limite atingido

#### PDF
- [ ] Marca d'agua aparece no plano Free
- [ ] Marca d'agua NAO aparece em planos pagos (mock)

#### Internacionalizacao
- [ ] Textos em PT-BR corretos
- [ ] Precos formatados corretamente (R$ X,XX)

---

## 7. Teste em Dispositivo Real (RC)

Apos verificacao local, o proximo passo e o RC em dispositivo real.

### 7.1 iOS (TestFlight)
1. Merge PRs #224 e #225 na master
2. CI cria tag automaticamente e sobe para TestFlight
3. Voce recebe notificacao no email
4. Baixar app via TestFlight
5. Configurar Sandbox Tester:
   - App Store Connect > Users > Sandbox Testers
   - Criar tester com email de teste
6. No iPhone: Settings > App Store > Sandbox Account
7. Login com sandbox tester
8. Testar compra real no app

### 7.2 Android (Internal Testing)
1. Mesmo merge sobe para Play Console (Internal track)
2. Google Play Console > Internal testing > Testers
3. Adicionar Gmail do tester
4. Aceitar convite via link
5. Baixar app
6. Testar compra real no app

### 7.3 Cenarios de Teste em Sandbox

| Cenario | Como Testar | Esperado |
|---------|-------------|----------|
| Compra Starter | Selecionar e confirmar | Plano atualiza para Starter |
| Upgrade Pro | Ja com Starter, assinar Pro | Plano atualiza para Pro |
| Cancelamento | Settings > Assinaturas > Cancelar | Status = canceled |
| Restore | Reinstalar app > Restaurar | Plano restaurado |
| Trial | Nova conta > Assinar | 7 dias gratis |

---

## 8. Resumo

### O que testar localmente (antes do RC):
1. **UI/UX** - Todas as telas de billing
2. **Feature Gates** - Usando mock subscription
3. **PDF Watermark** - Verificar marca d'agua
4. **Navegacao** - Deep links e fluxos
5. **Build** - Garantir que compila sem erros

### O que testar no RC (dispositivo real):
1. **Compras reais** - Via sandbox testers
2. **Webhooks** - Verificar no RevenueCat Dashboard
3. **Sincronizacao** - Compra reflete no app
4. **Restore** - Em novo dispositivo

---

**Conclusao:** Sim, conseguimos testar **~80% da implementacao** localmente em emuladores. Apenas as compras reais (IAP) requerem dispositivo fisico com sandbox configurado.
