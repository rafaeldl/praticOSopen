import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/models/subscription.dart';
import 'package:praticos/screens/widgets/next_step_block.dart';
import 'package:praticos/screens/widgets/primary_button.dart';
import 'package:praticos/services/feature_gate_service.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/services/paid_plans_config.dart';
import 'package:praticos/services/paywall_launcher.dart';
import 'package:praticos/services/subscription_service.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Início, in the 15 days before `config/paidPlans.limitsStartAt`: tells an
/// existing Free company that Free gets its work order limit on that day
/// (decision of 2026-11-13). The server sends the same as push and e-mail
/// (free-limits-notice.service.ts). Only for whoever can buy, in a build
/// that sells. "Agora não" hides it for that date.
class FreeLimitsBanner extends StatefulWidget {
  const FreeLimitsBanner({
    super.key,
    required this.notice,
    required this.companyId,
    this.onViewPlans,
  });

  final FreeLimitsNotice notice;

  /// Kept with "Agora não": a device can hold several companies.
  final String? companyId;

  /// Defaults to the paywall (tests inject).
  final VoidCallback? onViewPlans;

  /// The notice Início should show at [now], or null.
  static FreeLimitsNotice? noticeFor(Subscription? subscription, DateTime now) {
    if (!SubscriptionService.paidPlansEnabled || !PaywallLauncher.currentUserCanPurchase) {
      return null;
    }
    final isFree = (subscription ?? Subscription()).effectivePlan(now) == SubscriptionPlan.free;
    return FeatureGateService.paidPlansConfig.freeLimitsNotice(isFree: isFree, now: now);
  }

  @override
  State<FreeLimitsBanner> createState() => _FreeLimitsBannerState();
}

class _FreeLimitsBannerState extends State<FreeLimitsBanner> {
  /// Stays hidden until the saved "Agora não" has been read.
  bool _hidden = true;

  String get _key => '${widget.notice.dismissKey}_${widget.companyId}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _hidden = prefs.getBool(_key) == true);
  }

  Future<void> _dismiss() async {
    setState(() => _hidden = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }

  @override
  Widget build(BuildContext context) {
    if (_hidden) return const SizedBox.shrink();
    final l10n = context.l10n;
    final format = FormatService()..setLocale(l10n.localeName);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: NextStepBlock(
        key: const ValueKey('free_limits_banner'),
        label: l10n.freeLimitsBannerLabel,
        text: l10n.freeLimitsBannerText(
          format.formatDate(widget.notice.startsAt.toLocal()),
          currentPlanRow(SubscriptionPlan.free).ordersPerMonth,
        ),
        linkLabel: l10n.courtesyBannerLater,
        onLink: _dismiss,
        button: PrimaryButton(
          key: const ValueKey('free_limits_view_plans'),
          label: l10n.viewPlans,
          onPressed: widget.onViewPlans ?? () => PaywallLauncher.showPaywall(context),
        ),
      ),
    );
  }
}
