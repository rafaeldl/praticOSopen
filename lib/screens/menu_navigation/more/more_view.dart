import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/screens/menu_navigation/more/more_page.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';

/// Where a row of the "Mais" tab leads.
enum MoreDestination {
  account,
  company,
  team,
  plan,
  catalog,
  checklists,
  ratings,
  reminders,
  advanced,
}

/// Which rows the current role can see. Everything is on by default so the
/// full list (9 rows) is the reference layout.
class MoreVisibility {
  const MoreVisibility({
    this.account = true,
    this.company = true,
    this.team = true,
    this.plan = true,
    this.catalog = true,
    this.checklists = true,
    this.ratings = true,
    this.reminders = true,
    this.advanced = true,
  });

  final bool account;
  final bool company;
  final bool team;
  final bool plan;
  final bool catalog;
  final bool checklists;
  final bool ratings;
  final bool reminders;
  final bool advanced;

  bool isVisible(MoreDestination destination) {
    switch (destination) {
      case MoreDestination.account:
        return account;
      case MoreDestination.company:
        return company;
      case MoreDestination.team:
        return team;
      case MoreDestination.plan:
        return plan;
      case MoreDestination.catalog:
        return catalog;
      case MoreDestination.checklists:
        return checklists;
      case MoreDestination.ratings:
        return ratings;
      case MoreDestination.reminders:
        return reminders;
      case MoreDestination.advanced:
        return advanced;
    }
  }
}

/// The "Mais" tab: one flat list, in this order, each row opening a screen
/// (chevron): Sua conta, Sua empresa, Equipe, Plano, Catálogo, Checklists,
/// Avaliações, Lembretes, Avançado. No colored icons.
class MoreView extends StatelessWidget {
  const MoreView({
    super.key,
    required this.onOpen,
    this.visibility = const MoreVisibility(),
    this.planName,
    this.accountSubtitle,
    this.version,
  });

  final ValueChanged<MoreDestination> onOpen;
  final MoreVisibility visibility;

  /// Plan name shown at the end of the "Plano" row.
  final String? planName;

  /// Second line of "Sua conta" (user name and role).
  final String? accountSubtitle;

  /// App version shown in the footer; hidden when null.
  final String? version;

  String _title(BuildContext context, MoreDestination destination) {
    final l10n = context.l10n;
    switch (destination) {
      case MoreDestination.account:
        return l10n.yourAccount;
      case MoreDestination.company:
        return l10n.yourCompany;
      case MoreDestination.team:
        return l10n.team;
      case MoreDestination.plan:
        return l10n.planTitle;
      case MoreDestination.catalog:
        return l10n.catalog;
      case MoreDestination.checklists:
        return l10n.checklists;
      case MoreDestination.ratings:
        return l10n.ratings;
      case MoreDestination.reminders:
        return l10n.engagementReminders;
      case MoreDestination.advanced:
        return l10n.advancedTitle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      for (final destination in MoreDestination.values)
        if (visibility.isVisible(destination))
          AppListRow(
            key: ValueKey('more_row_${destination.name}'),
            title: _title(context, destination),
            subtitle:
                destination == MoreDestination.account ? accountSubtitle : null,
            trailing: destination == MoreDestination.plan ? planName : null,
            onTap: () => onOpen(destination),
          ),
    ];

    return MorePage(
      title: context.l10n.more,
      children: [
        MoreRows(rows: rows),
        if (version != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Center(
              child: Text(
                'PraticOS $version',
                style: AppTypography.label.copyWith(
                  color: AppColors.textSecondary.resolveFrom(context),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
