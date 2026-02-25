# Multi-Device Orders (Múltiplos Dispositivos por OS)

> **Issue:** [#178](https://github.com/rafaeldl/praticOSopen/issues/178)
> **Status:** Implementado (Fase 1–3 + parcial 4–7)
> **Última atualização:** 2026-02-24

---

## Índice

1. [Visão Geral](#1-visão-geral)
2. [Comparativo de Mercado](#2-comparativo-de-mercado)
3. [Arquitetura Proposta](#3-arquitetura-proposta)
4. [Fluxo de Dados](#4-fluxo-de-dados)
5. [Regras de Negócio](#5-regras-de-negócio)
6. [UX: Diálogo de Seleção de Dispositivo](#6-ux-diálogo-de-seleção-de-dispositivo)
7. [Agrupamento Visual na Tela da OS](#7-agrupamento-visual-na-tela-da-os)
8. [Retrocompatibilidade e Migração](#8-retrocompatibilidade-e-migração)
9. [Impacto no Bot](#9-impacto-no-bot)
10. [Roadmap de Implementação](#10-roadmap-de-implementação)
11. [Arquivos Impactados](#11-arquivos-impactados)
12. [Melhorias de UX Implementadas](#12-melhorias-de-ux-implementadas)

---

## 1. Visão Geral

### Problema

Atualmente o PraticOS suporta **apenas 1 dispositivo por Ordem de Serviço**:

```dart
class Order extends BaseAuditCompany {
  DeviceAggr? device;  // ← Apenas 1 dispositivo
  List<OrderService>? services;
  List<OrderProduct>? products;
  // ...
}
```

Isso gera limitações práticas para diversos segmentos:

| Segmento | Cenário real | Problema atual |
|----------|-------------|----------------|
| **HVAC** | Manutenção de 3 splits no mesmo local | Técnico cria 3 OS separadas para o mesmo atendimento |
| **CFTV** | Instalação de 8 câmeras + 1 DVR | Impossível registrar todos os equipamentos numa única OS |
| **TI** | Setup de estação (monitor, PC, impressora) | Apenas 1 device pode ser vinculado |
| **Eletrônica** | Cliente traz celular + tablet para reparo | 2 OS para o mesmo cliente na mesma visita |
| **Automotiva** | Frota de 5 veículos do mesmo cliente | 5 OS individuais com dados repetidos |

### Solução

Evoluir o modelo para suportar **N dispositivos por OS**, com vínculo opcional entre devices e itens (serviços, produtos, checklists):

```dart
class Order extends BaseAuditCompany {
  List<DeviceAggr>? devices;  // ← N dispositivos
  List<OrderService>? services;
  List<OrderProduct>? products;
  // ...
}

class OrderService {
  ServiceAggr? service;
  String? deviceId;  // ← Novo: vínculo opcional ao device
  double? value;
  // ...
}
```

### Princípios de Design

1. **Zero atrito para 1 device** — OS com único dispositivo funciona exatamente como hoje
2. **Vínculo opcional** — Serviços/produtos podem existir sem device (itens "globais")
3. **Retrocompatível** — OS existentes continuam funcionando sem migração
4. **Progressivo** — Segmentos simples usam 1 device; segmentos complexos usam N

### Segmentos Beneficiados

```
┌─────────────────────────────────────────────────────────┐
│                  MULTI-DEVICE POR SEGMENTO              │
├──────────────┬──────────────────────────────────────────┤
│ Segmento     │ Caso de uso típico                      │
├──────────────┼──────────────────────────────────────────┤
│ HVAC         │ 3 splits + 1 condensadora externa       │
│ CFTV         │ 8 câmeras + DVR + monitor               │
│ TI           │ PC + monitor + impressora + nobreak      │
│ Eletrônica   │ Celular + tablet + fone Bluetooth        │
│ Automotiva   │ Frota: 5 veículos do mesmo cliente       │
│ Refrigeração │ 2 freezers + 1 câmara fria               │
│ Elétrica     │ Quadro elétrico + 3 ar-condicionados     │
│ Elevadores   │ 2 elevadores do mesmo prédio             │
│ Solar        │ 12 painéis + 1 inversor + 1 string box   │
└──────────────┴──────────────────────────────────────────┘
```

---

## 2. Comparativo de Mercado

### Tabela Resumida

| Sistema | Modelo | Multi-device por WO | Vínculo serviço→device | Vínculo form→device | Custo |
|---------|--------|---------------------|------------------------|---------------------|-------|
| **ServiceTitan** | Equipment por Location | ✅ Via Equipment | ❌ Por WO inteira | ✅ Duplica form | $$$$$ |
| **Salesforce FSL** | Asset por LineItem | ✅ AssetId por line | ✅ Nativo | ❌ Manual | $$$$$ |
| **Dynamics 365** | Incidents por WO | ✅ Via Incidents | ✅ Incident→Asset | ✅ Por Incident | $$$$ |
| **IBM Maximo** | 3 patterns | ✅ Múltiplos padrões | ✅ Task→Asset | ✅ Por Task/WO | $$$$$ |
| **Jobber** | Equipment por Customer | ⚠️ Nível customer | ❌ | ❌ | $$ |
| **Housecall Pro** | Equipment por Customer | ⚠️ Nível customer | ❌ | ❌ | $$ |
| **FieldPulse** | Equipment por Job | ✅ Lista | ❌ | ❌ | $$$ |
| **PraticOS (proposta)** | Devices inline na OS | ✅ Lista com deviceId | ✅ Opcional | ✅ Opcional | $ |

### Detalhamento por Sistema

#### 2.1 ServiceTitan

**Referência:** [ServiceTitan Equipment Management](https://www.servicetitan.com/)

ServiceTitan é o líder no mercado de field service para HVAC, encanamento e elétrica nos EUA.

**Modelo de dados:**
```
Location (endereço do cliente)
  └── Equipment[] (equipamentos instalados)
        ├── equipmentType
        ├── manufacturer
        ├── model
        ├── serialNumber
        ├── installDate
        └── warrantyExpiration

Job (ordem de serviço)
  ├── location → Location
  ├── equipment → Equipment (1 principal)
  └── tasks[]
```

**Como funciona multi-device:**
- Equipment é vinculado ao **Location** do cliente, não à job
- Uma job referencia 1 equipment como principal
- Para múltiplos equipments na mesma visita, o técnico cria **múltiplas jobs** agrupadas num mesmo **appointment**
- Forms/inspections são **duplicados** manualmente para cada equipment

**Limitações:**
- Não existe vínculo nativo line-item → equipment
- Forms precisam ser preenchidos N vezes (sem duplicação automática)
- Modelo pensado para HVAC residencial (1 unit = 1 job)

**Prós:**
- Histórico completo por equipment
- Integração com catálogo de peças por equipment type

---

#### 2.2 Salesforce Field Service (FSL)

**Referência:** [Salesforce Field Service](https://www.salesforce.com/products/field-service/)

Salesforce FSL é a solução enterprise mais flexível do mercado.

**Modelo de dados:**
```
WorkOrder
  ├── Asset? (asset principal, opcional)
  └── WorkOrderLineItem[]
        ├── AssetId? (asset específico deste line item)
        ├── Description
        ├── Quantity
        └── UnitPrice

Asset (equivalente a Device)
  ├── Name
  ├── SerialNumber
  ├── Product2Id
  ├── AccountId (cliente)
  └── LocationId
```

**Como funciona multi-device:**
- `WorkOrder` pode ter um `Asset` principal
- Cada `WorkOrderLineItem` pode ter seu **próprio `AssetId`**
- Isso permite vincular serviços específicos a assets diferentes na mesma WO
- Não existe vínculo nativo form→asset (requer customização)

**Limitações:**
- Formulários/checklists não têm vínculo nativo com Asset (precisa de custom fields)
- Complexidade de configuração alta
- Licenciamento caro (Field Service Lightning)

**Prós:**
- Modelo de dados mais próximo do que estamos propondo
- Vínculo line-item → asset é nativo
- Flexibilidade total via customização

**Relevância para PraticOS:** O modelo `WorkOrderLineItem.AssetId` é a **inspiração direta** para nosso `OrderService.deviceId`. A diferença é que no PraticOS o vínculo é opcional e inclui forms.

---

#### 2.3 Microsoft Dynamics 365 Field Service

**Referência:** [Dynamics 365 Field Service](https://dynamics.microsoft.com/field-service/)

**Modelo de dados:**
```
Work Order
  └── Work Order Incidents[]
        ├── Customer Asset → Asset
        ├── Incident Type (template de serviço)
        │     ├── Service Tasks[]
        │     ├── Products[]
        │     └── Services[]
        └── estimatedDuration

Customer Asset
  ├── Name
  ├── Category
  ├── Product → Product
  ├── Account → Customer
  └── parentAsset → Customer Asset (hierarquia)
```

**Como funciona multi-device:**
- Cada Work Order tem N **Incidents**
- Cada Incident vincula 1 **Customer Asset**
- Incident Type é um template que traz services, products e tasks predefinidos
- Isso cria um agrupamento natural: Incident = (Asset + conjunto de tarefas)

**Limitações:**
- Modelo rígido: cada incident = 1 asset (sem itens compartilhados entre assets)
- Complexidade de setup alta (Incident Types precisam ser pré-configurados)
- Não permite itens "globais" sem asset

**Prós:**
- Agrupamento forte asset ↔ tarefas
- Templates reaproveitáveis (Incident Types)
- Hierarquia de assets (parent/child)

**Relevância para PraticOS:** O conceito de Incident Type é interessante para templates de serviço por tipo de equipamento, mas nosso modelo é mais flexível ao permitir itens sem vínculo (globais).

---

#### 2.4 IBM Maximo

**Referência:** [IBM Maximo Application Suite](https://www.ibm.com/maximo)

IBM Maximo é o sistema de gestão de ativos mais robusto do mercado, voltado para indústria pesada, utilities e grandes frotas.

**3 Patterns para multi-asset:**

```
Pattern 1: Child Work Orders
──────────────────────────
Parent Work Order (manutenção geral)
  ├── Child WO 1 → Asset A (bomba #1)
  ├── Child WO 2 → Asset B (bomba #2)
  └── Child WO 3 → Asset C (válvula)

Pattern 2: Tasks dentro do WO
──────────────────────────
Work Order → Asset principal
  ├── Task 1 (inspeção bomba #1)
  ├── Task 2 (inspeção bomba #2)
  └── Task 3 (troca filtro válvula)

Pattern 3: Multi-Asset Table (MULTIASSETLOCCI)
──────────────────────────
Work Order
  ├── MULTIASSETLOCCI[0] → Asset A + Location X
  ├── MULTIASSETLOCCI[1] → Asset B + Location Y
  └── MULTIASSETLOCCI[2] → Asset C + Location Z
  (cada entrada pode ter materials e labor separados)
```

**Limitações:**
- Extremamente complexo de configurar
- Pattern 3 (multi-asset table) é pouco documentado
- Voltado para indústria, não field service SMB

**Prós:**
- 3 abordagens diferentes para cenários distintos
- Multi-asset table é a solução mais completa
- Integração com IoT e monitoramento

**Relevância para PraticOS:** Nosso modelo se aproxima de uma versão simplificada do Pattern 3 (multi-asset inline) combinado com a flexibilidade de itens sem vínculo.

---

#### 2.5 Jobber

**Referência:** [Jobber](https://getjobber.com/)

Voltado para pequenas empresas de field service.

**Modelo de dados:**
```
Client (cliente)
  └── Equipment[] (equipamentos do cliente)
        ├── name
        ├── make
        ├── model
        └── serialNumber

Job (ordem de serviço)
  ├── client → Client
  ├── lineItems[] (sem vínculo com equipment)
  └── notes
```

**Como funciona:**
- Equipment é registrado no **nível do cliente**, não da job
- Não existe vínculo line-item → equipment
- Técnico referencia equipment nas notas/observações
- Simples e funcional para operações básicas

**Limitações:**
- Sem vínculo formal device ↔ serviço
- Sem multi-device por job (apenas referência textual)
- Sem forms/checklists vinculados a equipment

---

#### 2.6 Housecall Pro

**Referência:** [Housecall Pro](https://www.housecallpro.com/)

Similar ao Jobber, voltado para SMB.

**Modelo:**
- Equipment vinculado ao customer
- Jobs referenciam customer (não equipment diretamente)
- Sem vínculo line-item → equipment
- Modelo flat sem agrupamento

---

#### 2.7 Análise Comparativa: Onde o PraticOS se Posiciona

```
Complexidade do modelo
     ▲
     │
     │  IBM Maximo ●
     │                    ● Dynamics 365
     │
     │              ● Salesforce FSL
     │
     │         ● ServiceTitan
     │
     │    ● PraticOS (proposta) ←── Sweet spot
     │
     │  ● FieldPulse
     │  ● Jobber
     │  ● Housecall Pro
     │
     └────────────────────────────────────► Flexibilidade multi-device
           Nenhuma    Básica    Completa
```

**Posicionamento do PraticOS:**

O modelo proposto atinge um **sweet spot** entre simplicidade e poder:

1. **Mais simples que Salesforce/Dynamics:** Não requer configuração de Incident Types ou objetos custom
2. **Mais poderoso que Jobber/Housecall:** Vínculo formal device ↔ service/product/form
3. **Flexível como Maximo Pattern 3:** Multi-device inline com vínculo opcional
4. **Zero atrito para 1 device:** Experiência idêntica ao modelo atual

O diferencial é o **`deviceId` opcional**: itens podem existir sem device (globais) ou com device (vinculados), eliminando a rigidez de modelos como Dynamics 365 onde todo item precisa de um Incident/Asset.

---

## 3. Arquitetura Proposta

### 3.1 Modelo de Dados

#### Mudanças no Order

```dart
// ANTES (modelo atual)
class Order extends BaseAuditCompany {
  CustomerAggr? customer;
  DeviceAggr? device;           // ← 1 dispositivo
  List<OrderService>? services;
  List<OrderProduct>? products;
  List<OrderPhoto>? photos;
  double? total;
  String? status;
  int? number;
  // ...
}

// DEPOIS (modelo proposto)
class Order extends BaseAuditCompany {
  CustomerAggr? customer;
  @Deprecated('Use devices instead')
  DeviceAggr? device;           // ← Mantido para retrocompatibilidade (leitura)
  List<DeviceAggr>? devices;    // ← NOVO: N dispositivos
  List<OrderService>? services;
  List<OrderProduct>? products;
  List<OrderPhoto>? photos;
  double? total;
  String? status;
  int? number;
  // ...

  /// Retorna devices da OS. Lê de `devices` se disponível,
  /// senão faz fallback para `device` (retrocompatibilidade).
  List<DeviceAggr> get effectiveDevices {
    if (devices != null && devices!.isNotEmpty) return devices!;
    if (device != null) return [device!];
    return [];
  }

  /// Indica se a OS tem múltiplos dispositivos
  bool get isMultiDevice => effectiveDevices.length > 1;
}
```

#### Mudanças no OrderAggr

```dart
// ANTES
class OrderAggr extends BaseAuditCompanyAggr {
  CustomerAggr? customer;
  DeviceAggr? device;
}

// DEPOIS
class OrderAggr extends BaseAuditCompanyAggr {
  CustomerAggr? customer;
  DeviceAggr? device;           // Mantido (retrocompatibilidade)
  List<DeviceAggr>? devices;    // NOVO

  /// Primeiro device (para exibição em listas)
  DeviceAggr? get primaryDevice =>
    devices?.isNotEmpty == true ? devices!.first : device;

  /// Contagem de devices
  int get deviceCount {
    if (devices != null && devices!.isNotEmpty) return devices!.length;
    if (device != null) return 1;
    return 0;
  }
}
```

#### Mudanças no OrderService

```dart
// ANTES
class OrderService {
  ServiceAggr? service;
  String? description;
  double? value;
  String? photo;
}

// DEPOIS
class OrderService {
  ServiceAggr? service;
  String? description;
  double? value;
  String? photo;
  String? deviceId;    // ← NOVO: ID do device vinculado (opcional)
}
```

#### Mudanças no OrderProduct

```dart
// ANTES
class OrderProduct {
  ProductAggr? product;
  String? description;
  double? value;
  int? quantity;
  double? total;
  String? photo;
}

// DEPOIS
class OrderProduct {
  ProductAggr? product;
  String? description;
  double? value;
  int? quantity;
  double? total;
  String? photo;
  String? deviceId;    // ← NOVO: ID do device vinculado (opcional)
}
```

#### Mudanças no OrderForm

```dart
// ANTES
class OrderForm {
  String id;
  String formDefinitionId;
  String title;
  FormStatus status;
  List<FormItemDefinition> items;
  List<FormResponse> responses;
  // ...
}

// DEPOIS
class OrderForm {
  String id;
  String formDefinitionId;
  String title;
  FormStatus status;
  List<FormItemDefinition> items;
  List<FormResponse> responses;
  String? deviceId;    // ← NOVO: ID do device vinculado (opcional)
  // ...
}
```

### 3.2 Diagrama de Relacionamentos

```
┌─────────────────────────────────────────────────────────────────┐
│                          Order                                  │
│                                                                 │
│  devices: [DeviceAggr]                                          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                      │
│  │ Device A │  │ Device B │  │ Device C │                      │
│  │ id: "d1" │  │ id: "d2" │  │ id: "d3" │                      │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘                      │
│       │              │              │                            │
│  ┌────┼──────────────┼──────────────┼────────────────────┐      │
│  │    │   services   │              │                    │      │
│  │    │              │              │                    │      │
│  │  ┌─▼──────────┐ ┌▼───────────┐ ┌▼───────────┐       │      │
│  │  │ Limpeza    │ │ Instalação │ │ Config.    │       │      │
│  │  │ deviceId:  │ │ deviceId:  │ │ deviceId:  │       │      │
│  │  │  "d1"      │ │  "d2"      │ │  "d3"      │       │      │
│  │  └────────────┘ └────────────┘ └────────────┘       │      │
│  │                                                      │      │
│  │  ┌────────────┐                                      │      │
│  │  │ Deslocam.  │  ← deviceId: null (item global)     │      │
│  │  │ deviceId:  │                                      │      │
│  │  │  null      │                                      │      │
│  │  └────────────┘                                      │      │
│  └──────────────────────────────────────────────────────┘      │
│                                                                 │
│  ┌──────────────────────────────────────────────────────┐      │
│  │    products                                           │      │
│  │  ┌────────────┐ ┌────────────┐ ┌────────────┐       │      │
│  │  │ Filtro     │ │ Cabo HDMI  │ │ Parafusos  │       │      │
│  │  │ deviceId:  │ │ deviceId:  │ │ deviceId:  │       │      │
│  │  │  "d1"      │ │  "d2"      │ │  null      │       │      │
│  │  └────────────┘ └────────────┘ └────────────┘       │      │
│  └──────────────────────────────────────────────────────┘      │
│                                                                 │
│  ┌──────────────────────────────────────────────────────┐      │
│  │    forms (subcollection)                              │      │
│  │  ┌────────────┐ ┌────────────┐                       │      │
│  │  │ Checklist  │ │ Checklist  │                       │      │
│  │  │ Split A    │ │ Split B    │                       │      │
│  │  │ deviceId:  │ │ deviceId:  │                       │      │
│  │  │  "d1"      │ │  "d2"      │                       │      │
│  │  └────────────┘ └────────────┘                       │      │
│  └──────────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────────┘
```

### 3.3 Estrutura Firestore

O path dos documentos **não muda**. A mudança é no conteúdo do documento:

```
/companies/{companyId}/orders/{orderId}
```

#### Documento atual (1 device)

```json
{
  "number": 1042,
  "status": "pending",
  "customer": {
    "id": "cust_abc",
    "name": "João Silva"
  },
  "device": {
    "id": "dev_001",
    "name": "Split Samsung 12000 BTUs",
    "serial": "SM-12K-2024"
  },
  "services": [
    {
      "service": { "id": "svc_01", "name": "Limpeza", "value": 150.0 },
      "value": 150.0
    }
  ],
  "products": [
    {
      "product": { "id": "prd_01", "name": "Filtro", "value": 45.0 },
      "value": 45.0,
      "quantity": 1,
      "total": 45.0
    }
  ],
  "total": 195.0
}
```

#### Documento novo (N devices)

```json
{
  "number": 1043,
  "status": "pending",
  "customer": {
    "id": "cust_abc",
    "name": "João Silva"
  },
  "device": {
    "id": "dev_001",
    "name": "Split Samsung 12000 BTUs",
    "serial": "SM-12K-2024"
  },
  "devices": [
    {
      "id": "dev_001",
      "name": "Split Samsung 12000 BTUs",
      "serial": "SM-12K-2024"
    },
    {
      "id": "dev_002",
      "name": "Split LG 9000 BTUs",
      "serial": "LG-9K-2023"
    },
    {
      "id": "dev_003",
      "name": "Condensadora Samsung",
      "serial": "SM-COND-2024"
    }
  ],
  "services": [
    {
      "service": { "id": "svc_01", "name": "Limpeza", "value": 150.0 },
      "value": 150.0,
      "deviceId": "dev_001"
    },
    {
      "service": { "id": "svc_01", "name": "Limpeza", "value": 150.0 },
      "value": 150.0,
      "deviceId": "dev_002"
    },
    {
      "service": { "id": "svc_02", "name": "Deslocamento", "value": 80.0 },
      "value": 80.0,
      "deviceId": null
    }
  ],
  "products": [
    {
      "product": { "id": "prd_01", "name": "Filtro", "value": 45.0 },
      "value": 45.0,
      "quantity": 1,
      "total": 45.0,
      "deviceId": "dev_001"
    },
    {
      "product": { "id": "prd_01", "name": "Filtro", "value": 45.0 },
      "value": 45.0,
      "quantity": 1,
      "total": 45.0,
      "deviceId": "dev_002"
    },
    {
      "product": { "id": "prd_02", "name": "Parafusos", "value": 5.0 },
      "value": 5.0,
      "quantity": 10,
      "total": 50.0,
      "deviceId": null
    }
  ],
  "total": 520.0
}
```

**Observações:**
- O campo `device` (singular) é mantido para **retrocompatibilidade** com leituras antigas
- O campo `device` sempre espelha `devices[0]` quando `devices` existe
- O campo `deviceId` em services/products é `null` para itens globais
- Forms (subcollection) ganham `deviceId` no documento da instância

#### Subcollection de Forms

```
/companies/{companyId}/orders/{orderId}/forms/{formInstanceId}
```

```json
{
  "formDefinitionId": "form_checklist_split",
  "title": "Checklist de Manutenção",
  "status": "pending",
  "deviceId": "dev_001",
  "items": [...],
  "responses": [...]
}
```

---

## 4. Fluxo de Dados

### 4.1 Diagrama Geral

```
┌──────────────────────────────────────────────────────────┐
│                      FIREBASE                            │
│                                                          │
│  /companies/{id}/orders/{id}                             │
│    ├── devices: [DeviceAggr]                             │
│    ├── services: [{..., deviceId}]                       │
│    ├── products: [{..., deviceId}]                       │
│    └── /forms/{id}: {deviceId, ...}                      │
└────────────────────┬─────────────────────────────────────┘
                     │
                     ▼
┌──────────────────────────────────────────────────────────┐
│                   REPOSITORY                             │
│                                                          │
│  OrderRepository (TenantRepository<Order>)               │
│    ├── fromJson(): lê devices + fallback device          │
│    ├── toJson(): grava devices + device (compat)         │
│    └── save/update/delete (sem mudanças)                 │
│                                                          │
│  OrderFormRepository                                     │
│    └── fromJson/toJson: inclui deviceId                  │
└────────────────────┬─────────────────────────────────────┘
                     │
                     ▼
┌──────────────────────────────────────────────────────────┐
│                   STORE (MobX)                           │
│                                                          │
│  OrderStore                                              │
│    ├── @observable order: Order                           │
│    │                                                     │
│    ├── @computed servicesByDevice                         │
│    │   → Map<String?, List<OrderService>>                │
│    │   {                                                 │
│    │     null: [deslocamento],         // globais         │
│    │     "dev_001": [limpeza, ajuste], // device A       │
│    │     "dev_002": [limpeza],         // device B       │
│    │   }                                                 │
│    │                                                     │
│    ├── @computed productsByDevice                         │
│    │   → Map<String?, List<OrderProduct>>                │
│    │                                                     │
│    ├── @computed formsByDevice                            │
│    │   → Map<String?, List<OrderForm>>                   │
│    │                                                     │
│    ├── @action addService(service, {deviceId})            │
│    ├── @action addProduct(product, {deviceId})            │
│    ├── @action addDevice(device)                          │
│    ├── @action removeDevice(deviceId)                     │
│    └── @action duplicateForAllDevices(service)            │
└────────────────────┬─────────────────────────────────────┘
                     │
                     ▼
┌──────────────────────────────────────────────────────────┐
│                   UI (Observer)                           │
│                                                          │
│  OrderDetailScreen                                       │
│    ├── DevicesSection (lista de devices com chips)        │
│    ├── ServicesSection                                    │
│    │   ├── "Geral" (deviceId == null)                    │
│    │   ├── "Split Samsung" (deviceId == "dev_001")       │
│    │   └── "Split LG" (deviceId == "dev_002")            │
│    ├── ProductsSection (mesmo agrupamento)                │
│    └── FormsSection (mesmo agrupamento)                   │
│                                                          │
│  AddServiceFlow                                          │
│    ├── Se 1 device → sem diálogo extra                   │
│    └── Se N devices → DevicePickerSheet                  │
└──────────────────────────────────────────────────────────┘
```

### 4.2 Computed Properties no MobX

O agrupamento por device acontece via computed properties reativas:

```dart
abstract class _OrderStore with Store {
  @observable
  Order? order;

  @observable
  ObservableList<OrderForm> forms = ObservableList<OrderForm>();

  /// Agrupa serviços por deviceId.
  /// Chave null = itens globais (sem device vinculado).
  @computed
  Map<String?, List<OrderService>> get servicesByDevice {
    final map = <String?, List<OrderService>>{};
    for (final service in order?.services ?? []) {
      map.putIfAbsent(service.deviceId, () => []).add(service);
    }
    return map;
  }

  /// Agrupa produtos por deviceId.
  @computed
  Map<String?, List<OrderProduct>> get productsByDevice {
    final map = <String?, List<OrderProduct>>{};
    for (final product in order?.products ?? []) {
      map.putIfAbsent(product.deviceId, () => []).add(product);
    }
    return map;
  }

  /// Agrupa forms por deviceId.
  @computed
  Map<String?, List<OrderForm>> get formsByDevice {
    final map = <String?, List<OrderForm>>{};
    for (final form in forms) {
      map.putIfAbsent(form.deviceId, () => []).add(form);
    }
    return map;
  }

  /// Busca DeviceAggr pelo id.
  DeviceAggr? deviceById(String deviceId) {
    return order?.effectiveDevices.firstWhereOrNull((d) => d.id == deviceId);
  }

  /// Total por device (serviços + produtos vinculados).
  double totalForDevice(String? deviceId) {
    final services = servicesByDevice[deviceId] ?? [];
    final products = productsByDevice[deviceId] ?? [];
    return services.fold(0.0, (sum, s) => sum + (s.value ?? 0)) +
           products.fold(0.0, (sum, p) => sum + (p.total ?? 0));
  }
}
```

### 4.3 Fluxo de Adição de Serviço (com seleção de device)

```
Usuário toca "Adicionar Serviço"
          │
          ▼
    ┌─────────────┐
    │ Quantos      │
    │ devices na   │──── 0 devices ───→ Adiciona direto (deviceId = null)
    │ OS?          │
    └──────┬──────┘
           │
      1 device          2+ devices
           │                  │
           ▼                  ▼
    Adiciona direto     DevicePickerSheet
    (deviceId =         ┌──────────────────┐
     device.id)         │ Para qual device? │
                        │                  │
                        │ ○ Split Samsung  │
                        │ ○ Split LG       │
                        │ ○ Condensadora   │
                        │ ─────────────── │
                        │ ○ Todos os       │
                        │   dispositivos   │
                        │ ○ Geral (sem     │
                        │   vínculo)       │
                        └────────┬─────────┘
                                 │
                    ┌────────────┼────────────┐
                    │            │            │
               1 device    "Todos"      "Geral"
                    │            │            │
                    ▼            ▼            ▼
              Adiciona com  Duplica N    Adiciona com
              deviceId      vezes (1     deviceId = null
              selecionado   por device)
```

---

## 5. Regras de Negócio

### 5.1 Regras de Vínculo

| Regra | Descrição |
|-------|-----------|
| **RN-01** | Items sem `deviceId` (null) são **globais** — pertencem à OS como um todo |
| **RN-02** | Items com `deviceId` são **vinculados** — específicos de um dispositivo |
| **RN-03** | `deviceId` deve corresponder a um device presente em `order.devices` |
| **RN-04** | Remover um device da OS **não** remove automaticamente seus itens vinculados |
| **RN-05** | Ao remover um device, itens vinculados a ele passam para `deviceId = null` (globais) |

### 5.2 Regras de UX Condicional

| Regra | Descrição |
|-------|-----------|
| **RN-06** | OS com **0 devices** → sem diálogo de seleção, itens são globais |
| **RN-07** | OS com **1 device** → sem diálogo de seleção, itens vinculados automaticamente |
| **RN-08** | OS com **2+ devices** → exibe `DevicePickerSheet` ao adicionar item |
| **RN-09** | `DevicePickerSheet` sempre oferece opção "Geral (sem vínculo)" |
| **RN-10** | `DevicePickerSheet` sempre oferece opção "Todos os dispositivos" |

### 5.3 Regras de Duplicação ("Todos os dispositivos")

| Regra | Descrição |
|-------|-----------|
| **RN-11** | Selecionar "Todos os dispositivos" cria **N cópias** do item (1 por device) |
| **RN-12** | Cada cópia é independente — valor pode ser editado individualmente |
| **RN-13** | Para **serviços**: cria N `OrderService` com `deviceId` diferente |
| **RN-14** | Para **produtos**: cria N `OrderProduct` com `deviceId` diferente |
| **RN-15** | Para **checklists**: cria N instâncias de `OrderForm` com `deviceId` diferente |
| **RN-16** | Duplicação de checklist gera instâncias independentes (respostas separadas) |

### 5.4 Regras de Total

| Regra | Descrição |
|-------|-----------|
| **RN-17** | `order.total` = soma de **todos** os serviços + produtos (globais + vinculados) |
| **RN-18** | Total por device = soma de serviços + produtos onde `deviceId == device.id` |
| **RN-19** | Total geral = soma de serviços + produtos onde `deviceId == null` |
| **RN-20** | A visualização pode exibir subtotais por device + total global |

### 5.5 Regras de Retrocompatibilidade

| Regra | Descrição |
|-------|-----------|
| **RN-21** | Campo `device` (singular) continua sendo gravado = `devices[0]` |
| **RN-22** | Leitura: se `devices` existe, usa `devices`; senão fallback para `device` |
| **RN-23** | Items sem `deviceId` em OS antigas permanecem funcionais |
| **RN-24** | Nenhuma migration destrutiva no Firestore |

### 5.6 Exemplo Prático: HVAC

```
OS #1043 — Manutenção preventiva residencial
Cliente: João Silva
Endereço: Rua das Flores, 123

Devices:
  [1] Split Samsung 12000 BTUs  (serial: SM-12K-2024)
  [2] Split LG 9000 BTUs        (serial: LG-9K-2023)
  [3] Condensadora Samsung       (serial: SM-COND-2024)

Serviços:
  ┌─────────────────────────────────────────────┐
  │ GERAL (sem device)                          │
  │   • Deslocamento ................ R$ 80,00  │
  ├─────────────────────────────────────────────┤
  │ 🔵 Split Samsung 12000 BTUs                │
  │   • Limpeza completa ........... R$ 150,00  │
  │   • Recarga de gás ............. R$ 200,00  │
  ├─────────────────────────────────────────────┤
  │ 🔵 Split LG 9000 BTUs                      │
  │   • Limpeza completa ........... R$ 150,00  │
  ├─────────────────────────────────────────────┤
  │ 🔵 Condensadora Samsung                     │
  │   • Limpeza condensadora ....... R$ 120,00  │
  └─────────────────────────────────────────────┘

Produtos:
  ┌─────────────────────────────────────────────┐
  │ GERAL                                       │
  │   • Parafusos (10x) ........... R$ 50,00   │
  ├─────────────────────────────────────────────┤
  │ 🔵 Split Samsung                            │
  │   • Filtro anti-alérgico ....... R$ 45,00  │
  ├─────────────────────────────────────────────┤
  │ 🔵 Split LG                                 │
  │   • Filtro anti-alérgico ....... R$ 45,00  │
  └─────────────────────────────────────────────┘

Checklists:
  ┌─────────────────────────────────────────────┐
  │ 🔵 Split Samsung                            │
  │   ☑ Checklist de Manutenção — Concluído    │
  ├─────────────────────────────────────────────┤
  │ 🔵 Split LG                                 │
  │   ☐ Checklist de Manutenção — Pendente     │
  ├─────────────────────────────────────────────┤
  │ 🔵 Condensadora Samsung                     │
  │   ☐ Checklist de Condensadora — Pendente   │
  └─────────────────────────────────────────────┘

                    Subtotais por device:
                    Split Samsung:  R$ 395,00
                    Split LG:      R$ 195,00
                    Condensadora:  R$ 120,00
                    Geral:         R$ 130,00
                    ─────────────────────────
                    TOTAL:         R$ 840,00
```

---

## 6. UX: Diálogo de Seleção de Dispositivo

### 6.1 DevicePickerSheet

O `DevicePickerSheet` é um `CupertinoActionSheet` exibido quando o usuário adiciona um item (serviço, produto ou checklist) a uma OS com 2+ dispositivos.

#### Mockup ASCII

```
┌─────────────────────────────────────────┐
│                                         │
│     Para qual dispositivo?              │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │  📱 Split Samsung 12000 BTUs     │  │
│  │     SM-12K-2024                   │  │
│  ├───────────────────────────────────┤  │
│  │  📱 Split LG 9000 BTUs           │  │
│  │     LG-9K-2023                    │  │
│  ├───────────────────────────────────┤  │
│  │  📱 Condensadora Samsung          │  │
│  │     SM-COND-2024                  │  │
│  ├───────────────────────────────────┤  │
│  │  ─────────────────────────────── │  │
│  ├───────────────────────────────────┤  │
│  │  🔄 Todos os dispositivos         │  │
│  │     Duplicar para cada device     │  │
│  ├───────────────────────────────────┤  │
│  │  📋 Geral                         │  │
│  │     Sem vínculo com dispositivo   │  │
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │            Cancelar               │  │
│  └───────────────────────────────────┘  │
│                                         │
└─────────────────────────────────────────┘
```

#### Implementação (pseudo-código)

```dart
Future<DevicePickerResult?> showDevicePicker(
  BuildContext context,
  List<DeviceAggr> devices,
) async {
  return showCupertinoModalPopup<DevicePickerResult>(
    context: context,
    builder: (context) => CupertinoActionSheet(
      title: Text(context.l10n.selectDevice),
      message: Text(context.l10n.selectDeviceMessage),
      actions: [
        // Lista de devices
        ...devices.map((device) => CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(
            context,
            DevicePickerResult.single(device.id!),
          ),
          child: Column(
            children: [
              Text(device.name ?? ''),
              if (device.serial != null)
                Text(device.serial!,
                  style: TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
            ],
          ),
        )),
        // Separador visual
        // "Todos os dispositivos"
        CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(
            context,
            DevicePickerResult.all(),
          ),
          child: Text(context.l10n.allDevices),
        ),
        // "Geral"
        CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(
            context,
            DevicePickerResult.global(),
          ),
          child: Text(context.l10n.general),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        isDefaultAction: true,
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.cancel),
      ),
    ),
  );
}

/// Resultado da seleção de device
class DevicePickerResult {
  final DevicePickerType type;
  final String? deviceId;

  DevicePickerResult.single(this.deviceId) : type = DevicePickerType.single;
  DevicePickerResult.all() : deviceId = null, type = DevicePickerType.all;
  DevicePickerResult.global() : deviceId = null, type = DevicePickerType.global;
}

enum DevicePickerType { single, all, global }
```

### 6.2 Fluxo por Tipo de Item

#### Adicionando Serviço

```
[Toca "Adicionar Serviço"]
         │
         ▼
[Seleciona serviço do catálogo]
         │
         ▼
  ┌──────────────┐
  │ isMultiDevice?│─── false ──→ Adiciona com deviceId do único device
  └──────┬───────┘               (ou null se 0 devices)
         │ true
         ▼
[DevicePickerSheet]
    │         │          │
  single    "todos"    "geral"
    │         │          │
    ▼         ▼          ▼
  1 item    N items    1 item
  com       (1 por     com
  deviceId  device)    deviceId=null
```

#### Adicionando Produto

Mesmo fluxo do serviço. Ao selecionar "Todos", duplica quantidade e total individualmente.

#### Adicionando Checklist

```
[Toca "Adicionar Checklist"]
         │
         ▼
[Seleciona template de form]
         │
         ▼
  ┌──────────────┐
  │ isMultiDevice?│─── false ──→ Cria instância com deviceId do único device
  └──────┬───────┘
         │ true
         ▼
[DevicePickerSheet]
    │         │          │
  single    "todos"    "geral"
    │         │          │
    ▼         ▼          ▼
  1 form    N forms    1 form
  instance  instances  instance
  com       (1 por     com
  deviceId  device)    deviceId=null
```

**Nota sobre checklists:** Cada instância duplicada é independente — o técnico preenche cada uma separadamente. Isso é análogo ao modelo do ServiceTitan, mas com duplicação automática.

### 6.3 Comportamento Condicional

```dart
Future<void> onAddService(BuildContext context, ServiceAggr service) async {
  final order = orderStore.order!;
  final devices = order.effectiveDevices;

  String? deviceId;

  if (devices.length <= 1) {
    // 0 ou 1 device: sem diálogo, atribuição automática
    deviceId = devices.isNotEmpty ? devices.first.id : null;
    orderStore.addService(service, deviceId: deviceId);
  } else {
    // 2+ devices: exibe picker
    final result = await showDevicePicker(context, devices);
    if (result == null) return; // cancelou

    switch (result.type) {
      case DevicePickerType.single:
        orderStore.addService(service, deviceId: result.deviceId);
        break;
      case DevicePickerType.all:
        orderStore.duplicateServiceForAllDevices(service);
        break;
      case DevicePickerType.global:
        orderStore.addService(service, deviceId: null);
        break;
    }
  }
}
```

---

## 7. Agrupamento Visual na Tela da OS

### 7.1 Seção de Dispositivos

Na tela de detalhe da OS, a lista de devices aparece como chips horizontais:

```
┌─────────────────────────────────────────────────┐
│  ◀  OS #1043                          ⋯        │
├─────────────────────────────────────────────────┤
│                                                 │
│  CLIENTE                                        │
│  ┌─────────────────────────────────────────┐    │
│  │  👤 João Silva                          │    │
│  │     Rua das Flores, 123                 │    │
│  └─────────────────────────────────────────┘    │
│                                                 │
│  DISPOSITIVOS                        [+ Adicionar]│
│  ┌──────────────────┐ ┌───────────────────┐     │
│  │ Split Samsung    │ │ Split LG          │     │
│  │ SM-12K-2024      │ │ LG-9K-2023        │     │
│  └──────────────────┘ └───────────────────┘     │
│  ┌──────────────────┐                           │
│  │ Condensadora     │                           │
│  │ SM-COND-2024     │                           │
│  └──────────────────┘                           │
│                                                 │
```

### 7.2 Seção de Serviços (Agrupados)

```
│  SERVIÇOS                            [+ Adicionar]│
│                                                 │
│  ┌─────────────────────────────────────────┐    │
│  │  Geral                                  │    │
│  ├─────────────────────────────────────────┤    │
│  │  Deslocamento              R$ 80,00     │    │
│  └─────────────────────────────────────────┘    │
│                                                 │
│  ┌─────────────────────────────────────────┐    │
│  │  🔵 Split Samsung 12000 BTUs           │    │
│  ├─────────────────────────────────────────┤    │
│  │  Limpeza completa          R$ 150,00    │    │
│  │  Recarga de gás            R$ 200,00    │    │
│  ├─────────────────────────────────────────┤    │
│  │  Subtotal                  R$ 350,00    │    │
│  └─────────────────────────────────────────┘    │
│                                                 │
│  ┌─────────────────────────────────────────┐    │
│  │  🔵 Split LG 9000 BTUs                 │    │
│  ├─────────────────────────────────────────┤    │
│  │  Limpeza completa          R$ 150,00    │    │
│  ├─────────────────────────────────────────┤    │
│  │  Subtotal                  R$ 150,00    │    │
│  └─────────────────────────────────────────┘    │
│                                                 │
│  ┌─────────────────────────────────────────┐    │
│  │  🔵 Condensadora Samsung                │    │
│  ├─────────────────────────────────────────┤    │
│  │  Limpeza condensadora      R$ 120,00    │    │
│  ├─────────────────────────────────────────┤    │
│  │  Subtotal                  R$ 120,00    │    │
│  └─────────────────────────────────────────┘    │
│                                                 │
```

### 7.3 Seção de Produtos (Agrupados)

```
│  PRODUTOS                            [+ Adicionar]│
│                                                 │
│  ┌─────────────────────────────────────────┐    │
│  │  Geral                                  │    │
│  ├─────────────────────────────────────────┤    │
│  │  Parafusos (10x)          R$ 50,00      │    │
│  └─────────────────────────────────────────┘    │
│                                                 │
│  ┌─────────────────────────────────────────┐    │
│  │  🔵 Split Samsung                       │    │
│  ├─────────────────────────────────────────┤    │
│  │  Filtro anti-alérgico      R$ 45,00     │    │
│  └─────────────────────────────────────────┘    │
│                                                 │
│  ┌─────────────────────────────────────────┐    │
│  │  🔵 Split LG                            │    │
│  ├─────────────────────────────────────────┤    │
│  │  Filtro anti-alérgico      R$ 45,00     │    │
│  └─────────────────────────────────────────┘    │
│                                                 │
```

### 7.4 Seção de Checklists (Agrupados)

```
│  CHECKLISTS / VISTORIAS             [+ Adicionar]│
│                                                 │
│  ┌─────────────────────────────────────────┐    │
│  │  🔵 Split Samsung                       │    │
│  ├─────────────────────────────────────────┤    │
│  │  ☑ Checklist de Manutenção  Concluído   │    │
│  └─────────────────────────────────────────┘    │
│                                                 │
│  ┌─────────────────────────────────────────┐    │
│  │  🔵 Split LG                            │    │
│  ├─────────────────────────────────────────┤    │
│  │  ☐ Checklist de Manutenção  Pendente    │    │
│  └─────────────────────────────────────────┘    │
│                                                 │
│  ┌─────────────────────────────────────────┐    │
│  │  🔵 Condensadora Samsung                │    │
│  ├─────────────────────────────────────────┤    │
│  │  ☐ Checklist Condensadora   Pendente    │    │
│  └─────────────────────────────────────────┘    │
│                                                 │
```

### 7.5 Rodapé com Totais

```
│  ─────────────────────────────────────────────  │
│                                                 │
│  RESUMO                                         │
│  ┌─────────────────────────────────────────┐    │
│  │  Split Samsung              R$ 395,00   │    │
│  │  Split LG                  R$ 195,00    │    │
│  │  Condensadora              R$ 120,00    │    │
│  │  Geral                     R$ 130,00    │    │
│  ├─────────────────────────────────────────┤    │
│  │  TOTAL                     R$ 840,00    │    │
│  └─────────────────────────────────────────┘    │
│                                                 │
└─────────────────────────────────────────────────┘
```

### 7.6 Comportamento para 1 Device

Quando a OS tem apenas 1 device, **não exibe agrupamento** — a experiência é idêntica à atual:

```
│  SERVIÇOS                            [+ Adicionar]│
│                                                 │
│  ┌─────────────────────────────────────────┐    │
│  │  Limpeza completa          R$ 150,00    │    │
│  │  Recarga de gás            R$ 200,00    │    │
│  │  Deslocamento              R$ 80,00     │    │
│  ├─────────────────────────────────────────┤    │
│  │  Total Serviços            R$ 430,00    │    │
│  └─────────────────────────────────────────┘    │
│                                                 │
```

### 7.7 Implementação do Widget Agrupado

```dart
class GroupedByDeviceSection extends StatelessWidget {
  final Map<String?, List<dynamic>> itemsByDevice;
  final List<DeviceAggr> devices;
  final Widget Function(dynamic item) itemBuilder;
  final String title;

  @override
  Widget build(BuildContext context) {
    // Se apenas 1 device ou menos, não agrupa
    if (devices.length <= 1) {
      return _buildFlatList(context);
    }

    // Agrupa: globais primeiro, depois por device
    final sections = <Widget>[];

    // Seção "Geral" (deviceId == null)
    final globalItems = itemsByDevice[null] ?? [];
    if (globalItems.isNotEmpty) {
      sections.add(_buildDeviceGroup(
        context,
        label: context.l10n.general,
        items: globalItems,
        color: CupertinoColors.systemGrey,
      ));
    }

    // Seção por device
    for (final device in devices) {
      final items = itemsByDevice[device.id] ?? [];
      if (items.isNotEmpty) {
        sections.add(_buildDeviceGroup(
          context,
          label: device.name ?? '',
          items: items,
          color: CupertinoColors.activeBlue,
        ));
      }
    }

    return Column(children: sections);
  }
}
```

---

## 8. Retrocompatibilidade e Migração

### 8.1 Estratégia: Sem Migration Destrutiva

A abordagem é **aditiva** — novos campos são adicionados sem remover os antigos:

```
┌────────────────────────────────────────────────────────┐
│                  ESTRATÉGIA DE MIGRAÇÃO                │
├────────────────────────────────────────────────────────┤
│                                                        │
│  OS existente (campo device):                          │
│  {                                                     │
│    "device": { "id": "d1", "name": "Split Samsung" }  │
│    "services": [{ "service": {...}, "value": 150 }]   │
│  }                                                     │
│                                                        │
│         ▼  Após edição no app novo  ▼                  │
│                                                        │
│  {                                                     │
│    "device": { "id": "d1", "name": "Split Samsung" }, │
│    "devices": [                                        │
│      { "id": "d1", "name": "Split Samsung" }           │
│    ],                                                  │
│    "services": [                                       │
│      { "service": {...}, "value": 150, "deviceId": "d1" }│
│    ]                                                   │
│  }                                                     │
│                                                        │
│  ✅ device mantido (apps antigos continuam lendo)      │
│  ✅ devices adicionado (apps novos usam)               │
│  ✅ deviceId adicionado (vínculo criado)               │
│  ✅ services sem deviceId continuam funcionais         │
│                                                        │
└────────────────────────────────────────────────────────┘
```

### 8.2 Leitura com Fallback

```dart
// No fromJson do Order
factory Order.fromJson(Map<String, dynamic> json) {
  final order = _$OrderFromJson(json);

  // Fallback: se devices não existe mas device sim, cria lista
  if ((order.devices == null || order.devices!.isEmpty) && order.device != null) {
    order.devices = [order.device!];
  }

  return order;
}
```

### 8.3 Gravação com Compatibilidade

```dart
// No toJson do Order
Map<String, dynamic> toJson() {
  final json = _$OrderToJson(this);

  // Sempre grava device (singular) como devices[0] para retrocompatibilidade
  if (devices != null && devices!.isNotEmpty) {
    json['device'] = devices!.first.toJson();
  }

  return json;
}
```

### 8.4 Cenários de Migração

| Cenário | O que acontece | Ação necessária |
|---------|---------------|-----------------|
| OS antiga lida no app novo | `effectiveDevices` lê `device` como `[device]` | Nenhuma |
| OS antiga editada no app novo | `devices` é gravado, `device` atualizado | Automático |
| OS nova lida no app antigo | App antigo lê `device` (singular) normalmente | Nenhuma |
| OS nova com N devices lida no app antigo | App antigo vê apenas `device` (= devices[0]) | Limitado mas funcional |
| Services antigos sem deviceId | `deviceId` = null, tratados como globais | Nenhuma |

### 8.5 Migration Opcional (Batch)

Se necessário no futuro, uma Cloud Function pode popular `devices` em documentos existentes:

```javascript
// Cloud Function (OPCIONAL - executar apenas se necessário)
exports.migrateDeviceToDevices = functions.firestore
  .document('companies/{companyId}/orders/{orderId}')
  .onUpdate(async (change, context) => {
    const after = change.after.data();

    // Se tem device mas não devices, cria devices
    if (after.device && (!after.devices || after.devices.length === 0)) {
      await change.after.ref.update({
        devices: [after.device],
      });
    }
  });
```

**Recomendação:** Não executar batch migration. O fallback no app é suficiente e mais seguro.

---

## 9. Impacto no Bot

### 9.1 Card de OS com Múltiplos Devices

O bot WhatsApp (OpenClaw) exibe cards de OS. O card precisa acomodar múltiplos devices.

#### Card Atual (1 device)

```
📋 *OS #1043*
👤 João Silva
📱 Split Samsung 12000 BTUs
📅 24/02/2026
💰 R$ 195,00
🔵 Pendente
```

#### Card Novo (N devices)

```
📋 *OS #1043*
👤 João Silva
📱 Split Samsung 12000 BTUs (+2 dispositivos)
📅 24/02/2026
💰 R$ 840,00
🔵 Pendente
```

Ou, quando o usuário pede detalhes:

```
📋 *OS #1043 — Detalhes*
👤 João Silva

📱 *Dispositivos (3):*
  1. Split Samsung 12000 BTUs (SM-12K-2024)
  2. Split LG 9000 BTUs (LG-9K-2023)
  3. Condensadora Samsung (SM-COND-2024)

🔧 *Serviços:*
  _Geral:_
  • Deslocamento — R$ 80,00

  _Split Samsung:_
  • Limpeza completa — R$ 150,00
  • Recarga de gás — R$ 200,00

  _Split LG:_
  • Limpeza completa — R$ 150,00

  _Condensadora:_
  • Limpeza condensadora — R$ 120,00

📦 *Produtos:*
  _Geral:_
  • Parafusos (10x) — R$ 50,00

  _Split Samsung:_
  • Filtro — R$ 45,00

  _Split LG:_
  • Filtro — R$ 45,00

💰 *Total: R$ 840,00*
```

### 9.2 Fluxo de Criação via WhatsApp

O fluxo de criação de OS via bot precisa suportar múltiplos devices:

```
Bot: Qual o dispositivo/equipamento?
User: Split Samsung 12000 BTUs

Bot: ✅ Device adicionado: Split Samsung 12000 BTUs
     Deseja adicionar outro dispositivo?
     1️⃣ Sim, adicionar outro
     2️⃣ Não, continuar

User: 1

Bot: Qual o próximo dispositivo?
User: Split LG 9000 BTUs

Bot: ✅ Device adicionado: Split LG 9000 BTUs
     Deseja adicionar outro dispositivo?
     1️⃣ Sim, adicionar outro
     2️⃣ Não, continuar

User: 2

Bot: 📱 Dispositivos na OS:
     1. Split Samsung 12000 BTUs
     2. Split LG 9000 BTUs

     Agora, qual serviço deseja adicionar?
User: Limpeza

Bot: Para qual dispositivo?
     1️⃣ Split Samsung 12000 BTUs
     2️⃣ Split LG 9000 BTUs
     3️⃣ Todos os dispositivos
     4️⃣ Geral (sem vínculo)

User: 3

Bot: ✅ Serviço "Limpeza" adicionado para todos os dispositivos (2x)
```

### 9.3 Impacto nos Endpoints do Bot

| Endpoint | Mudança |
|----------|---------|
| `POST /orders` | Aceitar `devices[]` em vez de `device` |
| `GET /orders/:id` | Retornar `devices[]` + `deviceCount` |
| `POST /orders/:id/services` | Aceitar `deviceId` opcional |
| `POST /orders/:id/products` | Aceitar `deviceId` opcional |
| Card de OS (skill) | Exibir contagem de devices |
| Criação conversacional | Loop de adição de devices |

---

## 10. Roadmap de Implementação

### Fase 1: Model Layer (Foundation) — ✅ Concluída

- [x] Adicionar `devices: List<DeviceAggr>?` ao `Order`
- [x] Adicionar `effectiveDevices` getter ao `Order`
- [x] Adicionar `isMultiDevice` getter ao `Order`
- [x] Adicionar `deviceId: String?` ao `OrderService`
- [x] Adicionar `deviceId: String?` ao `OrderProduct`
- [x] Adicionar `deviceId: String?` ao `OrderForm`
- [x] Atualizar `OrderAggr` com `devices` e helpers
- [x] Executar `build_runner` para gerar `.g.dart`
- [x] Implementar `fromJson` com fallback `device → devices`
- [x] Implementar `toJson` com compatibilidade `devices[0] → device`
- [ ] Adicionar testes unitários para serialização
- [ ] Adicionar testes para retrocompatibilidade (leitura de docs antigos)

### Fase 2: Store Layer (Business Logic) — ✅ Concluída

- [x] Adicionar `@computed servicesByDevice` ao `OrderStore`
- [x] Adicionar `@computed productsByDevice` ao `OrderStore`
- [x] Adicionar `@computed formsByDevice` ao `OrderStore`
- [x] Adicionar `@action addDevice(DeviceAggr)` ao `OrderStore`
- [x] Adicionar `@action removeDevice(String deviceId)` ao `OrderStore`
- [x] Adicionar `@action addService(service, {deviceId})` (atualizar existente)
- [x] Adicionar `@action addProduct(product, {deviceId})` (atualizar existente)
- [x] Adicionar `@action duplicateServiceForAllDevices(service)`
- [x] Adicionar `@action duplicateProductForAllDevices(product)`
- [x] Implementar lógica de orphan cleanup (RN-05: remover device → itens viram globais)
- [x] Adicionar `totalForDevice(String? deviceId)` helper
- [x] Executar `build_runner`

### Fase 3: UI Layer (Screens & Widgets) — ✅ Concluída

- [x] Criar `DevicePickerSheet` (CupertinoActionSheet) — `lib/screens/widgets/device_picker_sheet.dart`
- [x] Criar `DevicePickerResult` model
- [x] Criar agrupamento visual por device na tela de OS
- [x] Atualizar `OrderForm` — seção de devices com lista e swipe-to-delete
- [x] Atualizar `OrderForm` — serviços agrupados por device
- [x] Atualizar `OrderForm` — produtos agrupados por device
- [x] Atualizar `OrderForm` — checklists vinculados a device
- [x] Atualizar `OrderForm` — botão "Adicionar Device" abaixo do cliente (some após 1º device)
- [x] Atualizar fluxo "Adicionar Serviço" com seleção condicional de device
- [x] Atualizar fluxo "Adicionar Produto" com seleção condicional de device
- [x] Atualizar fluxo "Adicionar Checklist" com seleção condicional de device
- [x] Atualizar `FormFillScreen` — exibir nome do device vinculado
- [x] Permitir adicionar múltiplos devices à OS (via botão + e nav bar)
- [x] Garantir que 1 device = sem agrupamento (UX idêntica à atual)
- [x] Diálogo de remoção de device usa label do segmento (ex: "Remover Veículo")
- [x] Adicionar strings i18n para novos labels
- [ ] Testar dark mode em todos os novos widgets

### Fase 4: Share Link & PDF — 🔧 Parcial

- [ ] Atualizar share link para exibir múltiplos devices
- [x] Atualizar geração de PDF/orçamento com suporte a múltiplos devices
- [ ] Atualizar página web pública de aprovação

### Fase 5: Bot (OpenClaw) — 🔧 Parcial

- [x] Atualizar card de OS para exibir contagem de devices
- [ ] Atualizar visualização detalhada com agrupamento
- [x] Atualizar endpoint `POST /orders` para aceitar `devices[]`
- [x] Atualizar endpoint `GET /orders/:id` com `devices`
- [x] Atualizar endpoints de services/products com `deviceId`
- [ ] Implementar loop de adição de devices na criação conversacional
- [ ] Implementar seleção de device ao adicionar serviço via bot
- [ ] Testar fluxos completos via WhatsApp

### Fase 6: Firestore & Indexes

- [ ] Verificar se indexes existentes suportam queries com `devices`
- [ ] Criar composite indexes se necessário
- [ ] Testar queries de listagem com novo campo
- [ ] Verificar Security Rules para novo campo

### Fase 7: i18n — ✅ Concluída

- [x] Adicionar chaves em `app_pt.arb`:
  - `selectDevice`, `selectDeviceMessage`, `allDevices`
  - `general`, `devicesCount`, `subtotal`
  - `addAnotherDevice`, `deviceLinked`, `noDeviceLinked`
  - `removeDevice`, `confirmRemoveDevice`, `removeDeviceHasItems`
  - `removeDeviceKeepItems`, `removeDeviceAndItems`
- [x] Adicionar chaves em `app_en.arb`
- [x] Adicionar chaves em `app_es.arb`
- [x] Executar `fvm flutter gen-l10n`

---

## 12. Melhorias de UX Implementadas

### 12.1 Botão "Adicionar Device" abaixo do Cliente

Na seção de cliente/endereço, um atalho para adicionar o primeiro device aparece logo abaixo do campo de endereço. O botão usa `primaryColor` e o label do segmento (ex: "Adicionar Veículo"). Ele desaparece automaticamente assim que o primeiro device é adicionado.

```
┌─────────────────────────────────────────────────┐
│  CLIENTE                                        │
│  ┌─────────────────────────────────────────┐    │
│  │  👤 João Silva                     >    │    │
│  │  📍 Rua das Flores, 123                 │    │
│  │  🚗 Adicionar Veículo             >    │ ← some após 1º device
│  └─────────────────────────────────────────┘    │
└─────────────────────────────────────────────────┘
```

### 12.2 Diálogo de remoção com label do segmento

O diálogo de confirmação de exclusão de device agora usa o label do segmento em vez de "Equipamento" fixo. Exemplos:

| Segmento | Título do diálogo | Botão destrutivo |
|----------|-------------------|------------------|
| Automotiva | Remover Veículo | Remover Veículo |
| Eletrônica | Remover Aparelho | Remover Aparelho |
| HVAC | Remover Equipamento | Remover Equipamento |
| Padrão | Remover Dispositivo | Remover Dispositivo |

### 12.3 Seção de Devices com swipe-to-delete

Devices são listados em `CupertinoListSection.insetGrouped` com:
- Ícone do segmento + nome do device
- Serial/identificador como subtítulo
- Swipe-to-delete (deslizar para remover)
- Botão "+" na nav bar para adicionar mais

### 12.4 DevicePickerSheet multi-select

Ao adicionar serviço/produto com 2+ devices, o `DevicePickerSheet` exibe:
1. Lista de devices individuais
2. Opção "Todos os dispositivos" (duplica o item N vezes)
3. Opção "Geral" (sem vínculo)

### 12.5 Agrupamento visual por device

Serviços e produtos são agrupados visualmente por device quando a OS tem 2+ devices. Com 1 device, a experiência é idêntica à anterior.

### 12.6 Device vinculado em telas de edição

As telas de edição de serviço (`OrderServiceScreen`), produto (`OrderProductScreen`) e formulário (`FormFillScreen`) exibem o nome do device vinculado.

---

## 11. Arquivos Impactados

### Models (✅ implementados)

| Arquivo | Mudança |
|---------|---------|
| `lib/models/order.dart` | `devices`, `effectiveDevices`, `isMultiDevice`, `deviceId` em OrderService/OrderProduct |
| `lib/models/order.g.dart` | Regenerado (build_runner) |
| `lib/models/order_form.dart` | `deviceId` adicionado |
| `lib/models/order_form.g.dart` | Regenerado |
| `lib/models/customer.dart` | Campo `address` adicionado |
| `lib/models/customer.g.dart` | Regenerado |

### Stores (✅ implementados)

| Arquivo | Mudança |
|---------|---------|
| `lib/mobx/order_store.dart` | `devices` observable, `servicesByDevice`/`productsByDevice` computed, actions de add/remove device, `removeDeviceAndItems` |
| `lib/mobx/order_store.g.dart` | Regenerado |

### Screens (✅ implementados)

| Arquivo | Mudança |
|---------|---------|
| `lib/screens/order_form.dart` | Seção de devices, agrupamento por device, botão "Adicionar Device" abaixo do cliente, diálogo de remoção com label do segmento, DevicePickerSheet integrado nos fluxos de serviço/produto/checklist |
| `lib/screens/order_service_screen.dart` | Exibir device vinculado ao serviço |
| `lib/screens/order_product_screen.dart` | Exibir device vinculado ao produto |
| `lib/screens/forms/form_fill_screen.dart` | Exibir device vinculado ao formulário |
| `lib/screens/customers/customer_form_screen.dart` | Campo de endereço |

### Widgets (✅ novos)

| Arquivo | Descrição |
|---------|-----------|
| `lib/screens/widgets/device_picker_sheet.dart` | **Novo** — CupertinoActionSheet com opções: device individual, todos, geral |

### Internacionalização (✅ implementados)

| Arquivo | Mudança |
|---------|---------|
| `lib/l10n/app_pt.arb` | 37 novas chaves (multi-device, remoção, seleção) |
| `lib/l10n/app_en.arb` | 37 novas chaves |
| `lib/l10n/app_es.arb` | 37 novas chaves |

### PDF (✅ parcial)

| Arquivo | Mudança |
|---------|---------|
| `lib/services/pdf/pdf_main_os_builder.dart` | Suporte a múltiplos devices no PDF |
| `lib/services/pdf/pdf_localizations.dart` | Labels de device no PDF |

### Bot (✅ parcial)

| Arquivo | Mudança |
|---------|---------|
| `backend/bot/skills/praticos/references/os-card.md` | Card atualizado com contagem de devices |
| `firebase/functions/src/routes/bot/orders-management.routes.ts` | Endpoints de add/remove device, serviços/produtos com deviceId |
| `firebase/functions/src/services/order.service.ts` | Lógica de multi-device no backend |
| `firebase/functions/src/models/types.ts` | Tipos atualizados |
| `firebase/functions/src/utils/validation.utils.ts` | Validações de deviceId |

### Serviços

| Arquivo | Mudança |
|---------|---------|
| `lib/services/location_service.dart` | `openInMaps` para endereço da OS |
| `lib/services/forms_service.dart` | Suporte a `deviceId` em forms |

### Pendentes

| Arquivo | Descrição |
|---------|-----------|
| `lib/screens/share/share_link_screen.dart` | Exibir múltiplos devices no share link |
| `firebase/hosting/src/share.njk` | Template público com multi-device |
| `test/models/order_test.dart` | Testes de serialização |
| `test/stores/order_store_test.dart` | Testes de computed properties |

---

## Referências

- **Issue:** [#178 — Support for multiple devices per service order](https://github.com/rafaeldl/praticOSopen/issues/178)
- **Device Catalog:** `docs/DEVICE_CATALOG_IMPLEMENTATION.md`
- **Dynamic Forms:** `docs/formularios_dinamicos.md`
- **Share Link:** `docs/SHARE_LINK.md`
- **Segment Fields:** `docs/SEGMENT_CUSTOM_FIELDS.md`
- **UX Guidelines:** `docs/UX_GUIDELINES.md`

### Referências Externas (Comparativo)

- [ServiceTitan Platform](https://www.servicetitan.com/)
- [Salesforce Field Service](https://www.salesforce.com/products/field-service/)
- [Dynamics 365 Field Service](https://dynamics.microsoft.com/field-service/)
- [IBM Maximo Application Suite](https://www.ibm.com/maximo)
- [Jobber](https://getjobber.com/)
- [Housecall Pro](https://www.housecallpro.com/)
