import 'package:praticos/global.dart';
import 'package:praticos/mobx/collaborator_store.dart';
import 'package:praticos/models/membership.dart';
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

  final CollaboratorStore _collaboratorStore = CollaboratorStore.instance;

  // ═══════════════════════════════════════════════════════════════════
  // ROLE MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════

  /// Retorna o perfil do usuário atual na empresa atual.
  RolesType? get currentUserRole {
    if (Global.currentUser == null || Global.companyAggr?.id == null) {
      return null;
    }

    final currentUserId = Global.currentUser!.uid;
    final membership = _collaboratorStore.collaborators.firstWhere(
      (m) => m.userId == currentUserId || m.user?.id == currentUserId,
      orElse: () => Membership(),
    );

    return membership.role;
  }

  /// Retorna o perfil normalizado (converte roles legados).
  RolesType? get normalizedRole {
    final role = currentUserRole;
    if (role == null) return null;

    // Normaliza roles legados
    switch (role) {
      // ignore: deprecated_member_use_from_same_package
      case RolesType.manager:
        return RolesType.supervisor;
      // ignore: deprecated_member_use_from_same_package
      case RolesType.user:
        return RolesType.tecnico;
      default:
        return role;
    }
  }

  /// Verifica se o usuário atual é administrador.
  bool get isAdmin => normalizedRole == RolesType.admin;

  /// Verifica se o usuário atual é gerente.
  bool get isGerente => normalizedRole == RolesType.gerente;

  /// Verifica se o usuário atual é supervisor.
  bool get isSupervisor => normalizedRole == RolesType.supervisor;

  /// Verifica se o usuário atual é consultor.
  bool get isConsultor => normalizedRole == RolesType.consultor;

  /// Verifica se o usuário atual é técnico.
  bool get isTecnico => normalizedRole == RolesType.tecnico;

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
  /// - Admin/Gerente/Supervisor: todas as OS
  /// - Consultor: apenas OS que criou
  /// - Técnico: apenas OS atribuídas
  bool canAccessOrder(Order order) {
    final role = normalizedRole;
    if (role == null) return false;
    if (Global.currentUser == null) return false;

    final currentUserId = Global.currentUser!.uid;

    switch (role) {
      case RolesType.admin:
      case RolesType.gerente:
      case RolesType.supervisor:
        // Acesso a todas as OS
        return true;

      case RolesType.consultor:
        // Apenas OS que criou
        return order.createdBy?.id == currentUserId;

      case RolesType.tecnico:
        // Apenas OS atribuídas (assignedTo) ou que criou
        return _isOrderAssignedToUser(order, currentUserId) ||
            order.createdBy?.id == currentUserId;

      default:
        return false;
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
      case RolesType.gerente:
      case RolesType.supervisor:
        // Retorna todas as OS
        return orders;

      case RolesType.consultor:
        // Apenas OS que criou
        return orders.where((o) => o.createdBy?.id == currentUserId).toList();

      case RolesType.tecnico:
        // Apenas OS atribuídas ou que criou
        return orders
            .where((o) =>
                _isOrderAssignedToUser(o, currentUserId) ||
                o.createdBy?.id == currentUserId)
            .toList();

      default:
        return [];
    }
  }
}
