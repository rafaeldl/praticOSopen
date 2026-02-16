import 'package:flutter/cupertino.dart';
import 'package:praticos/mobx/whatsapp_link_store.dart';
import 'package:praticos/screens/menu_navigation/widgets/link_whatsapp_sheet.dart';
import 'package:praticos/extensions/context_extensions.dart';

class WhatsAppOnboardingScreen extends StatefulWidget {
  const WhatsAppOnboardingScreen({super.key});

  @override
  State<WhatsAppOnboardingScreen> createState() =>
      _WhatsAppOnboardingScreenState();
}

class _WhatsAppOnboardingScreenState extends State<WhatsAppOnboardingScreen> {
  final WhatsAppLinkStore _whatsappStore = WhatsAppLinkStore();

  void _navigateToHome() {
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  void _linkNow() {
    LinkWhatsAppSheet.show(context, _whatsappStore).then((_) {
      _navigateToHome();
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: SafeArea(
        child: DefaultTextStyle(
          style: CupertinoTheme.of(context).textTheme.textStyle,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 40),
                // Icon
                const Icon(
                  CupertinoIcons.chat_bubble_2,
                  size: 64,
                  color: Color(0xFF25D366),
                ),
                const SizedBox(height: 24),
                // Title
                Text(
                  context.l10n.whatsappOnboardingTitle,
                  style: CupertinoTheme.of(context)
                      .textTheme
                      .navLargeTitleTextStyle
                      .copyWith(fontSize: 24),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                // Subtitle
                Text(
                  context.l10n.whatsappOnboardingSubtitle,
                  textAlign: TextAlign.center,
                  style:
                      CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                            color: CupertinoColors.secondaryLabel
                                .resolveFrom(context),
                            fontSize: 16,
                          ),
                ),
                const SizedBox(height: 32),
                // Benefits list
                Container(
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemBackground
                        .resolveFrom(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildBenefitRow(
                        context,
                        CupertinoIcons.bell,
                        context.l10n.whatsappBenefitNotifications,
                      ),
                      const SizedBox(height: 12),
                      _buildBenefitRow(
                        context,
                        CupertinoIcons.chat_bubble_text,
                        context.l10n.whatsappBenefitManage,
                      ),
                      const SizedBox(height: 12),
                      _buildBenefitRow(
                        context,
                        CupertinoIcons.paperplane,
                        context.l10n.whatsappBenefitClients,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // Primary button - Link now
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton.filled(
                    onPressed: _linkNow,
                    child: Text(context.l10n.linkNow),
                  ),
                ),
                const SizedBox(height: 12),
                // Secondary button - Maybe later
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    onPressed: _navigateToHome,
                    child: Text(
                      context.l10n.maybeLater,
                      style: TextStyle(
                        color: CupertinoColors.secondaryLabel
                            .resolveFrom(context),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitRow(
      BuildContext context, IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: const Color(0xFF25D366),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style:
                CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                      fontSize: 15,
                    ),
          ),
        ),
        const Icon(
          CupertinoIcons.checkmark,
          size: 18,
          color: CupertinoColors.systemGreen,
        ),
      ],
    );
  }
}
