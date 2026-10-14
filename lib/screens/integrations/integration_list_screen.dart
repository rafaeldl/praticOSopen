import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SelectableText;
import 'package:flutter/services.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/integration_token.dart';
import 'package:praticos/models/payment_settings.dart';
import 'package:praticos/screens/integrations/asaas_connection_screen.dart';
import 'package:praticos/screens/menu_navigation/more/more_page.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/screens/widgets/app_toast.dart';
import 'package:praticos/screens/widgets/glass_bar_button.dart';
import 'package:praticos/screens/widgets/list_states.dart';
import 'package:praticos/screens/widgets/pull_down_menu.dart';
import 'package:praticos/screens/widgets/section_label.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/services/integration_api_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';

/// Maps an [IntegrationApiException] to a localized, user-visible message.
///
/// The exception's `message` is the backend's raw diagnostic text in
/// English and must never reach the UI. Only `code` is used here; an
/// unmapped or null code falls back to the generic error string.
String integrationErrorText(AppLocalizations l10n, IntegrationApiException e) {
  switch (e.code) {
    case 'FORBIDDEN':
      return l10n.integrationsErrorForbidden;
    case 'NOT_FOUND':
      return l10n.integrationsErrorNotFound;
    default:
      return l10n.integrationsErrorGeneric;
  }
}

/// Asks for the connection name. Pops with the trimmed name, or null on cancel.
///
/// Owns its [TextEditingController] so it is disposed with the dialog, after
/// the exit transition — disposing it as soon as the dialog future completes
/// would still leave the text field rebuilding during that transition.
class IntegrationNameDialog extends StatefulWidget {
  const IntegrationNameDialog({super.key});

  @override
  State<IntegrationNameDialog> createState() => _IntegrationNameDialogState();
}

class _IntegrationNameDialogState extends State<IntegrationNameDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: Text(context.l10n.integrationsNew),
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: CupertinoTextField(
          controller: _controller,
          placeholder: context.l10n.integrationsNameHint,
          autofocus: true,
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: Text(context.l10n.save),
        ),
      ],
    );
  }
}

/// "Integrações": the Asaas account (when the company is in the pilot) and
/// the ChatGPT/Claude connections, each row with a one-line status. "+" on
/// top creates a connection; tapping one offers turning it off.
class IntegrationListScreen extends StatefulWidget {
  const IntegrationListScreen({super.key, this.service, this.paymentSettings});

  /// Test seam; defaults to [IntegrationApiService.instance].
  final IntegrationApiService? service;

  /// Test seam; defaults to [paymentSettingsStream].
  final Stream<PaymentSettings>? paymentSettings;

  @override
  State<IntegrationListScreen> createState() => _IntegrationListScreenState();
}

class _IntegrationListScreenState extends State<IntegrationListScreen> {
  final _formatService = FormatService();
  List<IntegrationToken> _tokens = [];
  bool _loading = true;
  String? _error;

  /// Null hides the Payments section (not owner/admin or no company).
  late final Stream<PaymentSettings>? _paymentSettings =
      widget.paymentSettings ?? paymentSettingsStream();

  IntegrationApiService get _service =>
      widget.service ?? IntegrationApiService.instance;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tokens = await _service.list();
      if (!mounted) return;
      setState(() {
        _tokens = tokens;
        _loading = false;
      });
    } on IntegrationApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = integrationErrorText(context.l10n, e);
        _loading = false;
      });
    }
  }

  Future<void> _create() async {
    final name = await showCupertinoDialog<String>(
      context: context,
      builder: (_) => const IntegrationNameDialog(),
    );

    if (name == null || name.isEmpty) return;

    try {
      final created = await _service.create(name: name);
      if (!mounted) return;
      await _showUrlOnce(created);
      if (!mounted) return;
      await _load();
    } on IntegrationApiException catch (e) {
      if (!mounted) return;
      _showError(integrationErrorText(context.l10n, e));
    }
  }

  Future<void> _showUrlOnce(CreatedIntegrationToken created) async {
    // The URL embeds the secret token: shown once here, never printed,
    // logged, or included in any error message.
    final url = created.url ?? '';

    await showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(dialogContext.l10n.integrationsNew),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Text(dialogContext.l10n.integrationsUrlOnce),
            const SizedBox(height: 12),
            SelectableText(
              url,
              style: AppTypography.label.copyWith(
                color: AppColors.text.resolveFrom(dialogContext),
              ),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: url));
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: Text(dialogContext.l10n.integrationsCopy),
          ),
        ],
      ),
    );
  }

  Future<void> _openToken(IntegrationToken token) async {
    final picked = await showPullDownMenu(
      context,
      groups: [
        PullDownGroup([
          PullDownItem(
            value: 'revoke',
            label: context.l10n.integrationsRevoke,
            icon: CupertinoIcons.power,
            destructive: true,
          ),
        ]),
      ],
    );
    if (picked == 'revoke' && mounted) await _revoke(token);
  }

  Future<void> _revoke(IntegrationToken token) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(token.name ?? ''),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(dialogContext.l10n.integrationsRevokeConfirm),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.l10n.cancel),
          ),
          CupertinoDialogAction(
            key: const Key('confirmRevokeAction'),
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.l10n.integrationsRevoke),
          ),
        ],
      ),
    );

    if (confirmed != true || token.id == null) return;

    try {
      await _service.revoke(token.id!);
      if (!mounted) return;
      showAppToast(context, context.l10n.integrationsRevoked);
      await _load();
    } on IntegrationApiException catch (e) {
      if (!mounted) return;
      _showError(integrationErrorText(context.l10n, e));
    }
  }

  void _showError(String message) {
    showAppToast(
      context,
      message,
      icon: CupertinoIcons.exclamationmark_circle_fill,
    );
  }

  String _subtitle(BuildContext context, IntegrationToken token) {
    if (token.lastUsedAt == null) return context.l10n.integrationsNeverUsed;
    return context.l10n.integrationsLastUsed(
      _formatService.formatDate(token.lastUsedAt!),
    );
  }

  @override
  Widget build(BuildContext context) {
    _formatService.setLocale(Localizations.localeOf(context).toString());
    final l10n = context.l10n;
    final paymentSettings = _paymentSettings;

    return MorePage(
      title: l10n.integrations,
      previousPageTitle: l10n.advancedTitle,
      trailing: GlassBarButton(
        key: const Key('integrationsAdd'),
        label: l10n.integrationsNew,
        icon: CupertinoIcons.add,
        onPressed: _create,
      ),
      children: [
        if (paymentSettings != null)
          PaymentsIntegrationSection(settingsStream: paymentSettings),
        SectionLabel(l10n.integrationsAiSection),
        _buildTokens(context),
      ],
    );
  }

  Widget _buildTokens(BuildContext context) {
    final l10n = context.l10n;
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: LoadingState(),
      );
    }

    if (_error != null) {
      return ErrorState(message: _error, onRetry: _load);
    }

    if (_tokens.isEmpty) {
      return Padding(
        key: const Key('integrationsEmpty'),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pageMargin,
          vertical: AppSpacing.sm,
        ),
        child: Text(
          l10n.integrationsEmptyLine,
          style: AppTypography.callout.copyWith(
            color: AppColors.textSecondary.resolveFrom(context),
          ),
        ),
      );
    }

    return MoreRows(
      rows: [
        for (final token in _tokens)
          AppListRow(
            key: Key('integrationToken_${token.id}'),
            title: token.name ?? '',
            subtitle: _subtitle(context, token),
            showChevron: false,
            onTap: () => _openToken(token),
          ),
      ],
    );
  }
}
