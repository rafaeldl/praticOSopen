import 'package:flutter/cupertino.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/theme/app_colors.dart';

/// Status of an order -> dot color + localized label.
///
/// Rule (docs/APP_DESIGN_SYSTEM.md): the color lives only on the dot; the
/// status text is always [AppColors.textSecondary]. "Overdue" is not a status,
/// it is a problem: dot and text use [AppColors.danger], text in bold.
class OrderStatusStyle {
  OrderStatusStyle._();

  /// Dynamic dot color. Resolve with `.resolveFrom(context)`.
  static CupertinoDynamicColor dotColor(String? status) {
    switch (status) {
      case 'approved':
        return AppColors.accentText;
      case 'progress':
        return AppColors.warning;
      case 'done':
        return AppColors.success;
      case 'quote':
      case 'canceled':
      default:
        return AppColors.textSecondary;
    }
  }

  /// Dot color for an overdue order.
  static const CupertinoDynamicColor overdueColor = AppColors.danger;

  /// Default (non segment-customized) label. Where the segment may rename
  /// statuses, prefer `SegmentConfigProvider.getStatus`.
  static String label(AppLocalizations l10n, String? status) {
    switch (status) {
      case 'quote':
        return l10n.statusQuote;
      case 'approved':
        return l10n.statusApproved;
      case 'progress':
        return l10n.statusInProgress;
      case 'done':
        return l10n.statusCompleted;
      case 'canceled':
        return l10n.statusCancelled;
      default:
        return status ?? '';
    }
  }

  /// Text style of the status label: neutral, never colored.
  static TextStyle textStyle(BuildContext context, {double fontSize = 13}) =>
      TextStyle(
        fontSize: fontSize,
        color: AppColors.textSecondary.resolveFrom(context),
      );

  /// Text style of the "Atrasada" label: danger, bold.
  static TextStyle overdueTextStyle(BuildContext context,
          {double fontSize = 13}) =>
      TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        color: overdueColor.resolveFrom(context),
      );
}

/// Status of a device -> dot color + localized label.
class DeviceStatusStyle {
  DeviceStatusStyle._();

  static CupertinoDynamicColor dotColor(String? status) {
    switch (status) {
      case 'maintenance':
        return AppColors.warning;
      case 'inactive':
      case 'decommissioned':
        return AppColors.textSecondary;
      case 'active':
      default:
        return AppColors.success;
    }
  }

  static String label(AppLocalizations l10n, String? status) {
    switch (status) {
      case 'maintenance':
        return l10n.deviceStatusMaintenance;
      case 'inactive':
        return l10n.deviceStatusInactive;
      case 'decommissioned':
        return l10n.deviceStatusDecommissioned;
      case 'active':
      default:
        return l10n.deviceStatusActive;
    }
  }
}
