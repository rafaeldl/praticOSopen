import 'package:praticos/config/feature_flags.dart';
import 'package:praticos/models/user_role.dart';
import 'package:praticos/repositories/repository.dart';
import 'package:praticos/repositories/tenant/tenant_role_repository.dart';
import 'package:praticos/repositories/tenant_repository.dart';
import 'package:praticos/repositories/v2/repository_v2.dart';

/// Repository base para UserRole (estrutura legada).
///
/// Na estrutura atual, roles são armazenados em `/roles/{roleId}`.
/// Na nova estrutura, serão `/companies/{companyId}/roles/{roleId}`.
class RoleRepository extends Repository<UserRole?> {
  static const String collectionName = 'roles';

  RoleRepository() : super(collectionName);

  @override
  UserRole fromJson(data) => UserRole.fromJson(data);

  @override
  Map<String, dynamic> toJson(UserRole? role) => role!.toJson();
}

/// Repository V2 para UserRoles com suporte a dual-write/dual-read.
class RoleRepositoryV2 extends RepositoryV2<UserRole?> {
  final RoleRepository _legacy = RoleRepository();
  final TenantRoleRepository _tenant = TenantRoleRepository();

  @override
  Repository<UserRole?> get legacyRepo => _legacy;

  @override
  TenantRepository<UserRole?> get tenantRepo => _tenant;

  // ═══════════════════════════════════════════════════════════════════
  // Role-specific methods
  // ═══════════════════════════════════════════════════════════════════

  /// Stream de todos os roles do tenant.
  Stream<List<UserRole?>> streamRoles(String companyId) {
    if (FeatureFlags.shouldReadFromNew) {
      final stream = _tenant.streamRoles(companyId);

      if (FeatureFlags.shouldFallbackToLegacy) {
        return stream.handleError((error) {
          print('[RoleRepositoryV2] Fallback streamRoles: $error');
          return _legacy.streamQueryList(
            args: [QueryArgs('company.id', companyId)],
          );
        });
      }

      return stream;
    }

    return _legacy.streamQueryList(
      args: [QueryArgs('company.id', companyId)],
    );
  }

  /// Busca role por ID do usuário.
  Future<UserRole?> getRoleByUserId(String companyId, String userId) async {
    if (FeatureFlags.shouldReadFromNew) {
      try {
        return await _tenant.getRoleByUserId(companyId, userId);
      } catch (e) {
        if (FeatureFlags.shouldFallbackToLegacy) {
          print('[RoleRepositoryV2] Fallback getRoleByUserId: $e');
          final roles = await _legacy.getQueryList(
            args: [
              QueryArgs('company.id', companyId),
              QueryArgs('user.id', userId),
            ],
            limit: 1,
          );
          return roles.isNotEmpty ? roles.first : null;
        }
        rethrow;
      }
    }

    final roles = await _legacy.getQueryList(
      args: [
        QueryArgs('company.id', companyId),
        QueryArgs('user.id', userId),
      ],
      limit: 1,
    );
    return roles.isNotEmpty ? roles.first : null;
  }

  /// Busca roles por tipo (admin, manager, user).
  Future<List<UserRole?>> getRolesByType(
    String companyId,
    RolesType roleType,
  ) async {
    if (FeatureFlags.shouldReadFromNew) {
      try {
        return await _tenant.getRolesByType(companyId, roleType);
      } catch (e) {
        if (FeatureFlags.shouldFallbackToLegacy) {
          print('[RoleRepositoryV2] Fallback getRolesByType: $e');
          return await _legacy.getQueryList(
            args: [
              QueryArgs('company.id', companyId),
              QueryArgs('role', roleType.name),
            ],
          );
        }
        rethrow;
      }
    }

    return await _legacy.getQueryList(
      args: [
        QueryArgs('company.id', companyId),
        QueryArgs('role', roleType.name),
      ],
    );
  }

  /// Verifica se um usuário tem acesso à empresa.
  Future<bool> hasAccess(String companyId, String userId) async {
    if (FeatureFlags.shouldReadFromNew) {
      try {
        return await _tenant.hasAccess(companyId, userId);
      } catch (e) {
        if (FeatureFlags.shouldFallbackToLegacy) {
          print('[RoleRepositoryV2] Fallback hasAccess: $e');
          final role = await getRoleByUserId(companyId, userId);
          return role != null;
        }
        rethrow;
      }
    }

    final role = await getRoleByUserId(companyId, userId);
    return role != null;
  }

  /// Verifica se um usuário é admin da empresa.
  Future<bool> isAdmin(String companyId, String userId) async {
    if (FeatureFlags.shouldReadFromNew) {
      try {
        return await _tenant.isAdmin(companyId, userId);
      } catch (e) {
        if (FeatureFlags.shouldFallbackToLegacy) {
          print('[RoleRepositoryV2] Fallback isAdmin: $e');
          final role = await getRoleByUserId(companyId, userId);
          return role?.role == RolesType.admin;
        }
        rethrow;
      }
    }

    final role = await getRoleByUserId(companyId, userId);
    return role?.role == RolesType.admin;
  }
}
