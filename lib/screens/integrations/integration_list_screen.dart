import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SelectableText;
import 'package:flutter/services.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/integration_token.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/services/integration_api_service.dart';

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

class IntegrationListScreen extends StatefulWidget {
  const IntegrationListScreen({super.key});

  @override
  State<IntegrationListScreen> createState() => _IntegrationListScreenState();
}

class _IntegrationListScreenState extends State<IntegrationListScreen> {
  final _formatService = FormatService();
  List<IntegrationToken> _tokens = [];
  bool _loading = true;
  String? _error;

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
      final tokens = await IntegrationApiService.instance.list();
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
    final controller = TextEditingController();

    final name = await showCupertinoDialog<String>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(dialogContext.l10n.integrationsNew),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            placeholder: dialogContext.l10n.integrationsNameHint,
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(dialogContext.l10n.cancel),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(dialogContext.l10n.save),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    try {
      final created = await IntegrationApiService.instance.create(name: name);
      if (!mounted) return;
      await _showUrlOnce(created);
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
              style: const TextStyle(fontSize: 12),
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
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.l10n.integrationsRevoke),
          ),
        ],
      ),
    );

    if (confirmed != true || token.id == null) return;

    try {
      await IntegrationApiService.instance.revoke(token.id!);
      await _load();
    } on IntegrationApiException catch (e) {
      if (!mounted) return;
      _showError(integrationErrorText(context.l10n, e));
    }
  }

  void _showError(String message) {
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(dialogContext.l10n.ok),
          ),
        ],
      ),
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

    return CupertinoPageScaffold(
      backgroundColor:
          CupertinoColors.systemGroupedBackground.resolveFrom(context),
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text(context.l10n.integrations),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _create,
              child: const Icon(CupertinoIcons.add),
            ),
          ),
          SliverToBoxAdapter(child: _buildBody(context)),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(
            _error!,
            style: TextStyle(
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ),
      );
    }

    if (_tokens.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Text(
              context.l10n.integrationsEmpty,
              style: TextStyle(
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.integrationsSubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.tertiaryLabel.resolveFrom(context),
              ),
            ),
          ],
        ),
      );
    }

    return CupertinoListSection.insetGrouped(
      children: _tokens.map((token) {
        return CupertinoListTile(
          title: Text(token.name ?? ''),
          subtitle: Text(_subtitle(context, token)),
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => _revoke(token),
            child: Text(
              context.l10n.integrationsRevoke,
              style: const TextStyle(
                fontSize: 14,
                color: CupertinoColors.systemRed,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
