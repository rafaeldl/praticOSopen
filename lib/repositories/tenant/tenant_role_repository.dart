import 'package:praticos/models/user_role.dart';
import 'package:praticos/repositories/tenant_repository.dart';
import 'package:praticos/repositories/repository.dart';

/// Repository para UserRoles usando subcollections por tenant.
///
/// Path: `/companies/{companyId}/roles/{roleId}`
class TenantRoleRepository extends TenantRepository<UserRole?> {
  static const String collectionName = 'roles';

  TenantRoleRepository() : super(collectionName);

  @override
  UserRole fromJson(Map<String, dynamic> data) => UserRole.fromJson(data);

  @override
  Map<String, dynamic> toJson(UserRole? role) => role!.toJson();

  // ═══════════════════════════════════════════════════════════════════
  // Role-specific methods
  // ═══════════════════════════════════════════════════════════════════

  /// Stream de todos os roles do tenant.
  Stream<List<UserRole?>> streamRoles(String companyId) {
    return streamQueryList(companyId);
  }

  /// Busca role por ID do usuário.
  Future<UserRole?> getRoleByUserId(String companyId, String userId) async {
    final roles = await getQueryList(
      companyId,
      args: [QueryArgs('user.id', userId)],
      limit: 1,
    );
    return roles.isNotEmpty ? roles.first : null;
  }

  /// Busca roles por tipo (admin, manager, user).
  Future<List<UserRole?>> getRolesByType(
    String companyId,
    RolesType roleType,
  ) {
    return getQueryList(
      companyId,
      args: [QueryArgs('role', roleType.name)],
    );
  }

  /// Verifica se um usuário tem acesso à empresa.
  Future<bool> hasAccess(String companyId, String userId) async {
    final role = await getRoleByUserId(companyId, userId);
    return role != null;
  }

  /// Verifica se um usuário é admin da empresa.
  Future<bool> isAdmin(String companyId, String userId) async {
    final role = await getRoleByUserId(companyId, userId);
    return role?.role == RolesType.admin;
  }
}
