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

  AuthorizationService._internal() {
    // Inicializar UserStore interno e carregar dados do usuário
    _internalUserStore = UserStore();
    _internalUserStore?.findCurrentUser();
  }
  factory AuthorizationService() => _instance;

  // Internal UserStore instance
  UserStore? _internalUserStore;

  // Shared UserStore instance - set this from screens that have loaded user data
  static UserStore? _sharedUserStore;

  /// Set the shared UserStore instance to be used by AuthorizationService.
  /// Call this from screens that load user data (e.g., Settings screen).
  static void setUserStore(UserStore userStore) {
    _sharedUserStore = userStore;
  }

  /// Get the active UserStore (shared or internal)
  UserStore? get _activeUserStore => _sharedUserStore ?? _internalUserStore;

  // ═══════════════════════════════════════════════════════════════════
  // ROLE MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════

  /// Retorna o perfil do usuário atual na empresa atual.
  RolesType? get currentUserRole {
    if (Global.currentUser == null || Global.companyAggr?.id == null) {
      return null;
    }

    // Get role from active UserStore (shared or internal fallback)
    final user = _activeUserStore?.user?.value;
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
        // Acesso a todas as OS (assignedTo ainda não implementado restritivamente)
        return true;
    }
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

  /// Verifica se o usuário pode deletar uma OS específica.
  ///
  /// Regras:
  /// - Admin: pode deletar sempre
  /// - Manager e Supervisor: podem deletar apenas se status for 'quote'
  /// - Consultant e Technician: podem deletar apenas OS que criaram, em status 'quote'
  bool canDeleteOrder(Order order) {
    if (!canAccessOrder(order)) return false;

    final role = normalizedRole;
    if (role == null) return false;
    if (Global.currentUser == null) return false;

    final currentUserId = Global.currentUser!.uid;
    final isCreator = order.createdBy?.id == currentUserId;

    switch (role) {
      case RolesType.admin:
        return true;

      case RolesType.manager:
      case RolesType.supervisor:
        // Podem deletar apenas se status for 'quote'
        return order.status == 'quote';

      case RolesType.consultant:
      case RolesType.technician:
        // Podem deletar apenas OS que criaram, em status 'quote'
        return isCreator && order.status == 'quote';
    }
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

  /// Verifica se o usuário pode adicionar/remover procedimentos (forms) em uma OS.
  ///
  /// Regras:
  /// - Admin, Manager, Consultant: podem gerenciar procedimentos em qualquer status
  /// - Supervisor: pode gerenciar procedimentos enquanto OS estiver ativa (não concluída/cancelada)
  /// - Técnico: só pode gerenciar procedimentos quando status = 'quote'
  bool canManageOrderForms(Order order) {
    if (!canAccessOrder(order)) return false;

    final role = normalizedRole;
    if (role == null) return false;

    // Admin, Manager e Consultant podem gerenciar sempre
    if (role == RolesType.admin ||
        role == RolesType.manager ||
        role == RolesType.consultant) {
      return hasPermission(PermissionType.editOrder);
    }

    // Supervisor pode gerenciar enquanto OS estiver ativa (não concluída/cancelada)
    if (role == RolesType.supervisor) {
      final status = order.status;
      return status != 'done' && status != 'canceled' && hasPermission(PermissionType.editOrder);
    }

    // Técnico só pode gerenciar quando status for 'quote'
    if (role == RolesType.technician) {
      return order.status == 'quote' && hasPermission(PermissionType.editOrder);
    }

    return false;
  }

  // ═══════════════════════════════════════════════════════════════════
  // ORDER STATUS FLOW CONTROL
  // ═══════════════════════════════════════════════════════════════════

  /// Verifica se o usuário pode alterar o status de uma OS para um novo status.
  ///
  /// Regras por perfil:
  /// - Admin/Manager: pode alterar para qualquer status, inclusive de 'done'
  /// - Consultant: de 'quote' para 'approved' ou 'canceled' (não pode alterar 'done')
  /// - Supervisor/Technician: de 'approved' para 'progress' ou 'done', e de 'progress' para 'done' (não pode alterar 'done')
  /// - Apenas Admin e Manager podem alterar status após 'done'
  bool canChangeOrderStatus(Order order, String newStatus) {
    final role = normalizedRole;
    if (role == null) return false;
    if (!canAccessOrder(order)) return false;

    final currentStatus = order.status;

    // Não pode "alterar" para o mesmo status
    if (currentStatus == newStatus) return false;

    switch (role) {
      case RolesType.admin:
      case RolesType.manager:
        return true;

      case RolesType.consultant:
        // Não pode alterar status 'done'
        if (currentStatus == 'done') return false;
        // De 'quote' para 'approved' ou 'canceled'
        return currentStatus == 'quote' &&
               (newStatus == 'approved' || newStatus == 'canceled');

      case RolesType.supervisor:
      case RolesType.technician:
        // Não pode alterar status 'done'
        if (currentStatus == 'done') return false;

        // Se for o criador da OS, permite sair de 'quote' para 'approved' ou 'progress' (auto-aprovação)
        final isCreator = Global.currentUser?.uid != null && order.createdBy?.id == Global.currentUser!.uid;
        if (currentStatus == 'quote' && isCreator && (newStatus == 'approved' || newStatus == 'progress')) {
           return true;
        }

        // De 'approved' para 'progress' ou 'done'
        if (currentStatus == 'approved' &&
            (newStatus == 'progress' || newStatus == 'done')) {
          return true;
        }
        // De 'progress' para 'done'
        if (currentStatus == 'progress' && newStatus == 'done') {
          return true;
        }
        return false;
    }
  }

  /// Retorna a lista de status disponíveis que o usuário pode selecionar
  /// para uma determinada OS, baseado no status atual e no perfil do usuário.
  ///
  /// Retorna apenas os status válidos de acordo com o fluxo de permissões.
  List<String> getAvailableStatuses(Order order) {
    final role = normalizedRole;
    if (role == null) return [];
    if (!canAccessOrder(order)) return [];

    final currentStatus = order.status;
    final availableStatuses = <String>[];

    switch (role) {
      case RolesType.admin:
      case RolesType.manager:
        // Podem selecionar qualquer status exceto o atual (inclusive alterar de 'done')
        availableStatuses.addAll([
          'quote',
          'approved',
          'progress',
          'done',
          'canceled',
        ]);
        availableStatuses.remove(currentStatus);
        break;

      case RolesType.consultant:
        // Se já está concluído, não pode alterar
        if (currentStatus == 'done') return [];
        // Pode aprovar ou cancelar orçamentos
        if (currentStatus == 'quote') {
          availableStatuses.addAll(['approved', 'canceled']);
        }
        break;

      case RolesType.supervisor:
      case RolesType.technician:
        // Se já está concluído, não pode alterar
        if (currentStatus == 'done') return [];

        // Se for o criador da OS e está em orçamento, pode aprovar ou iniciar
        final isCreator = Global.currentUser?.uid != null && order.createdBy?.id == Global.currentUser!.uid;
        if (currentStatus == 'quote' && isCreator) {
          availableStatuses.addAll(['approved', 'progress']);
        }

        if (currentStatus == 'approved') {
          // Podem iniciar ou concluir direto
          availableStatuses.addAll(['progress', 'done']);
        } else if (currentStatus == 'progress') {
          // Podem apenas concluir
          availableStatuses.add('done');
        }
        break;
    }

    return availableStatuses;
  }

  /// Verifica se o usuário pode reabrir procedimentos (forms) concluídos.
  ///
  /// Apenas Admin, Manager e Supervisor podem reabrir procedimentos concluídos.
  bool get canReopenCompletedForms {
    final role = normalizedRole;
    return role == RolesType.admin ||
           role == RolesType.manager ||
           role == RolesType.supervisor;
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
        // Retorna todas as OS (assignedTo ainda não implementado restritivamente)
        return orders;
    }
  }
}
