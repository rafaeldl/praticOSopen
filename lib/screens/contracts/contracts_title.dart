import 'package:flutter/widgets.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/services/segment_config_service.dart';

/// Name of the recurring-orders feature. When the segment already calls each
/// order "Contrato" (public works), plain "Contratos" would read as the
/// orders themselves, so the title becomes "Contratos que se repetem".
String contractsTitle(AppLocalizations l10n, String orderPlural) {
  final clashes =
      orderPlural.trim().toLowerCase() == l10n.contracts.trim().toLowerCase();
  return clashes ? l10n.recurringOrdersTitle(orderPlural) : l10n.contracts;
}

/// [contractsTitle] for the current segment.
String contractsTitleOf(BuildContext context) =>
    contractsTitle(context.l10n, SegmentConfigService().serviceOrderPlural);
