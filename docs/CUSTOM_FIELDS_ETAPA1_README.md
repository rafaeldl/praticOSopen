# Etapa 1: Labels Dinâmicos - Implementação Completa ✅

## O que foi implementado

Sistema de labels dinâmicos que permite customizar a terminologia do app de acordo com o segmento da empresa.

### Arquivos Criados

```
lib/
├── models/
│   └── custom_field.dart                    ✅ Model para customFields
├── services/
│   └── segment_config_service.dart          ✅ Serviço que carrega labels
├── providers/
│   └── segment_config_provider.dart         ✅ Provider para widgets
├── constants/
│   └── label_keys.dart                      ✅ Keys type-safe
└── scripts/
    └── seed_segments.dart                   ✅ Script de seed

docs/
├── CUSTOM_FIELDS_LABELS.md                  ✅ Documentação completa
└── CUSTOM_FIELDS_ETAPA1_README.md           ✅ Este arquivo
```

### Arquivos Modificados

```
lib/
├── main.dart                                ✅ Adicionado SegmentConfigProvider
└── screens/
    └── auth_wrapper.dart                    ✅ Carrega segmento na inicialização
```

---

## Como Funciona

### 1. Estrutura no Firestore

```javascript
// segments/automotive
{
  id: "automotive",
  name: "Oficina Mecânica",
  icon: "🚗",
  customFields: [
    {
      key: "device._entity",
      type: "label",
      labels: {
        "pt-BR": "Veículo",
        "en-US": "Vehicle"
      }
    },
    {
      key: "device.brand",
      type: "label",
      labels: {
        "pt-BR": "Montadora",
        "en-US": "Manufacturer"
      }
    }
  ]
}
```

### 2. Fluxo de Inicialização

```
1. App inicia (main.dart)
   ↓
2. Cria SegmentConfigProvider no MultiProvider
   ↓
3. Usuário faz login
   ↓
4. AuthWrapper verifica se tem empresa
   ↓
5. _SegmentLoader busca o segmentId da empresa
   ↓
6. Inicializa SegmentConfigProvider com segmentId
   ↓
7. SegmentConfigService.load() busca customFields do Firestore
   ↓
8. Parse: type="label" → cache de labels
   ↓
9. NavigationController é exibido
   ↓
10. Widgets podem usar labels dinâmicos!
```

### 3. Como Usar nos Widgets

```dart
// Importar
import 'package:provider/provider.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/constants/label_keys.dart';

// No build()
@override
Widget build(BuildContext context) {
  final config = context.watch<SegmentConfigProvider>();

  return Scaffold(
    appBar: AppBar(
      // "Veículos" ou "Equipamentos" ou "Aparelhos"
      title: Text(config.devicePlural),
    ),
    body: Column(
      children: [
        // Usando atalhos
        Text(config.device),           // "Veículo"
        Text(config.customer),          // "Cliente"

        // Usando label genérico
        Text(config.label('device.brand')), // "Montadora"

        // Usando constants type-safe
        Text(config.label(LabelKeys.deviceSerialNumber)), // "Placa"
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () {},
      // "Adicionar Veículo"
      label: Text(config.label(LabelKeys.createDevice)),
    ),
  );
}
```

---

## Próximos Passos

### Antes de Testar

1. **Popular segments no Firestore:**
   ```bash
   cd firebase/scripts
   npm run seed-segments
   # Ou com service account customizado:
   npm run seed-segments /caminho/para/service-account.json
   ```

2. **Garantir que empresas têm campo `segment`:**
   ```javascript
   // companies/{companyId}
   {
     name: "Clima Técnica",
     segment: "hvac",  // ← Necessário!
     // ...
   }
   ```

### Refatoração de Telas (Próxima Tarefa)

Telas que precisam ser refatoradas para usar labels dinâmicos:

- [ ] `lib/screens/devices/` - Todas as telas de dispositivos
- [ ] `lib/screens/customers/` - Telas de clientes
- [ ] `lib/screens/service_orders/` - Telas de OS
- [ ] Qualquer lugar com "Dispositivo", "Marca", "Modelo", etc hardcoded

**Exemplo de refatoração:**

```dart
// ANTES
Text('Dispositivos')
Text('Marca')
ElevatedButton(
  child: Text('Adicionar Dispositivo'),
  onPressed: () {},
)

// DEPOIS
final config = context.watch<SegmentConfigProvider>();

Text(config.devicePlural)
Text(config.label(LabelKeys.deviceBrand))
ElevatedButton(
  child: Text(config.label(LabelKeys.createDevice)),
  onPressed: () {},
)
```

---

## Etapa 2: Campos Customizados (Futuro)

Após completar a refatoração dos labels, a Etapa 2 incluirá:

1. **CustomFieldBuilder Widget** - Renderiza campos dinamicamente
2. **Integração em DeviceFormScreen** - Adiciona campos extras ao form
3. **Persistência** - Salva `customData` no Firestore
4. **Validações** - required, min, max, pattern, etc

---

## Debugging

### Verificar se o segmento foi carregado

```dart
final config = context.read<SegmentConfigProvider>();
print('Segmento carregado: ${config.segmentId}');
print('Device label: ${config.device}');
```

### Logs no console

O `_SegmentLoader` deve mostrar:
- Loading enquanto carrega
- Erro se falhar
- NavigationController quando sucesso

### Problemas Comuns

| Problema | Causa | Solução |
|----------|-------|---------|
| "Empresa sem segmento definido" | Campo `segment` não existe | Adicionar via onboarding ou Firebase Console |
| Labels não mudam | Usando strings hardcoded | Usar `config.label()` |
| `segmentId` é null | Provider não inicializou | Verificar AuthWrapper |

---

## Labels Disponíveis (Defaults)

Caso não haja override no segmento, estes são os labels padrão:

### Entidades
- `device._entity` → "Dispositivo"
- `device._entity_plural` → "Dispositivos"
- `customer._entity` → "Cliente"
- `customer._entity_plural` → "Clientes"

### Campos de Device
- `device.brand` → "Marca"
- `device.model` → "Modelo"
- `device.serialNumber` → "Número de Série"
- `device.description` → "Descrição"

### Ações
- `actions.create_device` → "Adicionar Dispositivo"
- `actions.edit_device` → "Editar Dispositivo"
- `actions.delete_device` → "Excluir Dispositivo"

### Status
- `status.pending` → "Pendente"
- `status.in_progress` → "Em Andamento"
- `status.completed` → "Concluído"

Veja `lib/services/segment_config_service.dart` para lista completa.

---

## Segmentos Pré-configurados

O script de seed cria 6 segmentos:

| ID | Nome | Icon | Labels Customizados |
|----|------|------|---------------------|
| `automotive` | Oficina Mecânica | 🚗 | Veículo, Montadora, Placa |
| `hvac` | Ar Condicionado | ❄️ | Equipamento |
| `smartphones` | Celulares | 📱 | Aparelho, Fabricante, IMEI |
| `computers` | Informática | 💻 | Computador |
| `appliances` | Eletrodomésticos | 🔌 | Eletrodoméstico |
| `other` | Outro | 🔧 | (usa defaults) |

---

## Suporte a i18n (Preparado para o Futuro)

O sistema já está preparado para múltiplos idiomas:

```dart
// Trocar idioma
await segmentConfigProvider.setLocale('en-US');

// Labels automaticamente mudam para inglês
// "Veículo" → "Vehicle"
// "Montadora" → "Manufacturer"
```

---

**Status:** ✅ Etapa 1 Completa
**Próximo:** Refatorar telas existentes para usar labels dinâmicos
**Depois:** Etapa 2 - Campos Customizados
