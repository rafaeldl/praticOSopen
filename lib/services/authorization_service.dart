import 'package:praticos/global.dart';
import 'package:praticos/mobx/user_store.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/permission.dart';
import 'package:praticos/models/receipt.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/models/user_role.dart';
import 'package:praticos/services/segment_config_service.dart';

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
  static final AuthorizationService _instance =
      AuthorizationService._internal();
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

    return roleIn(user, Global.companyAggr!.id);
  }

  /// Role of [user] in [companyId], or null when not a member.
  static RolesType? roleIn(User? user, String? companyId) {
    if (user?.companies == null || companyId == null) return null;
    for (final cr in user!.companies!) {
      if (cr.company?.id == companyId) return cr.role;
    }
    return null;
  }

  /// [currentUserRole], waiting for the user document when it hasn't loaded
  /// yet (right after the app opens). Null when it doesn't arrive in
  /// [timeout] or the user has no role in the company.
  Future<RolesType?> resolveCurrentRole({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final known = currentUserRole;
    if (known != null) return known;
    final companyId = Global.companyAggr?.id;
    if (Global.currentUser == null || companyId == null) return null;
    final store = _activeUserStore;
    if (store == null) return null;
    if (store.user == null) await store.findCurrentUser();
    final stream = store.user;
    if (stream == null) return null;
    try {
      final user = await stream
          .firstWhere((u) => roleIn(u, companyId) != null)
          .timeout(timeout);
      return roleIn(user, companyId);
    } catch (_) {
      return currentUserRole;
    }
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

  /// Whether the current company uses values and billing
  /// (`Company.useFinancial`, absent = true).
  bool get _useFinancial => SegmentConfigService().useFinancial;

  /// Verifica se o usuário atual possui uma determinada permissão.
  ///
  /// With `Company.useFinancial == false` the financial permissions
  /// ([RolePermissions.financialPermissions]) are denied for every role.
  bool hasPermission(PermissionType permission) {
    final role = normalizedRole;
    if (role == null) return false;

    return RolePermissions.hasPermissionInCompany(
      role,
      permission,
      useFinancial: _useFinancial,
    );
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

    final permissions = RolePermissions.getPermissions(role);
    if (_useFinancial) return permissions;
    return permissions.difference(RolePermissions.financialPermissions);
  }

  // ═══════════════════════════════════════════════════════════════════
  // ORDER ACCESS CONTROL
  // ═══════════════════════════════════════════════════════════════════

  /// Verifica se o usuário atual pode visualizar uma OS específica.
  ///
  /// Same rule as the Firestore order read rule: admin, manager and
  /// supervisor read every order; consultant and technician only the ones
  /// they created (assignedTo isn't in the rules yet).
  bool canAccessOrder(Order order) => canAccessOrderFor(
    role: normalizedRole,
    userId: Global.currentUser?.uid,
    order: order,
  );

  /// Pure version of [canAccessOrder].
  static bool canAccessOrderFor({
    required RolesType? role,
    required String? userId,
    required Order order,
  }) {
    if (role == null || userId == null) return false;
    if (RolePermissions.hasPermission(role, PermissionType.viewAllOrders)) {
      return true;
    }
    return order.createdBy?.id == userId;
  }

  /// Uid that every order list query must filter `createdBy.id` by, or null
  /// when the user reads every order. Without the filter the Firestore rules
  /// deny the whole query for consultant and technician.
  Future<String?> orderCreatorFilter() async => orderCreatorFilterFor(
    role: await resolveCurrentRole(),
    userId: Global.currentUser?.uid,
  );

  /// [orderCreatorFilter] now and again whenever the user's role changes.
  /// While the role is unknown (user document not loaded yet) it filters,
  /// and switches to "no filter" as soon as an owner/admin role arrives, so
  /// a live query doesn't stay stuck on the provisional filter.
  Stream<String?> orderCreatorFilterChanges() async* {
    final userId = Global.currentUser?.uid;
    final companyId = Global.companyAggr?.id;
    // Same wait as [orderCreatorFilter], so `.first` keeps its answer.
    final initial = await resolveCurrentRole();
    final users = _activeUserStore?.user;
    yield* creatorFilterChanges(
      initial: initial,
      roles: users == null
          ? const Stream.empty()
          : users.map((u) => roleIn(u, companyId)),
      userId: userId,
    );
  }

  /// Pure version of [orderCreatorFilterChanges]: the filter for [initial],
  /// then for each value of [roles], without repeating a value. A null role
  /// after a known one (user doc briefly missing) keeps the last filter.
  static Stream<String?> creatorFilterChanges({
    required RolesType? initial,
    required Stream<RolesType?> roles,
    required String? userId,
  }) async* {
    var current = orderCreatorFilterFor(role: initial, userId: userId);
    var known = initial != null;
    yield current;
    await for (final role in roles) {
      if (role == null && known) continue;
      known = known || role != null;
      final next = orderCreatorFilterFor(role: role, userId: userId);
      if (next == current) continue;
      current = next;
      yield current;
    }
  }

  /// Pure version of [orderCreatorFilter]. An unknown role filters too: the
  /// filtered query is allowed for every member.
  static String? orderCreatorFilterFor({
    required RolesType? role,
    required String? userId,
  }) {
    if (role != null &&
        RolePermissions.hasPermission(role, PermissionType.viewAllOrders)) {
      return null;
    }
    return userId;
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
      return status != 'done' &&
          status != 'canceled' &&
          hasPermission(PermissionType.editOrder);
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
        final isCreator =
            Global.currentUser?.uid != null &&
            order.createdBy?.id == Global.currentUser!.uid;
        if (currentStatus == 'quote' &&
            isCreator &&
            (newStatus == 'approved' || newStatus == 'progress')) {
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
        final isCreator =
            Global.currentUser?.uid != null &&
            order.createdBy?.id == Global.currentUser!.uid;
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

  // ═══════════════════════════════════════════════════════════════════
  // RECEIVING PAYMENTS
  // ═══════════════════════════════════════════════════════════════════

  /// Whether [role] (user [userId]) can register money received on [order]
  /// ("Receber"). Financial access (`viewFinancialReports`: owner, admin,
  /// manager) receives on any order; a consultant receives only on the
  /// orders they created (the same ownership as `viewOwnOrders` and the
  /// Firestore order update rule: `createdBy.id`). Supervisor and technician
  /// never. Off for everyone when the company does not use values and
  /// billing. Discount stays with financial access only.
  static bool canReceiveOnOrderFor({
    required RolesType? role,
    required String? userId,
    required Order? order,
    bool useFinancial = true,
  }) {
    if (role == null) return false;
    if (RolePermissions.hasPermissionInCompany(
      role,
      PermissionType.viewFinancialReports,
      useFinancial: useFinancial,
    )) {
      return true;
    }
    return role == RolesType.consultant &&
        RolePermissions.hasPermissionInCompany(
          role,
          PermissionType.viewPrices,
          useFinancial: useFinancial,
        ) &&
        userId != null &&
        order?.createdBy?.id == userId;
  }

  /// Whether [role] receives at all (on some order): financial access, or a
  /// consultant (on their own orders). Used before the orders are known.
  static bool canReceivePaymentsFor({
    required RolesType? role,
    bool useFinancial = true,
  }) {
    if (role == null) return false;
    if (RolePermissions.hasPermissionInCompany(
      role,
      PermissionType.viewFinancialReports,
      useFinancial: useFinancial,
    )) {
      return true;
    }
    return role == RolesType.consultant &&
        RolePermissions.hasPermissionInCompany(
          role,
          PermissionType.viewPrices,
          useFinancial: useFinancial,
        );
  }

  /// [canReceiveOnOrderFor] for the current user.
  bool canReceiveOnOrder(Order? order) => canReceiveOnOrderFor(
    role: normalizedRole,
    userId: Global.currentUser?.uid,
    order: order,
    useFinancial: _useFinancial,
  );

  /// [canReceivePaymentsFor] for the current user.
  bool get canReceivePayments =>
      canReceivePaymentsFor(role: normalizedRole, useFinancial: _useFinancial);

  /// Whether [role] (user [userId]) can see, undo and send the recibo of
  /// [receipt]: financial access on any receipt, a consultant only on the
  /// ones they registered (`createdBy.id`, as in the Firestore rules).
  static bool canManageReceiptFor({
    required RolesType? role,
    required String? userId,
    required Receipt? receipt,
    bool useFinancial = true,
  }) {
    if (role == null) return false;
    if (RolePermissions.hasPermissionInCompany(
      role,
      PermissionType.viewFinancialReports,
      useFinancial: useFinancial,
    )) {
      return true;
    }
    return canReceivePaymentsFor(role: role, useFinancial: useFinancial) &&
        userId != null &&
        receipt?.createdBy?.id == userId;
  }

  /// [canManageReceiptFor] for the current user.
  bool canManageReceipt(Receipt? receipt) => canManageReceiptFor(
    role: normalizedRole,
    userId: Global.currentUser?.uid,
    receipt: receipt,
    useFinancial: _useFinancial,
  );

  /// Verifica se o usuário pode acessar relatórios operacionais.
  bool get canViewOperationalReports =>
      hasPermission(PermissionType.viewOperationalReports);

  /// Verifica se o usuário pode acessar o dashboard.
  bool get canViewDashboard => hasPermission(PermissionType.viewDashboard);

  /// Verifica se o usuário pode gerar/cancelar cobranças da OS (Asaas).
  bool get canChargeOrder => hasPermission(PermissionType.chargeOrder);

  // ═══════════════════════════════════════════════════════════════════
  // MANAGEMENT PERMISSIONS
  // ═══════════════════════════════════════════════════════════════════

  /// Verifica se o usuário pode gerenciar colaboradores.
  bool get canManageUsers => hasPermission(PermissionType.manageUsers);

  /// Verifica se o usuário pode gerenciar perfis.
  bool get canManageRoles => hasPermission(PermissionType.manageRoles);

  /// Usage counters live on the company document, which only an admin may
  /// write (Firestore rules); other roles skip the write.
  bool get canWriteUsageCounters => isAdmin;

  /// Verifica se o usuário pode gerenciar a empresa.
  bool get canManageCompany => hasPermission(PermissionType.manageCompany);

  /// Verifica se o usuário pode gerenciar configurações.
  bool get canManageSettings => hasPermission(PermissionType.manageSettings);

  /// Verifica se o usuário pode gerenciar formulários.
  bool get canManageForms => hasPermission(PermissionType.manageForms);

  // ═══════════════════════════════════════════════════════════════════
  // UTILITY METHODS
  // ═══════════════════════════════════════════════════════════════════

  /// Retorna o label amigável do perfil com i18n.
  String getRoleLabelLocalized(dynamic l10n) {
    final role = normalizedRole;
    if (role == null) return l10n?.noRole ?? 'Sem perfil';
    return RolePermissions.getRoleLabel(role, l10n);
  }

  /// Retorna a descrição do perfil com i18n.
  String getRoleDescriptionLocalized(dynamic l10n) {
    final role = normalizedRole;
    if (role == null) return '';
    return RolePermissions.getRoleDescription(role, l10n);
  }

  /// Filtra uma lista de OS baseado nas permissões do usuário.
  List<Order> filterOrdersByPermission(List<Order> orders) => filterOrdersFor(
    role: normalizedRole,
    userId: Global.currentUser?.uid,
    orders: orders,
  );

  /// Pure version of [filterOrdersByPermission]. Mirrors the Firestore order
  /// read rule: consultant and technician only see the orders they created.
  static List<Order> filterOrdersFor({
    required RolesType? role,
    required String? userId,
    required List<Order> orders,
  }) {
    if (role == null || userId == null) return [];

    switch (role) {
      case RolesType.admin:
      case RolesType.manager:
      case RolesType.supervisor:
        return orders;

      case RolesType.consultant:
      case RolesType.technician:
        // assignedTo ainda não existe; quando existir, incluir aqui e nas rules
        return orders.where((o) => o.createdBy?.id == userId).toList();
    }
  }
}
