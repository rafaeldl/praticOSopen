import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/models/subscription.dart';
import 'package:praticos/screens/widgets/next_step_block.dart';
import 'package:praticos/screens/widgets/primary_button.dart';
import 'package:praticos/services/ai_order_assist_service.dart';
import 'package:praticos/services/analytics_service.dart';
import 'package:praticos/services/courtesy_notice.dart';
import 'package:praticos/services/paywall_launcher.dart';
import 'package:praticos/services/subscription_service.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Início, in the last days of the Pro courtesy: when it ends, what the
/// company used against Free, and the paywall. Only for whoever can buy.
/// "Agora não" hides it until the last days ([CourtesyNotice.dismissKey]).
class CourtesyBanner extends StatefulWidget {
  const CourtesyBanner({
    super.key,
    required this.subscription,
    this.loadAiStatus,
    this.onViewPlans,
  });

  final Subscription subscription;

  /// Assistant use of the month; defaults to the server (tests inject).
  final Future<AiStatus> Function()? loadAiStatus;

  /// Defaults to the paywall (tests inject).
  final VoidCallback? onViewPlans;

  /// Whether Início should build the banner at [now].
  static bool applies(Subscription? subscription, DateTime now) =>
      SubscriptionService.paidPlansEnabled &&
      PaywallLauncher.currentUserCanPurchase &&
      CourtesyNotice.of(subscription, now) != null;

  @override
  State<CourtesyBanner> createState() => _CourtesyBannerState();
}

class _CourtesyBannerState extends State<CourtesyBanner> {
  late final CourtesyNotice? _notice =
      CourtesyNotice.of(widget.subscription, DateTime.now());

  /// Stays hidden until the saved "Agora não" has been read.
  bool _hidden = true;
  int _aiUsed = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final notice = _notice;
    if (notice == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(notice.dismissKey) == true) return;
    final ai = await (widget.loadAiStatus ??
        () => AiOrderAssistService().status())();
    if (!mounted) return;
    setState(() {
      _hidden = false;
      _aiUsed = ai.used ?? 0;
    });
    AnalyticsService.logAiEvent('upgrade_modal_shown', {
      'trigger': notice.isLast ? 'courtesy_last' : 'courtesy_first',
    });
  }

  Future<void> _dismiss() async {
    setState(() => _hidden = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notice!.dismissKey, true);
  }

  String _text(BuildContext context, CourtesyNotice notice) {
    final l10n = context.l10n;
    final plan = recommendedPlan(widget.subscription.usage, _aiUsed);
    return [
      l10n.courtesyBannerEnds(notice.daysLeft),
      if (_aiUsed > 0)
        l10n.courtesyBannerAiUse(
          _aiUsed,
          kAiRequestsPerMonth[SubscriptionPlan.free] ?? 0,
        )
      else
        l10n.courtesyBannerToFree,
      if (plan != null) l10n.courtesyBannerPlan(plan.displayName),
    ].join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final notice = _notice;
    if (notice == null || _hidden) return const SizedBox.shrink();
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: NextStepBlock(
        key: const ValueKey('courtesy_banner'),
        label: l10n.courtesyBannerLabel,
        text: _text(context, notice),
        warning: notice.isLast,
        linkLabel: l10n.courtesyBannerLater,
        onLink: _dismiss,
        button: PrimaryButton(
          key: const ValueKey('courtesy_view_plans'),
          label: l10n.viewPlans,
          onPressed: widget.onViewPlans ??
              () => PaywallLauncher.showPaywall(context),
        ),
      ),
    );
  }
}
