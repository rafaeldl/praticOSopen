import 'package:flutter/cupertino.dart';
import 'package:praticos/mobx/whatsapp_link_store.dart';
import 'package:praticos/screens/menu_navigation/widgets/link_whatsapp_sheet.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/services/tracking_transparency_service.dart';
import 'package:praticos/screens/menu_navigation/more/more_page.dart';
import 'package:praticos/screens/onboarding/onboarding_flow.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/screens/widgets/primary_button.dart';
import 'package:praticos/screens/widgets/text_link.dart';
import 'package:praticos/theme/app_colors.dart';

/// Offer to link WhatsApp after the first access. Only shown with
/// `kWhatsAppBotEnabled` (off while the bot is down).
class WhatsAppOnboardingScreen extends StatefulWidget {
  const WhatsAppOnboardingScreen({super.key});

  @override
  State<WhatsAppOnboardingScreen> createState() =>
      _WhatsAppOnboardingScreenState();
}

class _WhatsAppOnboardingScreenState extends State<WhatsAppOnboardingScreen> {
  final WhatsAppLinkStore _whatsappStore = WhatsAppLinkStore();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TrackingTransparencyService.instance.requestIfEligible();
    });
  }

  void _navigateToHome() {
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  void _linkNow() {
    LinkWhatsAppSheet.show(context, _whatsappStore).then((_) {
      // Reload status to check if user actually linked
      _whatsappStore.loadStatus().then((_) {
        if (_whatsappStore.isLinked) {
          _navigateToHome();
        }
        // If not linked, stay on onboarding screen so user can try again
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final accent = AppColors.accentText.resolveFrom(context);
    Widget benefit(IconData icon, String text) => AppListRow(
          leading: Icon(icon, size: 24, color: accent),
          title: text,
        );

    return OnboardingPage(
      title: l10n.whatsappOnboardingTitle,
      subtitle: l10n.whatsappOnboardingSubtitle,
      slivers: [
        SliverToBoxAdapter(
          child: MoreRows(rows: [
            benefit(
              CupertinoIcons.bell,
              l10n.whatsappBenefitNotifications,
            ),
            benefit(
              CupertinoIcons.chat_bubble_text,
              l10n.whatsappBenefitManage,
            ),
            benefit(
              CupertinoIcons.paperplane,
              l10n.whatsappBenefitClients,
            ),
          ]),
        ),
      ],
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrimaryButton(
            key: const ValueKey('whatsapp_link_now'),
            label: l10n.linkNow,
            floating: true,
            onPressed: _linkNow,
          ),
          Center(
            child: TextLink(
              key: const ValueKey('whatsapp_maybe_later'),
              label: l10n.maybeLater,
              onPressed: _navigateToHome,
            ),
          ),
        ],
      ),
    );
  }
}
