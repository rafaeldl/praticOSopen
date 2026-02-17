import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Material, MaterialType;
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/share_token.dart';
import 'package:praticos/services/share_link_service.dart';

/// Sheet for sharing an order link with a customer
class ShareLinkSheet extends StatefulWidget {
  final Order order;
  final String? companyName;
  final String? statusContext;

  const ShareLinkSheet({
    super.key,
    required this.order,
    this.companyName,
    this.statusContext,
  });

  @override
  State<ShareLinkSheet> createState() => _ShareLinkSheetState();

  /// Show the share link sheet as a modal popup
  static Future<void> show(
    BuildContext context,
    Order order, {
    String? companyName,
    String? statusContext,
  }) {
    return showCupertinoModalPopup(
      context: context,
      builder: (context) => ShareLinkSheet(
        order: order,
        companyName: companyName,
        statusContext: statusContext,
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
  int _expiresInDays = 7;
  bool _isReusing = false;
  bool _showAdvancedOptions = false;

  @override
  void initState() {
    super.initState();
    _loadOrGenerateLink();
  }

  Future<void> _loadOrGenerateLink() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // First check if order already has a valid share link
    final existingLink = widget.order.shareLink;
    if (existingLink != null && !existingLink.isExpired && existingLink.token != null) {
      setState(() {
        _result = ShareLinkResult()
          ..token = existingLink.token
          ..permissions = existingLink.permissions
          ..expiresAt = existingLink.expiresAt
          ..customer = widget.order.customer;
        _result!.url = existingLink.url;
        _isReusing = true;
        _canApprove = existingLink.permissions?.contains('approve') ?? false;
        _canComment = existingLink.permissions?.contains('comment') ?? false;
        _isLoading = false;
      });
      return;
    }

    // If no local link, fetch from API or generate new
    try {
      final tokens = await _service.getShareTokens(widget.order.id!);
      final activeTokens = tokens.where((t) => !t.isExpired).toList();

      if (activeTokens.isNotEmpty) {
        final token = activeTokens.first;
        setState(() {
          _result = ShareLinkResult()
            ..token = token.token
            ..permissions = token.permissions
            ..expiresAt = token.expiresAt
            ..customer = token.customer;
          _result!.url = 'https://praticos.web.app/q/${token.token}';
          _isReusing = true;
          _canApprove = token.permissions?.contains('approve') ?? false;
          _canComment = token.permissions?.contains('comment') ?? false;
          _isLoading = false;
        });
      } else {
        await _generateLink();
      }
    } catch (e) {
      await _generateLink();
    }
  }

  void _showValidityPicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(context.l10n.selectValidity),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              if (_expiresInDays != 7) {
                setState(() => _expiresInDays = 7);
                _generateLink();
              }
            },
            child: Text('7 ${context.l10n.days}'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              if (_expiresInDays != 14) {
                setState(() => _expiresInDays = 14);
                _generateLink();
              }
            },
            child: Text('14 ${context.l10n.days}'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              if (_expiresInDays != 30) {
                setState(() => _expiresInDays = 30);
                _generateLink();
              }
            },
            child: Text('30 ${context.l10n.days}'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
      ),
    );
  }

  Future<void> _generateLink() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isReusing = false;
    });

    try {
      final permissions = <String>['view'];
      if (_canApprove) permissions.add('approve');
      if (_canComment) permissions.add('comment');

      final result = await _service.generateShareLink(
        orderId: widget.order.id!,
        permissions: permissions,
        expiresInDays: _expiresInDays,
      );

      setState(() {
        _result = result;
        _isLoading = false;
      });
      // Share link is saved to order by the API
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
    _showCupertinoToast(context.l10n.linkCopied);
  }

  void _shareLink() {
    if (_result?.url == null) return;

    final message = _service.buildShareMessage(
      customerName: widget.order.customer?.name ?? '',
      orderNumber: widget.order.number ?? 0,
      companyName: widget.companyName,
      locale: context.l10n.localeName,
      statusContext: widget.statusContext,
    );

    // Get the share position for iPad
    final box = context.findRenderObject() as RenderBox?;
    final sharePositionOrigin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : null;

    _service.shareViaSheet(
      url: _result!.url!,
      message: message,
      subject: '${context.l10n.order} #${widget.order.number}',
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  void _sendViaWhatsApp() {
    if (_result?.url == null) return;

    final phone = widget.order.customer?.phone;
    if (phone == null || phone.isEmpty) {
      _showCupertinoToast(context.l10n.invalidPhone);
      return;
    }

    final message = _service.buildShareMessage(
      customerName: widget.order.customer?.name ?? '',
      orderNumber: widget.order.number ?? 0,
      companyName: widget.companyName,
      locale: context.l10n.localeName,
      statusContext: widget.statusContext,
    );

    _service.shareViaWhatsApp(
      url: _result!.url!,
      phone: phone,
      message: message,
    );
  }

  void _showCupertinoToast(String message) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) {
        Future.delayed(const Duration(seconds: 2), () {
          if (context.mounted) Navigator.of(context).pop();
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

  void _confirmRevokeLink() {
    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(context.l10n.revokeLink),
        content: Text(context.l10n.revokeLinkConfirm),
        actions: [
          CupertinoDialogAction(
            child: Text(context.l10n.cancel),
            onPressed: () => Navigator.pop(dialogContext),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(dialogContext);
              _revokeLink();
            },
            child: Text(context.l10n.revokeLink),
          ),
        ],
      ),
    );
  }

  Future<void> _revokeLink() async {
    if (_result?.token == null) return;

    setState(() => _isLoading = true);

    try {
      await _service.revokeShareToken(widget.order.id!, _result!.token!);
      // Share link is cleared from order by the API

      if (mounted) {
        Navigator.pop(context);
        _showCupertinoToast(context.l10n.linkRevoked);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showCupertinoToast(e.toString());
    }
  }

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

            // Header - simplified
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.sendToCustomer,
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
                      onPressed: _generateLink,
                      child: Text(context.l10n.tryAgain),
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
    ),
    );
  }

  Widget _buildLinkContent() {
    final customer = widget.order.customer;
    final hasPhone = customer?.phone != null && customer!.phone!.isNotEmpty;

    return Column(
      children: [
        // Customer card
        if (customer != null) _buildCustomerCard(customer, hasPhone),

        const SizedBox(height: 20),

        // Primary action button
        if (hasPhone)
          _buildWhatsAppButton()
        else
          _buildShareButton(isPrimary: true),

        // Secondary share button (when WhatsApp is primary)
        if (hasPhone) ...[
          const SizedBox(height: 10),
          _buildSecondaryShareButton(),
        ],

        const SizedBox(height: 16),

        // Validity info with copy link - always visible
        _buildValidityRow(),

        const SizedBox(height: 8),

        // Advanced options toggle
        _buildAdvancedOptionsToggle(),

        // Advanced options content (collapsible)
        if (_showAdvancedOptions) _buildAdvancedOptions(),
      ],
    );
  }

  Widget _buildCustomerCard(dynamic customer, bool hasPhone) {
    final customerName = customer.name as String? ?? context.l10n.customer;
    final customerPhone = hasPhone ? customer.phone as String : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6.resolveFrom(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: CupertinoColors.activeBlue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                customerName.isNotEmpty ? customerName[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.activeBlue,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customerName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (customerPhone != null)
                  Text(
                    customerPhone,
                    style: TextStyle(
                      fontSize: 14,
                      color: CupertinoColors.secondaryLabel.resolveFrom(context),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhatsAppButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: CupertinoButton(
          color: const Color(0xFF25D366), // WhatsApp green
          borderRadius: BorderRadius.circular(12),
          padding: EdgeInsets.zero,
          onPressed: _sendViaWhatsApp,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(CupertinoIcons.chat_bubble_fill, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                context.l10n.sendViaWhatsApp,
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

  Widget _buildShareButton({required bool isPrimary}) {
    if (isPrimary) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: CupertinoButton.filled(
            borderRadius: BorderRadius.circular(12),
            padding: EdgeInsets.zero,
            onPressed: _shareLink,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.share, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  context.l10n.share,
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
    return const SizedBox.shrink();
  }

  Widget _buildSecondaryShareButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        height: 44,
        child: CupertinoButton(
          color: CupertinoColors.systemGrey5.resolveFrom(context),
          borderRadius: BorderRadius.circular(10),
          padding: EdgeInsets.zero,
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
                context.l10n.share,
                style: TextStyle(
                  color: CupertinoColors.label.resolveFrom(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildValidityRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.clock,
            size: 15,
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
          const SizedBox(width: 6),
          Text(
            context.l10n.linkValidFor(_expiresInDays),
            style: TextStyle(
              fontSize: 14,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          const Spacer(),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _copyLink,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CupertinoIcons.doc_on_doc,
                  size: 15,
                  color: CupertinoColors.activeBlue,
                ),
                const SizedBox(width: 4),
                Text(
                  context.l10n.copyLink,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedOptionsToggle() {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      onPressed: () => setState(() => _showAdvancedOptions = !_showAdvancedOptions),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.gear,
            size: 16,
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
          const SizedBox(width: 6),
          Text(
            context.l10n.advancedOptions,
            style: TextStyle(
              fontSize: 13,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          const Spacer(),
          Icon(
            _showAdvancedOptions
                ? CupertinoIcons.chevron_up
                : CupertinoIcons.chevron_down,
            size: 14,
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedOptions() {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Permissions header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              context.l10n.sharePermissions.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
                letterSpacing: 0.5,
              ),
            ),
          ),
          // Permissions list
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey6.resolveFrom(context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                _buildPermissionRow(
                  title: context.l10n.canApprove,
                  value: _canApprove,
                  onChanged: _isReusing
                      ? null
                      : (value) {
                          setState(() => _canApprove = value);
                          _generateLink();
                        },
                ),
                Container(
                  margin: const EdgeInsets.only(left: 16),
                  height: 0.5,
                  color: CupertinoColors.separator.resolveFrom(context),
                ),
                _buildPermissionRow(
                  title: context.l10n.canComment,
                  value: _canComment,
                  onChanged: _isReusing
                      ? null
                      : (value) {
                          setState(() => _canComment = value);
                          _generateLink();
                        },
                ),
              ],
            ),
          ),
          // Validity picker (when not reusing)
          if (!_isReusing)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Text(
                    context.l10n.linkValidity,
                    style: TextStyle(
                      fontSize: 14,
                      color: CupertinoColors.secondaryLabel.resolveFrom(context),
                    ),
                  ),
                  const Spacer(),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _showValidityPicker,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$_expiresInDays ${context.l10n.days}',
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(width: 4),
                        const Icon(CupertinoIcons.chevron_down, size: 14),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          // Reusing existing link indicator
          if (_isReusing) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.checkmark_circle_fill,
                    size: 15,
                    color: CupertinoColors.activeGreen,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    context.l10n.usingExistingLink,
                    style: const TextStyle(
                      fontSize: 14,
                      color: CupertinoColors.activeGreen,
                    ),
                  ),
                  const Spacer(),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      setState(() => _isReusing = false);
                      _generateLink();
                    },
                    child: Text(
                      context.l10n.generateNewLink,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            // Revoke link button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  color: CupertinoColors.systemRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  onPressed: _confirmRevokeLink,
                  child: Text(
                    context.l10n.revokeLink,
                    style: const TextStyle(
                      color: CupertinoColors.systemRed,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildPermissionRow({
    required String title,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16),
          ),
          const Spacer(),
          CupertinoSwitch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
