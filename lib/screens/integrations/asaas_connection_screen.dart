import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/global.dart';
import 'package:praticos/models/payment_settings.dart';
import 'package:praticos/models/permission.dart';
import 'package:praticos/repositories/tenant/payment_settings_repository.dart';
import 'package:praticos/screens/payments/asaas_error_text.dart';
import 'package:praticos/services/asaas_api_service.dart';
import 'package:praticos/services/authorization_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// Asaas dashboard page where the user creates an API key.
const asaasPanelUrl = 'https://www.asaas.com/customerConfigIntegrations/index';
const asaasSandboxPanelUrl =
    'https://sandbox.asaas.com/customerConfigIntegrations/index';

/// Settings stream shared by the Integrations list and the connection
/// screen. Null when there is no company or the user cannot manage
/// integrations (owner/admin only, same guard that opens Integrations).
Stream<PaymentSettings>? paymentSettingsStream() {
  final companyId = Global.companyAggr?.id;
  if (companyId == null ||
      !AuthorizationService.instance.hasPermission(PermissionType.manageUsers)) {
    return null;
  }
  return safePaymentSettings(PaymentSettingsRepository().watch(companyId));
}

/// Turns stream errors (e.g. permission-denied) into "not connected"
/// instead of leaving listeners waiting forever.
Stream<PaymentSettings> safePaymentSettings(Stream<PaymentSettings> source) {
  return source.transform(
    StreamTransformer<PaymentSettings, PaymentSettings>.fromHandlers(
      handleData: (data, sink) => sink.add(data),
      handleError: (error, stackTrace, sink) => sink.add(PaymentSettings()),
    ),
  );
}

/// "Payments" section of the Integrations screen. Hidden until the company
/// is in the Asaas pilot (`asaasEnabled`).
class PaymentsIntegrationSection extends StatelessWidget {
  const PaymentsIntegrationSection({super.key, required this.settingsStream});

  final Stream<PaymentSettings> settingsStream;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PaymentSettings>(
      stream: settingsStream,
      builder: (context, snapshot) {
        final settings = snapshot.data;
        if (settings == null || !settings.asaasEnabled) {
          return const SizedBox.shrink();
        }
        final l10n = context.l10n;
        return CupertinoListSection.insetGrouped(
          header: Text(l10n.payments.toUpperCase()),
          children: [
            CupertinoListTile(
              key: const Key('asaasIntegrationTile'),
              leading: const Icon(CupertinoIcons.creditcard),
              title: const Text('Asaas'),
              additionalInfo: Text(settings.asaasConnected
                  ? l10n.asaasConnected
                  : l10n.asaasDisconnected),
              trailing: const CupertinoListTileChevron(),
              onTap: () => Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (_) => const AsaasConnectionScreen(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Connects or disconnects the company's Asaas account.
///
/// The API key goes straight to the server and is cleared from the field;
/// the app never stores it.
class AsaasConnectionScreen extends StatefulWidget {
  const AsaasConnectionScreen({super.key, this.service, this.settingsStream});

  /// Test seam; defaults to [AsaasApiService.instance].
  final AsaasApiService? service;

  /// Test seam; defaults to the company's `settings/payments` document.
  final Stream<PaymentSettings>? settingsStream;

  @override
  State<AsaasConnectionScreen> createState() => _AsaasConnectionScreenState();
}

class _AsaasConnectionScreenState extends State<AsaasConnectionScreen> {
  final _apiKeyController = TextEditingController();
  StreamSubscription<PaymentSettings>? _subscription;
  PaymentSettings? _settings;
  bool _busy = false;

  AsaasApiService get _service => widget.service ?? AsaasApiService.instance;

  @override
  void initState() {
    super.initState();
    _subscription =
        safePaymentSettings(
                widget.settingsStream ?? paymentSettingsStream() ?? Stream.value(PaymentSettings()))
            .listen((settings) {
      if (!mounted) return;
      setState(() => _settings = settings);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty || _busy) return;

    setState(() => _busy = true);
    try {
      final settings = await _service.connect(apiKey);
      _apiKeyController.clear();
      if (!mounted) return;
      setState(() => _settings = settings);
    } on AsaasApiException catch (e) {
      if (!mounted) return;
      _showMessage(asaasErrorText(context.l10n, e));
    } catch (_) {
      // Unexpected response (e.g. malformed body): generic text, never raw.
      if (!mounted) return;
      _showMessage(context.l10n.asaasErrorGeneric);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disconnect() async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(dialogContext.l10n.asaasDisconnect),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(dialogContext.l10n.asaasDisconnectConfirm),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.l10n.cancel),
          ),
          CupertinoDialogAction(
            key: const Key('confirmAsaasDisconnectAction'),
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.l10n.asaasDisconnect),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await _service.disconnect();
      if (!mounted) return;
      setState(() => _settings = PaymentSettings(
            asaasEnabled: _settings?.asaasEnabled ?? true,
            asaasConnected: false,
          ));
    } on AsaasApiException catch (e) {
      if (!mounted) return;
      _showMessage(asaasErrorText(context.l10n, e));
    } catch (_) {
      // Unexpected response (e.g. malformed body): generic text, never raw.
      if (!mounted) return;
      _showMessage(context.l10n.asaasErrorGeneric);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openPanel(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  void _showMessage(String message) {
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

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    return CupertinoPageScaffold(
      backgroundColor:
          CupertinoColors.systemGroupedBackground.resolveFrom(context),
      child: CustomScrollView(
        slivers: [
          const CupertinoSliverNavigationBar(largeTitle: Text('Asaas')),
          if (settings == null)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CupertinoActivityIndicator()),
            )
          else
            SliverSafeArea(
              top: false,
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  settings.asaasConnected
                      ? _buildConnected(context, settings)
                      : _buildDisconnected(context),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildDisconnected(BuildContext context) {
    final l10n = context.l10n;
    final stepStyle = TextStyle(
      fontSize: 15,
      color: CupertinoColors.secondaryLabel.resolveFrom(context),
    );

    return [
      CupertinoListSection.insetGrouped(
        header: Text(l10n.asaasConnectTitle.toUpperCase()),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.asaasConnectIntro,
                  style: TextStyle(
                    fontSize: 15,
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
                ),
                const SizedBox(height: 12),
                Text(l10n.asaasConnectStep1, style: stepStyle),
                const SizedBox(height: 4),
                Text(l10n.asaasConnectStep2, style: stepStyle),
                const SizedBox(height: 4),
                Text(l10n.asaasConnectStep3, style: stepStyle),
              ],
            ),
          ),
          CupertinoListTile(
            title: Text(l10n.asaasOpenPanel),
            trailing: const Icon(CupertinoIcons.arrow_up_right_square),
            onTap: () => _openPanel(asaasPanelUrl),
          ),
          CupertinoListTile(
            title: Text(l10n.asaasOpenSandboxPanel),
            trailing: const Icon(CupertinoIcons.arrow_up_right_square),
            onTap: () => _openPanel(asaasSandboxPanelUrl),
          ),
        ],
      ),
      CupertinoListSection.insetGrouped(
        header: Text(l10n.asaasApiKey.toUpperCase()),
        footer: Text(l10n.asaasApiKeyHint),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: CupertinoTextField(
              key: const Key('asaasApiKeyField'),
              controller: _apiKeyController,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              placeholder: l10n.asaasApiKeyPlaceholder,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6.resolveFrom(context),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: SizedBox(
          width: double.infinity,
          child: CupertinoButton.filled(
            key: const Key('asaasConnectButton'),
            onPressed: _busy ? null : _connect,
            child: _busy
                ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                : Text(l10n.asaasConnect),
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildConnected(BuildContext context, PaymentSettings settings) {
    final l10n = context.l10n;
    final isSandbox = settings.isSandbox;
    final badgeColor = isSandbox
        ? CupertinoColors.systemOrange.resolveFrom(context)
        : CupertinoColors.systemGreen.resolveFrom(context);

    return [
      CupertinoListSection.insetGrouped(
        children: [
          CupertinoListTile(
            title: Text(l10n.asaasAccount),
            additionalInfo: Text(settings.asaasAccountName ?? ''),
          ),
          CupertinoListTile(
            title: Text(l10n.asaasEnvironment),
            additionalInfo: Container(
              key: const Key('asaasEnvironmentBadge'),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                isSandbox
                    ? l10n.asaasEnvironmentSandbox
                    : l10n.asaasEnvironmentProduction,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: badgeColor,
                ),
              ),
            ),
          ),
        ],
      ),
      CupertinoListSection.insetGrouped(
        children: [
          CupertinoListTile(
            key: const Key('asaasDisconnectTile'),
            title: Text(
              l10n.asaasDisconnect,
              style: const TextStyle(color: CupertinoColors.systemRed),
            ),
            trailing: _busy ? const CupertinoActivityIndicator() : null,
            onTap: _busy ? null : _disconnect,
          ),
        ],
      ),
    ];
  }
}
