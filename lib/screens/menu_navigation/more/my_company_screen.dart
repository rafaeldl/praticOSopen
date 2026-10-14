import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/global.dart';
import 'package:praticos/mobx/company_store.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/screens/menu_navigation/more/company_editors.dart';
import 'package:praticos/screens/menu_navigation/more/more_page.dart';
import 'package:praticos/services/onboarding_service.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/screens/widgets/section_label.dart';
import 'package:provider/provider.dart';

/// Company switches of "Como você trabalha" besides "Valores e cobrança",
/// keyed by their `Company` field.
enum CompanyFeature {
  useScheduling,
  fieldService,
  useContracts,
  useDeviceManagement,
}

/// "Sua empresa": what shows on the customer's order (name, logo, contact
/// and terms) and "Como você trabalha" (ramo, especialidades and switches).
///
/// Presentational: [MyCompanySettings] wires the switches to the company
/// document. A null callback renders that switch disabled.
class MyCompanyScreen extends StatelessWidget {
  const MyCompanyScreen({
    super.key,
    required this.onOpenCompanyData,
    required this.onOpenTerms,
    required this.onOpenSegment,
    this.onOpenSpecialties,
    this.companyName,
    this.segmentName,
    this.specialties,
    this.devicesLabel,
    this.useFinancial = true,
    this.onFinancialChanged,
    this.features = const {},
    this.onFeatureChanged,
  });

  /// Opens "Nome, logo e contato".
  final VoidCallback onOpenCompanyData;

  /// Opens "Termos para o cliente".
  final VoidCallback onOpenTerms;

  /// Opens the choice of the segment ("Ramo").
  final VoidCallback onOpenSegment;

  /// Opens the choice of the specialties; null hides "Especialidades" (the
  /// segment has none).
  final VoidCallback? onOpenSpecialties;
  final String? companyName;

  /// Current segment name, shown at the end of "Ramo".
  final String? segmentName;

  /// Names of the checked specialties; empty or null shows a hint.
  final List<String>? specialties;

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
        MoreRows(
          rows: [
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
              onTap: onOpenTerms,
            ),
          ],
        ),
        SectionLabel(l10n.howYouWork),
        MoreRows(
          rows: [
            AppListRow(
              key: const ValueKey('company_segment'),
              title: l10n.segmentRow,
              subtitle: l10n.segmentRowHint,
              trailing: segmentName,
              onTap: onOpenSegment,
            ),
            if (onOpenSpecialties != null)
              AppListRow(
                key: const ValueKey('company_specialties'),
                title: l10n.specialties,
                subtitle: specialties == null || specialties!.isEmpty
                    ? l10n.specialtiesNone
                    : specialties!.join(', '),
                onTap: onOpenSpecialties,
              ),
            MoreSwitchRow(
              key: const ValueKey('company_use_financial'),
              title: l10n.valuesAndBilling,
              subtitle: l10n.valuesAndBillingHint,
              value: useFinancial,
              onChanged: onFinancialChanged,
            ),
            feature(
              CompanyFeature.useScheduling,
              l10n.schedulingRow,
              l10n.schedulingRowHint,
            ),
            feature(
              CompanyFeature.fieldService,
              l10n.fieldServiceRow,
              l10n.fieldServiceRowHint,
            ),
            feature(
              CompanyFeature.useContracts,
              l10n.contracts,
              l10n.contractsRowHint,
            ),
            if (devicesLabel != null)
              feature(
                CompanyFeature.useDeviceManagement,
                l10n.deviceControlRow(devicesLabel!.toLowerCase()),
                l10n.deviceControlRowHint,
              ),
          ],
        ),
      ],
    );
  }
}

/// Writes fields of the company document (`/companies/{companyId}`).
typedef CompanyFieldsWriter =
    Future<void> Function(String companyId, Map<String, dynamic> fields);

Future<void> _writeCompanyFields(
  String companyId,
  Map<String, dynamic> fields,
) {
  return FirebaseFirestore.instance
      .collection('companies')
      .doc(companyId)
      .update(fields);
}

/// Reads the company document (defaults to [CompanyStore.retrieveCompany]).
typedef CompanyLoader = Future<Company?> Function(String companyId);

/// Reads the active segments (defaults to the first snapshot of
/// [firestoreOnboardingSegments]).
typedef SegmentsLoader = Future<List<OnboardingSegment>> Function();

Future<Company?> _loadCompanyWithStore(String companyId) async =>
    await CompanyStore().retrieveCompany(companyId) as Company?;

Future<void> _saveCompanyWithStore(Company company) =>
    CompanyStore().updateCompany(company);

Future<List<OnboardingSegment>> _loadActiveSegments() =>
    firestoreOnboardingSegments().first;

/// [MyCompanyScreen] wired to the company: "Valores e cobrança" reads the
/// resolved `useFinancial` from [SegmentConfigProvider] and writes
/// `Company.useFinancial`.
///
/// Turning it off asks for confirmation first (open payment links keep
/// working; nothing is deleted). The change applies right away for this
/// device and goes back if the write fails.
///
/// Each row opens its own editor: [CompanyDataScreen] (name, logo,
/// contact), [CompanyTermsScreen], and the choice of the segment and the
/// specialties (saved right after picking). Saves go through [saveCompany]
/// and update `Global.companyAggr` and [SegmentConfigProvider] (segment and
/// country), as the old company form did.
class MyCompanySettings extends StatefulWidget {
  const MyCompanySettings({
    super.key,
    required this.companyId,
    this.companyName,
    CompanyFieldsWriter? writer,
    CompanyLoader? loadCompany,
    CompanySaver? saveCompany,
    SegmentsLoader? loadSegments,
    this.uploadLogo,
  }) : writer = writer ?? _writeCompanyFields,
       loadCompany = loadCompany ?? _loadCompanyWithStore,
       saveCompany = saveCompany ?? _saveCompanyWithStore,
       loadSegments = loadSegments ?? _loadActiveSegments;

  /// Null when there is no current company: the switches are disabled.
  final String? companyId;

  /// Shown until the company document loads.
  final String? companyName;
  final CompanyFieldsWriter writer;
  final CompanyLoader loadCompany;
  final CompanySaver saveCompany;
  final SegmentsLoader loadSegments;
  final CompanyLogoUploader? uploadLogo;

  @override
  State<MyCompanySettings> createState() => _MyCompanySettingsState();
}

class _MyCompanySettingsState extends State<MyCompanySettings> {
  bool _saving = false;
  Company? _company;
  List<OnboardingSegment>? _segments;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final companyId = widget.companyId;
    if (companyId == null) return;
    try {
      final company = await widget.loadCompany(companyId);
      if (mounted) setState(() => _company = company);
    } catch (e) {
      debugPrint('Sua empresa: company failed to load: $e');
    }
    try {
      final segments = await widget.loadSegments();
      if (mounted) setState(() => _segments = segments);
    } catch (e) {
      debugPrint('Sua empresa: segments failed to load: $e');
    }
  }

  OnboardingSegment? get _segment {
    final id = _company?.segment;
    for (final s in _segments ?? const <OnboardingSegment>[]) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Saves [company] and applies it to the app.
  Future<void> _persist(Company company) async {
    company
      ..updatedAt = DateTime.now()
      ..updatedBy = Global.userAggr;
    await widget.saveCompany(company);
    if (!mounted) return;
    final aggr = Global.companyAggr;
    if (aggr != null && company.id == aggr.id) {
      aggr
        ..name = company.name
        ..country = company.country;
      final provider = context.read<SegmentConfigProvider>();
      final segment = company.segment;
      if (segment != null && provider.segmentId != segment) {
        provider.initialize(segment).catchError((Object e) {
          debugPrint('Sua empresa: segment failed to load: $e');
        });
      }
      if (company.country != null) provider.setCountry(company.country);
    }
  }

  Future<void> _push(Widget screen) async {
    final saved = await Navigator.of(
      context,
    ).push<Company>(CupertinoPageRoute<Company>(builder: (_) => screen));
    if (saved != null && mounted) setState(() => _company = saved);
  }

  void _openData() {
    final company = _company;
    if (company == null) return;
    _push(
      CompanyDataScreen(
        company: company,
        onSave: _persist,
        phoneMasks: context.read<SegmentConfigProvider>().getMasks(
          'company.phone',
        ),
        uploadLogo: widget.uploadLogo,
        onLogoChanged: (url) {
          if (mounted) setState(() => _company?.logo = url);
        },
      ),
    );
  }

  void _openTerms() {
    final company = _company;
    if (company == null) return;
    _push(
      CompanyTermsScreen(
        company: company,
        onSave: _persist,
        defaultTerms: context
            .read<SegmentConfigProvider>()
            .defaultTermsOfService,
      ),
    );
  }

  /// Saves a change picked from a list (segment, specialties).
  Future<void> _saveChange(void Function(Company copy) change) async {
    final company = _company;
    if (company == null) return;
    final copy = copyCompany(company);
    change(copy);
    setState(() => _saving = true);
    try {
      await _persist(copy);
      if (mounted) setState(() => _company = copy);
    } catch (_) {
      if (mounted) await _showError(context.l10n.companySettingSaveError);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openSegment() async {
    final segments = _segments;
    if (_company == null || segments == null || segments.isEmpty) return;
    final id = await pickCompanySegment(
      context,
      segments: segments,
      selectedId: _company?.segment,
    );
    if (id == null || id == _company?.segment || !mounted) return;
    // A new segment clears the specialties of the previous one.
    await _saveChange(
      (copy) => copy
        ..segment = id
        ..subspecialties = null,
    );
  }

  Future<void> _openSpecialties() async {
    final segment = _segment;
    if (segment == null) return;
    final ids = await pickCompanySpecialties(
      context,
      segment: segment,
      selected: _company?.subspecialties ?? const [],
    );
    if (ids == null || !mounted) return;
    await _saveChange((copy) => copy.subspecialties = ids.isEmpty ? null : ids);
  }

  /// Keeps the loaded company in step with a switch that was written, so a
  /// later save from an editor does not put the old value back.
  void _keepInCompany(String field, bool value) {
    final company = _company;
    if (company == null) return;
    switch (field) {
      case 'useFinancial':
        company.useFinancial = value;
      case 'useScheduling':
        company.useScheduling = value;
      case 'fieldService':
        company.fieldService = value;
      case 'useContracts':
        company.useContracts = value;
      case 'useDeviceManagement':
        company.useDeviceManagement = value;
    }
  }

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
      _keepInCompany('useFinancial', value);
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
      _keepInCompany(feature.name, value);
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
    final locale = Localizations.localeOf(context);
    final segment = _segment;
    final checked = _company?.subspecialties ?? const <String>[];
    return MyCompanyScreen(
      onOpenCompanyData: _openData,
      onOpenTerms: _openTerms,
      onOpenSegment: _openSegment,
      onOpenSpecialties: segment != null && segment.hasSubspecialties
          ? _openSpecialties
          : null,
      companyName: _company?.name ?? widget.companyName,
      segmentName: segment?.nameFor(locale),
      specialties: segment == null
          ? null
          : [
              for (final sub in segment.subspecialties)
                if (checked.contains(sub.id)) sub.nameFor(locale),
            ],
      devicesLabel: provider.devicePlural,
      useFinancial: provider.useFinancial,
      onFinancialChanged: enabled ? _change : null,
      features: _features(provider),
      onFeatureChanged: enabled ? _changeFeature : null,
    );
  }
}
