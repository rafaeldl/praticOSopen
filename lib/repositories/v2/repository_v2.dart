import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:praticos/models/base_audit_company.dart';
import 'package:praticos/repositories/repository.dart';
import 'package:praticos/repositories/tenant_repository.dart';

/// Base class para repositories V2 usando estrutura de subcollections por tenant.
///
/// Esta classe serve como wrapper para os TenantRepository, expondo uma API
/// simplificada para os stores consumirem.
///
/// Estrutura: `/companies/{companyId}/{collection}/{docId}`
abstract class RepositoryV2<T extends BaseAuditCompany?> {
  /// Repository de tenant (subcollections).
  TenantRepository<T> get tenantRepo;

  // ═══════════════════════════════════════════════════════════════════
  // Single Document Operations
  // ═══════════════════════════════════════════════════════════════════

  /// Busca um documento por ID.
  Future<T?> getSingle(String companyId, String? id) async {
    if (id == null) return null;
    return await tenantRepo.getSingle(companyId, id);
  }

  /// Stream de um documento específico.
  Stream<T?> streamSingle(String companyId, String? id) {
    if (id == null) return Stream.value(null);
    return tenantRepo.streamSingle(companyId, id);
  }

  // ═══════════════════════════════════════════════════════════════════
  // List Operations
  // ═══════════════════════════════════════════════════════════════════

  /// Stream de todos os documentos do tenant.
  Stream<List<T>> streamList(String companyId) {
    return tenantRepo.streamList(companyId);
  }

  /// Busca lista de documentos com query.
  Future<List<T>> getQueryList(
    String companyId, {
    List<OrderBy>? orderBy,
    List<QueryArgs>? args,
    int? limit,
    dynamic startAfter,
  }) async {
    return await tenantRepo.getQueryList(
      companyId,
      orderBy: orderBy,
      args: args,
      limit: limit,
      startAfter: startAfter,
    );
  }

  /// Stream de documentos com query customizada.
  Stream<List<T>> streamQueryList(
    String companyId, {
    List<OrderBy>? orderBy,
    List<QueryArgs>? args,
    int? limit,
  }) {
    return tenantRepo.streamQueryList(
      companyId,
      orderBy: orderBy,
      args: args,
      limit: limit,
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
    return await tenantRepo.getListFromTo(
      companyId,
      field,
      from,
      to,
      args: args,
    );
  }

  /// Stream de documentos em um intervalo de datas.
  Stream<List<T>> streamListFromTo(
    String companyId,
    String field,
    DateTime from,
    DateTime to, {
    List<QueryArgs> args = const [],
  }) {
    return tenantRepo.streamListFromTo(
      companyId,
      field,
      from,
      to,
      args: args,
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // CRUD Operations
  // ═══════════════════════════════════════════════════════════════════

  /// Cria ou atualiza um documento.
  Future<void> createItem(String companyId, T item, {String? id}) async {
    // Garante que temos um ID para manter consistência
    if (item?.id == null) {
      if (id != null) {
        item?.id = id;
      } else {
        item?.id = FirebaseFirestore.instance.collection('tmp').doc().id;
      }
    }

    await tenantRepo.createItem(companyId, item, id: item?.id);
  }

  /// Atualiza um documento existente.
  Future<void> updateItem(String companyId, T item) async {
    await tenantRepo.updateItem(companyId, item);
  }

  /// Remove um documento.
  Future<void> removeItem(String companyId, String? id) async {
    if (id == null) return;
    await tenantRepo.removeItem(companyId, id);
  }
}
