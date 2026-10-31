import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/screens/menu_navigation/home.dart' show ordersChanged;
import 'package:praticos/screens/order/order_route.dart';
import 'package:praticos/screens/widgets/primary_button.dart';
import 'package:praticos/screens/widgets/text_link.dart';
import 'package:praticos/services/ai_order_assist_service.dart';
import 'package:praticos/services/analytics_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Saved once the first-use sheet has been shown on this device.
const String kAiIntroSeenKey = 'ai_intro_seen_v1';

/// Shows [AiIntroSheet] once per device, where the assistant is on. The app
/// never asks again, whatever the answer. [isSettled] says the user is still
/// on Início: the answer from the server can take seconds, and the sheet must
/// not land on an order opened meanwhile. Returns false in that case, with
/// nothing saved, so the caller tries again later.
Future<bool> showAiIntroOnce(
  BuildContext context, {
  required bool Function() isSettled,
  AiOrderAssistClient? assistant,
}) async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(kAiIntroSeenKey) == true) return true;
  final on = await (assistant ?? AiOrderAssistService()).isEnabled();
  if (!on) return true;
  if (!context.mounted || !isSettled()) return false;
  await prefs.setBool(kAiIntroSeenKey, true);
  if (!context.mounted) return true;
  AnalyticsService.logAiEvent('ai_intro_shown');

  final accepted = await showCupertinoModalPopup<bool>(
    context: context,
    builder: (sheet) => AiIntroSheet(
      order: context.read<SegmentConfigProvider>().serviceOrder,
      onTry: () => Navigator.pop(sheet, true),
      onLater: () => Navigator.pop(sheet, false),
    ),
  );
  AnalyticsService.logAiEvent(
    accepted == true ? 'ai_intro_accepted' : 'ai_intro_dismissed',
  );
  if (accepted == true && context.mounted) {
    openNewOrder(
      context,
      startTalking: true,
    ).then((_) => ordersChanged.value++);
  }
  return true;
}

/// First use of the assistant: one sentence and one action, which opens the
/// "Nova OS" already listening.
class AiIntroSheet extends StatelessWidget {
  const AiIntroSheet({
    super.key,
    required this.order,
    required this.onTry,
    required this.onLater,
  });

  /// The segment's word for a work order.
  final String order;
  final VoidCallback onTry;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface.resolveFrom(context),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadii.block),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                CupertinoIcons.sparkles,
                size: 32,
                color: AppColors.accentText.resolveFrom(context),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.aiIntroTitle(order),
                textAlign: TextAlign.center,
                style: AppTypography.highlight.copyWith(
                  color: AppColors.text.resolveFrom(context),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.aiIntroBody,
                textAlign: TextAlign.center,
                style: AppTypography.callout.copyWith(
                  color: AppColors.textSecondary.resolveFrom(context),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                key: const ValueKey('ai_intro_try'),
                label: l10n.aiIntroTry,
                onPressed: onTry,
              ),
              TextLink(
                key: const ValueKey('ai_intro_later'),
                label: l10n.aiIntroLater,
                onPressed: onLater,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
