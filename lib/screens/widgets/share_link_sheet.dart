import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show ScaffoldMessenger, SnackBar;
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/share_token.dart';
import 'package:praticos/services/share_link_service.dart';

/// Sheet for sharing an order link with a customer
class ShareLinkSheet extends StatefulWidget {
  final Order order;
  final String? companyName;

  const ShareLinkSheet({
    super.key,
    required this.order,
    this.companyName,
  });

  @override
  State<ShareLinkSheet> createState() => _ShareLinkSheetState();

  /// Show the share link sheet as a modal popup
  static Future<void> show(BuildContext context, Order order, {String? companyName}) {
    return showCupertinoModalPopup(
      context: context,
      builder: (context) => ShareLinkSheet(
        order: order,
        companyName: companyName,
      ),
    );
  }
}

class _ShareLinkSheetState extends State<ShareLinkSheet> {
  final ShareLinkService _service = ShareLinkService.instance;

  bool _isLoading = true;
  bool _canApprove = true;
  bool _canComment = true;
  String? _errorMessage;
  ShareLinkResult? _result;

  @override
  void initState() {
    super.initState();
    _generateLink();
  }

  Future<void> _generateLink() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final permissions = <String>['view'];
      if (_canApprove) permissions.add('approve');
      if (_canComment) permissions.add('comment');

      final result = await _service.generateShareLink(
        orderId: widget.order.id!,
        permissions: permissions,
      );

      setState(() {
        _result = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _copyLink() {
    if (_result?.url == null) return;

    _service.copyToClipboard(_result!.url!);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.linkCopied)),
    );
  }

  void _shareLink() {
    if (_result?.url == null) return;

    final message = _service.buildShareMessage(
      customerName: widget.order.customer?.name ?? '',
      orderNumber: widget.order.number ?? 0,
      companyName: widget.companyName,
      locale: context.l10n.localeName,
    );

    _service.shareViaSheet(
      url: _result!.url!,
      message: message,
      subject: '${context.l10n.order} #${widget.order.number}',
    );
  }

  void _sendViaWhatsApp() {
    if (_result?.url == null) return;

    final phone = widget.order.customer?.phone;
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.invalidPhone)),
      );
      return;
    }

    final message = _service.buildShareMessage(
      customerName: widget.order.customer?.name ?? '',
      orderNumber: widget.order.number ?? 0,
      companyName: widget.companyName,
      locale: context.l10n.localeName,
    );

    _service.shareViaWhatsApp(
      url: _result!.url!,
      phone: phone,
      message: message,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: CupertinoColors.activeBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      CupertinoIcons.link,
                      color: CupertinoColors.activeBlue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.shareLinkTitle,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          context.l10n.shareLinkDescription,
                          style: TextStyle(
                            fontSize: 13,
                            color: CupertinoColors.secondaryLabel.resolveFrom(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Icon(CupertinoIcons.xmark_circle_fill),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Content
            if (_isLoading)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    const CupertinoActivityIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      context.l10n.generatingLink,
                      style: TextStyle(
                        color: CupertinoColors.secondaryLabel.resolveFrom(context),
                      ),
                    ),
                  ],
                ),
              )
            else if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    const Icon(
                      CupertinoIcons.exclamationmark_circle,
                      color: CupertinoColors.systemRed,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.l10n.errorGeneratingLink,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: CupertinoColors.secondaryLabel.resolveFrom(context),
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    CupertinoButton(
                      child: Text(context.l10n.tryAgain),
                      onPressed: _generateLink,
                    ),
                  ],
                ),
              )
            else
              _buildLinkContent(),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkContent() {
    return Column(
      children: [
        // Link preview
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey6.resolveFrom(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _result?.url ?? '',
                  style: const TextStyle(
                    fontSize: 13,
                    fontFamily: 'monospace',
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.all(8),
                minSize: 0,
                child: const Icon(CupertinoIcons.doc_on_doc, size: 20),
                onPressed: _copyLink,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Permissions toggles
        CupertinoListSection.insetGrouped(
          header: Text(context.l10n.sharePermissions),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            CupertinoListTile(
              leading: const Icon(CupertinoIcons.checkmark_seal),
              title: Text(context.l10n.canApprove),
              trailing: CupertinoSwitch(
                value: _canApprove,
                onChanged: (value) {
                  setState(() {
                    _canApprove = value;
                  });
                  _generateLink();
                },
              ),
            ),
            CupertinoListTile(
              leading: const Icon(CupertinoIcons.chat_bubble),
              title: Text(context.l10n.canComment),
              trailing: CupertinoSwitch(
                value: _canComment,
                onChanged: (value) {
                  setState(() {
                    _canComment = value;
                  });
                  _generateLink();
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Validity info
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Icon(
                CupertinoIcons.clock,
                size: 14,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
              const SizedBox(width: 4),
              Text(
                context.l10n.linkValidFor(7),
                style: TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Action buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              // WhatsApp button (primary if customer has phone)
              if (widget.order.customer?.phone != null &&
                  widget.order.customer!.phone!.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton.filled(
                    onPressed: _sendViaWhatsApp,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(CupertinoIcons.chat_bubble_fill, size: 18),
                        const SizedBox(width: 8),
                        Text(context.l10n.sendViaWhatsApp),
                      ],
                    ),
                  ),
                ),

              if (widget.order.customer?.phone != null &&
                  widget.order.customer!.phone!.isNotEmpty)
                const SizedBox(height: 8),

              // Share button
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: CupertinoColors.systemGrey5.resolveFrom(context),
                  onPressed: _shareLink,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.share,
                        size: 18,
                        color: CupertinoColors.label.resolveFrom(context),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        context.l10n.shareLink,
                        style: TextStyle(
                          color: CupertinoColors.label.resolveFrom(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Copy link button
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  onPressed: _copyLink,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(CupertinoIcons.doc_on_doc, size: 18),
                      const SizedBox(width: 8),
                      Text(context.l10n.copyLink),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
