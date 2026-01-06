# Sistema de Labels Dinâmicos e Campos Customizados

## 1. Visão Geral

Sistema unificado que permite:
- **Customizar labels** do sistema por segmento (ex: "Dispositivo" → "Veículo")
- **Adicionar campos extras** específicos por segmento (ex: Placa, Quilometragem)
- **Suporte a i18n** (múltiplos idiomas) desde o design

### 1.1 Problema que Resolve

Diferentes ramos de negócio usam terminologias diferentes:

| Segmento | "Dispositivo" é chamado de | "Número de Série" é |
|----------|----------------------------|---------------------|
| HVAC | Equipamento | Número de Série |
| Automotivo | Veículo | Placa |
| Celulares | Aparelho | IMEI |
| Informática | Computador | Serial |

Além disso, cada segmento precisa de **campos específicos**:
- Automotivo: Ano, Quilometragem, Chassi
- HVAC: BTUs, Voltagem, Tipo de Gás
- Celulares: Armazenamento, Cor, Saúde da Bateria

---

## 2. Arquitetura

### 2.1 Estrutura no Firestore

```javascript
// segments/{segmentId}
{
  id: "automotive",
  name: "Oficina Mecânica",
  icon: "🚗",
  active: true,

  customFields: [
    // ══════════════════════════════════════════════
    // LABELS (type: "label") - Apenas tradução
    // ══════════════════════════════════════════════
    {
      key: "device._entity",
      type: "label",
      labels: {
        "pt-BR": "Veículo",
        "en-US": "Vehicle",
        "es-ES": "Vehículo"
      }
    },
    {
      key: "device.brand",
      type: "label",
      labels: {
        "pt-BR": "Montadora",
        "en-US": "Manufacturer"
      }
    },

    // ══════════════════════════════════════════════
    // CAMPOS (type: "text|number|select|date")
    // ══════════════════════════════════════════════
    {
      key: "device.year",
      type: "number",
      labels: {
        "pt-BR": "Ano",
        "en-US": "Year"
      },
      required: true,
      min: 1900,
      max: 2030
    },
    {
      key: "device.mileage",
      type: "number",
      labels: {
        "pt-BR": "Quilometragem",
        "en-US": "Mileage"
      },
      suffix: "km"
    }
  ]
}
```

### 2.2 Namespaces (Padrão de Keys)

| Namespace | Uso | Exemplo |
|-----------|-----|---------|
| `device.*` | Campos/labels de dispositivos | `device._entity`, `device.brand`, `device.year` |
| `customer.*` | Campos/labels de clientes | `customer._entity`, `customer.name` |
| `service_order.*` | Campos/labels de OS | `service_order._entity` |
| `actions.*` | Labels de ações | `actions.create_device` |
| `status.*` | Labels de status | `status.pending`, `status.in_progress` |
| `common.*` | Labels comuns | `common.save`, `common.cancel` |

**Convenções:**
- `_entity` → Singular da entidade (ex: "Veículo")
- `_entity_plural` → Plural da entidade (ex: "Veículos")
- Campos padrão do sistema → mesmo nome (ex: `device.brand`)
- Campos customizados → nomes descritivos (ex: `device.year`, `device.mileage`)

### 2.3 Tipos de CustomField

| Tipo | Uso | Exemplo |
|------|-----|---------|
| `label` | Apenas tradução (não aparece como campo) | Override de "Marca" → "Montadora" |
| `text` | Campo de texto | Nome, Descrição, Cor |
| `number` | Campo numérico | Ano, Quilometragem, BTUs |
| `select` | Lista de opções | Voltagem (110V/220V), Armazenamento |
| `date` | Data | Data de Instalação, Data de Fabricação |
| `datetime` | Data e hora | Última Manutenção |
| `boolean` | Sim/Não | Garantia ativa? |

### 2.4 Propriedades de Validação

| Propriedade | Tipos | Descrição |
|-------------|-------|-----------|
| `required` | Todos | Campo obrigatório |
| `min` | number | Valor mínimo |
| `max` | number | Valor máximo |
| `minLength` | text | Tamanho mínimo |
| `maxLength` | text | Tamanho máximo |
| `pattern` | text | Regex para validação |
| `options` | select | Lista de opções |
| `suffix` | text, number | Sufixo (ex: "km", "%") |
| `prefix` | text, number | Prefixo (ex: "R$") |
| `placeholder` | text, number | Texto de exemplo |

---

## 3. Fluxo de Dados

```
1. App inicia
   ↓
2. Usuário faz login
   ↓
3. Carrega empresa do usuário
   ↓
4. Obtém segmentId da empresa
   ↓
5. SegmentConfigProvider.init(segmentId)
   ↓
6. SegmentConfigService.load(segmentId)
   ↓
7. Busca segments/{segmentId} no Firestore
   ↓
8. Parse customFields:
   - type: "label" → Cache de labels
   - outros types → Lista de custom fields
   ↓
9. Widgets usam:
   - provider.l(key) para labels
   - provider.fieldsFor('device') para campos customizados
```

---

## 4. Implementação

### 4.1 Etapa 1: Labels Dinâmicos

**Objetivo:** Trocar labels do sistema baseado no segmento.

**Arquivos:**
```
lib/
├── models/
│   └── custom_field.dart
├── services/
│   └── segment_config_service.dart
├── providers/
│   └── segment_config_provider.dart
└── constants/
    └── label_keys.dart
```

**Uso:**
```dart
// Antes
Text('Dispositivos')

// Depois
final config = context.watch<SegmentConfigProvider>();
Text(config.devicePlural) // "Veículos" ou "Equipamentos"
```

### 4.2 Etapa 2: Campos Customizados

**Objetivo:** Renderizar campos extras nas telas.

**Arquivos:**
```
lib/
├── widgets/
│   └── custom_field_builder.dart
└── screens/devices/
    └── device_form_screen.dart
```

**Uso:**
```dart
final customFields = config.fieldsFor('device');

...customFields.map((field) => CustomFieldBuilder(
  field: field,
  value: formData[field.key],
  onChanged: (v) => setState(() => formData[field.key] = v),
))
```

---

## 5. Exemplos de Configuração

### 5.1 Automotivo

```javascript
{
  id: "automotive",
  name: "Oficina Mecânica",
  icon: "🚗",
  customFields: [
    // Labels
    {"key": "device._entity", "type": "label", "labels": {"pt-BR": "Veículo", "en-US": "Vehicle"}},
    {"key": "device._entity_plural", "type": "label", "labels": {"pt-BR": "Veículos", "en-US": "Vehicles"}},
    {"key": "device.brand", "type": "label", "labels": {"pt-BR": "Montadora", "en-US": "Manufacturer"}},
    {"key": "device.serialNumber", "type": "label", "labels": {"pt-BR": "Placa", "en-US": "License Plate"}},

    // Campos customizados
    {"key": "device.year", "type": "number", "labels": {"pt-BR": "Ano", "en-US": "Year"}, "required": true, "min": 1900, "max": 2030},
    {"key": "device.mileage", "type": "number", "labels": {"pt-BR": "Quilometragem", "en-US": "Mileage"}, "suffix": "km"},
    {"key": "device.color", "type": "text", "labels": {"pt-BR": "Cor", "en-US": "Color"}},
    {"key": "device.chassis", "type": "text", "labels": {"pt-BR": "Chassi", "en-US": "Chassis"}, "maxLength": 17}
  ]
}
```

### 5.2 HVAC

```javascript
{
  id: "hvac",
  name: "Ar Condicionado / Refrigeração",
  icon: "❄️",
  customFields: [
    // Labels
    {"key": "device._entity", "type": "label", "labels": {"pt-BR": "Equipamento", "en-US": "Equipment"}},
    {"key": "device._entity_plural", "type": "label", "labels": {"pt-BR": "Equipamentos", "en-US": "Equipment"}},

    // Campos customizados
    {"key": "device.btus", "type": "select", "labels": {"pt-BR": "BTUs", "en-US": "BTUs"}, "required": true, "options": ["7000", "9000", "12000", "18000", "24000", "30000"]},
    {"key": "device.voltage", "type": "select", "labels": {"pt-BR": "Voltagem", "en-US": "Voltage"}, "required": true, "options": ["110V", "220V", "Bifásico"]},
    {"key": "device.gasType", "type": "select", "labels": {"pt-BR": "Tipo de Gás", "en-US": "Gas Type"}, "options": ["R-22", "R-410A", "R-32", "R-134a"]}
  ]
}
```

### 5.3 Smartphones

```javascript
{
  id: "smartphones",
  name: "Assistência Técnica - Celulares",
  icon: "📱",
  customFields: [
    // Labels
    {"key": "device._entity", "type": "label", "labels": {"pt-BR": "Aparelho", "en-US": "Device"}},
    {"key": "device._entity_plural", "type": "label", "labels": {"pt-BR": "Aparelhos", "en-US": "Devices"}},
    {"key": "device.brand", "type": "label", "labels": {"pt-BR": "Fabricante", "en-US": "Manufacturer"}},
    {"key": "device.serialNumber", "type": "label", "labels": {"pt-BR": "IMEI", "en-US": "IMEI"}},

    // Campos customizados
    {"key": "device.imei", "type": "text", "labels": {"pt-BR": "IMEI", "en-US": "IMEI"}, "required": true, "maxLength": 15, "pattern": "^[0-9]{15}$"},
    {"key": "device.storage", "type": "select", "labels": {"pt-BR": "Armazenamento", "en-US": "Storage"}, "options": ["64GB", "128GB", "256GB", "512GB", "1TB"]},
    {"key": "device.color", "type": "text", "labels": {"pt-BR": "Cor", "en-US": "Color"}},
    {"key": "device.batteryHealth", "type": "number", "labels": {"pt-BR": "Saúde da Bateria", "en-US": "Battery Health"}, "suffix": "%", "min": 0, "max": 100}
  ]
}
```

---

## 6. i18n (Internacionalização)

### 6.1 Como Funciona

Todos os labels estão dentro de `labels: {locale: texto}`:

```javascript
{
  key: "device._entity",
  type: "label",
  labels: {
    "pt-BR": "Veículo",
    "en-US": "Vehicle",
    "es-ES": "Vehículo",
    "fr-FR": "Véhicule"
  }
}
```

### 6.2 Fallback

```
Prioridade:
1. labels[locale] (ex: labels["en-US"])
2. labels["pt-BR"] (padrão)
3. key (como último recurso)
```

### 6.3 Trocar Idioma

```dart
// No app
await segmentConfigProvider.setLocale('en-US', segmentId);
```

---

## 7. Persistência de Dados

### 7.1 Device com Campos Customizados

```javascript
// companies/{companyId}/devices/{deviceId}
{
  // Campos padrão
  brand: "Toyota",
  model: "Corolla",
  serialNumber: "ABC1D23",

  // Campos customizados (flat)
  customData: {
    "device.year": 2020,
    "device.mileage": 45000,
    "device.color": "Prata",
    "device.chassis": "9BWAA05U08R123456"
  },

  createdAt: timestamp,
  updatedAt: timestamp
}
```

### 7.2 Salvando no Form

```dart
// Quando salvar o form
final data = {
  'brand': _brandController.text,
  'model': _modelController.text,
  'serialNumber': _serialController.text,

  // Custom fields
  'customData': {
    for (final field in customFields)
      field.key: formData[field.key]
  }
};

await FirebaseFirestore.instance
  .collection('companies/$companyId/devices')
  .doc(deviceId)
  .set(data);
```

---

## 8. Vantagens

| Aspecto | Benefício |
|---------|-----------|
| **Unificado** | Um só lugar para labels + campos |
| **Flexível** | Adicionar campos sem deploy |
| **Type-safe** | Enum de keys no Flutter |
| **i18n-ready** | Múltiplos idiomas desde o início |
| **Validação** | required, min, max, pattern |
| **Performance** | Cache em memória + offline do Firestore |
| **Manutenção** | Tudo junto, difícil esquecer tradução |

---

## 9. Roadmap

### Etapa 1: Labels Dinâmicos ✅ (Em Implementação)
- [x] Model CustomField
- [x] SegmentConfigService
- [x] SegmentConfigProvider
- [x] LabelKeys constants
- [ ] Seed de segments
- [ ] Integração no app
- [ ] Refatorar telas

### Etapa 2: Campos Customizados (Próxima)
- [ ] CustomFieldBuilder widget
- [ ] Integração em DeviceFormScreen
- [ ] Persistência de customData
- [ ] Testes

### Futuro
- [ ] Dashboard web para editar segments
- [ ] Validações customizadas avançadas
- [ ] Campos condicionais (if/show_when)
- [ ] Seções/abas nos forms

---

**Criado em:** Janeiro 2026
**Versão:** 1.0
**Responsável:** Equipe PráticOS
