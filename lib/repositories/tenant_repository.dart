import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:praticos/models/base_audit_company.dart';

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
      // Since T extends BaseAuditCompany which extends Base, id is mutable.
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
      case FilterOperator.isNotEqualTo:
         return query.where(filter.field, isNotEqualTo: filter.value);
      case FilterOperator.isGreaterThanOrEqualTo:
        return query.where(filter.field, isGreaterThanOrEqualTo: filter.value);
      case FilterOperator.isLessThanOrEqualTo:
        return query.where(filter.field, isLessThanOrEqualTo: filter.value);
      case FilterOperator.arrayContains:
        return query.where(filter.field, arrayContains: filter.value);
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
