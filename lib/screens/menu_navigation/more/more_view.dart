import 'package:flutter/cupertino.dart';
import 'package:praticos/screens/contracts/contracts_title.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/screens/menu_navigation/more/more_page.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/screens/widgets/section_label.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';

/// Where a row of the profile screen (former "Mais" tab) leads.
enum MoreDestination {
  account,
  customers,
  contracts,
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
    this.customers = true,
    this.contracts = true,
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
  final bool customers;
  final bool contracts;
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
      case MoreDestination.customers:
        return customers;
      case MoreDestination.contracts:
        return contracts;
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

/// Profile screen, opened from the company button on Início (it replaced the
/// "Mais" tab). In this order, each row opening a screen (chevron): the
/// account row (avatar + name), then "Cadastros" (Clientes, Catálogo,
/// Contratos, Checklists, Avaliações), "Empresa" (Sua empresa, Equipe, Plano)
/// and "Você" (Lembretes, Avançado). No colored icons.
class MoreView extends StatelessWidget {
  const MoreView({
    super.key,
    required this.onOpen,
    this.visibility = const MoreVisibility(),
    this.planName,
    this.accountName,
    this.companyName,
    this.catalogSubtitle,
    this.version,
    this.title,
  });

  /// Large title; the company name, else "Mais".
  final String? title;

  final ValueChanged<MoreDestination> onOpen;
  final MoreVisibility visibility;

  /// Plan name shown at the end of the "Plano" row.
  final String? planName;

  /// User name: the title of the account row ("Rafael"), with "Sua conta ·
  /// company" under it. Without it the row is titled "Sua conta".
  final String? accountName;

  /// Company shown on the account row.
  final String? companyName;

  /// Second line of "Catálogo" ("Serviços e peças").
  final String? catalogSubtitle;

  /// App version shown in the footer; hidden when null.
  final String? version;

  String _title(BuildContext context, MoreDestination destination) {
    final l10n = context.l10n;
    switch (destination) {
      case MoreDestination.account:
        return l10n.yourAccount;
      case MoreDestination.customers:
        return l10n.customers;
      case MoreDestination.contracts:
        return contractsTitleOf(context);
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

  String? _subtitle(BuildContext context, MoreDestination destination) {
    switch (destination) {
      case MoreDestination.account:
        final name = accountName;
        if (name == null || name.isEmpty) return companyName;
        return [
          context.l10n.yourAccount,
          if (companyName != null) companyName,
        ].join(' · ');
      case MoreDestination.company:
        return context.l10n.moreCompanySubtitle;
      case MoreDestination.catalog:
        return catalogSubtitle;
      default:
        return null;
    }
  }

  AppListRow _row(BuildContext context, MoreDestination destination) {
    final name = accountName;
    final isAccount = destination == MoreDestination.account;
    final hasName = isAccount && name != null && name.isNotEmpty;
    return AppListRow(
      key: ValueKey('more_row_${destination.name}'),
      leading: hasName ? _Avatar(name) : null,
      title: hasName ? name : _title(context, destination),
      subtitle: _subtitle(context, destination),
      trailing: destination == MoreDestination.plan ? planName : null,
      onTap: () => onOpen(destination),
    );
  }

  /// Rows under their section label, in the fixed order. The account row
  /// has no label; empty sections are left out.
  static const sections = <List<MoreDestination>>[
    [MoreDestination.account],
    [
      MoreDestination.customers,
      MoreDestination.catalog,
      MoreDestination.contracts,
      MoreDestination.checklists,
      MoreDestination.ratings,
    ],
    [MoreDestination.company, MoreDestination.team, MoreDestination.plan],
    [MoreDestination.reminders, MoreDestination.advanced],
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final labels = [
      null,
      l10n.moreSectionRecords,
      l10n.moreSectionCompany,
      l10n.moreSectionYou,
    ];
    final children = <Widget>[];
    for (var i = 0; i < sections.length; i++) {
      final visible = sections[i].where(visibility.isVisible).toList();
      if (visible.isEmpty) continue;
      if (labels[i] != null) children.add(SectionLabel(labels[i]!));
      children.add(MoreRows(rows: [for (final d in visible) _row(context, d)]));
    }

    return MorePage(
      title: title ?? context.l10n.more,
      children: [
        ...children,
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

/// Initial of the user in a grey circle, at the start of the account row.
class _Avatar extends StatelessWidget {
  const _Avatar(this.name);

  final String name;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.secondaryFill.resolveFrom(context),
          shape: BoxShape.circle,
        ),
        child: Text(
          name.characters.first.toUpperCase(),
          style: AppTypography.bodyStrong.copyWith(
            color: AppColors.onSecondaryFill.resolveFrom(context),
          ),
        ),
      ),
    );
  }
}
