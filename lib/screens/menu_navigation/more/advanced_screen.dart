import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/screens/menu_navigation/more/more_page.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/services/order_screen_preference.dart';

/// "Avançado": what is left after the daily items. Each entry keeps the
/// permission rule it had in the old settings screen; the "Avançado" row
/// itself shows when at least one entry is allowed.
class AdvancedScreen extends StatelessWidget {
  const AdvancedScreen({
    super.key,
    required this.devicesLabel,
    required this.showIntegrations,
    required this.showDevices,
    required this.onOpenIntegrations,
    required this.onOpenDevices,
  });

  /// Segment label of the vehicles list ("Veículos", "Aparelhos", ...).
  final String devicesLabel;
  final bool showIntegrations;
  final bool showDevices;
  final VoidCallback onOpenIntegrations;
  final VoidCallback onOpenDevices;

  /// Whether the "Avançado" row has anything to show. The "Nova tela da OS"
  /// pilot switch is always there, so the row always shows.
  static bool hasEntries({
    required bool showIntegrations,
    required bool showDevices,
  }) =>
      true;

  @override
  Widget build(BuildContext context) {
    return MorePage(
      title: context.l10n.advancedTitle,
      children: [
        MoreRows(rows: [
          if (showIntegrations)
            AppListRow(
              key: const ValueKey('advanced_integrations'),
              title: context.l10n.integrations,
              onTap: onOpenIntegrations,
            ),
          if (showDevices)
            AppListRow(
              key: const ValueKey('advanced_devices'),
              title: devicesLabel,
              onTap: onOpenDevices,
            ),
        ]),
        // "Nova tela da OS": local pilot switch (off by default)
        ValueListenableBuilder<bool>(
          valueListenable: OrderScreenPreference.useNewScreen,
          builder: (context, useNew, _) => CupertinoListSection.insetGrouped(
            footer: Text(context.l10n.newOrderScreenSettingHint),
            children: [
              CupertinoListTile(
                key: const ValueKey('advanced_new_order_screen'),
                title: Text(context.l10n.newOrderScreenSetting),
                trailing: CupertinoSwitch(
                  value: useNew,
                  onChanged: OrderScreenPreference.set,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
