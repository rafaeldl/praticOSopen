import 'package:flutter/cupertino.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:praticos/models/permission.dart';
import 'package:praticos/models/user_role.dart';
import 'package:praticos/services/authorization_service.dart';

/// Widget que mostra ou oculta conteúdo baseado em permissões.
///
/// Uso simples:
/// ```dart
/// PermissionGuard(
///   permission: PermissionType.viewPrices,
///   child: Text('R\$ 100,00'),
/// )
/// ```
///
/// Com fallback:
/// ```dart
/// PermissionGuard(
///   permission: PermissionType.viewPrices,
///   fallback: Text('***'),
///   child: Text('R\$ 100,00'),
/// )
/// ```
class PermissionGuard extends StatelessWidget {
  final PermissionType permission;
  final Widget child;
  final Widget? fallback;

  const PermissionGuard({
    super.key,
    required this.permission,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (_) {
        final auth = AuthorizationService.instance;
        if (auth.hasPermission(permission)) {
          return child;
        }
        return fallback ?? const SizedBox.shrink();
      },
    );
  }
}

/// Widget que mostra ou oculta conteúdo baseado em múltiplas permissões.
///
/// Modo 'all': requer todas as permissões.
/// Modo 'any': requer pelo menos uma das permissões.
class MultiPermissionGuard extends StatelessWidget {
  final List<PermissionType> permissions;
  final bool requireAll;
  final Widget child;
  final Widget? fallback;

  const MultiPermissionGuard({
    super.key,
    required this.permissions,
    this.requireAll = true,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (_) {
        final auth = AuthorizationService.instance;
        final hasAccess = requireAll
            ? auth.hasAllPermissions(permissions)
            : auth.hasAnyPermission(permissions);

        if (hasAccess) {
          return child;
        }
        return fallback ?? const SizedBox.shrink();
      },
    );
  }
}

/// Widget que mostra ou oculta conteúdo baseado no perfil do usuário.
///
/// Uso:
/// ```dart
/// RoleGuard(
///   allowedRoles: [RolesType.admin, RolesType.gerente],
///   child: FinancialDashboard(),
/// )
/// ```
class RoleGuard extends StatelessWidget {
  final List<RolesType> allowedRoles;
  final Widget child;
  final Widget? fallback;

  const RoleGuard({
    super.key,
    required this.allowedRoles,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (_) {
        final auth = AuthorizationService.instance;
        final currentRole = auth.normalizedRole;

        if (currentRole != null && allowedRoles.contains(currentRole)) {
          return child;
        }
        return fallback ?? const SizedBox.shrink();
      },
    );
  }
}

/// Builder que fornece informações de permissão para construção condicional.
///
/// Uso:
/// ```dart
/// PermissionBuilder(
///   permission: PermissionType.viewPrices,
///   builder: (context, hasPermission) {
///     return ListTile(
///       title: Text('Total'),
///       subtitle: hasPermission
///           ? Text('R\$ ${order.total}')
///           : Text('Sem acesso'),
///     );
///   },
/// )
/// ```
class PermissionBuilder extends StatelessWidget {
  final PermissionType permission;
  final Widget Function(BuildContext context, bool hasPermission) builder;

  const PermissionBuilder({
    super.key,
    required this.permission,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (_) {
        final auth = AuthorizationService.instance;
        return builder(context, auth.hasPermission(permission));
      },
    );
  }
}

/// Builder que fornece o perfil atual e suas permissões.
///
/// Uso avançado para lógica complexa:
/// ```dart
/// RoleBuilder(
///   builder: (context, role, permissions) {
///     if (role == RolesType.admin) {
///       return AdminView();
///     } else if (permissions.contains(PermissionType.viewPrices)) {
///       return FinancialView();
///     }
///     return BasicView();
///   },
/// )
/// ```
class RoleBuilder extends StatelessWidget {
  final Widget Function(
    BuildContext context,
    RolesType? role,
    Set<PermissionType> permissions,
  ) builder;

  const RoleBuilder({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (_) {
        final auth = AuthorizationService.instance;
        return builder(
          context,
          auth.normalizedRole,
          auth.currentPermissions,
        );
      },
    );
  }
}

/// Widget para ocultar valores financeiros de usuários sem permissão.
///
/// Automaticamente substitui o valor por '***' ou outro placeholder.
class ProtectedValue extends StatelessWidget {
  final String value;
  final String placeholder;
  final TextStyle? style;

  const ProtectedValue({
    super.key,
    required this.value,
    this.placeholder = '***',
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (_) {
        final auth = AuthorizationService.instance;
        final displayValue =
            auth.canViewPrices ? value : placeholder;

        return Text(
          displayValue,
          style: style,
        );
      },
    );
  }
}

/// Widget para formatar e proteger valores monetários.
///
/// Uso:
/// ```dart
/// ProtectedCurrency(
///   value: order.total,
///   prefix: 'R\$ ',
/// )
/// ```
class ProtectedCurrency extends StatelessWidget {
  final double? value;
  final String prefix;
  final String placeholder;
  final TextStyle? style;
  final int decimalDigits;

  const ProtectedCurrency({
    super.key,
    required this.value,
    this.prefix = 'R\$ ',
    this.placeholder = '***',
    this.style,
    this.decimalDigits = 2,
  });

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (_) {
        final auth = AuthorizationService.instance;

        if (!auth.canViewPrices) {
          return Text(placeholder, style: style);
        }

        final formattedValue = value != null
            ? '$prefix${value!.toStringAsFixed(decimalDigits)}'
            : '-';

        return Text(formattedValue, style: style);
      },
    );
  }
}

/// Tela de acesso negado padrão.
///
/// Pode ser usada como fallback em guards ou como tela standalone.
class AccessDeniedScreen extends StatelessWidget {
  final String? message;
  final VoidCallback? onBack;

  const AccessDeniedScreen({
    super.key,
    this.message,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Acesso Negado'),
        leading: onBack != null
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: onBack,
                child: const Icon(CupertinoIcons.back),
              )
            : null,
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  CupertinoIcons.lock_fill,
                  size: 64,
                  color: CupertinoColors.systemGrey,
                ),
                const SizedBox(height: 24),
                Text(
                  message ?? 'Você não tem permissão para acessar esta área.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
                const SizedBox(height: 32),
                if (onBack != null)
                  CupertinoButton.filled(
                    onPressed: onBack,
                    child: const Text('Voltar'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Wrapper para proteger rotas/páginas inteiras.
///
/// Uso:
/// ```dart
/// ProtectedRoute(
///   permission: PermissionType.viewFinancialReports,
///   child: FinancialReportScreen(),
/// )
/// ```
class ProtectedRoute extends StatelessWidget {
  final PermissionType permission;
  final Widget child;
  final String? accessDeniedMessage;

  const ProtectedRoute({
    super.key,
    required this.permission,
    required this.child,
    this.accessDeniedMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (_) {
        final auth = AuthorizationService.instance;

        if (auth.hasPermission(permission)) {
          return child;
        }

        return AccessDeniedScreen(
          message: accessDeniedMessage,
          onBack: () => Navigator.of(context).pop(),
        );
      },
    );
  }
}

/// Wrapper para proteger rotas baseado em perfil.
class ProtectedRouteByRole extends StatelessWidget {
  final List<RolesType> allowedRoles;
  final Widget child;
  final String? accessDeniedMessage;

  const ProtectedRouteByRole({
    super.key,
    required this.allowedRoles,
    required this.child,
    this.accessDeniedMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (_) {
        final auth = AuthorizationService.instance;
        final currentRole = auth.normalizedRole;

        if (currentRole != null && allowedRoles.contains(currentRole)) {
          return child;
        }

        return AccessDeniedScreen(
          message: accessDeniedMessage,
          onBack: () => Navigator.of(context).pop(),
        );
      },
    );
  }
}
