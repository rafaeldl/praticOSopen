import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:praticos/config/feature_flags.dart';
import 'package:praticos/models/base_audit_company.dart';
import 'package:praticos/repositories/repository.dart';
import 'package:praticos/repositories/tenant_repository.dart';

/// Base class para repositories V2 com suporte a dual-write e dual-read.
///
/// Esta classe serve como wrapper entre os repositories legados
/// (field-based filtering) e os novos tenant repositories (subcollections).
///
/// O comportamento é controlado pelas feature flags:
/// - `dualWriteEnabled`: Escreve em ambas as estruturas
/// - `dualReadEnabled`: Lê da nova estrutura com fallback para antiga
/// - `useNewTenantStructure`: Usa exclusivamente a nova estrutura
///
/// Exemplo de uso:
/// ```dart
/// class OrderRepositoryV2 extends RepositoryV2<Order?> {
///   final OrderRepository _legacy = OrderRepository();
///   final TenantOrderRepository _tenant = TenantOrderRepository();
///
///   @override
///   Repository<Order?> get legacyRepo => _legacy;
///
///   @override
///   TenantRepository<Order?> get tenantRepo => _tenant;
/// }
/// ```
abstract class RepositoryV2<T extends BaseAuditCompany?> {
  /// Repository legado (field-based filtering).
  Repository<T> get legacyRepo;

  /// Repository de tenant (subcollections).
  TenantRepository<T> get tenantRepo;

  // ═══════════════════════════════════════════════════════════════════
  // Single Document Operations
  // ═══════════════════════════════════════════════════════════════════

  /// Busca um documento por ID.
  Future<T?> getSingle(String companyId, String? id) async {
    if (id == null) return null;

    if (FeatureFlags.shouldReadFromNew) {
      try {
        return await tenantRepo.getSingle(companyId, id);
      } catch (e) {
        if (FeatureFlags.shouldFallbackToLegacy) {
          print('[RepositoryV2] Fallback getSingle: $e');
          return await legacyRepo.getSingle(id);
        }
        rethrow;
      }
    }

    return await legacyRepo.getSingle(id);
  }

  /// Stream de um documento específico.
  Stream<T?> streamSingle(String companyId, String? id) {
    if (id == null) return Stream.value(null);

    if (FeatureFlags.shouldReadFromNew) {
      final stream = tenantRepo.streamSingle(companyId, id);

      if (FeatureFlags.shouldFallbackToLegacy) {
        return stream.handleError((error) {
          print('[RepositoryV2] Fallback streamSingle: $error');
          return legacyRepo.streamSingle(id);
        });
      }

      return stream;
    }

    return legacyRepo.streamSingle(id);
  }

  // ═══════════════════════════════════════════════════════════════════
  // List Operations
  // ═══════════════════════════════════════════════════════════════════

  /// Stream de todos os documentos do tenant.
  Stream<List<T>> streamList(String companyId) {
    if (FeatureFlags.shouldReadFromNew) {
      final stream = tenantRepo.streamList(companyId);

      if (FeatureFlags.shouldFallbackToLegacy) {
        return stream.handleError((error) {
          print('[RepositoryV2] Fallback streamList: $error');
          return legacyRepo.streamQueryList(
            args: [QueryArgs('company.id', companyId)],
          );
        });
      }

      return stream;
    }

    return legacyRepo.streamQueryList(
      args: [QueryArgs('company.id', companyId)],
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
    if (FeatureFlags.shouldReadFromNew) {
      try {
        return await tenantRepo.getQueryList(
          companyId,
          orderBy: orderBy,
          args: args,
          limit: limit,
          startAfter: startAfter,
        );
      } catch (e) {
        if (FeatureFlags.shouldFallbackToLegacy) {
          print('[RepositoryV2] Fallback getQueryList: $e');
          return await legacyRepo.getQueryList(
            orderBy: orderBy,
            args: _addCompanyFilter(companyId, args),
            limit: limit,
            startAfter: startAfter,
          );
        }
        rethrow;
      }
    }

    return await legacyRepo.getQueryList(
      orderBy: orderBy,
      args: _addCompanyFilter(companyId, args),
      limit: limit,
      startAfter: startAfter,
    );
  }

  /// Stream de documentos com query customizada.
  Stream<List<T>> streamQueryList(
    String companyId, {
    List<OrderBy>? orderBy,
    List<QueryArgs>? args,
  }) {
    if (FeatureFlags.shouldReadFromNew) {
      final stream = tenantRepo.streamQueryList(
        companyId,
        orderBy: orderBy,
        args: args,
      );

      if (FeatureFlags.shouldFallbackToLegacy) {
        return stream.handleError((error) {
          print('[RepositoryV2] Fallback streamQueryList: $error');
          return legacyRepo.streamQueryList(
            orderBy: orderBy,
            args: _addCompanyFilter(companyId, args),
          );
        });
      }

      return stream;
    }

    return legacyRepo.streamQueryList(
      orderBy: orderBy,
      args: _addCompanyFilter(companyId, args),
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
    if (FeatureFlags.shouldReadFromNew) {
      try {
        return await tenantRepo.getListFromTo(
          companyId,
          field,
          from,
          to,
          args: args,
        );
      } catch (e) {
        if (FeatureFlags.shouldFallbackToLegacy) {
          print('[RepositoryV2] Fallback getListFromTo: $e');
          return await legacyRepo.getListFromTo(
            field,
            from,
            to,
            args: _addCompanyFilter(companyId, args),
          );
        }
        rethrow;
      }
    }

    return await legacyRepo.getListFromTo(
      field,
      from,
      to,
      args: _addCompanyFilter(companyId, args),
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
    if (FeatureFlags.shouldReadFromNew) {
      final stream = tenantRepo.streamListFromTo(
        companyId,
        field,
        from,
        to,
        args: args,
      );

      if (FeatureFlags.shouldFallbackToLegacy) {
        return stream.handleError((error) {
          print('[RepositoryV2] Fallback streamListFromTo: $error');
          return legacyRepo.streamListFromTo(
            field,
            from,
            to,
            args: _addCompanyFilter(companyId, args),
          );
        });
      }

      return stream;
    }

    return legacyRepo.streamListFromTo(
      field,
      from,
      to,
      args: _addCompanyFilter(companyId, args),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // CRUD Operations (com dual-write)
  // ═══════════════════════════════════════════════════════════════════

  /// Cria ou atualiza um documento.
  ///
  /// Se `dualWriteEnabled` estiver ativo, escreve em ambas as estruturas.
  /// Garante que o mesmo ID seja usado em ambas as estruturas.
  Future<void> createItem(String companyId, T item, {String? id}) async {
    final futures = <Future>[];

    // Garante que temos um ID para manter consistência entre as bases
    if (item?.id == null) {
      if (id != null) {
        item?.id = id;
      } else {
        // Gera um ID novo se não foi fornecido
        item?.id = FirebaseFirestore.instance.collection('tmp').doc().id;
      }
    }
    
    // Atualiza a variável id local caso tenha sido gerada agora
    id = item?.id;

    if (FeatureFlags.shouldWriteToLegacy) {
      futures.add(legacyRepo.createItem(item, id: id));
    }

    if (FeatureFlags.shouldWriteToNew) {
      futures.add(tenantRepo.createItem(companyId, item, id: id));
    }

    await Future.wait(futures);
  }

  /// Atualiza um documento existente.
  Future<void> updateItem(String companyId, T item) async {
    final futures = <Future>[];

    if (FeatureFlags.shouldWriteToLegacy) {
      futures.add(legacyRepo.updateItem(item));
    }

    if (FeatureFlags.shouldWriteToNew) {
      futures.add(tenantRepo.updateItem(companyId, item));
    }

    await Future.wait(futures);
  }

  /// Remove um documento.
  Future<void> removeItem(String companyId, String? id) async {
    if (id == null) return;

    final futures = <Future>[];

    if (FeatureFlags.shouldWriteToLegacy) {
      futures.add(legacyRepo.removeItem(id));
    }

    if (FeatureFlags.shouldWriteToNew) {
      futures.add(tenantRepo.removeItem(companyId, id));
    }

    await Future.wait(futures);
  }

  // ═══════════════════════════════════════════════════════════════════
  // Helper Methods
  // ═══════════════════════════════════════════════════════════════════

  /// Adiciona filtro de company.id à lista de argumentos (para estrutura legada).
  List<QueryArgs> _addCompanyFilter(String companyId, List<QueryArgs>? args) {
    final List<QueryArgs> newArgs = [QueryArgs('company.id', companyId)];

    if (args != null) {
      // Remove qualquer filtro de company.id existente para evitar duplicação
      newArgs.addAll(args.where((arg) => arg.key != 'company.id'));
    }

    return newArgs;
  }
}
