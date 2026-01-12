# Field Validation and Masks

Sistema de máscaras e validações multi-segmento e multi-país para campos de formulário.

## Visão Geral

O PraticOS suporta validações e máscaras dinâmicas baseadas em:
- **Segmento da empresa** (mecânica, eletrônica, TI, etc)
- **País da empresa** (Brasil, Portugal, EUA, etc)
- **Tipo de campo** (telefone, CEP, serial, etc)

### Princípios

1. **Telefone é complexo**: Usa biblioteca especializada ([phone_numbers_parser](https://pub.dev/packages/phone_numbers_parser))
2. **Outros campos são simples**: Configuração via `customFields` no Firestore
3. **Universal vs Regional**: Se não varia por país, configura uma vez só

## Arquitetura

```
┌─────────────────────────────────────────────────────────┐
│  Formulário (UI)                                        │
│  └─ PhoneField (telefone)                               │
│  └─ DynamicTextField (outros campos)                    │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│  SegmentConfigService                                   │
│  ├─ phone_numbers_parser (validação real de telefone)  │
│  └─ CustomField (máscaras configuradas no Firestore)   │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│  Firestore: /segments/{segmentId}                      │
│  └─ customFields[] (máscaras, validações, labels)      │
└─────────────────────────────────────────────────────────┘
```

## Tipos de Campos

### 1. Telefone (Complexo - Biblioteca Especializada)

**Por que biblioteca?**
- 200+ países com formatos diferentes
- Validação real (não apenas máscara)
- Detecta tipo (móvel, fixo, VoIP)
- Formatação automática

**Implementação:**
```dart
// Widget especializado para telefone
PhoneField(
  fieldKey: 'company.phone',
  initialValue: _company?.phone,
  onSaved: (val) => _company?.phone = val,
  required: false,
)
```

**Como funciona:**
- Usa `phone_numbers_parser` do Google
- País vem de `company.country`
- Validação real (não apenas formato)
- Formatação automática

### 2. Campos Universais (Não Variam por País)

**Exemplos:**
- IMEI (sempre 15 dígitos)
- UUID (formato padrão)
- Email (padrão universal)

**Configuração Firestore:**
```json
{
  "key": "device.serial",
  "type": "text",
  "labels": {"pt-BR": "IMEI", "en-US": "IMEI"},
  "masks": ["999999999999999"],
  "placeholder": "123456789012345",
  "keyboardType": "number"
}
```

**Lógica:**
- Campo `masks` (lista simples) = universal
- Não precisa repetir por país

### 3. Campos Regionais (Variam por País)

**Exemplos:**
- CEP/ZIP Code (BR: 99999-999, US: 99999)
- Placa de veículo (BR: AAA9N99, US: AAA-999)
- CPF/SSN (específico de cada país)

**Configuração Firestore:**
```json
{
  "key": "company.zipCode",
  "type": "text",
  "labels": {"pt-BR": "CEP", "en-US": "ZIP Code"},
  "masksByCountry": {
    "BR": ["99999-999"],
    "US": ["99999", "99999-9999"],
    "PT": ["9999-999"]
  },
  "placeholder": "12345-678"
}
```

**Lógica:**
- Campo `masksByCountry` (map) = regional
- Sistema usa `company.country` para escolher

## CustomField Model

```dart
class CustomField {
  final String key;              // Ex: 'device.serial', 'company.zipCode'
  final String type;             // 'text', 'number', 'label'
  final Map<String, String> labels;  // i18n labels

  // Configurações de input
  final List<String>? masks;           // Máscaras universais
  final Map<String, List<String>>? masksByCountry;  // Máscaras por país
  final String? keyboardType;          // 'phone', 'text', 'number', 'email'
  final String? textCapitalization;    // 'characters', 'words', 'sentences'
  final String? placeholder;

  // Validações
  final bool required;
  final num? min;
  final num? max;
  final int? maxLength;
  final String? pattern;  // Regex customizado

  // ... outros campos existentes
}
```

## SegmentConfigService

### Métodos Adicionados

```dart
class SegmentConfigService {
  String? _countryCode;

  /// Define país da empresa
  void setCountry(String? code) {
    _countryCode = code;
  }

  /// Obtém CustomField para um campo
  CustomField? getField(String key) {
    return _customFields.firstWhere(
      (f) => f.key == key && f.isField,
      orElse: () => null,
    );
  }

  /// Obtém máscaras para um campo
  /// Prioridade: masks → masksByCountry[country] → []
  List<String> getMasks(String fieldKey) {
    final field = getField(fieldKey);
    if (field == null) return [];

    // 1. Máscaras universais
    if (field.masks != null && field.masks!.isNotEmpty) {
      return field.masks!;
    }

    // 2. Máscaras por país
    if (field.masksByCountry != null && _countryCode != null) {
      return field.masksByCountry![_countryCode] ?? [];
    }

    // 3. Sem máscara (campo livre)
    return [];
  }

  /// Obtém tipo de teclado
  TextInputType getKeyboardType(String fieldKey) {
    final field = getField(fieldKey);
    if (field?.keyboardType != null) {
      return _parseKeyboardType(field!.keyboardType!);
    }

    // Fallback inteligente
    if (fieldKey.contains('phone')) return TextInputType.phone;
    if (fieldKey.contains('email')) return TextInputType.emailAddress;

    return TextInputType.text;
  }

  /// Obtém capitalização
  TextCapitalization getTextCapitalization(String fieldKey) {
    final field = getField(fieldKey);
    if (field?.textCapitalization != null) {
      return _parseTextCapitalization(field!.textCapitalization!);
    }

    return TextCapitalization.none;
  }
}
```

## Widgets

### PhoneField (Especializado)

```dart
/// Widget para campos de telefone com validação real
class PhoneField extends StatelessWidget {
  final String fieldKey;
  final String? initialValue;
  final FormFieldSetter<String>? onSaved;
  final bool required;
  final Widget? prefix;

  @override
  Widget build(BuildContext context) {
    final config = context.watch<SegmentConfigProvider>();
    final country = config.countryCode ?? 'BR';

    return CupertinoTextFormFieldRow(
      prefix: prefix ?? Text(config.label(fieldKey)),
      initialValue: initialValue,
      placeholder: '+${IsoCode.fromCode(country)?.dialCode ?? '55'}',
      keyboardType: TextInputType.phone,
      onSaved: onSaved,
      validator: (val) {
        if (required && (val == null || val.isEmpty)) {
          return context.l10n.required;
        }

        if (val != null && val.isNotEmpty) {
          try {
            final phone = PhoneNumber.parse(
              val,
              callerCountry: IsoCode.fromCode(country)
            );
            if (!phone.isValid()) {
              return context.l10n.invalidPhone;
            }
          } catch (e) {
            return context.l10n.invalidPhone;
          }
        }

        return null;
      },
    );
  }
}
```

### DynamicTextField (Genérico)

```dart
/// Widget para campos customizáveis (não-telefone)
class DynamicTextField extends StatelessWidget {
  final String fieldKey;
  final String? initialValue;
  final FormFieldSetter<String>? onSaved;
  final bool required;
  final Widget? prefix;

  @override
  Widget build(BuildContext context) {
    final config = context.watch<SegmentConfigProvider>();
    final field = config.getField(fieldKey);
    final masks = config.getMasks(fieldKey);

    return CupertinoTextFormFieldRow(
      prefix: prefix ?? Text(config.label(fieldKey)),
      initialValue: initialValue,
      placeholder: field?.placeholder,
      keyboardType: config.getKeyboardType(fieldKey),
      textCapitalization: config.getTextCapitalization(fieldKey),
      textAlign: TextAlign.right,
      inputFormatters: masks.isNotEmpty
          ? [TextInputMask(mask: masks.length == 1 ? masks.first : masks)]
          : null,
      onSaved: onSaved,
      validator: required
          ? (val) => val == null || val.isEmpty ? context.l10n.required : null
          : null,
    );
  }
}
```

## Uso nos Formulários

### Telefone

```dart
// company_form_screen.dart
PhoneField(
  fieldKey: 'company.phone',
  initialValue: _company?.phone,
  onSaved: (val) => _company?.phone = val,
  required: false,
),
```

### CEP (Regional)

```dart
// company_form_screen.dart
DynamicTextField(
  fieldKey: 'company.zipCode',
  initialValue: _company?.zipCode,
  onSaved: (val) => _company?.zipCode = val,
  required: true,
),
```

### Serial/IMEI (Universal ou Regional)

```dart
// device_form_screen.dart
DynamicTextField(
  fieldKey: 'device.serial',
  initialValue: _device?.serial,
  onSaved: (val) => _device?.serial = val?.toUpperCase(),
  required: true,
),
```

## Configuração no Firestore

### Segmento: Mecânica (Automotive)

```json
{
  "name": "Mecânica",
  "icon": "🚗",
  "customFields": [
    {
      "key": "device.serial",
      "type": "label",
      "labels": {
        "pt-BR": "Placa",
        "en-US": "License Plate",
        "es-ES": "Matrícula"
      }
    },
    {
      "key": "device.serial",
      "type": "text",
      "masks": ["AAA-9999", "AAA9N99"],
      "placeholder": "ABC-1234",
      "textCapitalization": "characters"
    }
  ]
}
```

### Segmento: Eletrônica (Electronics)

```json
{
  "name": "Eletrônica",
  "icon": "📱",
  "customFields": [
    {
      "key": "device.serial",
      "type": "label",
      "labels": {
        "pt-BR": "IMEI/Número de Série",
        "en-US": "IMEI/Serial Number"
      }
    },
    {
      "key": "device.serial",
      "type": "text",
      "masks": ["999999999999999"],
      "placeholder": "123456789012345",
      "keyboardType": "number"
    }
  ]
}
```

### Segmento: Global (Padrões)

```json
{
  "name": "Global",
  "customFields": [
    {
      "key": "company.zipCode",
      "type": "text",
      "labels": {
        "pt-BR": "CEP",
        "en-US": "ZIP Code",
        "es-ES": "Código Postal"
      },
      "masksByCountry": {
        "BR": ["99999-999"],
        "US": ["99999", "99999-9999"],
        "PT": ["9999-999"],
        "ES": ["99999"],
        "MX": ["99999"]
      },
      "placeholder": "12345-678"
    }
  ]
}
```

## Inicialização

```dart
// main.dart ou bootstrap_service.dart

// Ao carregar empresa
final company = await companyRepo.get(companyId);
Global.companyAggr = company.toAggr();

// Inicializar configurações
final segmentService = SegmentConfigService();
await segmentService.load(company.segment ?? 'global');
segmentService.setCountry(company.country);  // Ex: 'BR', 'US', 'PT'
segmentService.setLocale(locale);  // Ex: 'pt-BR', 'en-US'
```

## Fluxo de Decisão

```
┌─────────────────────────────────────────┐
│ Campo é telefone?                       │
└─────────────────────────────────────────┘
        │
        ├─ SIM → PhoneField → phone_numbers_parser
        │                     (validação real)
        │
        └─ NÃO → DynamicTextField
                   │
                   ├─ getField(fieldKey)
                   │   ├─ field.masks? → Usa (universal)
                   │   ├─ field.masksByCountry[country]? → Usa (regional)
                   │   └─ [] → Campo livre (sem máscara)
                   │
                   └─ Renderiza CupertinoTextFormFieldRow
```

## Exemplos Práticos

### Cenário 1: Mecânica no Brasil

```
company.country = 'BR'
company.segment = 'automotive'

device.serial:
  → getField('device.serial').masks = ['AAA-9999', 'AAA9N99']
  → Resultado: Placa Mercosul brasileira

company.phone:
  → PhoneField com country='BR'
  → phone_numbers_parser valida com +55
  → Resultado: (11) 98765-4321

company.zipCode:
  → getField('company.zipCode').masksByCountry['BR']
  → Resultado: 12345-678
```

### Cenário 2: Eletrônica em Portugal

```
company.country = 'PT'
company.segment = 'electronics'

device.serial:
  → getField('device.serial').masks = ['999999999999999']
  → Resultado: 123456789012345 (IMEI universal)

company.phone:
  → PhoneField com country='PT'
  → phone_numbers_parser valida com +351
  → Resultado: 912 345 678

company.zipCode:
  → getField('company.zipCode').masksByCountry['PT']
  → Resultado: 1234-567
```

### Cenário 3: Segmento sem configuração

```
company.segment = 'other'
device.serial não configurado

device.serial:
  → getField('device.serial') = null
  → getMasks('device.serial') = []
  → Resultado: Campo livre, sem máscara (aceita qualquer texto)
```

## Dependências

```yaml
# pubspec.yaml
dependencies:
  phone_numbers_parser: ^9.0.18  # Validação de telefone
  easy_mask: ^2.0.1              # Máscaras customizadas
```

## Benefícios

✅ **Telefone**: Validação real, não apenas formato
✅ **Flexível**: Customização por segmento
✅ **Escalável**: Novos campos sem alterar código
✅ **i18n**: Labels e placeholders traduzidos
✅ **Simples**: Uso de 1 linha nos formulários
✅ **Fallback**: Campo livre se não configurado
✅ **Universal vs Regional**: Facilita configuração

## Próximos Passos

1. ✅ Adicionar `country` ao modelo `Company`
2. ✅ Expandir `CustomField` com `masks` e `masksByCountry`
3. ✅ Implementar métodos no `SegmentConfigService`
4. ✅ Criar widgets `PhoneField` e `DynamicTextField`
5. ✅ Migrar formulários existentes
6. ✅ Configurar segmentos no Firestore
7. ✅ Adicionar testes unitários

## Referências

- [phone_numbers_parser](https://pub.dev/packages/phone_numbers_parser) - Validação de telefone
- [easy_mask](https://pub.dev/packages/easy_mask) - Máscaras customizadas
- [SEGMENT_CUSTOM_FIELDS.md](./SEGMENT_CUSTOM_FIELDS.md) - Labels customizados
- [I18N.md](./I18N.md) - Sistema de internacionalização
