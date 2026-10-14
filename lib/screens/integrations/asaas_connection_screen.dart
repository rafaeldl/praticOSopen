import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/global.dart';
import 'package:praticos/models/payment_settings.dart';
import 'package:praticos/models/permission.dart';
import 'package:praticos/repositories/tenant/payment_settings_repository.dart';
import 'package:praticos/screens/menu_navigation/more/more_page.dart';
import 'package:praticos/screens/payments/asaas_error_text.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/screens/widgets/app_toast.dart';
import 'package:praticos/screens/widgets/glass_bar_button.dart';
import 'package:praticos/screens/widgets/list_states.dart';
import 'package:praticos/screens/widgets/primary_button.dart';
import 'package:praticos/screens/widgets/pull_down_menu.dart';
import 'package:praticos/screens/widgets/section_label.dart';
import 'package:praticos/screens/widgets/status_dot.dart';
import 'package:praticos/screens/widgets/text_link.dart';
import 'package:praticos/services/asaas_api_service.dart';
import 'package:praticos/services/authorization_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';
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
      !AuthorizationService.instance.hasPermission(
        PermissionType.manageUsers,
      )) {
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

/// "Pagamentos" section of the Integrations screen: the Asaas row with a
/// one-line status (dot + "Conectado"/"Não conectado"). Hidden until the
/// company is in the Asaas pilot (`asaasEnabled`).
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
        final connected = settings.asaasConnected;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionLabel(l10n.payments),
            AppListRow(
              key: const Key('asaasIntegrationTile'),
              title: 'Asaas',
              subtitleWidget: _StatusLine(
                color: connected ? AppColors.success : AppColors.textSecondary,
                text: connected ? l10n.asaasConnected : l10n.asaasDisconnected,
              ),
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

/// Status dot + `textSecondary` text, wrapping when the text is large.
class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.color, required this.text});

  final CupertinoDynamicColor color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        StatusDot(color: color.resolveFrom(context)),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            text,
            style: AppTypography.callout.copyWith(
              color: AppColors.textSecondary.resolveFrom(context),
            ),
          ),
        ),
      ],
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
          widget.settingsStream ??
              paymentSettingsStream() ??
              Stream.value(PaymentSettings()),
        ).listen((settings) {
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
      showAppToast(context, context.l10n.asaasConnectedToast);
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
      setState(
        () => _settings = PaymentSettings(
          asaasEnabled: _settings?.asaasEnabled ?? true,
          asaasConnected: false,
        ),
      );
      showAppToast(context, context.l10n.asaasDisconnectedToast);
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
    showAppToast(
      context,
      message,
      icon: CupertinoIcons.exclamationmark_circle_fill,
    );
  }

  Future<void> _openMenu() async {
    final picked = await showPullDownMenu(
      context,
      groups: [
        PullDownGroup([
          PullDownItem(
            value: 'disconnect',
            label: context.l10n.asaasDisconnect,
            icon: CupertinoIcons.power,
            destructive: true,
          ),
        ]),
      ],
    );
    if (picked == 'disconnect' && mounted) await _disconnect();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = _settings;
    if (settings == null) {
      return MorePage(
        title: 'Asaas',
        previousPageTitle: l10n.integrations,
        children: const [LoadingState()],
      );
    }
    if (settings.asaasConnected) {
      return MorePage(
        title: 'Asaas',
        previousPageTitle: l10n.integrations,
        subtitle: l10n.asaasConnectedHeadline,
        trailing: _busy
            ? const CupertinoActivityIndicator()
            : GlassBarButton(
                key: const Key('asaasMenuButton'),
                label: l10n.asaasMenu,
                icon: CupertinoIcons.ellipsis,
                onPressed: _openMenu,
              ),
        children: _buildConnected(context, settings),
      );
    }
    return MorePage(
      title: 'Asaas',
      previousPageTitle: l10n.integrations,
      subtitle: l10n.asaasConnectHeadline,
      floatingButton: PrimaryButton(
        key: const Key('asaasConnectButton'),
        label: _busy ? l10n.asaasConnecting : l10n.asaasConnect,
        onPressed: _busy ? null : _connect,
      ),
      children: _buildDisconnected(context),
    );
  }

  List<Widget> _buildDisconnected(BuildContext context) {
    final l10n = context.l10n;
    final text = AppColors.text.resolveFrom(context);
    final secondary = AppColors.textSecondary.resolveFrom(context);
    final stepStyle = AppTypography.body.copyWith(color: text);

    return [
      SectionLabel(l10n.asaasConnectTitle),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageMargin),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.asaasConnectStep1, style: stepStyle),
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.asaasConnectStep2, style: stepStyle),
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.asaasConnectStep3, style: stepStyle),
            const SizedBox(height: AppSpacing.sm),
            TextLink(
              key: const Key('asaasOpenPanel'),
              label: l10n.asaasOpenPanel,
              onPressed: () => _openPanel(asaasPanelUrl),
            ),
            TextLink(
              key: const Key('asaasOpenSandboxPanel'),
              label: l10n.asaasOpenSandboxPanel,
              onPressed: () => _openPanel(asaasSandboxPanelUrl),
            ),
          ],
        ),
      ),
      SectionLabel(l10n.asaasApiKey),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageMargin),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CupertinoTextField(
              key: const Key('asaasApiKeyField'),
              controller: _apiKeyController,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              placeholder: l10n.asaasApiKeyPlaceholder,
              style: AppTypography.body.copyWith(color: text),
              placeholderStyle: AppTypography.body.copyWith(color: secondary),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface.resolveFrom(context),
                borderRadius: BorderRadius.circular(AppRadii.field),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.asaasApiKeyHint,
              style: AppTypography.label.copyWith(color: secondary),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildConnected(BuildContext context, PaymentSettings settings) {
    final l10n = context.l10n;
    final isSandbox = settings.isSandbox;

    return [
      MoreRows(
        rows: [
          AppListRow(
            title: l10n.asaasAccount,
            trailing: settings.asaasAccountName ?? '',
          ),
          AppListRow(
            key: const Key('asaasEnvironmentRow'),
            title: l10n.asaasEnvironment,
            subtitleWidget: _StatusLine(
              color: isSandbox ? AppColors.warning : AppColors.success,
              text: isSandbox
                  ? l10n.asaasEnvironmentSandbox
                  : l10n.asaasEnvironmentProduction,
            ),
          ),
        ],
      ),
    ];
  }
}
