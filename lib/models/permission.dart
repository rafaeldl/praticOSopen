import 'package:praticos/models/user_role.dart';

/// Tipos de permissão disponíveis no sistema PraticOS.
///
/// Cada permissão controla o acesso a funcionalidades específicas do sistema,
/// garantindo separação clara entre execução técnica, supervisão operacional,
/// vendas e gestão financeira.
enum PermissionType {
  // ═══════════════════════════════════════════════════════════════════
  // ORDENS DE SERVIÇO
  // ═══════════════════════════════════════════════════════════════════

  /// Visualizar todas as OS da empresa
  viewAllOrders,

  /// Visualizar apenas OS atribuídas ao usuário
  viewAssignedOrders,

  /// Visualizar apenas OS criadas pelo usuário
  viewOwnOrders,

  /// Criar novas OS
  createOrder,

  /// Editar OS (status, dados, etc.)
  editOrder,

  /// Atribuir/reatribuir técnicos às OS
  assignOrder,

  /// Executar serviços (preencher formulários, atualizar status)
  executeOrder,

  // ═══════════════════════════════════════════════════════════════════
  // DADOS FINANCEIROS
  // ═══════════════════════════════════════════════════════════════════

  /// Visualizar valores, preços e totais das OS
  viewPrices,

  /// Visualizar faturamento e indicadores financeiros
  viewBilling,

  /// Acessar relatórios financeiros
  viewFinancialReports,

  /// Editar valores e preços
  editPrices,

  // ═══════════════════════════════════════════════════════════════════
  // RELATÓRIOS
  // ═══════════════════════════════════════════════════════════════════

  /// Acessar relatórios operacionais (status, produtividade, SLA)
  viewOperationalReports,

  /// Acessar dashboard geral
  viewDashboard,

  // ═══════════════════════════════════════════════════════════════════
  // CADASTROS
  // ═══════════════════════════════════════════════════════════════════

  /// Gerenciar clientes
  manageCustomers,

  /// Visualizar clientes
  viewCustomers,

  /// Gerenciar produtos
  manageProducts,

  /// Visualizar produtos
  viewProducts,

  /// Gerenciar serviços (catálogo)
  manageServices,

  /// Visualizar serviços
  viewServices,

  /// Gerenciar dispositivos/equipamentos
  manageDevices,

  /// Visualizar dispositivos
  viewDevices,

  // ═══════════════════════════════════════════════════════════════════
  // FOTOS E EVIDÊNCIAS
  // ═══════════════════════════════════════════════════════════════════

  /// Anexar fotos e evidências às OS
  attachPhotos,

  /// Visualizar fotos e evidências
  viewPhotos,

  // ═══════════════════════════════════════════════════════════════════
  // FORMULÁRIOS
  // ═══════════════════════════════════════════════════════════════════

  /// Preencher formulários e checklists
  fillForms,

  /// Gerenciar templates de formulários
  manageForms,

  // ═══════════════════════════════════════════════════════════════════
  // ADMINISTRAÇÃO
  // ═══════════════════════════════════════════════════════════════════

  /// Gerenciar usuários e colaboradores
  manageUsers,

  /// Gerenciar perfis e permissões
  manageRoles,

  /// Configurar empresa (dados, logo, etc.)
  manageCompany,

  /// Configurar templates, regras e parâmetros globais
  manageSettings,
}

/// Mapeamento de permissões por perfil.
///
/// Define quais permissões cada perfil possui no sistema.
class RolePermissions {
  /// Retorna o conjunto de permissões para um determinado perfil.
  static Set<PermissionType> getPermissions(RolesType role) {
    // Normaliza roles legados
    final normalizedRole = _normalizeRole(role);

    switch (normalizedRole) {
      case RolesType.admin:
        return _adminPermissions;
      case RolesType.gerente:
        return _gerentePermissions;
      case RolesType.supervisor:
        return _supervisorPermissions;
      case RolesType.consultor:
        return _consultorPermissions;
      case RolesType.tecnico:
        return _tecnicoPermissions;
      default:
        return _tecnicoPermissions; // Fallback para menor privilégio
    }
  }

  /// Verifica se um perfil possui uma determinada permissão.
  static bool hasPermission(RolesType role, PermissionType permission) {
    return getPermissions(role).contains(permission);
  }

  /// Normaliza roles legados para os novos perfis.
  static RolesType _normalizeRole(RolesType role) {
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

  /// Retorna o label amigável para exibição do perfil.
  static String getRoleLabel(RolesType role) {
    final normalizedRole = _normalizeRole(role);
    switch (normalizedRole) {
      case RolesType.admin:
        return 'Administrador';
      case RolesType.gerente:
        return 'Gerente';
      case RolesType.supervisor:
        return 'Supervisor';
      case RolesType.consultor:
        return 'Consultor';
      case RolesType.tecnico:
        return 'Técnico';
      default:
        return 'Técnico';
    }
  }

  /// Retorna a descrição do perfil.
  static String getRoleDescription(RolesType role) {
    final normalizedRole = _normalizeRole(role);
    switch (normalizedRole) {
      case RolesType.admin:
        return 'Acesso total ao sistema';
      case RolesType.gerente:
        return 'Gestão financeira e relatórios';
      case RolesType.supervisor:
        return 'Gestão operacional dos técnicos';
      case RolesType.consultor:
        return 'Vendas e acompanhamento comercial';
      case RolesType.tecnico:
        return 'Execução de serviços';
      default:
        return 'Execução de serviços';
    }
  }

  /// Retorna o ícone associado ao perfil.
  static String getRoleIcon(RolesType role) {
    final normalizedRole = _normalizeRole(role);
    switch (normalizedRole) {
      case RolesType.admin:
        return '👨‍💼';
      case RolesType.gerente:
        return '💰';
      case RolesType.supervisor:
        return '🧑‍🔧';
      case RolesType.consultor:
        return '🧑‍💼';
      case RolesType.tecnico:
        return '👷';
      default:
        return '👷';
    }
  }

  /// Lista de perfis disponíveis para seleção (exclui legados).
  static List<RolesType> get availableRoles => [
        RolesType.admin,
        RolesType.gerente,
        RolesType.supervisor,
        RolesType.consultor,
        RolesType.tecnico,
      ];

  // ═══════════════════════════════════════════════════════════════════
  // DEFINIÇÃO DE PERMISSÕES POR PERFIL
  // ═══════════════════════════════════════════════════════════════════

  /// 👨‍💼 Administrador - Acesso total
  static final Set<PermissionType> _adminPermissions = {
    // Ordens de Serviço
    PermissionType.viewAllOrders,
    PermissionType.viewAssignedOrders,
    PermissionType.viewOwnOrders,
    PermissionType.createOrder,
    PermissionType.editOrder,
    PermissionType.assignOrder,
    PermissionType.executeOrder,
    // Dados Financeiros
    PermissionType.viewPrices,
    PermissionType.viewBilling,
    PermissionType.viewFinancialReports,
    PermissionType.editPrices,
    // Relatórios
    PermissionType.viewOperationalReports,
    PermissionType.viewDashboard,
    // Cadastros
    PermissionType.manageCustomers,
    PermissionType.viewCustomers,
    PermissionType.manageProducts,
    PermissionType.viewProducts,
    PermissionType.manageServices,
    PermissionType.viewServices,
    PermissionType.manageDevices,
    PermissionType.viewDevices,
    // Fotos
    PermissionType.attachPhotos,
    PermissionType.viewPhotos,
    // Formulários
    PermissionType.fillForms,
    PermissionType.manageForms,
    // Administração
    PermissionType.manageUsers,
    PermissionType.manageRoles,
    PermissionType.manageCompany,
    PermissionType.manageSettings,
  };

  /// 💰 Gerente (Financeiro) - Gestão financeira
  static final Set<PermissionType> _gerentePermissions = {
    // Ordens de Serviço (visualização total, sem execução)
    PermissionType.viewAllOrders,
    PermissionType.viewAssignedOrders,
    PermissionType.viewOwnOrders,
    // Dados Financeiros (acesso total)
    PermissionType.viewPrices,
    PermissionType.viewBilling,
    PermissionType.viewFinancialReports,
    PermissionType.editPrices,
    // Relatórios
    PermissionType.viewOperationalReports,
    PermissionType.viewDashboard,
    // Cadastros (visualização)
    PermissionType.viewCustomers,
    PermissionType.viewProducts,
    PermissionType.viewServices,
    PermissionType.viewDevices,
    // Fotos
    PermissionType.viewPhotos,
  };

  /// 🧑‍🔧 Supervisor - Gestão operacional
  static final Set<PermissionType> _supervisorPermissions = {
    // Ordens de Serviço (gestão total, sem valores)
    PermissionType.viewAllOrders,
    PermissionType.viewAssignedOrders,
    PermissionType.viewOwnOrders,
    PermissionType.createOrder,
    PermissionType.editOrder,
    PermissionType.assignOrder,
    PermissionType.executeOrder,
    // Relatórios operacionais (sem financeiros)
    PermissionType.viewOperationalReports,
    PermissionType.viewDashboard,
    // Cadastros
    PermissionType.manageCustomers,
    PermissionType.viewCustomers,
    PermissionType.manageProducts,
    PermissionType.viewProducts,
    PermissionType.manageServices,
    PermissionType.viewServices,
    PermissionType.manageDevices,
    PermissionType.viewDevices,
    // Fotos
    PermissionType.attachPhotos,
    PermissionType.viewPhotos,
    // Formulários
    PermissionType.fillForms,
    PermissionType.manageForms,
  };

  /// 🧑‍💼 Consultor (Vendedor) - Perfil comercial
  static final Set<PermissionType> _consultorPermissions = {
    // Ordens de Serviço (apenas próprias)
    PermissionType.viewOwnOrders,
    PermissionType.createOrder,
    PermissionType.editOrder,
    // Visualizar preços para orçamentos
    PermissionType.viewPrices,
    // Cadastros (visualização para criação de OS)
    PermissionType.manageCustomers,
    PermissionType.viewCustomers,
    PermissionType.viewProducts,
    PermissionType.viewServices,
    PermissionType.viewDevices,
    // Fotos
    PermissionType.attachPhotos,
    PermissionType.viewPhotos,
    // Formulários
    PermissionType.fillForms,
  };

  /// 👷 Técnico - Execução de serviços
  static final Set<PermissionType> _tecnicoPermissions = {
    // Ordens de Serviço (apenas atribuídas)
    PermissionType.viewAssignedOrders,
    PermissionType.executeOrder,
    // Visualização básica
    PermissionType.viewCustomers,
    PermissionType.viewDevices,
    // Fotos
    PermissionType.attachPhotos,
    PermissionType.viewPhotos,
    // Formulários
    PermissionType.fillForms,
  };
}
