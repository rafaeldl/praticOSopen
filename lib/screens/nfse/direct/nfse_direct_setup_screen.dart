import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/global.dart';
import 'package:praticos/models/fiscal_emitter.dart';
import 'package:praticos/repositories/tenant/fiscal_emitter_repository.dart';
import 'package:praticos/screens/menu_navigation/more/more_page.dart';
import 'package:praticos/screens/nfse/direct/certificate_upload_sheet.dart';
import 'package:praticos/screens/nfse/direct/fiscal_emitter_screen.dart';
import 'package:praticos/screens/nfse/direct/nfse_direct_texts.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/screens/widgets/app_toast.dart';
import 'package:praticos/screens/widgets/glass_bar_button.dart';
import 'package:praticos/screens/widgets/list_states.dart';
import 'package:praticos/screens/widgets/picker_screen.dart';
import 'package:praticos/screens/widgets/primary_button.dart';
import 'package:praticos/screens/widgets/section_label.dart';
import 'package:praticos/services/nfse_direct_api_service.dart';
import 'package:praticos/theme/app_colors.dart';

/// "Nota fiscal" of the NFS-e direct (spec §4.1), owner and admin, behind
/// `settings/payments.nfseDirectEnabled`: the company's CNPJs (✓ on the
/// default), "+" to add one with its certificate, and "Emitir sozinha
/// quando concluir a OS". Without any CNPJ the one blue button adds the
/// first.
class NfseDirectSetupScreen extends StatefulWidget {
  const NfseDirectSetupScreen({
    super.key,
    this.emitters,
    this.settings,
    this.service,
    this.pickFile,
    this.now,
    this.emitterOf,
  });

  /// Test seams; default to Firestore and the real API.
  final Stream<List<FiscalEmitter>>? emitters;
  final Stream<NfseDirectSettings>? settings;
  final NfseDirectApiService? service;
  final Future<PickedCertificate?> Function()? pickFile;
  final DateTime? now;

  /// Test seam: the stream the emitter screen watches.
  final Stream<FiscalEmitter?> Function(String id)? emitterOf;

  static Future<void> open(BuildContext context) =>
      Navigator.of(context, rootNavigator: true).push<void>(
        CupertinoPageRoute<void>(
          settings: const RouteSettings(name: '/nfse_direct_setup'),
          builder: (_) => const NfseDirectSetupScreen(),
        ),
      );

  @override
  State<NfseDirectSetupScreen> createState() => _NfseDirectSetupScreenState();
}

class _NfseDirectSetupScreenState extends State<NfseDirectSetupScreen> {
  StreamSubscription<List<FiscalEmitter>>? _emittersSub;
  StreamSubscription<NfseDirectSettings>? _settingsSub;
  List<FiscalEmitter>? _emitters;
  NfseDirectSettings _settings = const NfseDirectSettings();
  bool _failed = false;
  bool _saving = false;

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
    _emittersSub?.cancel();
    _settingsSub?.cancel();
    _failed = false;
    _emittersSub = (widget.emitters ?? repository().watchAll(companyId)).listen(
      (list) => setState(() {
        _emitters = list;
        _failed = false;
      }),
      onError: (Object _) => setState(() => _failed = true),
    );
    _settingsSub = (widget.settings ?? repository().watchSettings(companyId))
        .listen(
          (settings) => setState(() => _settings = settings),
          onError: (Object _) {},
        );
  }

  @override
  void dispose() {
    _emittersSub?.cancel();
    _settingsSub?.cancel();
    super.dispose();
  }

  /// The default emitter: the one in settings, else the only one.
  String? get _defaultId {
    final list = _emitters ?? const [];
    final id = _settings.defaultEmitterId;
    if (id != null && list.any((e) => e.id == id)) return id;
    return list.length == 1 ? list.first.id : null;
  }

  Future<void> _add() async {
    final saved = await CertificateUploadSheet.show(
      context,
      service: widget.service,
      pickFile: widget.pickFile,
    );
    if (saved == true && mounted) {
      showAppToast(
        context,
        context.l10n.nfseDirectCnpjAdded,
        icon: CupertinoIcons.checkmark_circle,
      );
    }
  }

  Future<void> _open(FiscalEmitter emitter) => Navigator.of(context).push<void>(
    CupertinoPageRoute<void>(
      builder: (_) => FiscalEmitterScreen(
        emitterId: emitter.id!,
        emitter: widget.emitterOf?.call(emitter.id!),
        settings: widget.settings,
        service: widget.service,
        pickFile: widget.pickFile,
        now: widget.now,
      ),
    ),
  );

  Future<void> _pickAutoIssue() async {
    final l10n = context.l10n;
    final current = _settings.autoIssue;
    final picked = await pickOne<NfseDirectAutoIssue>(
      context,
      title: l10n.nfseDirectAutoIssueQuestion,
      previousTitle: l10n.nfseRowTitle,
      selected: current,
      options: [
        for (final option in NfseDirectAutoIssue.values)
          PickerItem(
            key: Key('nfseDirectAutoIssue_${option.name}'),
            value: option,
            title: nfseDirectAutoIssueLabel(l10n, option),
            subtitle: nfseDirectAutoIssueHint(l10n, option),
          ),
      ],
    );
    if (picked == null || picked == current || !mounted) return;
    setState(() => _saving = true);
    try {
      await _api.setAutoIssue(picked);
    } catch (e) {
      if (mounted) {
        showAppToast(
          context,
          nfseDirectErrorText(context.l10n, e),
          icon: CupertinoIcons.exclamationmark_circle,
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _setManagerCanIssue(bool value) async {
    setState(() => _saving = true);
    try {
      await _api.setManagerCanIssue(value);
    } catch (e) {
      if (mounted) {
        final forbidden = e is NfseDirectApiException && e.code == 'FORBIDDEN';
        showAppToast(
          context,
          forbidden
              ? context.l10n.nfseDirectErrorOwnerOnly
              : nfseDirectErrorText(context.l10n, e),
          icon: CupertinoIcons.exclamationmark_circle,
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final emitters = _emitters;
    if (emitters == null) {
      return MorePage(
        title: l10n.nfseRowTitle,
        children: [
          SizedBox(
            height: 260,
            child: _failed
                ? ErrorState(
                    message: l10n.nfseDirectErrorGeneric,
                    onRetry: () => setState(_listen),
                  )
                : const LoadingState(),
          ),
        ],
      );
    }
    final empty = emitters.isEmpty;
    final defaultId = _defaultId;
    return MorePage(
      title: l10n.nfseRowTitle,
      subtitle: empty
          ? l10n.nfseDirectHeadEmpty
          : l10n.nfseDirectHeadWithEmitters,
      trailing: empty
          ? null
          : GlassBarButton(
              key: const Key('nfseDirectAdd'),
              label: l10n.nfseDirectAddCnpjTitle,
              icon: CupertinoIcons.add,
              onPressed: _add,
            ),
      floatingButton: empty
          ? PrimaryButton(
              key: const Key('nfseDirectAddFirst'),
              label: l10n.nfseDirectAddCnpjTitle,
              onPressed: _add,
            )
          : null,
      children: [
        if (!empty) ...[
          SectionLabel(l10n.nfseDirectEmittersSection),
          MoreRows(
            rows: [
              for (final emitter in emitters)
                AppListRow(
                  key: ValueKey('nfseDirectEmitter_${emitter.id}'),
                  title: emitter.legalName ?? '',
                  subtitleWidget: _EmitterSubtitle(
                    emitter: emitter,
                    now: widget.now,
                  ),
                  selected: emitter.id == defaultId,
                  onTap: () => _open(emitter),
                ),
            ],
          ),
          MoreRows(
            rows: [
              AppListRow(
                key: const Key('nfseDirectAutoIssueRow'),
                title: l10n.nfseDirectAutoIssueRow,
                subtitle: nfseDirectAutoIssueLabel(l10n, _settings.autoIssue),
                onTap: _saving ? null : _pickAutoIssue,
              ),
              MoreSwitchRow(
                key: const Key('nfseDirectManagerCanIssue'),
                title: l10n.nfseDirectManagerCanIssue,
                subtitle: l10n.nfseDirectManagerCanIssueHint,
                value: _settings.managerCanIssue,
                onChanged: _saving ? null : _setManagerCanIssue,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// "Simples" or "MEI", then the certificate (dot + text).
class _EmitterSubtitle extends StatelessWidget {
  const _EmitterSubtitle({required this.emitter, this.now});

  final FiscalEmitter emitter;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          fiscalRegimeLabel(l10n, emitter.regime),
          style: DefaultTextStyle.of(
            context,
          ).style.copyWith(color: AppColors.textSecondary.resolveFrom(context)),
        ),
        CertificateStatusLine(emitter: emitter, now: now),
      ],
    );
  }
}
