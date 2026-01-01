# Plano de Migração: Multi-Tenancy com Subcollections

## Sumário

1. [Contexto e Motivação](#1-contexto-e-motivação)
2. [Arquitetura Atual vs Proposta](#2-arquitetura-atual-vs-proposta)
3. [Vantagens da Migração](#3-vantagens-da-migração)
4. [Riscos e Cuidados](#4-riscos-e-cuidados)
5. [Plano de Migração](#5-plano-de-migração)
6. [Implementação Detalhada](#6-implementação-detalhada)
7. [Plano de Rollback](#7-plano-de-rollback)
8. [Checklist de Validação](#8-checklist-de-validação)

---

## 1. Contexto e Motivação

### 1.1 Situação Atual

O PraticOS utiliza uma arquitetura multi-tenant baseada em **filtragem por campo** (field-based filtering). Todos os documentos de entidades como `orders`, `customers`, `devices`, etc., são armazenados em collections de nível raiz e filtrados por `company.id`.

```
Estrutura Atual:
/orders/{orderId}           → { company: { id: "abc" }, ... }
/customers/{customerId}     → { company: { id: "abc" }, ... }
/devices/{deviceId}         → { company: { id: "abc" }, ... }
```

### 1.2 Por Que Migrar?

A estrutura atual apresenta limitações que podem impactar **segurança**, **performance** e **manutenibilidade** à medida que o sistema escala:

1. **Risco de Vazamento de Dados**: Um bug no código que esqueça o filtro `company.id` pode expor dados de outros tenants.

2. **Complexidade nas Security Rules**: Cada regra precisa validar `resource.data.company.id`, aumentando a chance de erros.

3. **Índices Compostos Obrigatórios**: Toda query precisa incluir `company.id`, multiplicando a quantidade de índices necessários.

4. **Performance Degradada**: À medida que a collection cresce com dados de todos os tenants, as queries ficam mais lentas.

---

## 2. Arquitetura Atual vs Proposta

### 2.1 Estrutura Atual (Field-Based)

```
Firestore
├── /companies/{companyId}
├── /users/{userId}
├── /orders/{orderId}           ← Todos os tenants misturados
│     └── { company: { id, name }, customer, device, ... }
├── /customers/{customerId}     ← Filtro por company.id
├── /devices/{deviceId}
├── /products/{productId}
├── /services/{serviceId}
└── /roles/{roleId}
```

**Query atual:**
```dart
_db.collection('orders')
   .where('company.id', isEqualTo: companyId)
   .orderBy('createdAt', descending: true)
```

### 2.2 Estrutura Proposta (Subcollections per Tenant)

```
Firestore
├── /users/{userId}                           ← Global (usuário pode ter múltiplas empresas)
└── /companies/{companyId}
      ├── /orders/{orderId}                   ← Isolado por tenant
      │     ├── /photos/{photoId}             ← Subcollection (resolve limite 1MB)
      │     └── { customer, device, services[], products[], ... }
      ├── /customers/{customerId}
      ├── /devices/{deviceId}
      ├── /products/{productId}
      ├── /services/{serviceId}
      └── /roles/{roleId}
```

**Query proposta:**
```dart
_db.collection('companies')
   .doc(companyId)
   .collection('orders')
   .orderBy('createdAt', descending: true)
// Não precisa filtrar por company.id - já está no path!
```

---

## 3. Vantagens da Migração

### 3.1 Segurança

| Aspecto | Antes | Depois |
|---------|-------|--------|
| Isolamento | Lógico (filtro) | **Estrutural (path)** |
| Vazamento por bug | Possível | **Impossível** |
| Security Rules | Complexas | **Triviais** |

**Security Rules simplificadas:**

```javascript
// ANTES: Propenso a erros - precisa validar em cada regra
match /orders/{orderId} {
  allow read: if request.auth != null
    && resource.data.company.id == request.auth.token.companyId;
}

// DEPOIS: Impossível acessar dados de outro tenant
match /companies/{companyId}/{collection}/{docId} {
  allow read, write: if request.auth != null
    && request.auth.token.companyId == companyId;
}
```

### 3.2 Performance

| Métrica | Antes | Depois |
|---------|-------|--------|
| Tamanho da collection | Todos os tenants | **Apenas 1 tenant** |
| Índices necessários | `company.id` + campos | **Apenas campos** |
| Custo de storage | Maior (índices) | **Menor** |
| Latência de queries | Cresce com volume total | **Constante por tenant** |

### 3.3 Índices

**Antes:** Cada combinação de filtro precisa de índice composto com `company.id`:
```
company.id + createdAt
company.id + status + createdAt
company.id + customer.id
company.id + number
```

**Depois:** Índices single-field são automáticos:
```
createdAt           ← Automático
status + createdAt  ← Único índice composto necessário
```

### 3.4 Código Mais Limpo

**Antes:**
```dart
Future<Stream<List<Order>>> getOrders() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? companyId = prefs.getString('companyId');

  List<QueryArgs> filterList = [QueryArgs('company.id', companyId)];
  List<OrderBy> orderBy = [OrderBy('createdAt', descending: true)];

  return streamQueryList(orderBy: orderBy, args: filterList);
}
```

**Depois:**
```dart
Stream<List<Order>> getOrders(String companyId) {
  return _db.collection('companies')
      .doc(companyId)
      .collection('orders')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map((d) => Order.fromJson(d.data())).toList());
}
```

### 3.5 Benefícios Adicionais

- **Billing por tenant**: Possível calcular custos de reads/writes por empresa
- **Backup seletivo**: Exportar dados de um tenant específico facilmente
- **GDPR/LGPD**: Deletar todos os dados de um tenant é trivial
- **Escalabilidade**: Sharding natural por tenant

---

## 4. Riscos e Cuidados

### 4.1 Riscos Identificados

| Risco | Probabilidade | Impacto | Mitigação |
|-------|---------------|---------|-----------|
| Perda de dados na migração | Baixa | **Crítico** | Backup + validação + dual-write |
| Inconsistência durante transição | Média | Alto | Dual-write por 1+ semana |
| Downtime durante cutover | Baixa | Médio | Migração sem interrupção |
| Bugs no novo código | Média | Alto | Feature flags + rollback |
| Queries cross-tenant quebradas | Alta | Médio | Collection groups para admin |

### 4.2 Cuidados Essenciais

#### Backup Obrigatório
```bash
# Antes de qualquer migração
gcloud firestore export gs://praticos-backup/pre-migration-$(date +%Y%m%d)
```

#### Manter IDs Iguais
Os documentos migrados DEVEM manter o mesmo `id` para:
- Preservar referências em aggregates
- Permitir rollback sem quebrar relacionamentos
- Manter URLs de compartilhamento funcionando

#### Não Deletar Dados Antigos Prematuramente
Manter estrutura antiga por **mínimo 4 semanas** após cutover completo.

#### Testar em Ambiente de Staging
Executar migração completa em projeto Firebase de teste antes de produção.

### 4.3 O Que NÃO Migrar

| Entidade | Motivo |
|----------|--------|
| `/users` | Usuário pode pertencer a múltiplas empresas |
| `/companies` (documento raiz) | É o próprio tenant container |

---

## 5. Plano de Migração

### 5.1 Visão Geral das Fases

```
┌─────────────────────────────────────────────────────────────────────┐
│  FASE 1: Preparação                                                 │
│  Duração: 1-2 semanas │ Risco: Nenhum │ Impacto: Nenhum            │
│  - Criar TenantRepository base                                      │
│  - Implementar feature flags                                        │
│  - Preparar Security Rules                                          │
│  - Criar índices na nova estrutura                                  │
├─────────────────────────────────────────────────────────────────────┤
│  FASE 2: Dual-Write                                                 │
│  Duração: 1-2 semanas │ Risco: Baixo │ Impacto: Mínimo             │
│  - Toda escrita vai para AMBAS as estruturas                        │
│  - Leitura continua da estrutura antiga                             │
│  - Monitorar erros e latência                                       │
├─────────────────────────────────────────────────────────────────────┤
│  FASE 3: Migração de Dados Históricos                               │
│  Duração: 1-2 dias │ Risco: Médio │ Impacto: Nenhum                │
│  - Script batch para copiar dados existentes                        │
│  - Validação de integridade                                         │
│  - Manter dual-write ativo                                          │
├─────────────────────────────────────────────────────────────────────┤
│  FASE 4: Dual-Read com Fallback                                     │
│  Duração: 1 semana │ Risco: Baixo │ Impacto: Mínimo                │
│  - Leitura primária da nova estrutura                               │
│  - Fallback automático para antiga em caso de erro                  │
│  - Logs para identificar inconsistências                            │
├─────────────────────────────────────────────────────────────────────┤
│  FASE 5: Cutover                                                    │
│  Duração: 1 dia │ Risco: Médio │ Impacto: Baixo                    │
│  - Ativar nova estrutura como única fonte                           │
│  - Manter dual-write por segurança                                  │
│  - Monitoramento intensivo                                          │
├─────────────────────────────────────────────────────────────────────┤
│  FASE 6: Cleanup                                                    │
│  Duração: Após 4+ semanas │ Risco: Baixo │ Impacto: Nenhum         │
│  - Desativar dual-write                                             │
│  - Backup final da estrutura antiga                                 │
│  - Remover dados e código legado                                    │
└─────────────────────────────────────────────────────────────────────┘
```

### 5.2 Cronograma Estimado

| Semana | Fase | Atividades |
|--------|------|------------|
| 1-2 | Preparação | Desenvolvimento do código de migração |
| 3 | Dual-Write | Deploy e ativação gradual |
| 3 (fim) | Migração | Executar script de migração |
| 4 | Dual-Read | Validação e monitoramento |
| 5 | Cutover | Ativação da nova estrutura |
| 6-9 | Estabilização | Monitoramento contínuo |
| 10+ | Cleanup | Remoção de código e dados legados |

---

## 6. Implementação Detalhada

### 6.1 Feature Flags

```dart
// lib/config/feature_flags.dart
class FeatureFlags {
  /// Usar nova estrutura de subcollections para tenants
  static const bool useNewTenantStructure = false;

  /// Escrever em ambas as estruturas (antiga e nova)
  static const bool dualWriteEnabled = false;

  /// Ler da nova estrutura com fallback para antiga
  static const bool dualReadEnabled = false;
}
```

### 6.2 Novo Repository Base

```dart
// lib/repositories/tenant_repository.dart
abstract class TenantRepository<T extends BaseAuditCompany?> {
  final String collection;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  TenantRepository(this.collection);

  /// Retorna a collection reference para o tenant específico
  CollectionReference<Map<String, dynamic>> _getCollection(String companyId) {
    return _db
        .collection('companies')
        .doc(companyId)
        .collection(collection);
  }

  /// Busca um documento por ID
  Future<T?> getSingle(String companyId, String id) async {
    final snap = await _getCollection(companyId).doc(id).get();
    if (!snap.exists) return null;
    return fromJson(_addId(id, snap.data()!));
  }

  /// Stream de um documento específico
  Stream<T?> streamSingle(String companyId, String id) {
    return _getCollection(companyId)
        .doc(id)
        .snapshots()
        .map((snap) => snap.exists ? fromJson(_addId(id, snap.data()!)) : null);
  }

  /// Stream de todos os documentos do tenant
  Stream<List<T>> streamList(String companyId) {
    return _getCollection(companyId)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => fromJson(_addId(doc.id, doc.data())))
            .toList());
  }

  /// Stream com query customizada
  Stream<List<T>> streamQuery(
    String companyId, {
    List<QueryFilter>? filters,
    List<QueryOrder>? orderBy,
    int? limit,
  }) {
    Query<Map<String, dynamic>> query = _getCollection(companyId);

    if (filters != null) {
      for (final filter in filters) {
        query = _applyFilter(query, filter);
      }
    }

    if (orderBy != null) {
      for (final order in orderBy) {
        query = query.orderBy(order.field, descending: order.descending);
      }
    }

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map((snap) => snap.docs
        .map((doc) => fromJson(_addId(doc.id, doc.data())))
        .toList());
  }

  /// Cria ou atualiza um documento
  Future<void> save(String companyId, T item) async {
    final json = toJson(item);
    final id = item?.id;

    if (id != null && id.isNotEmpty) {
      await _getCollection(companyId).doc(id).set(json, SetOptions(merge: true));
    } else {
      final docRef = await _getCollection(companyId).add(json);
      item?.id = docRef.id;
    }
  }

  /// Remove um documento
  Future<void> remove(String companyId, String id) {
    return _getCollection(companyId).doc(id).delete();
  }

  /// Adiciona ID ao map de dados
  Map<String, dynamic> _addId(String id, Map<String, dynamic> data) {
    return {...data, 'id': id};
  }

  /// Aplica filtro à query
  Query<Map<String, dynamic>> _applyFilter(
    Query<Map<String, dynamic>> query,
    QueryFilter filter,
  ) {
    switch (filter.operator) {
      case FilterOperator.isEqualTo:
        return query.where(filter.field, isEqualTo: filter.value);
      case FilterOperator.isGreaterThan:
        return query.where(filter.field, isGreaterThan: filter.value);
      case FilterOperator.isLessThan:
        return query.where(filter.field, isLessThan: filter.value);
      // ... outros operadores
    }
  }

  T fromJson(Map<String, dynamic> data);
  Map<String, dynamic> toJson(T item);
}

/// Filtro para queries
class QueryFilter {
  final String field;
  final FilterOperator operator;
  final dynamic value;

  QueryFilter(this.field, this.operator, this.value);
}

enum FilterOperator {
  isEqualTo,
  isNotEqualTo,
  isGreaterThan,
  isGreaterThanOrEqualTo,
  isLessThan,
  isLessThanOrEqualTo,
  arrayContains,
}

/// Ordenação para queries
class QueryOrder {
  final String field;
  final bool descending;

  QueryOrder(this.field, {this.descending = false});
}
```

### 6.3 Repository com Dual-Write

```dart
// lib/repositories/order_repository_v2.dart
class OrderRepositoryV2 {
  final OrderRepository _legacyRepo = OrderRepository();
  final TenantOrderRepository _newRepo = TenantOrderRepository();

  /// Cria ou atualiza uma ordem - escreve em ambas estruturas se dual-write ativo
  Future<void> save(Order order, String companyId) async {
    if (FeatureFlags.dualWriteEnabled) {
      await Future.wait([
        _legacyRepo.createItem(order),
        _newRepo.save(companyId, order),
      ]);
    } else if (FeatureFlags.useNewTenantStructure) {
      await _newRepo.save(companyId, order);
    } else {
      await _legacyRepo.createItem(order);
    }
  }

  /// Remove uma ordem
  Future<void> remove(String id, String companyId) async {
    if (FeatureFlags.dualWriteEnabled) {
      await Future.wait([
        _legacyRepo.removeItem(id),
        _newRepo.remove(companyId, id),
      ]);
    } else if (FeatureFlags.useNewTenantStructure) {
      await _newRepo.remove(companyId, id);
    } else {
      await _legacyRepo.removeItem(id);
    }
  }

  /// Stream de ordens - com fallback se dual-read ativo
  Stream<List<Order?>> streamOrders(String companyId) {
    if (FeatureFlags.useNewTenantStructure) {
      final stream = _newRepo.streamList(companyId);

      if (FeatureFlags.dualReadEnabled) {
        return stream.handleError((error) {
          print('[OrderRepository] Fallback para estrutura antiga: $error');
          return _legacyRepo.getOrders();
        });
      }

      return stream;
    }

    return _legacyRepo.getOrders();
  }
}
```

### 6.4 Script de Migração

```dart
// scripts/migrate_tenant_data.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class TenantDataMigration {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const int batchSize = 500;
  static const List<String> collectionsToMigrate = [
    'orders',
    'customers',
    'devices',
    'products',
    'services',
    'roles',
  ];

  /// Executa migração completa
  Future<MigrationReport> migrateAll() async {
    final report = MigrationReport();

    print('════════════════════════════════════════════════════════════');
    print('  INICIANDO MIGRAÇÃO DE DADOS PARA SUBCOLLECTIONS');
    print('════════════════════════════════════════════════════════════\n');

    for (final collection in collectionsToMigrate) {
      final result = await migrateCollection(collection);
      report.addResult(collection, result);
    }

    print('\n════════════════════════════════════════════════════════════');
    print('  MIGRAÇÃO CONCLUÍDA');
    print('════════════════════════════════════════════════════════════');
    print(report.summary());

    return report;
  }

  /// Migra uma collection específica
  Future<CollectionMigrationResult> migrateCollection(String collectionName) async {
    print('► Migrando collection: $collectionName');

    final result = CollectionMigrationResult(collectionName);
    final snapshot = await _db.collection(collectionName).get();

    WriteBatch batch = _db.batch();
    int batchCount = 0;

    for (final doc in snapshot.docs) {
      try {
        final data = doc.data();
        final companyId = data['company']?['id'] as String?;

        if (companyId == null || companyId.isEmpty) {
          print('  ⚠️  Doc ${doc.id} sem company.id - pulando');
          result.skipped++;
          continue;
        }

        // Verificar se já existe na nova estrutura
        final existingDoc = await _db
            .collection('companies')
            .doc(companyId)
            .collection(collectionName)
            .doc(doc.id)
            .get();

        if (existingDoc.exists) {
          // Comparar timestamps para decidir qual é mais recente
          final existingUpdatedAt = existingDoc.data()?['updatedAt'];
          final currentUpdatedAt = data['updatedAt'];

          if (existingUpdatedAt != null &&
              currentUpdatedAt != null &&
              existingUpdatedAt.compareTo(currentUpdatedAt) >= 0) {
            result.skipped++;
            continue;
          }
        }

        // Criar referência na nova estrutura (mantendo mesmo ID)
        final newRef = _db
            .collection('companies')
            .doc(companyId)
            .collection(collectionName)
            .doc(doc.id);

        batch.set(newRef, data);
        batchCount++;
        result.migrated++;

        // Commit a cada batchSize documentos
        if (batchCount >= batchSize) {
          await batch.commit();
          print('  ✓ Migrados ${result.migrated} documentos...');
          batch = _db.batch();
          batchCount = 0;
        }

      } catch (e) {
        print('  ✗ Erro ao migrar ${doc.id}: $e');
        result.errors.add('${doc.id}: $e');
      }
    }

    // Commit final
    if (batchCount > 0) {
      await batch.commit();
    }

    print('  ✓ $collectionName: ${result.migrated} migrados, '
          '${result.skipped} pulados, ${result.errors.length} erros\n');

    return result;
  }

  /// Valida a migração comparando estruturas
  Future<ValidationReport> validateMigration(String collectionName) async {
    print('► Validando collection: $collectionName');

    final report = ValidationReport(collectionName);
    final oldDocs = await _db.collection(collectionName).get();

    for (final doc in oldDocs.docs) {
      final data = doc.data();
      final companyId = data['company']?['id'] as String?;

      if (companyId == null) {
        report.skipped++;
        continue;
      }

      final newDoc = await _db
          .collection('companies')
          .doc(companyId)
          .collection(collectionName)
          .doc(doc.id)
          .get();

      if (!newDoc.exists) {
        report.missing.add(doc.id);
      } else {
        final newData = newDoc.data()!;
        if (data['updatedAt'] != newData['updatedAt']) {
          report.divergent.add(doc.id);
        } else {
          report.valid++;
        }
      }
    }

    print('  Resultado: ${report.valid} válidos, '
          '${report.missing.length} faltando, '
          '${report.divergent.length} divergentes\n');

    return report;
  }
}

class MigrationReport {
  final Map<String, CollectionMigrationResult> results = {};

  void addResult(String collection, CollectionMigrationResult result) {
    results[collection] = result;
  }

  String summary() {
    final buffer = StringBuffer();
    int totalMigrated = 0;
    int totalSkipped = 0;
    int totalErrors = 0;

    for (final entry in results.entries) {
      totalMigrated += entry.value.migrated;
      totalSkipped += entry.value.skipped;
      totalErrors += entry.value.errors.length;
    }

    buffer.writeln('Total migrado: $totalMigrated documentos');
    buffer.writeln('Total pulado: $totalSkipped documentos');
    buffer.writeln('Total erros: $totalErrors');

    return buffer.toString();
  }
}

class CollectionMigrationResult {
  final String collection;
  int migrated = 0;
  int skipped = 0;
  final List<String> errors = [];

  CollectionMigrationResult(this.collection);
}

class ValidationReport {
  final String collection;
  int valid = 0;
  int skipped = 0;
  final List<String> missing = [];
  final List<String> divergent = [];

  ValidationReport(this.collection);
}
```

### 6.5 Security Rules Atualizadas

```javascript
// firestore.rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // ══════════════════════════════════════════════════════════════
    // USUÁRIOS - Global (usuário pode pertencer a múltiplas empresas)
    // ══════════════════════════════════════════════════════════════
    match /users/{userId} {
      allow read: if request.auth != null && request.auth.uid == userId;
      allow write: if request.auth != null && request.auth.uid == userId;
    }

    // ══════════════════════════════════════════════════════════════
    // ESTRUTURA ANTIGA (manter durante período de migração)
    // Remover após cleanup completo
    // ══════════════════════════════════════════════════════════════
    match /orders/{orderId} {
      allow read, write: if request.auth != null
        && resource.data.company.id in request.auth.token.companies;
    }

    match /customers/{customerId} {
      allow read, write: if request.auth != null
        && resource.data.company.id in request.auth.token.companies;
    }

    match /devices/{deviceId} {
      allow read, write: if request.auth != null
        && resource.data.company.id in request.auth.token.companies;
    }

    match /products/{productId} {
      allow read, write: if request.auth != null
        && resource.data.company.id in request.auth.token.companies;
    }

    match /services/{serviceId} {
      allow read, write: if request.auth != null
        && resource.data.company.id in request.auth.token.companies;
    }

    match /roles/{roleId} {
      allow read, write: if request.auth != null
        && resource.data.company.id in request.auth.token.companies;
    }

    // ══════════════════════════════════════════════════════════════
    // NOVA ESTRUTURA - Subcollections por Tenant
    // ══════════════════════════════════════════════════════════════
    match /companies/{companyId} {
      // Documento da empresa - apenas membros podem ler
      allow read: if request.auth != null
        && companyId in request.auth.token.companies;

      // Apenas admins podem editar dados da empresa
      allow write: if request.auth != null
        && companyId in request.auth.token.companies
        && request.auth.token.roles[companyId] == 'admin';

      // ────────────────────────────────────────────────────────────
      // Subcollections - isoladas automaticamente por tenant
      // ────────────────────────────────────────────────────────────
      match /orders/{orderId} {
        allow read, write: if request.auth != null
          && companyId in request.auth.token.companies;

        // Subcollection de fotos dentro de orders
        match /photos/{photoId} {
          allow read, write: if request.auth != null
            && companyId in request.auth.token.companies;
        }
      }

      match /customers/{customerId} {
        allow read, write: if request.auth != null
          && companyId in request.auth.token.companies;
      }

      match /devices/{deviceId} {
        allow read, write: if request.auth != null
          && companyId in request.auth.token.companies;
      }

      match /products/{productId} {
        allow read, write: if request.auth != null
          && companyId in request.auth.token.companies;
      }

      match /services/{serviceId} {
        allow read, write: if request.auth != null
          && companyId in request.auth.token.companies;
      }

      match /roles/{roleId} {
        allow read, write: if request.auth != null
          && companyId in request.auth.token.companies;
      }
    }
  }
}
```

### 6.6 Índices para Nova Estrutura

```json
// firestore.indexes.json
{
  "indexes": [
    {
      "collectionGroup": "orders",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "status", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "orders",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "done", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "orders",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "paid", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "orders",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "customer.id", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    }
  ],
  "fieldOverrides": []
}
```

---

## 7. Plano de Rollback

### 7.1 Cenários de Rollback

| Cenário | Ação | Tempo Estimado |
|---------|------|----------------|
| Bug crítico após cutover | Reverter feature flags | 5 minutos |
| Inconsistência de dados | Sincronizar da estrutura antiga | 1-2 horas |
| Falha na migração | Abortar e reverter | 30 minutos |

### 7.2 Procedimento de Rollback

```dart
// 1. Reverter feature flags imediatamente
class FeatureFlags {
  static const bool useNewTenantStructure = false;  // ← REVERTER
  static const bool dualWriteEnabled = true;        // ← MANTER
  static const bool dualReadEnabled = false;
}

// 2. Se houver dados escritos apenas na nova estrutura durante cutover,
//    sincronizar de volta para estrutura antiga:
Future<void> emergencyRollback() async {
  final companies = await _db.collection('companies').get();

  for (final company in companies.docs) {
    for (final collection in collectionsToMigrate) {
      final newDocs = await _db
          .collection('companies')
          .doc(company.id)
          .collection(collection)
          .get();

      final batch = _db.batch();

      for (final doc in newDocs.docs) {
        final oldRef = _db.collection(collection).doc(doc.id);
        batch.set(oldRef, doc.data(), SetOptions(merge: true));
      }

      await batch.commit();
    }
  }
}
```

### 7.3 Comunicação em Caso de Rollback

1. Notificar equipe via Slack/Discord imediatamente
2. Documentar o problema encontrado
3. Criar issue no GitHub com detalhes
4. Agendar post-mortem após resolução

---

## 8. Checklist de Validação

### 8.1 Pré-Migração

- [ ] Backup completo do Firestore realizado
- [ ] Código de migração testado em ambiente de staging
- [ ] Feature flags implementadas e testadas
- [ ] Security Rules atualizadas e deployadas
- [ ] Índices criados na nova estrutura
- [ ] Plano de rollback documentado e testado
- [ ] Equipe notificada sobre a migração

### 8.2 Durante Migração

- [ ] Dual-write ativado sem erros
- [ ] Script de migração executado com sucesso
- [ ] Validação de integridade executada
- [ ] Nenhum documento faltando ou divergente
- [ ] Logs monitorados para erros

### 8.3 Pós-Cutover

- [ ] Nova estrutura ativada como primária
- [ ] Todas as funcionalidades testadas manualmente
- [ ] Métricas de performance verificadas
- [ ] Nenhum erro nos logs de produção
- [ ] Usuários não reportaram problemas

### 8.4 Pós-Cleanup

- [ ] Dual-write desativado
- [ ] Backup final da estrutura antiga realizado
- [ ] Dados antigos removidos
- [ ] Código legado removido
- [ ] Documentação atualizada

---

## Referências

- [Firestore Multi-tenancy Best Practices](https://firebase.google.com/docs/firestore/solutions/aggregation)
- [Firestore Security Rules](https://firebase.google.com/docs/firestore/security/get-started)
- [Firestore Indexes](https://firebase.google.com/docs/firestore/query-data/indexing)

---

**Documento criado em:** Janeiro 2026
**Última atualização:** -
**Responsável:** Equipe PraticOS
