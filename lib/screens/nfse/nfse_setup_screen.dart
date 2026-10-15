import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/nfse.dart';
import 'package:praticos/screens/integrations/asaas_connection_screen.dart'
    show asaasNfsePanelUrl, asaasSandboxNfsePanelUrl;
import 'package:praticos/screens/menu_navigation/more/more_page.dart';
import 'package:praticos/screens/order/new_order_form.dart';
import 'package:praticos/screens/payments/asaas_error_text.dart';
import 'package:praticos/screens/widgets/app_form_field.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/screens/widgets/app_toast.dart';
import 'package:praticos/screens/widgets/form_sheet.dart';
import 'package:praticos/screens/widgets/list_states.dart';
import 'package:praticos/screens/widgets/picker_screen.dart';
import 'package:praticos/screens/widgets/primary_button.dart';
import 'package:praticos/screens/widgets/section_label.dart';
import 'package:praticos/screens/widgets/status_dot.dart';
import 'package:praticos/screens/widgets/text_link.dart';
import 'package:praticos/services/asaas_api_service.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';
import 'package:url_launcher/url_launcher.dart';

/// Text for a percent field ("2,50"); empty for zero.
String nfsePercentText(double value) =>
    value == 0 ? '' : FormatService().formatDecimal(value);

/// Parses a percent field ("2,5" or "2.5"); invalid or empty is 0.
double parseNfsePercent(String text) {
  final clean = text.trim().replaceAll('%', '').replaceAll(',', '.');
  final value = double.tryParse(clean) ?? 0;
  return value < 0 ? 0 : (value > 100 ? 100 : value);
}

final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// "Nota fiscal" under Integrations > Asaas (owner/admin, with the
/// `nfseEnabled` flag): what is ready and what is missing before the first
/// nota. Three steps: the company's fiscal info (kept in Asaas), the access
/// to the city (certificate/password/token, sent in the Asaas panel) and the
/// default service of the notas (kept in PraticOS). One blue button opens
/// the next missing step.
class NfseSetupScreen extends StatefulWidget {
  const NfseSetupScreen({
    super.key,
    this.sandbox = false,
    this.service,
    this.openUrl,
  });

  /// The Asaas connection is sandbox (opens the sandbox panel).
  final bool sandbox;

  /// Test seam; defaults to [AsaasApiService.instance].
  final AsaasApiService? service;

  /// Test seam; defaults to [launchUrl].
  final Future<void> Function(String url)? openUrl;

  @override
  State<NfseSetupScreen> createState() => _NfseSetupScreenState();
}

class _NfseSetupScreenState extends State<NfseSetupScreen> {
  NfseSetup? _setup;
  String? _error;
  bool _loading = true;

  AsaasApiService get _service => widget.service ?? AsaasApiService.instance;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final setup = await _service.nfseSetup();
      if (mounted) {
        setState(() {
          _setup = setup;
          _loading = false;
        });
      }
    } on AsaasApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = asaasErrorText(context.l10n, e, nota: true);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = context.l10n.asaasErrorGeneric;
          _loading = false;
        });
      }
    }
  }

  Future<void> _openFiscalInfo() async {
    final setup = _setup;
    if (setup == null) return;
    final saved = await FormSheet.show<NfseSetup>(
      context,
      (_) => NfseFiscalInfoSheet(
        current: setup.fiscalInfo,
        cityOptions: setup.cityOptions,
        service: widget.service,
      ),
    );
    if (saved == null || !mounted) return;
    setState(() => _setup = saved);
    showAppToast(
      context,
      context.l10n.nfseFiscalSaved,
      icon: CupertinoIcons.checkmark_circle,
    );
  }

  Future<void> _openService() async {
    final setup = _setup;
    if (setup == null) return;
    final saved = await FormSheet.show<NfseSetup>(
      context,
      (_) => NfseServiceSheet(current: setup.service, service: widget.service),
    );
    if (saved == null || !mounted) return;
    setState(() => _setup = saved);
    showAppToast(
      context,
      context.l10n.nfseServiceSaved,
      icon: CupertinoIcons.checkmark_circle,
    );
  }

  Future<void> _pickAutoIssue() async {
    final current = _setup?.service;
    if (current == null || _loading) return;
    final l10n = context.l10n;
    final picked = await pickOne<NfseAutoIssue>(
      context,
      title: l10n.nfseAutoIssueQuestion,
      previousTitle: l10n.nfseRowTitle,
      selected: current.autoIssue ?? NfseAutoIssue.manual,
      options: [
        for (final option in NfseAutoIssue.values)
          PickerItem(
            key: Key('nfseAutoIssue_${option.name}'),
            value: option,
            title: nfseAutoIssueLabel(l10n, option),
            subtitle: nfseAutoIssueHint(l10n, option),
          ),
      ],
    );
    if (picked == null || picked == current.autoIssue || !mounted) return;
    setState(() => _loading = true);
    String? failure;
    try {
      final saved = await _service.saveNfseService(
        current.copyWith(autoIssue: picked),
      );
      if (mounted) setState(() => _setup = saved);
    } on AsaasApiException catch (e) {
      if (mounted) failure = asaasErrorText(context.l10n, e, nota: true);
    } catch (_) {
      if (mounted) failure = context.l10n.asaasErrorGeneric;
    }
    if (!mounted) return;
    setState(() => _loading = false);
    if (failure != null) {
      showAppToast(
        context,
        failure,
        icon: CupertinoIcons.exclamationmark_circle,
      );
    }
  }

  Future<void> _openPanel() async {
    final url = widget.sandbox ? asaasSandboxNfsePanelUrl : asaasNfsePanelUrl;
    final custom = widget.openUrl;
    if (custom != null) return custom(url);
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Future<void> _next() async {
    final missing = _setup?.missing ?? const [];
    if (missing.contains(NfseMissing.fiscalInfo)) return _openFiscalInfo();
    if (missing.contains(NfseMissing.cityAccess)) return _openPanel();
    if (missing.contains(NfseMissing.service)) return _openService();
  }

  String _cityAccessText(AppLocalizations l10n, NfseSetup setup) {
    if (setup.fiscalInfo == null) return l10n.nfseCityAccessFirst;
    switch (setup.cityOptions?.authenticationType) {
      case 'CERTIFICATE':
        return l10n.nfseCityAccessCertificate;
      case 'TOKEN':
        return l10n.nfseCityAccessToken;
      case 'USER_AND_PASSWORD':
        return l10n.nfseCityAccessPassword;
      default:
        return l10n.nfseCityAccessNone;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final setup = _setup;
    if (setup == null) {
      return MorePage(
        title: l10n.nfseRowTitle,
        previousPageTitle: 'Asaas',
        children: [
          if (_loading)
            const SizedBox(height: 200, child: LoadingState())
          else
            SizedBox(
              height: 260,
              child: ErrorState(message: _error, onRetry: _load),
            ),
        ],
      );
    }
    final missing = setup.missing;
    final options = setup.cityOptions;
    final cityAccessDone =
        setup.fiscalInfo != null && !missing.contains(NfseMissing.cityAccess);
    final needsCityAccess =
        setup.fiscalInfo != null &&
        options?.authenticationType != null &&
        missing.contains(NfseMissing.cityAccess);

    return MorePage(
      title: l10n.nfseRowTitle,
      previousPageTitle: 'Asaas',
      subtitle: setup.ready
          ? l10n.nfseSetupHeadReady
          : l10n.nfseSetupHeadMissing(missing.length),
      floatingButton: setup.ready
          ? null
          : PrimaryButton(
              key: const Key('nfseSetupNext'),
              label: l10n.nfseSetupNext,
              onPressed: _loading ? null : _next,
            ),
      children: [
        MoreRows(
          rows: [
            AppListRow(
              key: const Key('nfseSetupFiscalInfo'),
              title: l10n.nfseSetupFiscalInfo,
              subtitleWidget: _StepStatus(
                done: !missing.contains(NfseMissing.fiscalInfo),
              ),
              onTap: _openFiscalInfo,
            ),
            AppListRow(
              key: const Key('nfseSetupCityAccess'),
              title: l10n.nfseSetupCityAccess,
              subtitleWidget: _StepStatus(done: cityAccessDone),
              onTap: needsCityAccess ? _openPanel : null,
            ),
            AppListRow(
              key: const Key('nfseSetupService'),
              title: l10n.nfseSetupService,
              subtitle: setup.service?.municipalServiceName,
              subtitleWidget: setup.service == null
                  ? const _StepStatus(done: false)
                  : null,
              onTap: _openService,
            ),
            if (setup.service != null)
              AppListRow(
                key: const Key('nfseSetupAutoIssue'),
                title: l10n.nfseAutoIssueRow,
                subtitle: nfseAutoIssueLabel(
                  l10n,
                  setup.service!.autoIssue ?? NfseAutoIssue.manual,
                ),
                onTap: _loading ? null : _pickAutoIssue,
              ),
          ],
        ),
        SectionLabel(l10n.nfseSetupCityAccess),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pageMargin,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _cityAccessText(l10n, setup),
                key: const Key('nfseCityAccessText'),
                style: AppTypography.body.copyWith(
                  color: AppColors.text.resolveFrom(context),
                ),
              ),
              if (options?.supportsCancellation == false) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.nfseNoCancelNote,
                  style: AppTypography.callout.copyWith(
                    color: AppColors.textSecondary.resolveFrom(context),
                  ),
                ),
              ],
              if (needsCityAccess) ...[
                const SizedBox(height: AppSpacing.sm),
                TextLink(
                  key: const Key('nfseOpenAsaasPanel'),
                  label: l10n.nfseOpenAsaasPanel,
                  onPressed: _openPanel,
                ),
                TextLink(
                  key: const Key('nfseCheckAgain'),
                  label: l10n.nfseCheckAgain,
                  onPressed: _loading ? null : _load,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// "Só quando eu pedir", "Quando a OS for paga", "Quando a OS for concluída".
String nfseAutoIssueLabel(AppLocalizations l10n, NfseAutoIssue option) {
  switch (option) {
    case NfseAutoIssue.manual:
      return l10n.nfseAutoIssueManual;
    case NfseAutoIssue.paid:
      return l10n.nfseAutoIssuePaid;
    case NfseAutoIssue.completed:
      return l10n.nfseAutoIssueCompleted;
  }
}

String nfseAutoIssueHint(AppLocalizations l10n, NfseAutoIssue option) {
  switch (option) {
    case NfseAutoIssue.manual:
      return l10n.nfseAutoIssueManualHint;
    case NfseAutoIssue.paid:
      return l10n.nfseAutoIssuePaidHint;
    case NfseAutoIssue.completed:
      return l10n.nfseAutoIssueCompletedHint;
  }
}

/// "Pronto" (green dot) or "Falta" (amber dot).
class _StepStatus extends StatelessWidget {
  const _StepStatus({required this.done});

  final bool done;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
        StatusDot(color: done ? AppColors.success : AppColors.warning),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            done ? l10n.nfseSetupDone : l10n.nfseSetupTodo,
            style: AppTypography.callout.copyWith(
              color: AppColors.textSecondary.resolveFrom(context),
            ),
          ),
        ),
      ],
    );
  }
}

/// "Dados fiscais": e-mail, municipal registration, Simples Nacional and,
/// when the city uses them, the special regime and the service list item.
/// Saved in Asaas through the server; pops with the new [NfseSetup].
class NfseFiscalInfoSheet extends StatefulWidget {
  const NfseFiscalInfoSheet({
    super.key,
    this.current,
    this.cityOptions,
    this.service,
  });

  final NfseFiscalInfo? current;
  final NfseCityOptions? cityOptions;
  final AsaasApiService? service;

  @override
  State<NfseFiscalInfoSheet> createState() => _NfseFiscalInfoSheetState();
}

class _NfseFiscalInfoSheetState extends State<NfseFiscalInfoSheet> {
  late final _email = TextEditingController(text: widget.current?.email);
  late final _inscription = TextEditingController(
    text: widget.current?.municipalInscription,
  );
  late final _cnae = TextEditingController(text: widget.current?.cnae);
  late final _listItem = TextEditingController(
    text: widget.current?.serviceListItem,
  );
  late bool _simples = widget.current?.simplesNacional ?? true;
  late String? _regime = widget.current?.specialTaxRegime;
  bool _dirty = false;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _inscription.dispose();
    _cnae.dispose();
    _listItem.dispose();
    super.dispose();
  }

  void _changed(String _) => setState(() => _dirty = true);

  bool get _valid => _email.text.trim().isNotEmpty && _email.hasMatch;

  Future<void> _pickRegime() async {
    final regimes = widget.cityOptions?.specialTaxRegimes ?? const [];
    final l10n = context.l10n;
    final picked = await pickOne<String>(
      context,
      title: l10n.nfseFiscalSpecialRegimeQuestion,
      selected: _regime ?? '',
      options: [
        PickerItem(value: '', title: l10n.none),
        for (final r in regimes) PickerItem(value: r.value, title: r.label),
      ],
    );
    if (picked == null || !mounted) return;
    setState(() {
      _regime = picked.isEmpty ? null : picked;
      _dirty = true;
    });
  }

  Future<void> _save() async {
    if (_busy || !_valid) return;
    setState(() => _busy = true);
    final service = widget.service ?? AsaasApiService.instance;
    String failure;
    try {
      final setup = await service.saveNfseFiscalInfo(
        email: _email.text,
        simplesNacional: _simples,
        municipalInscription: _inscription.text,
        cnae: _cnae.text,
        specialTaxRegime: _regime,
        serviceListItem: _listItem.text,
      );
      if (!mounted) return;
      Navigator.pop(context, setup);
      return;
    } on AsaasApiException catch (e) {
      failure = asaasErrorText(context.l10n, e, nota: true);
    } catch (_) {
      failure = context.l10n.asaasErrorGeneric;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    showAppToast(context, failure, icon: CupertinoIcons.exclamationmark_circle);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final options = widget.cityOptions;
    final regimes = options?.specialTaxRegimes ?? const [];
    String? regimeLabel;
    for (final r in regimes) {
      if (r.value == _regime) regimeLabel = r.label;
    }
    return FormSheet(
      key: const Key('nfseFiscalInfoSheet'),
      title: l10n.nfseSetupFiscalInfo,
      canSave: _valid,
      missingHint: _valid ? null : l10n.nfseFiscalEmailMissing,
      dirty: _dirty,
      busy: _busy,
      onSave: _save,
      children: [
        FormFieldsCard(
          children: [
            AppFormField(
              key: const Key('nfseFiscalEmail'),
              label: l10n.nfseFiscalEmail,
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              onChanged: _changed,
            ),
            AppFormField(
              key: const Key('nfseFiscalInscription'),
              label: l10n.nfseFiscalMunicipalInscription,
              controller: _inscription,
              keyboardType: TextInputType.number,
              onChanged: _changed,
            ),
            AppFormField(
              key: const Key('nfseFiscalCnae'),
              label: l10n.nfseFiscalCnae,
              controller: _cnae,
              keyboardType: TextInputType.number,
              onChanged: _changed,
            ),
            if (options?.usesServiceListItem == true)
              AppFormField(
                key: const Key('nfseFiscalListItem'),
                label: l10n.nfseFiscalServiceListItem,
                controller: _listItem,
                onChanged: _changed,
              ),
          ],
        ),
        FormCard(
          note: l10n.nfseFiscalNote,
          children: [
            MoreSwitchRow(
              key: const Key('nfseFiscalSimples'),
              title: l10n.nfseFiscalSimples,
              value: _simples,
              onChanged: (value) => setState(() {
                _simples = value;
                _dirty = true;
              }),
            ),
            if (options?.usesSpecialTaxRegimes == true && regimes.isNotEmpty)
              FormRow(
                key: const Key('nfseFiscalRegime'),
                title: l10n.nfseFiscalSpecialRegime,
                value: regimeLabel ?? l10n.none,
                onTap: _pickRegime,
              ),
          ],
        ),
      ],
    );
  }
}

extension on TextEditingController {
  bool get hasMatch => _email.hasMatch(text.trim());
}

/// "Serviço da nota": the city's service (searched in its list, or typed
/// code and name), ISS and the other taxes, and the text template. Kept in
/// `settings/nfse` by the server; pops with the new [NfseSetup].
class NfseServiceSheet extends StatefulWidget {
  const NfseServiceSheet({super.key, this.current, this.service});

  final NfseServiceSettings? current;
  final AsaasApiService? service;

  @override
  State<NfseServiceSheet> createState() => _NfseServiceSheetState();
}

class _NfseServiceSheetState extends State<NfseServiceSheet> {
  late String? _serviceId = widget.current?.municipalServiceId;
  late String _serviceName = widget.current?.municipalServiceName ?? '';
  late final _code = TextEditingController(
    text: widget.current?.municipalServiceCode,
  );
  late final _name = TextEditingController(
    text: widget.current?.municipalServiceCode == null
        ? ''
        : widget.current?.municipalServiceName,
  );
  late bool _typing = widget.current?.municipalServiceCode != null;
  late final NfseTaxes _taxes = widget.current?.taxes ?? const NfseTaxes();
  late bool _retainIss = _taxes.retainIss;
  late final Map<String, TextEditingController> _tax;
  late final _template = TextEditingController(
    text:
        widget.current?.descriptionTemplate ??
        NfseServiceSettings.defaultTemplate,
  );
  bool _dirty = false;
  bool _busy = false;

  AsaasApiService get _service => widget.service ?? AsaasApiService.instance;

  @override
  void initState() {
    super.initState();
    _tax = {
      'iss': TextEditingController(text: nfsePercentText(_taxes.iss)),
      'pis': TextEditingController(text: nfsePercentText(_taxes.pis)),
      'cofins': TextEditingController(text: nfsePercentText(_taxes.cofins)),
      'csll': TextEditingController(text: nfsePercentText(_taxes.csll)),
      'inss': TextEditingController(text: nfsePercentText(_taxes.inss)),
      'ir': TextEditingController(text: nfsePercentText(_taxes.ir)),
    };
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _template.dispose();
    for (final c in _tax.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _valid => _typing
      ? _code.text.trim().isNotEmpty && _name.text.trim().isNotEmpty
      : _serviceId != null;

  Future<void> _pickService() async {
    final picked = await Navigator.of(context).push<NfseMunicipalService>(
      CupertinoPageRoute(
        builder: (_) => NfseMunicipalServicePicker(service: widget.service),
      ),
    );
    if (picked == null || !mounted) return;
    final issTax = picked.issTax;
    setState(() {
      _typing = false;
      _serviceId = picked.id;
      _serviceName = picked.description;
      _dirty = true;
      if (issTax != null && _tax['iss']!.text.trim().isEmpty) {
        _tax['iss']!.text = nfsePercentText(issTax);
      }
    });
  }

  Future<void> _save() async {
    if (_busy || !_valid) return;
    setState(() => _busy = true);
    double tax(String key) => parseNfsePercent(_tax[key]!.text);
    final settings = NfseServiceSettings(
      municipalServiceId: _typing ? null : _serviceId,
      municipalServiceCode: _typing ? _code.text.trim() : null,
      municipalServiceName: _typing ? _name.text.trim() : _serviceName,
      taxes: NfseTaxes(
        retainIss: _retainIss,
        iss: tax('iss'),
        pis: tax('pis'),
        cofins: tax('cofins'),
        csll: tax('csll'),
        inss: tax('inss'),
        ir: tax('ir'),
      ),
      descriptionTemplate: _template.text.trim().isEmpty
          ? NfseServiceSettings.defaultTemplate
          : _template.text.trim(),
    );
    String failure;
    try {
      final setup = await _service.saveNfseService(settings);
      if (!mounted) return;
      Navigator.pop(context, setup);
      return;
    } on AsaasApiException catch (e) {
      failure = asaasErrorText(context.l10n, e, nota: true);
    } catch (_) {
      failure = context.l10n.asaasErrorGeneric;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    showAppToast(context, failure, icon: CupertinoIcons.exclamationmark_circle);
  }

  Widget _percent(String key, String label) => AppFormField(
    key: Key('nfseTax_$key'),
    label: label,
    controller: _tax[key],
    placeholder: '0',
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    onChanged: (_) => setState(() => _dirty = true),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FormSheet(
      key: const Key('nfseServiceSheet'),
      title: l10n.nfseSetupService,
      canSave: _valid,
      missingHint: _valid ? null : l10n.nfseServiceMissing,
      dirty: _dirty,
      busy: _busy,
      onSave: _save,
      children: [
        if (_typing)
          FormFieldsCard(
            children: [
              AppFormField(
                key: const Key('nfseServiceCode'),
                label: l10n.nfseServiceCode,
                controller: _code,
                onChanged: (_) => setState(() => _dirty = true),
              ),
              AppFormField(
                key: const Key('nfseServiceName'),
                label: l10n.nfseServiceName,
                controller: _name,
                onChanged: (_) => setState(() => _dirty = true),
              ),
            ],
          )
        else
          FormCard(
            children: [
              FormRow(
                key: const Key('nfseServicePick'),
                title: l10n.nfseServiceRow,
                subtitle: _serviceName.isEmpty ? null : _serviceName,
                value: _serviceName.isEmpty ? l10n.none : null,
                onTap: _pickService,
              ),
            ],
          ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pageMargin,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextLink(
              key: const Key('nfseServiceToggleTyping'),
              label: _typing
                  ? l10n.nfseServicePickTitle
                  : l10n.nfseServiceTypeCode,
              onPressed: () => setState(() => _typing = !_typing),
            ),
          ),
        ),
        FormFieldsCard(children: [_percent('iss', l10n.nfseIss)]),
        FormCard(
          children: [
            MoreSwitchRow(
              key: const Key('nfseRetainIss'),
              title: l10n.nfseRetainIss,
              value: _retainIss,
              onChanged: (value) => setState(() {
                _retainIss = value;
                _dirty = true;
              }),
            ),
          ],
        ),
        FormMoreCard(
          title: l10n.nfseOtherTaxes,
          hint: l10n.nfseTaxesNote,
          children: [
            // Tax names are proper names (same in every language).
            _percent('pis', 'PIS'),
            _percent('cofins', 'COFINS'),
            _percent('csll', 'CSLL'),
            _percent('inss', 'INSS'),
            _percent('ir', 'IR'),
          ],
        ),
        FormFieldsCard(
          children: [
            AppFormField(
              key: const Key('nfseTemplate'),
              label: l10n.nfseTemplateLabel,
              controller: _template,
              maxLines: 3,
              hint: l10n.nfseTemplateHint('{os}', '{servicos}'),
              onChanged: (_) => setState(() => _dirty = true),
            ),
          ],
        ),
      ],
    );
  }
}

/// "Qual serviço você presta?": searches the city's service list (Asaas)
/// as the user types; pops with the chosen [NfseMunicipalService].
class NfseMunicipalServicePicker extends StatefulWidget {
  const NfseMunicipalServicePicker({super.key, this.service});

  final AsaasApiService? service;

  @override
  State<NfseMunicipalServicePicker> createState() =>
      _NfseMunicipalServicePickerState();
}

class _NfseMunicipalServicePickerState
    extends State<NfseMunicipalServicePicker> {
  List<NfseMunicipalService>? _results;
  String? _error;
  Timer? _debounce;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onQuery(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(query));
  }

  Future<void> _search(String query) async {
    final request = ++_request;
    try {
      final results = await (widget.service ?? AsaasApiService.instance)
          .nfseMunicipalServices(query);
      if (!mounted || request != _request) return;
      setState(() {
        _results = results;
        _error = null;
      });
    } on AsaasApiException catch (e) {
      if (!mounted || request != _request) return;
      setState(() => _error = asaasErrorText(context.l10n, e, nota: true));
    } catch (_) {
      if (!mounted || request != _request) return;
      setState(() => _error = context.l10n.asaasErrorGeneric);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final results = _results;
    final secondary = AppColors.textSecondary.resolveFrom(context);
    return MorePage(
      title: l10n.nfseServicePickTitle,
      fitTitle: true,
      previousPageTitle: l10n.nfseSetupService,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageMargin,
            0,
            AppSpacing.pageMargin,
            AppSpacing.md,
          ),
          child: CupertinoSearchTextField(
            key: const Key('nfseServiceSearch'),
            placeholder: l10n.nfseServiceSearch,
            onChanged: _onQuery,
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pageMargin,
            ),
            child: Text(
              _error!,
              style: AppTypography.body.copyWith(color: secondary),
            ),
          )
        else if (results == null)
          const SizedBox(height: 160, child: LoadingState())
        else if (results.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pageMargin,
            ),
            child: Text(
              l10n.nfseServiceSearchEmpty,
              style: AppTypography.body.copyWith(color: secondary),
            ),
          )
        else
          MoreRows(
            rows: [
              for (final s in results)
                AppListRow(
                  key: ValueKey('nfseService_${s.id}'),
                  title: s.description,
                  onTap: () => Navigator.of(context).pop(s),
                ),
            ],
          ),
      ],
    );
  }
}
