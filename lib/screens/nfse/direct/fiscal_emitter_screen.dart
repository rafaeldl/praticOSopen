import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/global.dart';
import 'package:praticos/models/fiscal_emitter.dart';
import 'package:praticos/repositories/tenant/fiscal_emitter_repository.dart';
import 'package:praticos/screens/menu_navigation/more/more_page.dart';
import 'package:praticos/screens/nfse/direct/certificate_upload_sheet.dart';
import 'package:praticos/screens/nfse/direct/fiscal_emitter_editors.dart';
import 'package:praticos/screens/nfse/direct/nfse_direct_texts.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/screens/widgets/app_toast.dart';
import 'package:praticos/screens/widgets/form_sheet.dart';
import 'package:praticos/screens/widgets/glass_bar_button.dart';
import 'package:praticos/screens/widgets/list_states.dart';
import 'package:praticos/screens/widgets/pull_down_menu.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/services/nfse_direct_api_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';
import 'package:praticos/utils/tax_id.dart';

/// One CNPJ that issues notas (spec §4.7), pushed from "Seus CNPJs": who it
/// is, what it issued this year and month (and, for the MEI, how far from
/// the limit), and one line per thing to set up, each opening its editor.
/// "…": use as default, replace and delete the certificate.
class FiscalEmitterScreen extends StatefulWidget {
  const FiscalEmitterScreen({
    super.key,
    required this.emitterId,
    this.emitter,
    this.settings,
    this.service,
    this.pickFile,
    this.now,
  });

  final String emitterId;

  /// Test seams; default to Firestore and the real API.
  final Stream<FiscalEmitter?>? emitter;
  final Stream<NfseDirectSettings>? settings;
  final NfseDirectApiService? service;
  final Future<PickedCertificate?> Function()? pickFile;
  final DateTime? now;

  @override
  State<FiscalEmitterScreen> createState() => _FiscalEmitterScreenState();
}

class _FiscalEmitterScreenState extends State<FiscalEmitterScreen> {
  StreamSubscription<FiscalEmitter?>? _emitterSub;
  StreamSubscription<NfseDirectSettings>? _settingsSub;
  FiscalEmitter? _emitter;
  NfseDirectSettings _settings = const NfseDirectSettings();
  bool _loaded = false;
  bool _failed = false;

  NfseDirectApiService get _api =>
      widget.service ?? NfseDirectApiService.instance;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  void _listen() {
    final companyId = Global.companyAggr?.id ?? '';
    FiscalEmitterRepository? created;
    FiscalEmitterRepository repository() =>
        created ??= FiscalEmitterRepository();
    _emitterSub?.cancel();
    _settingsSub?.cancel();
    _emitterSub =
        (widget.emitter ??
                repository().streamSingle(companyId, widget.emitterId))
            .listen(
              (emitter) => setState(() {
                _emitter = emitter;
                _loaded = true;
                _failed = false;
              }),
              onError: (Object _) => setState(() {
                _loaded = true;
                _failed = true;
              }),
            );
    _settingsSub = (widget.settings ?? repository().watchSettings(companyId))
        .listen(
          (settings) => setState(() => _settings = settings),
          onError: (Object _) {},
        );
  }

  @override
  void dispose() {
    _emitterSub?.cancel();
    _settingsSub?.cancel();
    super.dispose();
  }

  bool get _isDefault => _settings.defaultEmitterId == widget.emitterId;

  void _toast(String text, {bool error = false}) => showAppToast(
    context,
    text,
    icon: error
        ? CupertinoIcons.exclamationmark_circle
        : CupertinoIcons.checkmark_circle,
  );

  Future<void> _openSheet(Widget sheet, String savedText) async {
    final saved = await FormSheet.show<bool>(context, (_) => sheet);
    if (saved == true && mounted) _toast(savedText);
  }

  Future<void> _replaceCertificate(FiscalEmitter emitter) async {
    final saved = await CertificateUploadSheet.show(
      context,
      emitterId: emitter.id,
      legalName: emitter.legalName,
      service: widget.service,
      pickFile: widget.pickFile,
    );
    if (saved == true && mounted) {
      _toast(context.l10n.nfseDirectCertificateReplaced);
    }
  }

  Future<void> _useAsDefault() async {
    try {
      await _api.setDefaultEmitter(widget.emitterId);
      if (mounted) _toast(context.l10n.nfseDirectDefaultSaved);
    } catch (e) {
      if (mounted) _toast(nfseDirectErrorText(context.l10n, e), error: true);
    }
  }

  Future<void> _confirmDelete(FiscalEmitter emitter) async {
    final l10n = context.l10n;
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(l10n.nfseDirectDeleteTitle),
        content: Text(l10n.nfseDirectDeleteMessage(emitter.legalName ?? '')),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          CupertinoDialogAction(
            key: const Key('emitterDeleteConfirm'),
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.nfseDirectDeleteAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _api.deleteCertificate(widget.emitterId);
      if (mounted) _toast(l10n.nfseDirectCertificateDeleted);
    } catch (e) {
      if (mounted) _toast(nfseDirectErrorText(l10n, e), error: true);
    }
  }

  Future<void> _showMenu(FiscalEmitter emitter) async {
    final l10n = context.l10n;
    final hasCertificate =
        certificateState(emitter, now: widget.now) != CertificateState.missing;
    final picked = await showPullDownMenu(
      context,
      groups: [
        PullDownGroup([
          if (!_isDefault)
            PullDownItem(
              value: 'default',
              label: l10n.nfseDirectUseAsDefault,
              icon: CupertinoIcons.checkmark_circle,
            ),
          PullDownItem(
            value: 'replace',
            label: hasCertificate
                ? l10n.nfseDirectReplaceTitle
                : l10n.nfseDirectSendCertificate,
            icon: CupertinoIcons.arrow_2_circlepath,
          ),
        ]),
        if (hasCertificate)
          PullDownGroup([
            PullDownItem(
              value: 'delete',
              label: l10n.nfseDirectDeleteAction,
              icon: CupertinoIcons.trash,
              destructive: true,
            ),
          ]),
      ],
    );
    if (!mounted) return;
    switch (picked) {
      case 'default':
        await _useAsDefault();
      case 'replace':
        await _replaceCertificate(emitter);
      case 'delete':
        await _confirmDelete(emitter);
    }
  }

  String _certificateRowText(FiscalEmitter emitter) {
    final l10n = context.l10n;
    final cert = emitter.certificate;
    final state = certificateState(emitter, now: widget.now);
    if (cert == null || state == CertificateState.missing) {
      return l10n.nfseDirectCertMissing;
    }
    final format = FormatService();
    final end = cert.notAfter == null
        ? ''
        : format.formatDate(cert.notAfter!.toLocal());
    final by = cert.uploadedBy?.name;
    final at = cert.uploadedAt;
    final expires = state == CertificateState.expired
        ? l10n.nfseDirectCertExpiredOn(end)
        : l10n.nfseDirectCertExpiresOn(end);
    if (by == null || at == null) return expires;
    return l10n.nfseDirectCertSentBy(
      expires,
      by,
      format.formatDate(at.toLocal()),
    );
  }

  Widget _totals(FiscalEmitter emitter) {
    final l10n = context.l10n;
    final format = FormatService();
    final totals = emitter.totals;
    final now = widget.now ?? DateTime.now();
    final year = totals?.year == now.year ? totals!.yearValue : 0.0;
    final month = totals?.year == now.year && totals?.month == now.month
        ? totals!.monthValue
        : 0.0;
    final secondary = AppColors.textSecondary.resolveFrom(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageMargin,
        0,
        AppSpacing.pageMargin,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.nfseDirectTotals(
              format.formatCurrency(year),
              format.formatCurrency(month),
            ),
            key: const Key('emitterTotals'),
            style: AppTypography.body.copyWith(
              color: AppColors.text.resolveFrom(context),
            ),
          ),
          if (emitter.isMei) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.nfseDirectMeiLimit(
                format.formatCurrency(year),
                format.formatCurrency(meiAnnualLimit),
              ),
              key: const Key('emitterMeiLimit'),
              style: AppTypography.callout.copyWith(
                color: year >= meiAnnualLimit * 0.8
                    ? AppColors.warning.resolveFrom(context)
                    : secondary,
                fontWeight: year >= meiAnnualLimit * 0.8
                    ? FontWeight.w600
                    : null,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          CertificateStatusLine(emitter: emitter, now: widget.now),
          if (!emitter.enabledInCity) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.nfseDirectNotEnabledInCity(emitter.cityName ?? ''),
              key: const Key('emitterNotEnabled'),
              style: AppTypography.callout.copyWith(color: secondary),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final emitter = _emitter;
    if (emitter == null) {
      return MorePage(
        title: l10n.nfseDirectEmitterTitle,
        children: [
          SizedBox(
            height: 260,
            child: !_loaded
                ? const LoadingState()
                : ErrorState(
                    message: _failed
                        ? l10n.nfseDirectErrorGeneric
                        : l10n.nfseDirectErrorNotFound,
                    onRetry: () => setState(() {
                      _loaded = false;
                      _listen();
                    }),
                  ),
          ),
        ],
      );
    }
    final service = emitter.service;
    final style = emitter.descriptionStyle;
    final api = widget.service;
    final subtitle = [
      if (emitter.taxId != null) formatTaxId(emitter.taxId!),
      fiscalRegimeLabel(l10n, emitter.regime),
      if (_isDefault) l10n.nfseDirectDefault,
    ].join(' · ');
    return MorePage(
      title: emitter.legalName ?? l10n.nfseDirectEmitterTitle,
      fitTitle: true,
      subtitle: subtitle,
      trailing: GlassBarButton(
        key: const Key('emitterMenu'),
        label: l10n.nfseListMenu,
        icon: CupertinoIcons.ellipsis,
        onPressed: () => _showMenu(emitter),
      ),
      children: [
        _totals(emitter),
        MoreRows(
          rows: [
            AppListRow(
              key: const Key('emitterServiceRow'),
              title: l10n.nfseDirectServiceRow,
              subtitle: service?.name ?? l10n.nfseDirectMissing,
              onTap: () => _openSheet(
                EmitterServiceSheet(emitter: emitter, service: api),
                l10n.nfseDirectSaved,
              ),
            ),
            AppListRow(
              key: const Key('emitterRegistrationRow'),
              title: l10n.nfseDirectRegistrationRow,
              subtitle: emitter.municipalRegistration ?? l10n.nfseDirectNone,
              onTap: () => _openSheet(
                EmitterRegistrationSheet(emitter: emitter, service: api),
                l10n.nfseDirectSaved,
              ),
            ),
            AppListRow(
              key: const Key('emitterStyleRow'),
              title: l10n.nfseDirectStyleRow,
              subtitle: descriptionStylePreview(
                style ?? FiscalDescriptionStyle(),
                [l10n.nfseDirectSampleService1, l10n.nfseDirectSampleService2],
              ),
              onTap: () => Navigator.of(context).push<void>(
                CupertinoPageRoute<void>(
                  builder: (_) => EmitterDescriptionStyleScreen(
                    emitter: emitter,
                    service: api,
                  ),
                ),
              ),
            ),
            AppListRow(
              key: const Key('emitterCertificateRow'),
              title: l10n.nfseDirectCertificateRow,
              subtitle: _certificateRowText(emitter),
              onTap: () => _replaceCertificate(emitter),
            ),
          ],
        ),
      ],
    );
  }
}
