import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/screens/menu_navigation/more/more_page.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/screens/widgets/section_label.dart';
import 'package:provider/provider.dart';

/// "Sua empresa": company data and the "Como você trabalha" switches.
///
/// Presentational: [MyCompanySettings] wires "Valores e cobrança" to
/// `Company.useFinancial`. Without [onFinancialChanged] the row shows as
/// disabled.
class MyCompanyScreen extends StatelessWidget {
  const MyCompanyScreen({
    super.key,
    required this.onOpenCompanyData,
    this.useFinancial = true,
    this.onFinancialChanged,
  });

  final VoidCallback onOpenCompanyData;
  final bool useFinancial;

  /// Null renders the row disabled.
  final ValueChanged<bool>? onFinancialChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return MorePage(
      title: l10n.yourCompany,
      children: [
        MoreRows(rows: [
          AppListRow(
            key: const ValueKey('company_data'),
            title: l10n.companyData,
            onTap: onOpenCompanyData,
          ),
        ]),
        SectionLabel(l10n.howYouWork),
        MoreRows(rows: [
          MoreSwitchRow(
            key: const ValueKey('company_use_financial'),
            title: l10n.valuesAndBilling,
            subtitle: l10n.valuesAndBillingHint,
            value: useFinancial,
            onChanged: onFinancialChanged,
          ),
        ]),
      ],
    );
  }
}

/// Writes fields of the company document (`/companies/{companyId}`).
typedef CompanyFieldsWriter = Future<void> Function(
  String companyId,
  Map<String, dynamic> fields,
);

Future<void> _writeCompanyFields(
  String companyId,
  Map<String, dynamic> fields,
) {
  return FirebaseFirestore.instance
      .collection('companies')
      .doc(companyId)
      .update(fields);
}

/// [MyCompanyScreen] wired to the company: "Valores e cobrança" reads the
/// resolved `useFinancial` from [SegmentConfigProvider] and writes
/// `Company.useFinancial`.
///
/// Turning it off asks for confirmation first (open payment links keep
/// working; nothing is deleted). The change applies right away for this
/// device and goes back if the write fails.
class MyCompanySettings extends StatefulWidget {
  const MyCompanySettings({
    super.key,
    required this.companyId,
    required this.onOpenCompanyData,
    CompanyFieldsWriter? writer,
  }) : writer = writer ?? _writeCompanyFields;

  /// Null when there is no current company: the switch is disabled.
  final String? companyId;
  final VoidCallback onOpenCompanyData;
  final CompanyFieldsWriter writer;

  @override
  State<MyCompanySettings> createState() => _MyCompanySettingsState();
}

class _MyCompanySettingsState extends State<MyCompanySettings> {
  bool _saving = false;

  Future<bool> _confirmTurnOff() async {
    final l10n = context.l10n;
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(l10n.valuesAndBillingOffTitle),
        content: Text(l10n.valuesAndBillingOffMessage),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.valuesAndBillingOffAction),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _change(bool value) async {
    final companyId = widget.companyId;
    if (companyId == null || _saving) return;
    if (!value && !await _confirmTurnOff()) return;
    if (!mounted) return;
    final provider = context.read<SegmentConfigProvider>();
    final previous = provider.useFinancial;
    setState(() => _saving = true);
    provider.setUseFinancial(value);
    try {
      await widget.writer(companyId, {'useFinancial': value});
    } catch (_) {
      provider.setUseFinancial(previous);
      if (mounted) await _showError();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showError() {
    final l10n = context.l10n;
    return showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        content: Text(l10n.valuesAndBillingSaveError),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final useFinancial = context.watch<SegmentConfigProvider>().useFinancial;
    return MyCompanyScreen(
      onOpenCompanyData: widget.onOpenCompanyData,
      useFinancial: useFinancial,
      onFinancialChanged:
          widget.companyId == null || _saving ? null : _change,
    );
  }
}
