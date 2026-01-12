# SEGMENT_CUSTOM_FIELDS.md - Campos Customizados por Segmento

## Visão Geral

O PraticOS permite que cada segmento de negócio (ex: Oficinas Mecânicas, Assistências Técnicas, Salões de Beleza) tenha labels customizados para campos específicos, adaptando a terminologia do sistema ao vocabulário do segmento.

## Arquitetura

### Estrutura no Firestore

```
/segments/{segmentId}
  ├── name: "Oficinas Mecânicas"
  ├── icon: "car_repair"
  └── customLabels: {
       "device": "Veículo",
       "devicePlaceholder": "Ex: Fiat Uno 2015",
       "customer": "Cliente",
       "service": "Serviço",
       "product": "Peça"
     }
```

### SegmentConfigService

Serviço singleton que gerencia configurações de segmento.

```dart
class SegmentConfigService {
  static final SegmentConfigService _instance = SegmentConfigService._internal();
  factory SegmentConfigService() => _instance;

  String? _segmentId;
  Map<String, dynamic>? _customLabels;

  // Carrega configuração do segmento
  Future<void> loadSegmentConfig(String segmentId);

  // Retorna label customizado ou fallback padrão
  String getLabel(String key, {String? fallback});
}
```

## Campos Customizáveis

### Campos Principais

| Campo | Chave | Padrão (pt-BR) | Exemplo Mecânica | Exemplo Salão |
|-------|-------|----------------|------------------|---------------|
| Dispositivo | `device` | Dispositivo | Veículo | - |
| Cliente | `customer` | Cliente | Cliente | Cliente |
| Serviço | `service` | Serviço | Serviço | Serviço |
| Produto | `product` | Produto | Peça | Produto |

### Placeholders

| Campo | Chave | Padrão | Exemplo Mecânica |
|-------|-------|--------|------------------|
| Device Placeholder | `devicePlaceholder` | Ex: iPhone 12 | Ex: Fiat Uno 2015 |
| Customer Placeholder | `customerPlaceholder` | Nome do cliente | Nome do cliente |

## Uso no Código

### 1. Inicialização (no login/startup)

```dart
// Após login, quando companyId está disponível
final segmentProvider = context.read<SegmentConfigProvider>();
final segmentId = segmentProvider.segmentId;

if (segmentId != null) {
  await SegmentConfigService().loadSegmentConfig(segmentId);
}
```

### 2. Obter Label Customizado

```dart
import 'package:praticos/services/segment_config_service.dart';

final segmentService = SegmentConfigService();

// Com fallback padrão
final deviceLabel = segmentService.getLabel(
  'device',
  fallback: context.l10n.device,
);

// Uso em widget
Text(deviceLabel)  // "Veículo" para mecânicas, "Dispositivo" para outros
```

### 3. Combinar com i18n

O sistema deve sempre priorizar i18n para o idioma, e depois aplicar customização de segmento:

```dart
// ✅ CORRETO - i18n + customização
final baseLabel = context.l10n.device;  // "Device" (en), "Dispositivo" (pt), "Dispositivo" (es)
final customLabel = SegmentConfigService().getLabel('device', fallback: baseLabel);

Text(customLabel)  // "Veículo" (pt-BR + mecânica), "Vehicle" (en + mecânica)

// ❌ ERRADO - Hardcoded
Text('Veículo')  // Não adapta ao idioma nem ao segmento
```

## Implementação em Telas

### Exemplo: Formulário de Dispositivo

```dart
class DeviceFormScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final segmentService = SegmentConfigService();
    final deviceLabel = segmentService.getLabel(
      'device',
      fallback: context.l10n.device,
    );
    final devicePlaceholder = segmentService.getLabel(
      'devicePlaceholder',
      fallback: context.l10n.devicePlaceholder,
    );

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(deviceLabel),  // "Veículo" ou "Dispositivo"
      ),
      child: CupertinoListSection.insetGrouped(
        children: [
          CupertinoTextFormFieldRow(
            prefix: Text(deviceLabel),
            placeholder: devicePlaceholder,  // "Ex: Fiat Uno 2015"
            // ...
          ),
        ],
      ),
    );
  }
}
```

### Exemplo: Lista com Filtros

```dart
// Título da tela adapta ao segmento
final deviceLabel = SegmentConfigService().getLabel(
  'device',
  fallback: context.l10n.devices,
);

CupertinoSliverNavigationBar(
  largeTitle: Text(deviceLabel),  // "Veículos" ou "Dispositivos"
)
```

## Seeding de Segmentos

Script para popular segmentos com labels customizados:

```javascript
// firebase/scripts/seed_segments.js
const segments = [
  {
    id: 'automotive',
    name: {
      'pt': 'Oficinas Mecânicas',
      'en': 'Automotive Repair',
      'es': 'Talleres Mecánicos'
    },
    customLabels: {
      'pt': {
        device: 'Veículo',
        devicePlaceholder: 'Ex: Fiat Uno 2015',
      },
      'en': {
        device: 'Vehicle',
        devicePlaceholder: 'Ex: Ford Focus 2020',
      },
      'es': {
        device: 'Vehículo',
        devicePlaceholder: 'Ej: Seat Ibiza 2018',
      }
    }
  }
];
```

Executar:
```bash
cd firebase/scripts
node seed_segments.js
```

## Fluxo de Dados

```
Usuário faz login
    ↓
Company tem segmentId
    ↓
SegmentConfigProvider carrega segment
    ↓
SegmentConfigService.loadSegmentConfig(segmentId)
    ↓
Busca documento /segments/{segmentId}
    ↓
Armazena customLabels em memória
    ↓
Telas usam getLabel() para obter labels customizados
    ↓
Labels aparecem adaptados ao segmento + idioma
```

## Provider Pattern

### SegmentConfigProvider

```dart
class SegmentConfigProvider with ChangeNotifier {
  String? _segmentId;

  String? get segmentId => _segmentId;

  void setSegment(String? segmentId) {
    _segmentId = segmentId;
    notifyListeners();

    if (segmentId != null) {
      SegmentConfigService().loadSegmentConfig(segmentId);
    }
  }
}
```

### Inicialização no main.dart

```dart
void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SegmentConfigProvider()),
        // ...
      ],
      child: MyApp(),
    ),
  );
}
```

## Casos de Uso

### 1. Oficinas Mecânicas

```dart
// Segmento: automotive
device → "Veículo"
devicePlaceholder → "Ex: Fiat Uno 2015"
product → "Peça"
service → "Serviço"
```

### 2. Assistências Técnicas (Eletrônicos)

```dart
// Segmento: electronics_repair
device → "Aparelho"
devicePlaceholder → "Ex: iPhone 12 Pro"
product → "Componente"
service → "Reparo"
```

### 3. Salões de Beleza

```dart
// Segmento: beauty_salon
device → null  // Não usa
customer → "Cliente"
product → "Produto"
service → "Serviço"
```

## Regras Importantes

### ✅ SEMPRE

1. Combinar com i18n (idioma primeiro, customização depois)
2. Fornecer fallback padrão usando `context.l10n`
3. Verificar se `segmentId` está disponível antes de usar
4. Usar o mesmo padrão em toda a aplicação

### ❌ NUNCA

1. Hardcoded labels específicos de segmento
2. Ignorar o idioma do sistema
3. Assumir que todos os segmentos têm customizações
4. Usar customLabels diretamente sem fallback

### Ordem de Prioridade

```
1. customLabels do segmento (se disponível)
   ↓
2. Tradução i18n do idioma atual (fallback)
   ↓
3. String hardcoded em inglês (último recurso)
```

## Migração de Código Existente

### Identificar Labels que Devem ser Customizáveis

```bash
# Buscar labels hardcoded que variam por segmento
grep -r "Veículo\|Dispositivo\|Aparelho" lib/screens/
```

### Processo de Migração

1. Identificar campos que variam por segmento
2. Adicionar chaves correspondentes em `customLabels`
3. Atualizar `SegmentConfigService` se necessário
4. Substituir strings hardcoded por `getLabel()`
5. Adicionar fallback com `context.l10n`
6. Testar com diferentes segmentos

## Exemplos de Implementação

### Antes (Hardcoded)

```dart
// ❌ Não adapta nem ao idioma nem ao segmento
CupertinoNavigationBar(
  middle: Text('Veículo'),
)
```

### Depois (i18n + Custom)

```dart
// ✅ Adapta ao idioma E ao segmento
final deviceLabel = SegmentConfigService().getLabel(
  'device',
  fallback: context.l10n.device,
);

CupertinoNavigationBar(
  middle: Text(deviceLabel),
)
```

## Recursos Adicionais

- `lib/services/segment_config_service.dart` - Implementação do serviço
- `lib/providers/segment_config_provider.dart` - Provider de segmento
- `firebase/scripts/seed_segments.js` - Script de seeding
- `docs/MULTI_TENANCY.md` - Arquitetura multi-tenant relacionada
