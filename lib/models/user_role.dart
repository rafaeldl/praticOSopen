import 'package:praticos/models/base_audit_company.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/user.dart';
import 'package:json_annotation/json_annotation.dart';

part 'user_role.g.dart';

/// Perfis de usuário no PraticOS com controle rigoroso de permissões (RBAC).
///
/// Hierarquia de perfis:
/// - [admin]: Acesso total ao sistema
/// - [gerente]: Gestão financeira (valores, faturamento, relatórios financeiros)
/// - [supervisor]: Gestão operacional (todas OS, sem valores financeiros)
/// - [consultor]: Perfil comercial (apenas suas próprias OS)
/// - [tecnico]: Execução técnica (apenas OS atribuídas, sem valores)
enum RolesType {
  /// 👨‍💼 Administrador - Acesso total ao sistema
  /// Pode: gerenciar usuários, perfis, permissões, acessar todas as áreas,
  /// configurar templates, regras e parâmetros globais
  admin,

  /// 💰 Gerente (Financeiro) - Gestão financeira
  /// Pode: visualizar valores, preços, faturamento, relatórios financeiros
  /// Não pode: alterar execução técnica, gerenciar templates operacionais
  gerente,

  /// 🧑‍🔧 Supervisor - Gestão operacional dos técnicos
  /// Pode: visualizar todas OS, atribuir/reatribuir OS, relatórios operacionais
  /// Não pode: visualizar valores financeiros, faturamento, dados contábeis
  supervisor,

  /// 🧑‍💼 Consultor (Vendedor) - Perfil comercial
  /// Pode: criar e acompanhar suas próprias OS, visualizar status e histórico
  /// Não pode: visualizar OS de outros, relatórios gerais, dados financeiros globais
  consultor,

  /// 👷 Técnico - Execução de serviços
  /// Pode: executar serviços, preencher formulários, anexar fotos, atualizar status
  /// Não pode: visualizar valores/preços, acessar relatórios, dados comerciais
  tecnico,

  /// Compatibilidade com sistema legado - mapeado para tecnico
  @Deprecated('Use tecnico instead')
  manager,

  /// Compatibilidade com sistema legado - mapeado para tecnico
  @Deprecated('Use tecnico instead')
  user,
}

@JsonSerializable(explicitToJson: true)
class UserRole extends BaseAuditCompany {
  UserAggr? user;
  RolesType? role;

  UserRole();
  factory UserRole.fromJson(Map<String, dynamic> json) =>
      _$UserRoleFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$UserRoleToJson(this);
  UserRoleAggr toUserRoleAggr() => _$UserRoleAggrFromJson(toJson());
  CompanyRoleAggr toCompanyRoleAggr() =>
      _$CompanyRoleAggrFromJson(toJson());
}

@JsonSerializable(explicitToJson: true)
class UserRoleAggr {
  UserAggr? user;
  RolesType? role;

  UserRoleAggr();
  factory UserRoleAggr.fromJson(Map<String, dynamic> json) =>
      _$UserRoleAggrFromJson(json);
  Map<String, dynamic> toJson() => _$UserRoleAggrToJson(this);
}

@JsonSerializable(explicitToJson: true)
class CompanyRoleAggr {
  CompanyAggr? company;
  RolesType? role;

  CompanyRoleAggr();
  factory CompanyRoleAggr.fromJson(Map<String, dynamic> json) =>
      _$CompanyRoleAggrFromJson(json);
  Map<String, dynamic> toJson() => _$CompanyRoleAggrToJson(this);
}
