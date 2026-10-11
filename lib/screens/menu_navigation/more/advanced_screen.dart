import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/screens/menu_navigation/more/more_page.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';

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

  /// Whether the "Avançado" row has anything to show.
  static bool hasEntries({
    required bool showIntegrations,
    required bool showDevices,
  }) =>
      showIntegrations || showDevices;

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
      ],
    );
  }
}
