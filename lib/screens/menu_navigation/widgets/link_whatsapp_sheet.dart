import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:praticos/mobx/whatsapp_link_store.dart';
import 'package:praticos/extensions/context_extensions.dart';

class LinkWhatsAppSheet extends StatefulWidget {
  final WhatsAppLinkStore store;

  const LinkWhatsAppSheet({
    super.key,
    required this.store,
  });

  @override
  State<LinkWhatsAppSheet> createState() => _LinkWhatsAppSheetState();

  /// Show the bottom sheet for linking WhatsApp
  static Future<void> show(BuildContext context, WhatsAppLinkStore store) {
    return showCupertinoModalPopup(
      context: context,
      builder: (context) => LinkWhatsAppSheet(store: store),
    );
  }
}

class _LinkWhatsAppSheetState extends State<LinkWhatsAppSheet> {
  Timer? _expirationTimer;
  int _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _generateToken();
  }

  @override
  void dispose() {
    _expirationTimer?.cancel();
    widget.store.clearToken();
    super.dispose();
  }

  Future<void> _generateToken() async {
    final token = await widget.store.generateToken();
    if (token != null && mounted) {
      _startExpirationTimer(token.expiresIn);
    }
  }

  void _startExpirationTimer(int expiresIn) {
    _remainingSeconds = expiresIn;
    _expirationTimer?.cancel();
    _expirationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _remainingSeconds--;
          if (_remainingSeconds <= 0) {
            timer.cancel();
            widget.store.clearToken();
          }
        });
      } else {
        timer.cancel();
      }
    });
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _openWhatsApp(String link) async {
    final uri = Uri.parse(link);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Container(
        decoration: BoxDecoration(
          color: CupertinoTheme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 16,
          bottom: MediaQuery.of(context).padding.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey4.resolveFrom(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              context.l10n.linkWhatsApp,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: CupertinoColors.label.resolveFrom(context),
              ),
            ),
            const SizedBox(height: 8),

            // Description
            Text(
              context.l10n.linkWhatsAppDescription,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
            const SizedBox(height: 24),

            // Content based on state
            Observer(
              builder: (_) {
                if (widget.store.isLoading) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: CupertinoActivityIndicator(),
                  );
                }

                if (widget.store.error != null) {
                  return _buildErrorState();
                }

                if (widget.store.currentToken != null) {
                  return _buildTokenState();
                }

                return const SizedBox.shrink();
              },
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Column(
      children: [
        Icon(
          CupertinoIcons.exclamationmark_circle,
          size: 48,
          color: CupertinoColors.systemRed.resolveFrom(context),
        ),
        const SizedBox(height: 16),
        Text(
          widget.store.error ?? context.l10n.errorGeneratingToken,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: CupertinoColors.systemRed.resolveFrom(context),
          ),
        ),
        const SizedBox(height: 16),
        CupertinoButton(
          onPressed: _generateToken,
          child: Text(context.l10n.tryAgain),
        ),
      ],
    );
  }

  Widget _buildTokenState() {
    final token = widget.store.currentToken!;

    return Column(
      children: [
        // QR Code
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CupertinoColors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: QrImageView(
            data: token.link,
            version: QrVersions.auto,
            size: 180,
            backgroundColor: CupertinoColors.white,
            errorStateBuilder: (context, error) => const Icon(
              CupertinoIcons.exclamationmark_triangle,
              size: 48,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Timer
        if (_remainingSeconds > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey6.resolveFrom(context),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CupertinoIcons.timer,
                  size: 16,
                  color: _remainingSeconds < 60
                      ? CupertinoColors.systemRed.resolveFrom(context)
                      : CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
                const SizedBox(width: 6),
                Text(
                  context.l10n.linkExpiresIn(_formatTime(_remainingSeconds)),
                  style: TextStyle(
                    fontSize: 13,
                    color: _remainingSeconds < 60
                        ? CupertinoColors.systemRed.resolveFrom(context)
                        : CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ],
            ),
          )
        else
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _generateToken,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(CupertinoIcons.refresh, size: 16),
                const SizedBox(width: 6),
                Text(context.l10n.tryAgain),
              ],
            ),
          ),

        const SizedBox(height: 24),

        // Open WhatsApp button
        SizedBox(
          width: double.infinity,
          child: CupertinoButton.filled(
            onPressed: () => _openWhatsApp(token.link),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.chat_bubble_fill, size: 18),
                const SizedBox(width: 8),
                Text(context.l10n.openWhatsApp),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
