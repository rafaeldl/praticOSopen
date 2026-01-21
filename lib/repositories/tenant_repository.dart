import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:praticos/models/base_audit_company.dart';
import 'package:praticos/repositories/repository.dart';
import 'package:praticos/global.dart';

/// Repository base para entidades com isolamento por tenant usando subcollections.
///
/// Usa a estrutura: `/companies/{companyId}/{collection}/{docId}`
///
/// Esta classe é a base para todos os repositories que trabalham com
/// dados isolados por tenant (orders, customers, devices, etc.).
///
/// Exemplo de uso:
/// ```dart
/// class TenantOrderRepository extends TenantRepository<Order?> {
///   TenantOrderRepository() : super('orders');
///
///   @override
///   Order fromJson(data) => Order.fromJson(data);
///
///   @override
///   Map<String, dynamic> toJson(Order? order) => order!.toJson();
/// }
/// ```
abstract class TenantRepository<T extends BaseAuditCompany?> {
  final String collection;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  TenantRepository(this.collection);

  // ═══════════════════════════════════════════════════════════════════
  // Collection Reference
  // ═══════════════════════════════════════════════════════════════════

  /// Retorna a referência da collection para um tenant específico.
  ///
  /// Path: `/companies/{companyId}/{collection}`
  CollectionReference<Map<String, dynamic>> _getCollection(String companyId) {
    return _db.collection('companies').doc(companyId).collection(collection);
  }

  // ═══════════════════════════════════════════════════════════════════
  // Single Document Operations
  // ═══════════════════════════════════════════════════════════════════

  /// Busca um documento por ID.
  Future<T?> getSingle(String companyId, String? id) async {
    if (id == null) return null;
    final snap = await _getCollection(companyId).doc(id).get();
    if (!snap.exists) return null;
    return _fromJsonID(id, snap.data()!);
  }

  /// Stream de um documento específico.
  Stream<T?> streamSingle(String companyId, String? id) {
    if (id == null) return Stream.value(null);
    return _getCollection(companyId).doc(id).snapshots().map((snap) {
      if (!snap.exists) return null;
      return _fromJsonID(id, snap.data()!);
    });
  }

  // ═══════════════════════════════════════════════════════════════════
  // List Operations
  // ═══════════════════════════════════════════════════════════════════

  /// Stream de todos os documentos do tenant.
  Stream<List<T>> streamList(String companyId) {
    return _getCollection(companyId).snapshots().map(
          (snap) => snap.docs.map((doc) => _fromJsonID(doc.id, doc.data())).toList(),
        );
  }

  /// Busca lista de documentos com query.
  Future<List<T>> getQueryList(
    String companyId, {
    List<OrderBy>? orderBy,
    List<QueryArgs>? args,
    int? limit,
    dynamic startAfter,
  }) async {
    Query<Map<String, dynamic>> query = _getCollection(companyId);

    // Aplicar filtros (sem necessidade de company.id!)
    if (args != null) {
      for (final arg in args) {
        query = _applyQueryArg(query, arg);
      }
    }

    // Aplicar ordenação
    if (orderBy != null) {
      for (final order in orderBy) {
        query = query.orderBy(order.field, descending: order.descending);
      }
    }

    // Aplicar limite
    if (limit != null) {
      query = query.limit(limit);
    }

    // Aplicar paginação
    if (startAfter != null && orderBy != null) {
      query = query.startAfter([startAfter]);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => _fromJsonID(doc.id, doc.data()))
        .toList();
  }

  /// Stream de documentos com query customizada.
  Stream<List<T>> streamQueryList(
    String companyId, {
    List<OrderBy>? orderBy,
    List<QueryArgs>? args,
    int? limit,
  }) {
    Query<Map<String, dynamic>> query = _getCollection(companyId);

    // Aplicar ordenação primeiro (melhor para índices)
    if (orderBy != null) {
      for (final order in orderBy) {
        query = query.orderBy(order.field, descending: order.descending);
      }
    }

    // Aplicar filtros (sem necessidade de company.id!)
    if (args != null) {
      for (final arg in args) {
        query = _applyQueryArg(query, arg);
      }
    }

    // Aplicar limite
    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map(
          (snap) => snap.docs.map((doc) => _fromJsonID(doc.id, doc.data())).toList(),
        );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Date Range Operations
  // ═══════════════════════════════════════════════════════════════════

  /// Busca documentos em um intervalo de datas.
  Future<List<T>> getListFromTo(
    String companyId,
    String field,
    DateTime from,
    DateTime to, {
    List<QueryArgs> args = const [],
  }) async {
    var query = _getCollection(companyId).orderBy(field);

    for (final arg in args) {
      query = query.where(arg.key, isEqualTo: arg.value);
    }

    final snapshot = await query.startAt([from]).endAt([to]).get();
    return snapshot.docs
        .map((doc) => _fromJsonID(doc.id, doc.data()))
        .toList();
  }

  /// Stream de documentos em um intervalo de datas.
  Stream<List<T>> streamListFromTo(
    String companyId,
    String field,
    DateTime from,
    DateTime to, {
    List<QueryArgs> args = const [],
  }) {
    var ref = _getCollection(companyId).orderBy(field, descending: true);

    for (final arg in args) {
      ref = ref.where(arg.key, isEqualTo: arg.value);
    }

    return ref.startAfter([to]).endAt([from]).snapshots().map(
          (snap) => snap.docs.map((doc) => _fromJsonID(doc.id, doc.data())).toList(),
        );
  }

  // ═══════════════════════════════════════════════════════════════════
  // CRUD Operations
  // ═══════════════════════════════════════════════════════════════════

  /// Aplica campos de audit antes de persistir.
  /// - createdAt/createdBy: só seta se null (preserva criador original)
  /// - updatedAt/updatedBy: sempre seta (última modificação)
  void _applyAuditFields(T item) {
    if (item == null) return;

    final now = DateTime.now();
    final currentUser = Global.userAggr;

    item.createdAt ??= now;
    item.createdBy ??= currentUser;
    item.updatedAt = now;
    item.updatedBy = currentUser;
  }

  /// Cria ou atualiza um documento.
  ///
  /// Se o item já tiver um ID, atualiza o documento existente.
  /// Caso contrário, cria um novo documento.
  Future<void> createItem(String companyId, T item, {String? id}) async {
    _applyAuditFields(item);
    if (item?.id != null) {
      final json = toJson(item);
      json.remove('number'); // Compatibilidade com Order
      await _getCollection(companyId)
          .doc(item?.id)
          .set(json, SetOptions(merge: true));
    } else if (id != null) {
      final json = toJson(item);
      json.remove('number');
      await _getCollection(companyId).doc(id).set(json, SetOptions(merge: true));
      item?.id = id;
    } else {
      final docRef = await _getCollection(companyId).add(toJson(item));
      item?.id = docRef.id;
    }
  }

  /// Atualiza um documento existente.
  Future<void> updateItem(String companyId, T item) {
    _applyAuditFields(item);

    return _getCollection(companyId)
        .doc(item?.id)
        .set(toJson(item), SetOptions(merge: true));
  }

  /// Remove um documento.
  Future<void> removeItem(String companyId, String? id) {
    if (id == null) return Future.value();
    return _getCollection(companyId).doc(id).delete();
  }

  // ═══════════════════════════════════════════════════════════════════
  // Pagination Support
  // ═══════════════════════════════════════════════════════════════════

  /// Busca documentos com paginação usando DocumentSnapshot.
  Future<QuerySnapshot<Map<String, dynamic>>> getQueryWithPagination(
    String companyId, {
    List<OrderBy>? orderBy,
    List<QueryArgs>? args,
    int? limit,
    DocumentSnapshot? startAfterDocument,
  }) async {
    Query<Map<String, dynamic>> query = _getCollection(companyId);

    // Aplicar filtros
    if (args != null) {
      for (final arg in args) {
        query = _applyQueryArg(query, arg);
      }
    }

    // Aplicar ordenação
    if (orderBy != null) {
      for (final order in orderBy) {
        query = query.orderBy(order.field, descending: order.descending);
      }
    }

    // Aplicar paginação
    if (startAfterDocument != null) {
      query = query.startAfterDocument(startAfterDocument);
    }

    // Aplicar limite
    if (limit != null) {
      query = query.limit(limit);
    }

    return query.get();
  }

  // ═══════════════════════════════════════════════════════════════════
  // Helper Methods
  // ═══════════════════════════════════════════════════════════════════

  /// Adiciona o ID ao map de dados e converte para o tipo T.
  T _fromJsonID(String? id, Map<String, dynamic> data) {
    final dataWithId = {...data, 'id': id};
    return fromJson(dataWithId);
  }

  /// Aplica um QueryArg à query.
  Query<Map<String, dynamic>> _applyQueryArg(
    Query<Map<String, dynamic>> query,
    QueryArgs arg,
  ) {
    // Ignora filtros de company.id (não necessário em subcollections)
    if (arg.key == 'company.id') return query;

    switch (arg.oper) {
      case 'isEqualTo':
        return query.where(arg.key, isEqualTo: arg.value);
      case 'isNotEqualTo':
        return query.where(arg.key, isNotEqualTo: arg.value);
      case 'isGreaterThan':
        return query.where(arg.key, isGreaterThan: arg.value);
      case 'isGreaterThanOrEqualTo':
        return query.where(arg.key, isGreaterThanOrEqualTo: arg.value);
      case 'isLessThan':
        return query.where(arg.key, isLessThan: arg.value);
      case 'isLessThanOrEqualTo':
        return query.where(arg.key, isLessThanOrEqualTo: arg.value);
      case 'arrayContains':
        return query.where(arg.key, arrayContains: arg.value);
      case 'arrayContainsAny':
        return query.where(arg.key, arrayContainsAny: arg.value);
      case 'whereIn':
        return query.where(arg.key, whereIn: arg.value);
      case 'whereNotIn':
        return query.where(arg.key, whereNotIn: arg.value);
      case 'isNull':
        return query.where(arg.key, isNull: arg.value);
      default:
        return query.where(arg.key, isEqualTo: arg.value);
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // Abstract Methods
  // ═══════════════════════════════════════════════════════════════════

  /// Converte um Map para o tipo T.
  T fromJson(Map<String, dynamic> data);

  /// Converte um item do tipo T para Map.
  Map<String, dynamic> toJson(T item);
}
