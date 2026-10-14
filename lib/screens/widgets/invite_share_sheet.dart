import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/screens/widgets/app_toast.dart';
import 'package:praticos/screens/widgets/glass_bar_button.dart';
import 'package:praticos/screens/widgets/primary_button.dart';
import 'package:praticos/screens/widgets/pull_down_menu.dart';
import 'package:praticos/screens/widgets/text_link.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// "Convite para a equipe": the invite code, one sentence of what to do with
/// it and one blue button to share it. WhatsApp is a grey button, copying the
/// code a link. Same pattern as "Mandar para o cliente" (`ShareLinkSheet`):
/// it only shares what already exists, so there is nothing to save.
///
/// With [onCancelInvite] the "…" menu offers "Cancelar convite" (red; the
/// caller confirms and cancels).
class InviteShareSheet extends StatelessWidget {
  final String token;
  final String? whatsappPhone;
  final int expirationDays;
  final VoidCallback? onDone;
  final VoidCallback? onCancelInvite;

  /// Test seams; default to the system share sheet and to opening WhatsApp.
  final Future<void> Function(String message)? onShare;
  final Future<void> Function(Uri url)? onOpenUrl;

  const InviteShareSheet({
    super.key,
    required this.token,
    this.whatsappPhone,
    required this.expirationDays,
    this.onDone,
    this.onCancelInvite,
    this.onShare,
    this.onOpenUrl,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = AppColors.text.resolveFrom(context);
    final secondary = AppColors.textSecondary.resolveFrom(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.resolveFrom(context),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadii.button),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageMargin,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.inviteSheetTitle,
                      style: AppTypography.highlight.copyWith(color: text),
                    ),
                  ),
                  if (onCancelInvite != null) ...[
                    GlassBarButton(
                      key: const Key('inviteShareMenu'),
                      label: l10n.inviteMenu,
                      icon: CupertinoIcons.ellipsis,
                      onPressed: () => _openMenu(context),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  GlassBarButton(
                    key: const Key('inviteShareClose'),
                    label: l10n.close,
                    icon: CupertinoIcons.xmark,
                    onPressed: () {
                      Navigator.pop(context);
                      onDone?.call();
                    },
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.inviteShareSentence(expirationDays),
                      style: AppTypography.callout.copyWith(color: secondary),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      token,
                      key: const Key('inviteCode'),
                      style: AppTypography.highlight.copyWith(
                        color: text,
                        fontFeatures: AppTypography.tabular,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    PrimaryButton(
                      key: const Key('inviteSharePrimary'),
                      label: l10n.inviteShareButton,
                      icon: CupertinoIcons.share,
                      onPressed: () => _shareCode(context),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    CupertinoButton(
                      key: const Key('inviteShareWhatsApp'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      minimumSize: const Size(
                        AppSizes.minTouchTarget,
                        AppSizes.minTouchTarget + 6,
                      ),
                      color: AppColors.secondaryFill.resolveFrom(context),
                      borderRadius: BorderRadius.circular(AppRadii.button),
                      onPressed: () => _sendViaWhatsApp(context),
                      child: Text(
                        l10n.inviteSendWhatsApp,
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyStrong.copyWith(
                          color: AppColors.accentText.resolveFrom(context),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Center(
                      child: TextLink(
                        key: const Key('inviteShareCopy'),
                        label: l10n.inviteCopyCode,
                        onPressed: () => _copyCode(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openMenu(BuildContext context) async {
    final l10n = context.l10n;
    final picked = await showPullDownMenu(
      context,
      groups: [
        PullDownGroup([
          PullDownItem(
            value: 'cancel',
            label: l10n.teamCancelInvite,
            icon: CupertinoIcons.xmark_circle,
            destructive: true,
          ),
        ]),
      ],
    );
    if (picked == 'cancel' && context.mounted) {
      Navigator.pop(context);
      onCancelInvite?.call();
    }
  }

  String _buildShareMessage(BuildContext context) {
    return context.l10n.inviteWhatsAppMessage(token);
  }

  Future<void> _sendViaWhatsApp(BuildContext context) async {
    final message = Uri.encodeComponent(_buildShareMessage(context));

    final String whatsappUrl;
    if (whatsappPhone != null && whatsappPhone!.isNotEmpty) {
      final cleanNumber = whatsappPhone!.replaceAll(RegExp(r'\D'), '');
      whatsappUrl = 'https://wa.me/$cleanNumber?text=$message';
    } else {
      whatsappUrl = 'https://wa.me/?text=$message';
    }

    final url = Uri.parse(whatsappUrl);
    final open = onOpenUrl;
    if (open != null) return open(url);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _copyCode(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: token));
    if (!context.mounted) return;
    showAppToast(context, context.l10n.inviteCodeCopied);
  }

  Future<void> _shareCode(BuildContext context) async {
    final message = _buildShareMessage(context);
    final share = onShare;
    if (share != null) return share(message);

    // Get the share position for iPad
    final box = context.findRenderObject() as RenderBox?;
    final sharePositionOrigin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : null;

    await SharePlus.instance.share(
      ShareParams(
        text: message,
        subject: context.l10n.inviteSheetTitle,
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

  /// Shows the invite share sheet at the bottom of the screen.
  static Future<void> show(
    BuildContext context, {
    required String token,
    String? whatsappPhone,
    required int expirationDays,
    VoidCallback? onDone,
    VoidCallback? onCancelInvite,
  }) {
    return showCupertinoModalPopup(
      context: context,
      builder: (context) => InviteShareSheet(
        token: token,
        whatsappPhone: whatsappPhone,
        expirationDays: expirationDays,
        onDone: onDone,
        onCancelInvite: onCancelInvite,
      ),
    );
  }
}
