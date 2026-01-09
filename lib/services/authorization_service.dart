import 'package:praticos/global.dart';
import 'package:praticos/mobx/user_store.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/permission.dart';
import 'package:praticos/models/user_role.dart';

/// Serviço de autorização centralizado para o PraticOS.
///
/// Implementa controle de acesso baseado em funções (RBAC) verificando
/// permissões do usuário atual com base em seu perfil na empresa.
///
/// Uso:
/// ```dart
/// final auth = AuthorizationService.instance;
///
/// // Verificar permissão simples
/// if (auth.hasPermission(PermissionType.viewPrices)) {
///   // Mostrar preços
/// }
///
/// // Verificar acesso a OS
/// if (auth.canAccessOrder(order)) {
///   // Mostrar OS
/// }
/// ```
class AuthorizationService {
  static final AuthorizationService _instance = AuthorizationService._internal();
  static AuthorizationService get instance => _instance;

  AuthorizationService._internal();
  factory AuthorizationService() => _instance;

  // Shared UserStore instance - set this from screens that have loaded user data
  static UserStore? _sharedUserStore;

  /// Set the shared UserStore instance to be used by AuthorizationService.
  /// Call this from screens that load user data (e.g., Settings screen).
  static void setUserStore(UserStore userStore) {
    _sharedUserStore = userStore;
  }

  // ═══════════════════════════════════════════════════════════════════
  // ROLE MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════

  /// Retorna o perfil do usuário atual na empresa atual.
  RolesType? get currentUserRole {
    if (Global.currentUser == null || Global.companyAggr?.id == null) {
      return null;
    }

    // Get role from shared UserStore (user.companies[].role)
    final user = _sharedUserStore?.user?.value;
    if (user?.companies == null) {
      return null;
    }

    // Find the CompanyRoleAggr for current company
    final companyRole = user!.companies!.firstWhere(
      (cr) => cr.company?.id == Global.companyAggr!.id,
      orElse: () => CompanyRoleAggr(),
    );

    return companyRole.role;
  }

  /// Returns the current user role.
  RolesType? get normalizedRole => currentUserRole;

  /// Verifica se o usuário atual é administrador.
  bool get isAdmin => normalizedRole == RolesType.admin;

  /// Verifica se o usuário atual é gerente.
  bool get isManager => normalizedRole == RolesType.manager;

  /// Verifica se o usuário atual é supervisor.
  bool get isSupervisor => normalizedRole == RolesType.supervisor;

  /// Verifica se o usuário atual é consultor.
  bool get isConsultant => normalizedRole == RolesType.consultant;

  /// Verifica se o usuário atual é técnico.
  bool get isTechnician => normalizedRole == RolesType.technician;

  // ═══════════════════════════════════════════════════════════════════
  // PERMISSION CHECKS
  // ═══════════════════════════════════════════════════════════════════

  /// Verifica se o usuário atual possui uma determinada permissão.
  bool hasPermission(PermissionType permission) {
    final role = normalizedRole;
    if (role == null) return false;

    return RolePermissions.hasPermission(role, permission);
  }

  /// Verifica se o usuário atual possui todas as permissões especificadas.
  bool hasAllPermissions(List<PermissionType> permissions) {
    return permissions.every((p) => hasPermission(p));
  }

  /// Verifica se o usuário atual possui pelo menos uma das permissões.
  bool hasAnyPermission(List<PermissionType> permissions) {
    return permissions.any((p) => hasPermission(p));
  }

  /// Retorna o conjunto de permissões do usuário atual.
  Set<PermissionType> get currentPermissions {
    final role = normalizedRole;
    if (role == null) return {};

    return RolePermissions.getPermissions(role);
  }

  // ═══════════════════════════════════════════════════════════════════
  // ORDER ACCESS CONTROL
  // ═══════════════════════════════════════════════════════════════════

  /// Verifica se o usuário atual pode visualizar uma OS específica.
  ///
  /// Regras:
  /// - Admin/Manager/Supervisor: todas as OS
  /// - Consultant: apenas OS que criou
  /// - Technician: apenas OS atribuídas
  bool canAccessOrder(Order order) {
    final role = normalizedRole;
    if (role == null) return false;
    if (Global.currentUser == null) return false;

    final currentUserId = Global.currentUser!.uid;

    switch (role) {
      case RolesType.admin:
      case RolesType.manager:
      case RolesType.supervisor:
        // Acesso a todas as OS
        return true;

      case RolesType.consultant:
        // Apenas OS que criou
        return order.createdBy?.id == currentUserId;

      case RolesType.technician:
        // Apenas OS atribuídas (assignedTo) ou que criou
        return _isOrderAssignedToUser(order, currentUserId) ||
            order.createdBy?.id == currentUserId;
    }
  }

  /// Verifica se uma OS está atribuída ao usuário.
  bool _isOrderAssignedToUser(Order order, String userId) {
    // Verifica pelo campo assignedTo (UserAggr tem campo id)
    if (order.assignedTo?.id == userId) {
      return true;
    }
    // Fallback: verifica pelo createdBy para compatibilidade
    return order.createdBy?.id == userId;
  }

  /// Verifica se o usuário pode editar uma OS específica.
  bool canEditOrder(Order order) {
    if (!canAccessOrder(order)) return false;
    return hasPermission(PermissionType.editOrder);
  }

  /// Verifica se o usuário pode executar (preencher formulários, atualizar status) uma OS.
  bool canExecuteOrder(Order order) {
    if (!canAccessOrder(order)) return false;
    return hasPermission(PermissionType.executeOrder);
  }

  /// Verifica se o usuário pode atribuir/reatribuir técnicos a uma OS.
  bool canAssignOrder(Order order) {
    if (!canAccessOrder(order)) return false;
    return hasPermission(PermissionType.assignOrder);
  }

  /// Verifica se o usuário pode editar campos principais da OS.
  ///
  /// Supervisor e Técnico só podem editar serviços, produtos, procedimentos,
  /// data de entrega, cliente e device enquanto o status for 'quote' (orçamento).
  /// Após aprovação, apenas podem editar observações de serviços/produtos.
  ///
  /// Admin, Manager e Consultant podem editar em qualquer status.
  bool canEditOrderMainFields(Order order) {
    if (!canAccessOrder(order)) return false;

    final role = normalizedRole;
    if (role == null) return false;

    // Admin, Manager e Consultant podem editar sempre
    if (role == RolesType.admin ||
        role == RolesType.manager ||
        role == RolesType.consultant) {
      return hasPermission(PermissionType.editOrder);
    }

    // Supervisor e Técnico só podem editar enquanto status for 'quote'
    if (role == RolesType.supervisor || role == RolesType.technician) {
      return order.status == 'quote' && hasPermission(PermissionType.editOrder);
    }

    return false;
  }

  // ═══════════════════════════════════════════════════════════════════
  // DATA VISIBILITY
  // ═══════════════════════════════════════════════════════════════════

  /// Verifica se o usuário pode visualizar valores/preços.
  bool get canViewPrices => hasPermission(PermissionType.viewPrices);

  /// Verifica se o usuário pode visualizar faturamento.
  bool get canViewBilling => hasPermission(PermissionType.viewBilling);

  /// Verifica se o usuário pode acessar relatórios financeiros.
  bool get canViewFinancialReports =>
      hasPermission(PermissionType.viewFinancialReports);

  /// Verifica se o usuário pode acessar relatórios operacionais.
  bool get canViewOperationalReports =>
      hasPermission(PermissionType.viewOperationalReports);

  /// Verifica se o usuário pode acessar o dashboard.
  bool get canViewDashboard => hasPermission(PermissionType.viewDashboard);

  // ═══════════════════════════════════════════════════════════════════
  // MANAGEMENT PERMISSIONS
  // ═══════════════════════════════════════════════════════════════════

  /// Verifica se o usuário pode gerenciar colaboradores.
  bool get canManageUsers => hasPermission(PermissionType.manageUsers);

  /// Verifica se o usuário pode gerenciar perfis.
  bool get canManageRoles => hasPermission(PermissionType.manageRoles);

  /// Verifica se o usuário pode gerenciar a empresa.
  bool get canManageCompany => hasPermission(PermissionType.manageCompany);

  /// Verifica se o usuário pode gerenciar configurações.
  bool get canManageSettings => hasPermission(PermissionType.manageSettings);

  /// Verifica se o usuário pode gerenciar formulários.
  bool get canManageForms => hasPermission(PermissionType.manageForms);

  // ═══════════════════════════════════════════════════════════════════
  // UTILITY METHODS
  // ═══════════════════════════════════════════════════════════════════

  /// Retorna o label amigável do perfil atual.
  String get currentRoleLabel {
    final role = normalizedRole;
    if (role == null) return 'Sem perfil';
    return RolePermissions.getRoleLabel(role);
  }

  /// Retorna a descrição do perfil atual.
  String get currentRoleDescription {
    final role = normalizedRole;
    if (role == null) return '';
    return RolePermissions.getRoleDescription(role);
  }

  /// Filtra uma lista de OS baseado nas permissões do usuário.
  List<Order> filterOrdersByPermission(List<Order> orders) {
    final role = normalizedRole;
    if (role == null) return [];
    if (Global.currentUser == null) return [];

    final currentUserId = Global.currentUser!.uid;

    switch (role) {
      case RolesType.admin:
      case RolesType.manager:
      case RolesType.supervisor:
        // Retorna todas as OS
        return orders;

      case RolesType.consultant:
        // Apenas OS que criou
        return orders.where((o) => o.createdBy?.id == currentUserId).toList();

      case RolesType.technician:
        // Apenas OS atribuídas ou que criou
        return orders
            .where((o) =>
                _isOrderAssignedToUser(o, currentUserId) ||
                o.createdBy?.id == currentUserId)
            .toList();
    }
  }
}
