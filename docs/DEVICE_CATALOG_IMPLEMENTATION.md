# Implementação: Catálogo de Dispositivos

## Sumário

1. [Visão Geral](#1-visão-geral)
2. [Etapa 1: Catálogo Local do Tenant](#2-etapa-1-catálogo-local-do-tenant)
3. [Etapa 2: Catálogo Global](#3-etapa-2-catálogo-global)
4. [Etapa 3: Curadoria e Atualização](#4-etapa-3-curadoria-e-atualização)
5. [Security Rules](#5-security-rules)
6. [Índices](#6-índices)
7. [Setup Inicial](#7-setup-inicial)
8. [Roadmap de Implementação](#8-roadmap-de-implementação)
9. [Métricas e Monitoramento](#9-métricas-e-monitoramento)

---

## 1. Visão Geral

### 1.1 Objetivo

Criar um sistema de catálogo de dispositivos que:
- Evita digitação repetitiva de marcas/modelos
- Padroniza dados e reduz erros
- Aprende com o uso (autocomplete inteligente)
- Segmenta por ramo de atuação do tenant
- Cresce organicamente com contribuição da comunidade

### 1.2 Arquitetura em 2 Etapas

```
┌─────────────────────────────────────────────────────────┐
│ ETAPA 1: MVP - Segments Globais + Catálogo Local       │
│ • Segments (ramos) são globais (read-only)             │
│ • Brands e Models são locais por tenant                │
│ • Autocomplete aprende com uso do tenant               │
│ • Simples e funciona 100% offline                      │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│ ETAPA 2: Catálogo Global + Curadoria                   │
│ • Seed inicial de brands/modelos comuns                │
│ • Busca em paralelo: global + local                    │
│ • Tenants contribuem automaticamente                   │
│ • Rafsoft aprova/edita via dashboard                   │
│ • Catálogo global cresce com uso real                  │
└─────────────────────────────────────────────────────────┘
```

### 1.3 Fluxo do Usuário

```
1. Onboarding → Escolhe ramo (HVAC, Oficina, Celular, etc.)
2. Criar OS → Autocomplete de marca/modelo
3. Digita "Sam..." → Sugere "Samsung Galaxy S21"
4. Seleciona → Incrementa contador de uso
5. Próxima vez → Aparece no topo (mais usado)
```

---

## 2. Etapa 1: MVP - Segments Globais + Catálogo Local

### 2.1 Estrutura Firestore

```
Firestore (root)
│
├── segments/{segmentId}              ← Segments globais (read-only)
│     {
│       id: "hvac",
│       name: "Ar Condicionado / Refrigeração",
│       icon: "❄️",
│       active: true,
│       customFields: [
│         { key: "btus", label: "BTUs", type: "number" },
│         { key: "voltage", label: "Voltagem", type: "select", options: ["110V", "220V"] }
│       ],
│       createdAt: timestamp
│     }
│
└── companies/{companyId}/
      ├── segment: "hvac"             ← Referência ao segment (ID)
      │
      ├── brands/{brandId}            ← Brands locais do tenant
      │     {
      │       name: "LG",
      │       usageCount: 25,
      │       createdAt: timestamp
      │     }
      │
      └── deviceCatalog/{itemId}      ← Modelos locais do tenant
            {
              brandId: "lg",                 ← Referência à brand
              brand: "LG",                   ← Desnormalizado (performance)
              model: "Dual Inverter",
              variants: ["9000", "12000", "18000", "24000"],
              searchKey: "lg dual inverter", ← Para autocomplete
              usageCount: 15,
              createdAt: timestamp,
              updatedAt: timestamp
            }
```

**Observações:**
- **segments**: Collection global (Rafsoft mantém via Admin SDK)
- **brands**: Local por tenant, criada automaticamente ao usar
- **deviceCatalog**: Local por tenant, modelos específicos

**Exemplos:**

```javascript
// Brand (companies/abc123/brands/samsung)
{
  name: "Samsung",
  usageCount: 45,
  createdAt: timestamp
}

// Model (companies/abc123/deviceCatalog/xyz)
{
  brandId: "samsung",
  brand: "Samsung",
  model: "WindFree",
  variants: ["9000", "12000", "18000"],
  searchKey: "samsung windfree",
  usageCount: 23,
  createdAt: timestamp
}
```

### 2.2 Models

```dart
// lib/models/brand.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Brand {
  String? id;
  String name;
  int usageCount;
  DateTime? createdAt;

  Brand({
    this.id,
    required this.name,
    this.usageCount = 0,
    this.createdAt,
  });

  factory Brand.fromJson(Map<String, dynamic> json) {
    return Brand(
      id: json['id'],
      name: json['name'] ?? '',
      usageCount: json['usageCount'] ?? 0,
      createdAt: json['createdAt']?.toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'usageCount': usageCount,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }

  String get searchKey => name.toLowerCase();
}

// lib/models/device_catalog_item.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class DeviceCatalogItem {
  String? id;
  String? brandId;          // Referência à brand
  String brand;             // Desnormalizado (performance)
  String model;
  List<String> variants;    // Ex: ["9000 BTUs", "12000 BTUs"]
  String searchKey;         // Texto para busca (lowercase)
  int usageCount;           // Quantas vezes foi usado
  DateTime? createdAt;
  DateTime? updatedAt;

  DeviceCatalogItem({
    this.id,
    this.brandId,
    required this.brand,
    required this.model,
    this.variants = const [],
    required this.searchKey,
    this.usageCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory DeviceCatalogItem.fromJson(Map<String, dynamic> json) {
    return DeviceCatalogItem(
      id: json['id'],
      brandId: json['brandId'],
      brand: json['brand'] ?? '',
      model: json['model'] ?? '',
      variants: List<String>.from(json['variants'] ?? []),
      searchKey: json['searchKey'] ?? '',
      usageCount: json['usageCount'] ?? 0,
      createdAt: json['createdAt']?.toDate(),
      updatedAt: json['updatedAt']?.toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (brandId != null) 'brandId': brandId,
      'brand': brand,
      'model': model,
      'variants': variants,
      'searchKey': searchKey,
      'usageCount': usageCount,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Gera searchKey a partir dos dados
  static String generateSearchKey(String brand, String model) {
    return '$brand $model'.toLowerCase();
  }

  @override
  String toString() => '$brand $model';
}
```

### 2.3 Repository

```dart
// lib/repositories/device_catalog_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/brand.dart';
import '../models/device_catalog_item.dart';

class DeviceCatalogRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ══════════════════════════════════════════════════════════════
  // BRANDS
  // ══════════════════════════════════════════════════════════════

  CollectionReference _brandsCollection(String companyId) {
    return _db.collection('companies').doc(companyId).collection('brands');
  }

  /// Busca brands por query
  Future<List<Brand>> searchBrands(String companyId, String query) async {
    if (query.isEmpty) return [];

    final q = query.toLowerCase();

    final snap = await _brandsCollection(companyId)
        .orderBy('usageCount', descending: true)
        .get();

    // Filtra no client (não precisa de índice)
    return snap.docs
        .map((d) => Brand.fromJson({...d.data() as Map, 'id': d.id}))
        .where((b) => b.searchKey.contains(q))
        .take(10)
        .toList();
  }

  /// Adiciona ou incrementa uso da brand
  Future<String> addOrIncrementBrand(String companyId, String brandName) async {
    final searchKey = brandName.toLowerCase();

    // Busca se já existe
    final existing = await _brandsCollection(companyId)
        .where('name', isEqualTo: brandName)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      // Incrementa contador
      final docRef = existing.docs.first.reference;
      await docRef.update({'usageCount': FieldValue.increment(1)});
      return docRef.id;
    }

    // Cria nova brand
    final docRef = await _brandsCollection(companyId).add({
      'name': brandName,
      'usageCount': 1,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  /// Lista todas as brands (ordenado por uso)
  Stream<List<Brand>> streamAllBrands(String companyId) {
    return _brandsCollection(companyId)
        .orderBy('usageCount', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Brand.fromJson({...d.data() as Map, 'id': d.id}))
            .toList());
  }

  // ══════════════════════════════════════════════════════════════
  // DEVICE CATALOG (MODELS)
  // ══════════════════════════════════════════════════════════════

  CollectionReference _modelsCollection(String companyId) {
    return _db
        .collection('companies')
        .doc(companyId)
        .collection('deviceCatalog');
  }

  /// Busca modelos por query (todos ou filtrado por brand)
  Future<List<DeviceCatalogItem>> searchModels(
    String companyId,
    String query, {
    String? brandId,
  }) async {
    if (query.isEmpty) return [];

    final q = query.toLowerCase();

    Query ref = _modelsCollection(companyId)
        .orderBy('usageCount', descending: true);

    if (brandId != null) {
      ref = ref.where('brandId', isEqualTo: brandId);
    }

    final snap = await ref.get();

    // Filtra no client por searchKey
    return snap.docs
        .map((d) => DeviceCatalogItem.fromJson({...d.data() as Map, 'id': d.id}))
        .where((m) => m.searchKey.contains(q))
        .take(20)
        .toList();
  }

  /// Adiciona ou incrementa uso do modelo
  Future<String> addOrIncrementModel(
    String companyId,
    DeviceCatalogItem item,
  ) async {
    // Busca se já existe
    final existing = await _modelsCollection(companyId)
        .where('searchKey', isEqualTo: item.searchKey)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      // Incrementa contador
      final docRef = existing.docs.first.reference;
      await docRef.update({
        'usageCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    }

    // Cria novo modelo
    final docRef = await _modelsCollection(companyId).add(item.toJson());
    return docRef.id;
  }

  /// Lista todos os modelos (ordenado por uso)
  Stream<List<DeviceCatalogItem>> streamAllModels(
    String companyId, {
    String? brandId,
  }) {
    Query ref = _modelsCollection(companyId).orderBy('usageCount', descending: true);

    if (brandId != null) {
      ref = ref.where('brandId', isEqualTo: brandId);
    }

    return ref.snapshots().map((snap) => snap.docs
        .map((d) => DeviceCatalogItem.fromJson({...d.data() as Map, 'id': d.id}))
        .toList());
  }

  /// Remove modelo
  Future<void> removeModel(String companyId, String modelId) async {
    await _modelsCollection(companyId).doc(modelId).delete();
  }

  /// Remove brand (e opcionalmente seus modelos)
  Future<void> removeBrand(String companyId, String brandId,
      {bool removeModels = false}) async {
    await _brandsCollection(companyId).doc(brandId).delete();

    if (removeModels) {
      // Remove todos os modelos dessa brand
      final models = await _modelsCollection(companyId)
          .where('brandId', isEqualTo: brandId)
          .get();

      final batch = _db.batch();
      for (final doc in models.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }
}
```

### 2.4 Widget de Autocomplete

```dart
// lib/widgets/device_autocomplete_field.dart

import 'package:flutter/material.dart';
import '../models/device_catalog_item.dart';
import '../repositories/device_catalog_repository.dart';

class DeviceAutocompleteField extends StatefulWidget {
  final String companyId;
  final String label;
  final String type; // "brand" ou "model"
  final String? initialValue;
  final Function(String) onSelected;
  final String? brandFilter; // Para filtrar modelos por marca

  const DeviceAutocompleteField({
    Key? key,
    required this.companyId,
    required this.label,
    required this.type,
    this.initialValue,
    required this.onSelected,
    this.brandFilter,
  }) : super(key: key);

  @override
  State<DeviceAutocompleteField> createState() =>
      _DeviceAutocompleteFieldState();
}

class _DeviceAutocompleteFieldState extends State<DeviceAutocompleteField> {
  final _repo = DeviceCatalogRepository();
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null) {
      _controller.text = widget.initialValue!;
    }
  }

  Future<List<String>> _getSuggestions(String query) async {
    if (query.isEmpty) return [];

    final items = await _repo.search(
      widget.companyId,
      query,
      type: widget.type,
    );

    // Filtrar por marca se necessário
    final filtered = widget.brandFilter != null
        ? items.where((i) => i.brand == widget.brandFilter).toList()
        : items;

    return filtered
        .map((i) => i.type == 'brand' ? i.brand! : i.model!)
        .toSet() // Remove duplicatas
        .toList();
  }

  void _handleSelection(String value) {
    widget.onSelected(value);

    // Incrementa uso no catálogo
    final item = DeviceCatalogItem(
      type: widget.type,
      brand: widget.type == 'brand' ? value : widget.brandFilter,
      model: widget.type == 'model' ? value : null,
      searchKey: DeviceCatalogItem.generateSearchKey(
        widget.type == 'brand' ? value : widget.brandFilter,
        widget.type == 'model' ? value : null,
      ),
    );

    _repo.addOrIncrementUsage(widget.companyId, item);
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: widget.initialValue ?? ''),
      optionsBuilder: (textEditingValue) async {
        return await _getSuggestions(textEditingValue.text);
      },
      onSelected: _handleSelection,
      fieldViewBuilder: (context, controller, focusNode, onSubmit) {
        // Sincroniza com controller local
        if (controller.text != _controller.text) {
          _controller.text = controller.text;
        }

        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: widget.label,
            border: OutlineInputBorder(),
            suffixIcon: Icon(Icons.arrow_drop_down),
          ),
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              _handleSelection(value);
            }
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 200, maxWidth: 300),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return ListTile(
                    title: Text(option),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
```

### 2.5 Fluxo de Onboarding Completo

#### 2.5.1 Visão Geral do Fluxo

```
┌────────────────────────────────────────────────┐
│  1. Dados da Empresa                           │
│     • Nome da empresa                          │
│     • Telefone                                 │
│     • Endereço (opcional)                      │
└────────────────────────────────────────────────┘
                    ↓
┌────────────────────────────────────────────────┐
│  2. Escolher Segmento                          │
│     • Lista de ramos (segments collection)    │
│     • Ícones e descrições                      │
└────────────────────────────────────────────────┘
                    ↓
┌────────────────────────────────────────────────┐
│  3. Confirmação & Criação                      │
│     • Salva company no Firestore               │
│     • Redireciona para Home                    │
└────────────────────────────────────────────────┘
```

#### 2.5.2 Tela 1: Dados da Empresa

```dart
// lib/screens/onboarding/company_info_screen.dart

import 'package:flutter/material.dart';

class CompanyInfoScreen extends StatefulWidget {
  const CompanyInfoScreen({Key? key}) : super(key: key);

  @override
  State<CompanyInfoScreen> createState() => _CompanyInfoScreenState();
}

class _CompanyInfoScreenState extends State<CompanyInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  void _next() {
    if (_formKey.currentState?.validate() ?? false) {
      // Navega para escolha de segmento, passando os dados
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SelectSegmentScreen(
            companyName: _nameController.text,
            phone: _phoneController.text,
            address: _addressController.text,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Criar Empresa'),
      ),
      body: Padding(
        padding: EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Bem-vindo ao PráticOS!',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              SizedBox(height: 8),
              Text(
                'Vamos começar com alguns dados da sua empresa',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              SizedBox(height: 32),

              // Nome da empresa
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Nome da Empresa *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Nome da empresa é obrigatório';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),

              // Telefone
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Telefone *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                  hintText: '(00) 00000-0000',
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Telefone é obrigatório';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),

              // Endereço (opcional)
              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(
                  labelText: 'Endereço (Opcional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
                maxLines: 2,
              ),

              Spacer(),

              ElevatedButton(
                onPressed: _next,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text('Próximo'),
              ),
              SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }
}
```

#### 2.5.3 Tela 2: Escolher Segmento

```dart
// lib/screens/onboarding/select_segment_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SelectSegmentScreen extends StatefulWidget {
  final String companyName;
  final String phone;
  final String address;

  const SelectSegmentScreen({
    Key? key,
    required this.companyName,
    required this.phone,
    required this.address,
  }) : super(key: key);

  @override
  State<SelectSegmentScreen> createState() => _SelectSegmentScreenState();
}

class _SelectSegmentScreenState extends State<SelectSegmentScreen> {
  bool _isCreating = false;

  Future<void> _createCompany(
    BuildContext context,
    String segmentId,
    Map<String, dynamic> segmentData,
  ) async {
    if (_isCreating) return;

    setState(() => _isCreating = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Usuário não autenticado');

      final db = FirebaseFirestore.instance;

      // Cria a empresa
      final companyRef = await db.collection('companies').add({
        'name': widget.companyName,
        'phone': widget.phone,
        'address': widget.address,
        'segment': segmentId,
        'owner': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Adiciona o usuário como membro da empresa
      await db.collection('users').doc(user.uid).set({
        'email': user.email,
        'name': user.displayName ?? user.email?.split('@')[0],
        'companies': FieldValue.arrayUnion([companyRef.id]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (context.mounted) {
        // Mostra confirmação
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Empresa criada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );

        // Redireciona para home
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
      }
    } catch (e) {
      setState(() => _isCreating = false);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao criar empresa: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Qual o ramo do seu negócio?'),
        centerTitle: true,
      ),
      body: _isCreating
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Criando empresa...'),
                ],
              ),
            )
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('segments')
                  .where('active', isEqualTo: true)
                  .orderBy('name')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.red),
                        SizedBox(height: 16),
                        Text('Erro ao carregar segmentos'),
                        SizedBox(height: 8),
                        Text(
                          snapshot.error.toString(),
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                final segments = snapshot.data?.docs ?? [];

                if (segments.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 48, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('Nenhum segmento disponível'),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    // Cabeçalho
                    Container(
                      padding: EdgeInsets.all(24),
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      child: Column(
                        children: [
                          Icon(
                            Icons.business_center,
                            size: 48,
                            color: Theme.of(context).primaryColor,
                          ),
                          SizedBox(height: 16),
                          Text(
                            widget.companyName,
                            style: Theme.of(context).textTheme.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Selecione o ramo de atuação para personalizar o sistema',
                            style: TextStyle(color: Colors.grey[600]),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    // Lista de segmentos
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: segments.length,
                        itemBuilder: (context, index) {
                          final segment = segments[index].data() as Map<String, dynamic>;
                          final segmentId = segments[index].id;

                          return Card(
                            margin: EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              leading: Text(
                                segment['icon'] ?? '🔧',
                                style: TextStyle(fontSize: 32),
                              ),
                              title: Text(
                                segment['name'] ?? 'Sem nome',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              trailing: Icon(Icons.arrow_forward_ios, size: 16),
                              onTap: () => _createCompany(context, segmentId, segment),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
```

#### 2.5.4 Como Integrar no Fluxo Principal

```dart
// No routing do app (main.dart ou app_routes.dart)

routes: {
  '/onboarding': (context) => CompanyInfoScreen(),
  '/home': (context) => HomeScreen(),
  // ...
}

// Na tela de login/registro, após autenticação bem-sucedida:
class LoginScreen extends StatelessWidget {
  Future<void> _checkUserHasCompany(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Verifica se usuário já tem empresa
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final companies = userDoc.data()?['companies'] as List?;

    if (companies == null || companies.isEmpty) {
      // Não tem empresa → Onboarding
      Navigator.pushReplacementNamed(context, '/onboarding');
    } else {
      // Já tem empresa → Home
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  // ...
}
```

#### 2.5.5 Resultado no Firestore

Após completar o onboarding, a estrutura fica assim:

```
companies/{newCompanyId}/
  {
    name: "Clima Técnica",
    phone: "(11) 98765-4321",
    address: "Rua das Flores, 123",
    segment: "hvac",
    owner: "user123",
    createdAt: timestamp,
    updatedAt: timestamp
  }
  ├── brands/           ← Vazia inicialmente
  └── deviceCatalog/    ← Vazia inicialmente

users/{userId}/
  {
    email: "joao@email.com",
    name: "João",
    companies: ["newCompanyId"],
    updatedAt: timestamp
  }
```

---

### 2.6 Exemplo de Uso no Form de Device

```dart
// lib/screens/devices/device_form_screen.dart

class DeviceFormScreen extends StatefulWidget {
  // ...
}

class _DeviceFormScreenState extends State<DeviceFormScreen> {
  String? _selectedBrand;
  String? _selectedModel;

  @override
  Widget build(BuildContext context) {
    final companyId = /* get from context/provider */;

    return Scaffold(
      appBar: AppBar(title: Text('Adicionar Dispositivo')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Autocomplete de Marca
            DeviceAutocompleteField(
              companyId: companyId,
              label: 'Marca',
              type: 'brand',
              onSelected: (brand) {
                setState(() {
                  _selectedBrand = brand;
                  _selectedModel = null; // Limpa modelo ao trocar marca
                });
              },
            ),
            SizedBox(height: 16),

            // Autocomplete de Modelo (filtrado pela marca)
            if (_selectedBrand != null)
              DeviceAutocompleteField(
                companyId: companyId,
                label: 'Modelo',
                type: 'model',
                brandFilter: _selectedBrand,
                onSelected: (model) {
                  setState(() => _selectedModel = model);
                },
              ),

            // Campos customizados baseados no segmento...
          ],
        ),
      ),
    );
  }
}
```

---

## 3. Etapa 2: Catálogo Global

### 3.1 Estrutura Firestore

```
Firestore (root)
│
├── segments/{segmentId}              ← Collection de nível raiz
│     {
│       id: "hvac",
│       name: "Ar Condicionado / Refrigeração",
│       icon: "❄️",
│       active: true,
│       customFields: [
│         { key: "btus", label: "BTUs", type: "number" },
│         { key: "voltage", label: "Voltagem", type: "select", options: ["110V", "220V"] }
│       ],
│       createdAt: timestamp
│     }
│
├── catalog/
│   └── models/{modelId}              ← Modelos globais
│         {
│           segment: "hvac",
│           brand: "LG",
│           model: "Dual Inverter",
│           variants: ["9000", "12000", "18000", "24000"],
│           searchKey: "lg dual inverter",
│           source: "rafsoft",       ← "rafsoft" ou "community"
│           usageCount: 0,           ← Global usage counter
│           createdAt: timestamp,
│           updatedAt: timestamp
│         }
│
└── companies/{companyId}/
      ├── segment: "hvac"             ← Referência ao segment
      └── deviceCatalog/{itemId}      ← Catálogo local do tenant
```

### 3.2 Script de Seed Inicial

```dart
// scripts/seed_global_catalog.dart

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  final db = FirebaseFirestore.instance;

  print('═══════════════════════════════════════════════════');
  print('  SEED CATÁLOGO GLOBAL DE DISPOSITIVOS');
  print('═══════════════════════════════════════════════════\n');

  // Seed segments
  await seedSegments(db);

  // Seed modelos por segmento
  await seedHVACModels(db);
  await seedAutomotiveModels(db);
  await seedSmartphoneModels(db);

  print('\n✅ Catálogo global populado com sucesso!');
  exit(0);
}

Future<void> seedSegments(FirebaseFirestore db) async {
  print('📦 Populando segments...');

  final segments = [
    {
      'id': 'hvac',
      'name': 'Ar Condicionado / Refrigeração',
      'icon': '❄️',
      'active': true,
      'customFields': [
        {'key': 'btus', 'label': 'BTUs', 'type': 'number'},
        {
          'key': 'voltage',
          'label': 'Voltagem',
          'type': 'select',
          'options': ['110V', '220V', 'Bifásico']
        },
        {'key': 'gasType', 'label': 'Tipo de Gás', 'type': 'text'},
      ]
    },
    {
      'id': 'automotive',
      'name': 'Oficina Mecânica',
      'icon': '🚗',
      'active': true,
      'customFields': [
        {'key': 'plate', 'label': 'Placa', 'type': 'text'},
        {'key': 'year', 'label': 'Ano', 'type': 'number'},
        {'key': 'mileage', 'label': 'Km', 'type': 'number'},
        {'key': 'chassis', 'label': 'Chassi', 'type': 'text'},
      ]
    },
    {
      'id': 'smartphones',
      'name': 'Assistência Técnica - Celulares',
      'icon': '📱',
      'active': true,
      'customFields': [
        {'key': 'imei', 'label': 'IMEI', 'type': 'text'},
        {'key': 'color', 'label': 'Cor', 'type': 'text'},
        {
          'key': 'storage',
          'label': 'Armazenamento',
          'type': 'select',
          'options': ['64GB', '128GB', '256GB', '512GB', '1TB']
        },
      ]
    },
    {
      'id': 'appliances',
      'name': 'Eletrodomésticos',
      'icon': '🔌',
      'active': true,
      'customFields': [
        {'key': 'serialNumber', 'label': 'Número de Série', 'type': 'text'},
        {
          'key': 'voltage',
          'label': 'Voltagem',
          'type': 'select',
          'options': ['110V', '220V']
        },
      ]
    },
    {
      'id': 'computers',
      'name': 'Informática',
      'icon': '💻',
      'active': true,
      'customFields': [
        {'key': 'processor', 'label': 'Processador', 'type': 'text'},
        {'key': 'ram', 'label': 'Memória RAM', 'type': 'text'},
        {'key': 'storage', 'label': 'Armazenamento', 'type': 'text'},
        {'key': 'serialNumber', 'label': 'Serial', 'type': 'text'},
      ]
    },
    {
      'id': 'other',
      'name': 'Outro',
      'icon': '🔧',
      'active': true,
      'customFields': [],
    },
  ];

  // Salva diretamente na collection segments (nível raiz)
  for (final segment in segments) {
    await db.collection('segments').doc(segment['id'] as String).set({
      ...segment,
      'createdAt': FieldValue.serverTimestamp(),
    });

    print('  ✓ ${segment['name']}');
  }
}

Future<void> seedHVACModels(FirebaseFirestore db) async {
  print('\n📦 Populando HVAC...');

  final models = [
    {'brand': 'LG', 'model': 'Dual Inverter', 'variants': ['9000', '12000', '18000', '24000']},
    {'brand': 'LG', 'model': 'Art Cool', 'variants': ['9000', '12000', '18000']},
    {'brand': 'Samsung', 'model': 'WindFree', 'variants': ['9000', '12000', '18000', '24000']},
    {'brand': 'Samsung', 'model': 'Digital Inverter', 'variants': ['9000', '12000', '18000']},
    {'brand': 'Carrier', 'model': 'X-Power', 'variants': ['9000', '12000', '18000', '22000']},
    {'brand': 'Daikin', 'model': 'Advance', 'variants': ['9000', '12000', '18000', '24000']},
    {'brand': 'Midea', 'model': 'Liva Eco', 'variants': ['9000', '12000', '18000']},
    {'brand': 'Gree', 'model': 'Eco Garden', 'variants': ['9000', '12000', '18000', '24000']},
  ];

  await _seedModels(db, 'hvac', models);
}

Future<void> seedAutomotiveModels(FirebaseFirestore db) async {
  print('\n📦 Populando Automotive...');

  final models = [
    {'brand': 'Honda', 'model': 'Civic', 'variants': []},
    {'brand': 'Honda', 'model': 'Fit', 'variants': []},
    {'brand': 'Toyota', 'model': 'Corolla', 'variants': []},
    {'brand': 'Toyota', 'model': 'Hilux', 'variants': []},
    {'brand': 'Volkswagen', 'model': 'Gol', 'variants': []},
    {'brand': 'Volkswagen', 'model': 'Polo', 'variants': []},
    {'brand': 'Fiat', 'model': 'Uno', 'variants': []},
    {'brand': 'Fiat', 'model': 'Argo', 'variants': []},
  ];

  await _seedModels(db, 'automotive', models);
}

Future<void> seedSmartphoneModels(FirebaseFirestore db) async {
  print('\n📦 Populando Smartphones...');

  final models = [
    {'brand': 'Apple', 'model': 'iPhone 13', 'variants': ['128GB', '256GB', '512GB']},
    {'brand': 'Apple', 'model': 'iPhone 14', 'variants': ['128GB', '256GB', '512GB']},
    {'brand': 'Samsung', 'model': 'Galaxy S21', 'variants': ['128GB', '256GB']},
    {'brand': 'Samsung', 'model': 'Galaxy A54', 'variants': ['128GB', '256GB']},
    {'brand': 'Xiaomi', 'model': 'Redmi Note 12', 'variants': ['128GB', '256GB']},
    {'brand': 'Motorola', 'model': 'Moto G73', 'variants': ['128GB', '256GB']},
  ];

  await _seedModels(db, 'smartphones', models);
}

Future<void> _seedModels(
  FirebaseFirestore db,
  String segment,
  List<Map<String, dynamic>> models,
) async {
  final batch = db.batch();
  int count = 0;

  for (final m in models) {
    // Salva em catalog/models (sem o /items/ intermediário)
    final docRef = db.collection('catalog').doc('models').collection(segment).doc();

    batch.set(docRef, {
      'segment': segment,
      'brand': m['brand'],
      'model': m['model'],
      'variants': m['variants'],
      'searchKey': '${m['brand']} ${m['model']}'.toLowerCase(),
      'source': 'rafsoft',
      'usageCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    count++;
    print('  ✓ ${m['brand']} ${m['model']}');
  }

  await batch.commit();
  print('  Total: $count modelos');
}
```

### 3.3 Repository Atualizado (Busca Global + Local)

```dart
// lib/repositories/device_catalog_repository.dart (atualizado)

class DeviceCatalogRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference _collection(String companyId) {
    return _db
        .collection('companies')
        .doc(companyId)
        .collection('deviceCatalog');
  }

  CollectionReference _globalCollection(String segment) {
    return _db
        .collection('catalog')
        .doc('models')
        .collection(segment);
  }

  /// Busca em paralelo: catálogo global + local
  Future<List<DeviceCatalogItem>> search(
    String companyId,
    String segment,
    String query, {
    String? type,
  }) async {
    if (query.isEmpty) return [];

    final q = query.toLowerCase();

    // Busca paralela em ambas as fontes
    final results = await Future.wait([
      // Global - subcollection do segmento
      _globalCollection(segment)
          .where('searchKey', isGreaterThanOrEqualTo: q)
          .where('searchKey', isLessThanOrEqualTo: '$q\uf8ff')
          .orderBy('searchKey')
          .orderBy('usageCount', descending: true)
          .limit(10)
          .get(),

      // Local do tenant
      _collection(companyId)
          .where('searchKey', isGreaterThanOrEqualTo: q)
          .where('searchKey', isLessThanOrEqualTo: '$q\uf8ff')
          .orderBy('searchKey')
          .orderBy('usageCount', descending: true)
          .limit(10)
          .get(),
    ]);

    // Converte docs para modelos
    final globalItems = results[0]
        .docs
        .map((d) => DeviceCatalogItem.fromJson({
              ...d.data() as Map<String, dynamic>,
              'id': d.id,
            }))
        .toList();

    final localItems = results[1]
        .docs
        .map((d) => DeviceCatalogItem.fromJson({
              ...d.data() as Map<String, dynamic>,
              'id': d.id,
            }))
        .toList();

    // Merge: local primeiro (mais relevante), depois global
    // Remove duplicatas pelo searchKey
    final seen = <String>{};
    final merged = <DeviceCatalogItem>[];

    for (final item in [...localItems, ...globalItems]) {
      if (!seen.contains(item.searchKey)) {
        seen.add(item.searchKey);
        merged.add(item);
      }
    }

    // Filtrar por tipo se especificado
    if (type != null) {
      return merged.where((i) => i.type == type).toList();
    }

    return merged;
  }

  // Métodos addOrIncrementUsage, streamAll, remove permanecem iguais...
}
```

---

## 4. Etapa 3: Curadoria e Atualização

### 4.1 Estrutura de Revisão

```
catalog/
├── pendingReview/{itemId}
│     {
│       ...deviceCatalogItem,
│       status: "pending" | "approved" | "rejected",
│       submittedBy: {
│         tenantId: "abc123",
│         tenantName: "Clima Técnica",
│         date: timestamp
│       },
│       reviewedBy: {
│         adminId: "admin123",
│         adminName: "Rafael",
│         date: timestamp
│       },
│       notes: "Corrigido typo Samsumg → Samsung"
│     }
```

### 4.2 Cloud Function: Auto-Submit

```typescript
// firebase/functions/src/catalogCuration.ts

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

/**
 * Quando item do catálogo local atinge X usos, submete para revisão
 */
export const onDeviceCatalogUpdated = functions.firestore
  .document('companies/{companyId}/deviceCatalog/{itemId}')
  .onUpdate(async (change, context) => {
    const { companyId, itemId } = context.params;
    const before = change.before.data();
    const after = change.after.data();

    // Threshold: 3 usos
    const threshold = 3;

    // Se passou de < threshold para >= threshold
    if (before.usageCount < threshold && after.usageCount >= threshold) {
      // Buscar info da empresa
      const companySnap = await admin
        .firestore()
        .collection('companies')
        .doc(companyId)
        .get();

      const companyData = companySnap.data();

      // Verificar se já não está em revisão
      const existingReview = await admin
        .firestore()
        .collection('catalog')
        .doc('pendingReview')
        .collection('items')
        .where('searchKey', '==', after.searchKey)
        .limit(1)
        .get();

      if (!existingReview.empty) {
        console.log(`Item ${itemId} já está em revisão`);
        return;
      }

      // Criar na fila de revisão
      await admin
        .firestore()
        .collection('catalog')
        .doc('pendingReview')
        .collection('items')
        .add({
          ...after,
          status: 'pending',
          submittedBy: {
            tenantId: companyId,
            tenantName: companyData?.name || 'Unknown',
            date: admin.firestore.FieldValue.serverTimestamp(),
          },
          reviewedBy: null,
          notes: '',
        });

      console.log(
        `✓ Item "${after.brand} ${after.model}" submetido para revisão por ${companyData?.name}`
      );
    }
  });

/**
 * Aprovar modelo para catálogo global
 */
export const approveCatalogItem = functions.https.onCall(
  async (data, context) => {
    // Verificar autenticação
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Usuário não autenticado'
      );
    }

    // Verificar se é admin (custom claim)
    if (!context.auth.token.isRafsoftAdmin) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Apenas admins podem aprovar itens'
      );
    }

    const { itemId, editedData, notes } = data;

    if (!itemId || !editedData) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'itemId e editedData são obrigatórios'
      );
    }

    const db = admin.firestore();

    // Buscar item na fila
    const pendingRef = db
      .collection('catalog')
      .doc('pendingReview')
      .collection('items')
      .doc(itemId);

    const pendingSnap = await pendingRef.get();

    if (!pendingSnap.exists) {
      throw new functions.https.HttpsError(
        'not-found',
        'Item não encontrado na fila de revisão'
      );
    }

    const pendingData = pendingSnap.data()!;

    // Promover para catálogo global
    await db
      .collection('catalog')
      .doc('models')
      .collection(editedData.segment)
      .add({
        segment: editedData.segment,
        brand: editedData.brand,
        model: editedData.model,
        variants: editedData.variants || [],
        searchKey: editedData.searchKey,
        source: 'community',
        usageCount: 0,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        approvedAt: admin.firestore.FieldValue.serverTimestamp(),
        submittedBy: pendingData.submittedBy,
      });

    // Atualizar status na fila
    await pendingRef.update({
      status: 'approved',
      reviewedBy: {
        adminId: context.auth.uid,
        date: admin.firestore.FieldValue.serverTimestamp(),
      },
      notes: notes || '',
    });

    console.log(`✅ Item ${itemId} aprovado e adicionado ao catálogo global`);

    return { success: true, itemId };
  }
);

/**
 * Rejeitar item
 */
export const rejectCatalogItem = functions.https.onCall(
  async (data, context) => {
    if (!context.auth?.token.isRafsoftAdmin) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Apenas admins podem rejeitar itens'
      );
    }

    const { itemId, reason } = data;

    const db = admin.firestore();

    const pendingRef = db
      .collection('catalog')
      .doc('pendingReview')
      .collection('items')
      .doc(itemId);

    const pendingSnap = await pendingRef.get();

    if (!pendingSnap.exists) {
      throw new functions.https.HttpsError('not-found', 'Item não encontrado');
    }

    await pendingRef.update({
      status: 'rejected',
      reviewedBy: {
        adminId: context.auth!.uid,
        date: admin.firestore.FieldValue.serverTimestamp(),
      },
      notes: reason || 'Rejeitado',
    });

    console.log(`❌ Item ${itemId} rejeitado: ${reason}`);

    return { success: true, itemId };
  }
);
```

### 4.3 Service para Chamar Cloud Functions (Flutter)

```dart
// lib/services/catalog_curation_service.dart

import 'package:cloud_functions/cloud_functions.dart';

class CatalogCurationService {
  final _functions = FirebaseFunctions.instance;

  /// Aprovar item (apenas admin)
  Future<void> approveItem(
    String itemId,
    Map<String, dynamic> editedData, {
    String? notes,
  }) async {
    try {
      final result = await _functions.httpsCallable('approveCatalogItem').call({
        'itemId': itemId,
        'editedData': editedData,
        'notes': notes,
      });

      if (result.data['success'] != true) {
        throw Exception('Falha ao aprovar item');
      }
    } catch (e) {
      throw Exception('Erro ao aprovar: $e');
    }
  }

  /// Rejeitar item (apenas admin)
  Future<void> rejectItem(String itemId, String reason) async {
    try {
      final result = await _functions.httpsCallable('rejectCatalogItem').call({
        'itemId': itemId,
        'reason': reason,
      });

      if (result.data['success'] != true) {
        throw Exception('Falha ao rejeitar item');
      }
    } catch (e) {
      throw Exception('Erro ao rejeitar: $e');
    }
  }
}
```

---

## 5. Security Rules

```javascript
// firebase/firestore.rules

rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // ══════════════════════════════════════════════════════════════
    // SEGMENTS GLOBAIS (Read-only para todos autenticados)
    // ══════════════════════════════════════════════════════════════
    match /segments/{segmentId} {
      allow read: if request.auth != null;
      allow write: if false;  // Só via Admin SDK
    }

    // ══════════════════════════════════════════════════════════════
    // CATÁLOGO GLOBAL (Read-only para todos autenticados)
    // ══════════════════════════════════════════════════════════════
    match /catalog/{document=**} {
      allow read: if request.auth != null;
      allow write: if false;  // Só via Admin SDK ou Cloud Functions
    }

    // ══════════════════════════════════════════════════════════════
    // DADOS DO TENANT (Isolados por companyId)
    // ══════════════════════════════════════════════════════════════
    match /companies/{companyId} {
      // Documento da empresa
      allow read: if request.auth != null
        && companyId in request.auth.token.companies;

      // Catálogo de dispositivos do tenant
      match /deviceCatalog/{itemId} {
        allow read: if request.auth != null
          && companyId in request.auth.token.companies;

        allow create, update: if request.auth != null
          && companyId in request.auth.token.companies;

        allow delete: if request.auth != null
          && companyId in request.auth.token.companies
          && request.auth.token.roles[companyId] == 'admin';
      }
    }
  }
}
```

---

## 6. Índices

```json
// firebase/firestore.indexes.json

{
  "indexes": [
    {
      "collectionGroup": "deviceCatalog",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "searchKey", "order": "ASCENDING" },
        { "fieldPath": "usageCount", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "deviceCatalog",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "type", "order": "ASCENDING" },
        { "fieldPath": "searchKey", "order": "ASCENDING" },
        { "fieldPath": "usageCount", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "hvac",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "searchKey", "order": "ASCENDING" },
        { "fieldPath": "usageCount", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "automotive",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "searchKey", "order": "ASCENDING" },
        { "fieldPath": "usageCount", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "smartphones",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "searchKey", "order": "ASCENDING" },
        { "fieldPath": "usageCount", "order": "DESCENDING" }
      ]
    }
  ],
  "fieldOverrides": []
}
```

**Deploy dos índices:**

```bash
firebase deploy --only firestore:indexes
```

---

## 7. Setup Inicial

### 7.1 Popular Segmentos no Firestore

Antes de iniciar o app, é necessário popular a collection `segments` com os segmentos iniciais.

**Executar o script:**

```bash
cd firebase/scripts
npm run seed-segments
# ou com arquivo de credenciais
npm run seed-segments /caminho/service-account-key.json
```

O script criará os seguintes segmentos:
- ❄️ Ar Condicionado / Refrigeração (hvac)
- 🚗 Oficina Mecânica / Automotivo (automotive)
- 📱 Celulares / Smartphones (smartphones)
- 💻 Informática / Computadores (computers)
- 🏠 Eletrodomésticos (home-appliances)
- 🔌 Eletrônicos em Geral (electronics)

**Nota:** Este script pode ser executado múltiplas vezes de forma segura. Ele atualizará segmentos existentes sem duplicá-los.

---

## 8. Roadmap de Implementação

### 8.1 Etapa 1: Catálogo Local (1-2 semanas)

**Checklist:**

- [ ] Criar model `DeviceCatalogItem`
- [ ] Criar repository `DeviceCatalogRepository`
- [ ] Criar widget `DeviceAutocompleteField`
- [ ] Criar tela de onboarding `SelectSegmentScreen`
- [ ] Adicionar campo `segment` e `segmentConfig` em `companies`
- [ ] Integrar autocomplete no form de devices
- [ ] Testar fluxo completo
- [ ] Deploy security rules
- [ ] Deploy índices

**Resultado:**
- ✅ App funciona standalone
- ✅ Cada tenant tem catálogo próprio
- ✅ Autocomplete inteligente baseado em uso

---

### 8.2 Etapa 2: Catálogo Global (3-5 dias)

**Checklist:**

- [ ] Criar collection `segments/` (nível raiz) no Firestore
- [ ] Criar estrutura `catalog/models/{segment}/` no Firestore
- [ ] Criar script `seed_global_catalog.dart`
- [ ] Popular segments globais
- [ ] Popular catálogo inicial de modelos (HVAC, Automotive, Smartphones)
- [ ] Atualizar repository para buscar global + local
- [ ] Atualizar onboarding para buscar segments da collection global
- [ ] Testar merge de resultados
- [ ] Validar performance com cache do Firestore

**Resultado:**
- ✅ Catálogo global funcional
- ✅ Busca unificada (global + local)
- ✅ Novos tenants já têm sugestões

---

### 8.3 Etapa 3: Curadoria (1 semana)

**Checklist:**

- [ ] Criar estrutura `catalog/pendingReview`
- [ ] Implementar Cloud Function `onDeviceCatalogUpdated`
- [ ] Implementar Cloud Functions `approveCatalogItem` e `rejectCatalogItem`
- [ ] Criar service Flutter `CatalogCurationService`
- [ ] (Opcional) Criar dashboard admin web para revisão
- [ ] Testar fluxo de submissão → aprovação → catálogo global
- [ ] Configurar custom claim `isRafsoftAdmin`

**Resultado:**
- ✅ Tenants contribuem automaticamente
- ✅ Rafsoft pode aprovar/rejeitar via dashboard
- ✅ Catálogo global cresce organicamente

---

## 9. Métricas e Monitoramento

### 9.1 Métricas a Acompanhar

| Métrica | Descrição | Como Medir |
|---------|-----------|------------|
| Taxa de uso do autocomplete | % de devices criados com autocomplete | Analytics event |
| Itens no catálogo local | Média de itens por tenant | Firestore query |
| Itens pendentes de revisão | Fila de curadoria | Firestore count |
| Taxa de aprovação | % de itens aprovados vs rejeitados | Dashboard admin |
| Top marcas/modelos | Mais usados globalmente | Aggregation query |

### 8.2 Dashboard de Métricas (Conceito)

```
╔═══════════════════════════════════════════════════════════╗
║  📊 Catálogo de Dispositivos - Métricas                  ║
╠═══════════════════════════════════════════════════════════╣
║                                                           ║
║  Catálogo Global:                                         ║
║  • Total de modelos: 2.145                               ║
║  • Segmentos: 5                                          ║
║  • Fonte Rafsoft: 450 (21%)                              ║
║  • Fonte Community: 1.695 (79%)                          ║
║                                                           ║
║  Curadoria:                                               ║
║  • Pendentes de revisão: 23                              ║
║  • Aprovados este mês: 145                               ║
║  • Taxa de aprovação: 78%                                ║
║                                                           ║
║  Top Marcas (Global):                                     ║
║  1. Samsung - 1.234 usos                                 ║
║  2. LG - 987 usos                                        ║
║  3. Apple - 765 usos                                     ║
║                                                           ║
║  Top Contribuidores:                                      ║
║  1. Clima Técnica - 34 modelos aprovados                ║
║  2. Cell Repair Pro - 28 modelos                         ║
║  3. Auto Center Silva - 19 modelos                       ║
╚═══════════════════════════════════════════════════════════╝
```

---

## 9. Considerações Finais

### 9.1 Vantagens da Abordagem

| Aspecto | Benefício |
|---------|-----------|
| **Progressiva** | Cada etapa entrega valor independente |
| **Escalável** | Catálogo cresce organicamente |
| **Isolamento** | Respeita arquitetura multi-tenant |
| **Performance** | Cache nativo do Firestore |
| **Custo** | Tenants fazem o trabalho de catalogação |
| **Qualidade** | Curadoria garante padronização |

### 9.2 Próximos Passos Opcionais

1. **Dashboard Admin Web**: Interface visual para curadoria
2. **Gamificação**: Badges para tenants contribuidores
3. **ML/AI**: Sugestão automática de correções de typos
4. **Analytics**: Insights sobre marcas/modelos mais problemáticos
5. **API Pública**: Permitir integrações externas

---

**Documento criado em:** Janeiro 2026
**Versão:** 1.0
**Responsável:** Equipe PráticOS
