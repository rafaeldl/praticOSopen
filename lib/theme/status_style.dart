import 'package:flutter/cupertino.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/theme/app_colors.dart';

/// Status of an order -> dot color + localized label.
///
/// Rule (docs/DESIGN_TOKENS.md, "Situação da OS"): the color lives only on
/// the dot; the status text is always [AppColors.textSecondary]. "Overdue" and
/// "Parada" are problems, not statuses: they come after the status in text
/// ("● Pintura · Atrasada 2 dias"), bold, in [AppColors.danger] /
/// [AppColors.warning], and the dot keeps the status color.
class OrderStatusStyle {
  OrderStatusStyle._();

  /// Dynamic dot color. Resolve with `.resolveFrom(context)`.
  static CupertinoDynamicColor dotColor(String? status) {
    switch (status) {
      case 'approved':
        return AppColors.accentText;
      case 'progress':
        return AppColors.warningDot;
      case 'done':
        return AppColors.success;
      case 'quote':
      case 'canceled':
      default:
        return AppColors.textSecondary;
    }
  }

  /// Color of the "Atrasada" text (never of the dot).
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
  static TextStyle overdueTextStyle(
    BuildContext context, {
    double fontSize = 13,
  }) => TextStyle(
    fontSize: fontSize,
    fontWeight: FontWeight.w700,
    color: overdueColor.resolveFrom(context),
  );
}

/// "Parada" mark of an order -> color + localized text.
class OrderHoldStyle {
  OrderHoldStyle._();

  /// Text and icon of a stopped order ("Parada"). Resolve with
  /// `.resolveFrom(context)`.
  static const CupertinoDynamicColor color = AppColors.warning;

  /// Localized reason ("Esperando peça").
  static String reasonLabel(AppLocalizations l10n, String? reason) {
    switch (reason) {
      case OrderHoldReason.part:
        return l10n.orderHoldReasonPart;
      case OrderHoldReason.customer:
        return l10n.orderHoldReasonCustomer;
      case OrderHoldReason.authorization:
        return l10n.orderHoldReasonAuthorization;
      default:
        return l10n.orderHoldReasonOther;
    }
  }

  /// "Parada há 3 dias · Esperando peça".
  static String line(AppLocalizations l10n, OrderHold hold, DateTime now) =>
      '${l10n.orderHoldSince(hold.daysSince(now))} · '
      '${reasonLabel(l10n, hold.reason)}';
}

/// Status of a device -> dot color + localized label.
class DeviceStatusStyle {
  DeviceStatusStyle._();

  static CupertinoDynamicColor dotColor(String? status) {
    switch (status) {
      case 'maintenance':
        return AppColors.warningDot;
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
