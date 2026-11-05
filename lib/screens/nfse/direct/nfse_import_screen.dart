import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/models/nfse_import.dart';
import 'package:praticos/screens/menu_navigation/more/more_page.dart';
import 'package:praticos/screens/nfse/direct/nfse_direct_texts.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/screens/widgets/app_toast.dart';
import 'package:praticos/screens/widgets/list_states.dart';
import 'package:praticos/screens/widgets/picker_screen.dart';
import 'package:praticos/screens/widgets/primary_button.dart';
import 'package:praticos/screens/widgets/section_label.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/services/nfse_direct_api_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';

/// "Importar notas" (spec §4.3): right after the certificate, the server
/// reads the notas the CNPJ already issued and proposes what to fill. This
/// screen shows "Lendo suas notas no governo…" while it reads, then the
/// summary: the emitter, the customers (new and completed), the doubtful
/// ones ("Este é o mesmo cliente?"), stores billed on another CNPJ, the
/// customers that could get the automatic nota (nothing comes on) and how
/// many notas link to orders. One blue button: "Importar".
///
/// Pops with true when the import was applied.
class NfseImportScreen extends StatefulWidget {
  const NfseImportScreen({super.key, required this.emitterId, this.service});

  final String emitterId;

  /// Test seam; defaults to [NfseDirectApiService.instance].
  final NfseDirectApiService? service;

  static Future<bool?> open(
    BuildContext context,
    String emitterId, {
    NfseDirectApiService? service,
  }) => Navigator.of(context, rootNavigator: true).push<bool>(
    CupertinoPageRoute<bool>(
      settings: const RouteSettings(name: '/nfse_import'),
      builder: (_) => NfseImportScreen(emitterId: emitterId, service: service),
    ),
  );

  @override
  State<NfseImportScreen> createState() => _NfseImportScreenState();
}

class _NfseImportScreenState extends State<NfseImportScreen> {
  NfseImportBatch? _batch;
  Object? _error;
  bool _applying = false;

  /// "Este é o mesmo cliente?" answers by group key (absent = not answered).
  final Map<String, bool> _same = {};
  final Set<String> _autoIssue = {};

  NfseDirectApiService get _api =>
      widget.service ?? NfseDirectApiService.instance;

  @override
  void initState() {
    super.initState();
    _read();
  }

  /// Starts (or resumes) the reading and keeps asking until the proposal comes.
  Future<void> _read() async {
    setState(() => _error = null);
    try {
      var batch = await _api.startImport(widget.emitterId);
      if (mounted) setState(() => _batch = batch);
      while (mounted && batch.status == NfseImportStatus.reading) {
        batch = await _api.continueImport(batch.id);
        if (mounted) setState(() => _batch = batch);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _apply() async {
    final batch = _batch;
    if (batch == null || _applying) return;
    setState(() => _applying = true);
    try {
      await _api.applyImport(
        batch.id,
        sameCustomer: Map.of(_same),
        autoIssueCustomerIds: _autoIssue.toList(),
      );
      if (!mounted) return;
      showAppToast(
        context,
        context.l10n.nfseImportDone,
        icon: CupertinoIcons.checkmark_circle,
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _applying = false);
      showAppToast(
        context,
        nfseDirectErrorText(context.l10n, e),
        icon: CupertinoIcons.exclamationmark_circle,
      );
    }
  }

  Future<void> _ask(NfseImportGroup group) async {
    final l10n = context.l10n;
    final answer = await pickOne<bool>(
      context,
      title: l10n.nfseImportAskSection,
      subtitle: '${group.legalName} · ${group.customerName ?? ''}',
      selected: _same[group.key],
      options: [
        PickerItem(
          key: const Key('nfseImportAnswerSame'),
          value: true,
          title: l10n.nfseImportAskSame,
          subtitle: l10n.nfseImportAskSubtitle(group.customerName ?? ''),
        ),
        PickerItem(
          key: const Key('nfseImportAnswerNew'),
          value: false,
          title: l10n.nfseImportAskNew,
        ),
      ],
    );
    if (answer != null && mounted) setState(() => _same[group.key] = answer);
  }

  String? _subtitle(NfseImportBatch? batch) {
    final l10n = context.l10n;
    final proposal = batch?.proposal;
    if (_error != null) return null;
    if (batch == null || batch.status == NfseImportStatus.reading) {
      return l10n.nfseImportReading;
    }
    if (proposal == null) return null;
    if (proposal.notas == 0) return l10n.nfseImportHeadlineEmpty;
    return l10n.nfseImportHeadline(proposal.notas, proposal.customers);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final batch = _batch;
    final proposal = batch?.status == NfseImportStatus.proposed
        ? batch?.proposal
        : null;
    return MorePage(
      title: l10n.nfseImportTitle,
      subtitle: _subtitle(batch),
      floatingButton: proposal == null
          ? null
          : PrimaryButton(
              key: const Key('nfseImportApply'),
              label: l10n.nfseImportButton,
              floating: true,
              onPressed: _applying ? null : _apply,
            ),
      children: [
        if (_error != null)
          ErrorState(
            message: nfseDirectErrorText(l10n, _error!),
            onRetry: _read,
          )
        else if (proposal == null)
          LoadingState(
            key: const Key('nfseImportReading'),
            label: l10n.nfseImportReadingCount(batch?.documentsRead ?? 0),
          )
        else
          ..._summary(proposal),
      ],
    );
  }

  List<Widget> _summary(NfseImportProposal p) {
    final l10n = context.l10n;
    final format = FormatService();
    final emitter = p.emitter;
    final service = emitter.service;
    final secondary = AppColors.textSecondary.resolveFrom(context);
    final toAsk = p.toAsk;
    final withStores = p.withStores;
    // "Sim" completes an existing customer; anything else creates one.
    final yes = toAsk.where((g) => _same[g.key] == true).length;
    return [
      SectionLabel(l10n.nfseImportEmitterSection),
      MoreRows(
        rows: [
          AppListRow(
            key: const Key('nfseImportEmitter'),
            title: emitter.legalName ?? '',
            subtitle: emitter.regime == null
                ? null
                : fiscalRegimeLabel(l10n, emitter.regime),
          ),
          if (emitter.municipalRegistration != null)
            AppListRow(
              title: l10n.nfseDirectRegistrationRow,
              trailing: emitter.municipalRegistration,
            ),
          if (service?.name != null)
            AppListRow(
              key: const Key('nfseImportService'),
              title: l10n.nfseImportServiceRow,
              subtitle: (service!.issRate ?? 0) > 0
                  ? l10n.nfseImportServiceValue(
                      service.name!,
                      format.formatPercent(service.issRate!),
                    )
                  : service.name,
            ),
          if (emitter.dpsSeries != null)
            AppListRow(
              key: const Key('nfseImportSeries'),
              title: l10n.nfseImportSeriesRow,
              trailing: emitter.dpsSeries,
            ),
        ],
      ),
      if (p.customers > 0) ...[
        SectionLabel(l10n.nfseImportCustomersSection),
        MoreRows(
          rows: [
            AppListRow(
              key: const Key('nfseImportCustomersNew'),
              title: l10n.nfseImportCustomersNew(
                p.newCustomers + toAsk.length - yes,
              ),
            ),
            AppListRow(
              key: const Key('nfseImportCustomersCompleted'),
              title: l10n.nfseImportCustomersCompleted(
                p.completedCustomers + yes,
              ),
            ),
          ],
        ),
        MoreFootnote(l10n.nfseImportCustomersHint),
      ],
      if (toAsk.isNotEmpty) ...[
        SectionLabel(l10n.nfseImportAskSection),
        MoreRows(
          rows: [
            for (final group in toAsk)
              AppListRow(
                key: Key('nfseImportAsk-${group.key}'),
                title: group.legalName,
                subtitle: l10n.nfseImportAskSubtitle(group.customerName ?? ''),
                trailing: switch (_same[group.key]) {
                  true => l10n.nfseImportAskSame,
                  false => l10n.nfseImportAskNew,
                  null => l10n.nfseImportAskUnanswered,
                },
                showChevron: true,
                onTap: _applying ? null : () => _ask(group),
              ),
          ],
        ),
        MoreFootnote(l10n.nfseImportAskHint),
      ],
      if (withStores.isNotEmpty) ...[
        SectionLabel(l10n.nfseImportStoresSection),
        MoreRows(
          rows: [
            for (final group in withStores)
              for (final store in group.stores)
                AppListRow(
                  key: Key('nfseImportStore-${store.customerId}'),
                  title: store.customerName,
                  subtitle: l10n.nfseImportStoreRow(
                    group.customerName ?? group.legalName,
                  ),
                ),
          ],
        ),
      ],
      if (p.autoIssue.isNotEmpty) ...[
        SectionLabel(l10n.nfseImportAutoSection),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageMargin,
            0,
            AppSpacing.pageMargin,
            AppSpacing.sm,
          ),
          child: Text(
            l10n.nfseImportAutoQuestion(p.autoIssue.length),
            style: AppTypography.callout.copyWith(color: secondary),
          ),
        ),
        MoreRows(
          rows: [
            for (final s in p.autoIssue)
              MoreSwitchRow(
                key: Key('nfseImportAuto-${s.customerId}'),
                title: s.customerName,
                value: _autoIssue.contains(s.customerId),
                onChanged: _applying
                    ? null
                    : (on) => setState(
                        () => on
                            ? _autoIssue.add(s.customerId)
                            : _autoIssue.remove(s.customerId),
                      ),
              ),
          ],
        ),
      ],
      if (p.notas > 0) ...[
        SectionLabel(l10n.nfseImportNotasSection),
        MoreRows(
          rows: [
            AppListRow(
              key: const Key('nfseImportLinked'),
              title: l10n.nfseImportNotasLinked(p.linked),
            ),
            AppListRow(
              key: const Key('nfseImportHistory'),
              title: l10n.nfseImportNotasHistory(p.historyOnly),
            ),
          ],
        ),
      ],
      const SizedBox(height: AppSpacing.xl * 3),
    ];
  }
}
