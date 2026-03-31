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

  // ═══════════════════════════════════════════════════════════════════
  // MÓDULO FINANCEIRO AVANÇADO
  // ═══════════════════════════════════════════════════════════════════

  /// Gerenciar lançamentos financeiros (receitas/despesas)
  manageFinancialEntries,

  /// Gerenciar contas financeiras (caixa, banco, cartão)
  manageFinancialAccounts,

  /// Visualizar extrato financeiro consolidado
  viewFinancialStatement,
}

/// Mapeamento de permissões por perfil.
///
/// Define quais permissões cada perfil possui no sistema.
class RolePermissions {
  /// Returns the set of permissions for a given role.
  static Set<PermissionType> getPermissions(RolesType role) {
    switch (role) {
      case RolesType.admin:
        return _adminPermissions;
      case RolesType.manager:
        return _managerPermissions;
      case RolesType.supervisor:
        return _supervisorPermissions;
      case RolesType.consultant:
        return _consultantPermissions;
      case RolesType.technician:
        return _technicianPermissions;
    }
  }

  /// Verifica se um perfil possui uma determinada permissão.
  static bool hasPermission(RolesType role, PermissionType permission) {
    return getPermissions(role).contains(permission);
  }

  /// Returns the friendly label for role display.
  /// Requires [l10n] for internationalization support.
  static String getRoleLabel(RolesType role, dynamic l10n) {
    switch (role) {
      case RolesType.admin:
        return l10n.roleAdmin;
      case RolesType.supervisor:
        return l10n.roleSupervisor;
      case RolesType.manager:
        return l10n.roleManager;
      case RolesType.consultant:
        return l10n.roleConsultant;
      case RolesType.technician:
        return l10n.roleTechnician;
    }
  }

  /// Returns the role description.
  /// Requires [l10n] for internationalization support.
  static String getRoleDescription(RolesType role, dynamic l10n) {
    switch (role) {
      case RolesType.admin:
        return l10n.roleDescAdmin;
      case RolesType.supervisor:
        return l10n.roleDescSupervisor;
      case RolesType.manager:
        return l10n.roleDescManager;
      case RolesType.consultant:
        return l10n.roleDescConsultant;
      case RolesType.technician:
        return l10n.roleDescTechnician;
    }
  }

  /// Returns the icon associated with the role.
  static String getRoleIcon(RolesType role) {
    switch (role) {
      case RolesType.admin:
        return '👨‍💼';
      case RolesType.supervisor:
        return '🧑‍🔧';
      case RolesType.manager:
        return '💰';
      case RolesType.consultant:
        return '🧑‍💼';
      case RolesType.technician:
        return '👷';
    }
  }

  /// List of available roles for selection (excludes legacy).
  /// Ordered by hierarchy: Admin > Supervisor > Manager > Consultant > Technician
  static List<RolesType> get availableRoles => [
        RolesType.admin,
        RolesType.supervisor,
        RolesType.manager,
        RolesType.consultant,
        RolesType.technician,
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
    // Módulo Financeiro Avançado
    PermissionType.manageFinancialEntries,
    PermissionType.manageFinancialAccounts,
    PermissionType.viewFinancialStatement,
  };

  /// 💰 Manager (Financial) - Financial management
  static final Set<PermissionType> _managerPermissions = {
    // Ordens de Serviço (visualização total, sem execução)
    PermissionType.viewAllOrders,
    PermissionType.viewAssignedOrders,
    PermissionType.viewOwnOrders,
    PermissionType.editOrder,
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
    // Módulo Financeiro Avançado
    PermissionType.manageFinancialEntries,
    PermissionType.manageFinancialAccounts,
    PermissionType.viewFinancialStatement,
  };

  /// 🧑‍🔧 Supervisor - Gestão operacional (SEM acesso financeiro)
  static final Set<PermissionType> _supervisorPermissions = {
    // Ordens de Serviço (gestão total, sem valores)
    PermissionType.viewAllOrders,
    PermissionType.viewAssignedOrders,
    PermissionType.viewOwnOrders,
    PermissionType.createOrder,
    PermissionType.editOrder,
    PermissionType.assignOrder,
    PermissionType.executeOrder,
    // Cadastros (clientes e equipamentos apenas)
    PermissionType.manageCustomers,
    PermissionType.viewCustomers,
    PermissionType.viewProducts,
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

  /// 🧑‍💼 Consultant (Sales) - Commercial profile
  static final Set<PermissionType> _consultantPermissions = {
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

  /// 👷 Technician - Service execution
  static final Set<PermissionType> _technicianPermissions = {
    // Ordens de Serviço (apenas atribuídas)
    PermissionType.viewAssignedOrders,
    PermissionType.createOrder,
    PermissionType.editOrder,
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
