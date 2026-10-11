import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/screens/menu_navigation/more/more_page.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/screens/widgets/section_label.dart';
import 'package:provider/provider.dart';

/// Company switches of "Como você trabalha" besides "Valores e cobrança",
/// keyed by their `Company` field.
enum CompanyFeature { useScheduling, fieldService, useContracts, useDeviceManagement }

/// "Sua empresa": what shows on the customer's order (name, logo, contact
/// and terms) and "Como você trabalha" (ramo, especialidades and switches).
///
/// Presentational: [MyCompanySettings] wires the switches to the company
/// document. A null callback renders that switch disabled.
class MyCompanyScreen extends StatelessWidget {
  const MyCompanyScreen({
    super.key,
    required this.onOpenCompanyData,
    this.companyName,
    this.devicesLabel,
    this.useFinancial = true,
    this.onFinancialChanged,
    this.features = const {},
    this.onFeatureChanged,
  });

  /// Opens the company form (name, logo, contact, terms, ramo).
  final VoidCallback onOpenCompanyData;
  final String? companyName;

  /// Plural device label of the segment ("veículos"); null hides "Controle
  /// de veículos".
  final String? devicesLabel;
  final bool useFinancial;

  /// Null renders the row disabled.
  final ValueChanged<bool>? onFinancialChanged;

  /// Current value of each switch; absent ones read as off.
  final Map<CompanyFeature, bool> features;

  /// Null renders those switches disabled.
  final void Function(CompanyFeature feature, bool value)? onFeatureChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    MoreSwitchRow feature(CompanyFeature f, String title, String subtitle) =>
        MoreSwitchRow(
          key: ValueKey('company_${f.name}'),
          title: title,
          subtitle: subtitle,
          value: features[f] ?? false,
          onChanged: onFeatureChanged == null
              ? null
              : (value) => onFeatureChanged!(f, value),
        );
    final name = companyName?.trim();
    return MorePage(
      title: l10n.yourCompany,
      children: [
        SectionLabel(l10n.companyShownOnOrder),
        MoreRows(rows: [
          AppListRow(
            key: const ValueKey('company_data'),
            title: name == null || name.isEmpty ? l10n.companyData : name,
            subtitle: l10n.companyNameLogoContact,
            onTap: onOpenCompanyData,
          ),
          AppListRow(
            key: const ValueKey('company_terms'),
            title: l10n.customerTerms,
            subtitle: l10n.customerTermsHint,
            onTap: onOpenCompanyData,
          ),
        ]),
        SectionLabel(l10n.howYouWork),
        MoreRows(rows: [
          AppListRow(
            key: const ValueKey('company_segment'),
            title: l10n.segmentRow,
            subtitle: l10n.segmentRowHint,
            onTap: onOpenCompanyData,
          ),
          MoreSwitchRow(
            key: const ValueKey('company_use_financial'),
            title: l10n.valuesAndBilling,
            subtitle: l10n.valuesAndBillingHint,
            value: useFinancial,
            onChanged: onFinancialChanged,
          ),
          feature(CompanyFeature.useScheduling, l10n.schedulingRow,
              l10n.schedulingRowHint),
          feature(CompanyFeature.fieldService, l10n.fieldServiceRow,
              l10n.fieldServiceRowHint),
          feature(CompanyFeature.useContracts, l10n.contracts,
              l10n.contractsRowHint),
          if (devicesLabel != null)
            feature(
              CompanyFeature.useDeviceManagement,
              l10n.deviceControlRow(devicesLabel!.toLowerCase()),
              l10n.deviceControlRowHint,
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
    this.companyName,
    CompanyFieldsWriter? writer,
  }) : writer = writer ?? _writeCompanyFields;

  /// Null when there is no current company: the switches are disabled.
  final String? companyId;
  final String? companyName;
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

  /// Writes one "Como você trabalha" switch; applies it right away and goes
  /// back if the write fails.
  Future<void> _changeFeature(CompanyFeature feature, bool value) async {
    final companyId = widget.companyId;
    if (companyId == null || _saving) return;
    final provider = context.read<SegmentConfigProvider>();
    final previous = _features(provider);
    setState(() => _saving = true);
    _apply(provider, {...previous, feature: value});
    try {
      await widget.writer(companyId, {feature.name: value});
    } catch (_) {
      _apply(provider, previous);
      if (mounted) await _showError(context.l10n.companySettingSaveError);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Map<CompanyFeature, bool> _features(SegmentConfigProvider provider) => {
        CompanyFeature.useScheduling: provider.useScheduling,
        CompanyFeature.fieldService: provider.fieldService,
        CompanyFeature.useContracts: provider.useContracts,
        CompanyFeature.useDeviceManagement: provider.useDeviceManagement,
      };

  void _apply(SegmentConfigProvider provider, Map<CompanyFeature, bool> f) {
    provider.setCompanyConfig(
      fieldService: f[CompanyFeature.fieldService]!,
      useScheduling: f[CompanyFeature.useScheduling]!,
      useDeviceManagement: f[CompanyFeature.useDeviceManagement]!,
      useContracts: f[CompanyFeature.useContracts]!,
      useFinancial: provider.useFinancial,
    );
  }

  Future<void> _showError([String? message]) {
    final l10n = context.l10n;
    return showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        content: Text(message ?? l10n.valuesAndBillingSaveError),
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
    final provider = context.watch<SegmentConfigProvider>();
    final enabled = widget.companyId != null && !_saving;
    return MyCompanyScreen(
      onOpenCompanyData: widget.onOpenCompanyData,
      companyName: widget.companyName,
      devicesLabel: provider.devicePlural,
      useFinancial: provider.useFinancial,
      onFinancialChanged: enabled ? _change : null,
      features: _features(provider),
      onFeatureChanged: enabled ? _changeFeature : null,
    );
  }
}
