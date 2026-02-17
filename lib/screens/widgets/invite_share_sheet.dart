import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Material, MaterialType;
import 'package:flutter/services.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Sheet for sharing an invite code with a new collaborator
class InviteShareSheet extends StatelessWidget {
  final String token;
  final String? whatsappPhone;
  final int expirationDays;
  final VoidCallback? onDone;

  const InviteShareSheet({
    super.key,
    required this.token,
    this.whatsappPhone,
    required this.expirationDays,
    this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Container(
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground.resolveFrom(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey4.resolveFrom(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.l10n.shareInvite,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: Icon(
                        CupertinoIcons.xmark_circle_fill,
                        color: CupertinoColors.systemGrey3.resolveFrom(context),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        onDone?.call();
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Token display
              _buildTokenCard(context),

              const SizedBox(height: 20),

              // WhatsApp button (primary)
              _buildWhatsAppButton(context),

              const SizedBox(height: 10),

              // Copy Code button
              _buildCopyCodeButton(context),

              const SizedBox(height: 10),

              // Share button
              _buildShareButton(context),

              const SizedBox(height: 16),

              // Expiration info
              _buildExpirationInfo(context),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTokenCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6.resolveFrom(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Invite icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: CupertinoColors.activeBlue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                CupertinoIcons.ticket,
                size: 22,
                color: CupertinoColors.activeBlue,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Token info
          Expanded(
            child: Text(
              token,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'Menlo',
                color: CupertinoColors.label.resolveFrom(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhatsAppButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: CupertinoButton(
          color: const Color(0xFF25D366), // WhatsApp green
          borderRadius: BorderRadius.circular(12),
          padding: EdgeInsets.zero,
          onPressed: () => _sendViaWhatsApp(context),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(CupertinoIcons.chat_bubble_fill, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                context.l10n.sendViaWhatsAppInvite,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCopyCodeButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: CupertinoButton(
          color: CupertinoColors.activeBlue,
          borderRadius: BorderRadius.circular(12),
          padding: EdgeInsets.zero,
          onPressed: () => _copyCode(context),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(CupertinoIcons.doc_on_clipboard, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                context.l10n.copyInviteCode,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShareButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: CupertinoButton(
          color: CupertinoColors.systemGrey5.resolveFrom(context),
          borderRadius: BorderRadius.circular(12),
          padding: EdgeInsets.zero,
          onPressed: () => _shareCode(context),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                CupertinoIcons.share,
                color: CupertinoColors.label.resolveFrom(context),
              ),
              const SizedBox(width: 8),
              Text(
                context.l10n.share,
                style: TextStyle(
                  color: CupertinoColors.label.resolveFrom(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpirationInfo(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.clock,
            size: 15,
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
          const SizedBox(width: 6),
          Text(
            context.l10n.inviteExpiresIn(expirationDays),
            style: TextStyle(
              fontSize: 14,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }

  String _buildShareMessage(BuildContext context) {
    return context.l10n.inviteWhatsAppMessage(token);
  }

  void _sendViaWhatsApp(BuildContext context) async {
    final message = Uri.encodeComponent(_buildShareMessage(context));

    final String whatsappUrl;
    if (whatsappPhone != null && whatsappPhone!.isNotEmpty) {
      final cleanNumber = whatsappPhone!.replaceAll(RegExp(r'\D'), '');
      whatsappUrl = 'https://wa.me/$cleanNumber?text=$message';
    } else {
      whatsappUrl = 'https://wa.me/?text=$message';
    }

    final url = Uri.parse(whatsappUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _copyCode(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: token));
    _showCupertinoToast(context, context.l10n.inviteCodeCopied);
  }

  void _shareCode(BuildContext context) async {
    // Get the share position for iPad
    final box = context.findRenderObject() as RenderBox?;
    final sharePositionOrigin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : null;

    await SharePlus.instance.share(
      ShareParams(
        text: _buildShareMessage(context),
        subject: context.l10n.shareInvite,
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

  void _showCupertinoToast(BuildContext context, String message) {
    showCupertinoModalPopup(
      context: context,
      builder: (toastContext) {
        Future.delayed(const Duration(seconds: 2), () {
          if (toastContext.mounted) Navigator.of(toastContext).pop();
        });
        return DefaultTextStyle(
          style: const TextStyle(
            fontFamily: '.SF Pro Text',
            decoration: TextDecoration.none,
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.only(bottom: 100),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey.darkColor,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Text(
                message,
                style: const TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Show the invite share sheet as a modal popup
  static Future<void> show(
    BuildContext context, {
    required String token,
    String? whatsappPhone,
    required int expirationDays,
    VoidCallback? onDone,
  }) {
    return showCupertinoModalPopup(
      context: context,
      builder: (context) => InviteShareSheet(
        token: token,
        whatsappPhone: whatsappPhone,
        expirationDays: expirationDays,
        onDone: onDone,
      ),
    );
  }
}
