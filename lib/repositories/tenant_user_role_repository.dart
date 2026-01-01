import 'package:praticos/models/user_role.dart';
import 'package:praticos/repositories/tenant_repository.dart';

class TenantUserRoleRepository extends TenantRepository<UserRole> {
  TenantUserRoleRepository() : super('roles');

  @override
  UserRole fromJson(Map<String, dynamic> data) => UserRole.fromJson(data);

  @override
  Map<String, dynamic> toJson(UserRole? item) => item!.toJson();
}
