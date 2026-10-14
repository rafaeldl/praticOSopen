import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/share_token.dart';
import 'package:praticos/screens/widgets/glass_bar_button.dart';
import 'package:praticos/screens/widgets/picker_screen.dart';
import 'package:praticos/screens/widgets/primary_button.dart';
import 'package:praticos/screens/widgets/pull_down_menu.dart';
import 'package:praticos/screens/widgets/text_link.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/services/share_link_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';

/// "Mandar para o cliente": the order link, with one blue button to send it
/// (WhatsApp when the customer has a phone). Validity, what the customer can
/// do, a new link and turning it off live in the "…" menu.
class ShareLinkSheet extends StatefulWidget {
  final Order order;
  final String? companyName;
  final String? statusContext;

  /// Network and share calls; tests pass a fake.
  final ShareLinkService? service;

  const ShareLinkSheet({
    super.key,
    required this.order,
    this.companyName,
    this.statusContext,
    this.service,
  });

  @override
  State<ShareLinkSheet> createState() => _ShareLinkSheetState();

  /// Shows the sheet at the bottom of the screen.
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

/// What the customer can do through the link.
enum _Access { all, approve, comment, view }

class _ShareLinkSheetState extends State<ShareLinkSheet> {
  late final ShareLinkService _service =
      widget.service ?? ShareLinkService.instance;

  bool _isLoading = true;
  bool _canApprove = true;
  bool _canComment = true;
  bool _failed = false;
  bool _copied = false;
  ShareLinkResult? _result;
  int _expiresInDays = 7;
  Timer? _copiedTimer;

  static const _validityOptions = [7, 14, 30];

  @override
  void initState() {
    super.initState();
    _loadOrGenerateLink();
  }

  @override
  void dispose() {
    _copiedTimer?.cancel();
    super.dispose();
  }

  void _useExisting({
    required String? token,
    required String? url,
    required List<String>? permissions,
    required DateTime? expiresAt,
  }) {
    setState(() {
      _result = ShareLinkResult()
        ..token = token
        ..url = url
        ..permissions = permissions
        ..expiresAt = expiresAt
        ..customer = widget.order.customer;
      _canApprove = permissions?.contains('approve') ?? false;
      _canComment = permissions?.contains('comment') ?? false;
      _isLoading = false;
    });
  }

  Future<void> _loadOrGenerateLink() async {
    setState(() {
      _isLoading = true;
      _failed = false;
    });

    // The order already has a valid link: reuse it.
    final existing = widget.order.shareLink;
    if (existing != null && !existing.isExpired && existing.token != null) {
      _useExisting(
        token: existing.token,
        url: existing.url,
        permissions: existing.permissions,
        expiresAt: existing.expiresAt,
      );
      return;
    }

    try {
      final tokens = await _service.getShareTokens(widget.order.id!);
      final active = tokens.where((t) => !t.isExpired).toList();
      if (!mounted) return;
      if (active.isNotEmpty) {
        final token = active.first;
        _useExisting(
          token: token.token,
          url: 'https://praticos.web.app/q/${token.token}',
          permissions: token.permissions,
          expiresAt: token.expiresAt,
        );
        return;
      }
    } catch (_) {
      // Falls through to a new link.
    }
    await _generateLink();
  }

  Future<void> _generateLink() async {
    setState(() {
      _isLoading = true;
      _failed = false;
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
      if (!mounted) return;
      setState(() {
        _result = result;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _isLoading = false;
      });
    }
  }

  String _message() => _service.buildShareMessage(
    customerName: widget.order.customer?.name ?? '',
    orderNumber: widget.order.number ?? 0,
    companyName: widget.companyName,
    locale: context.l10n.localeName,
    statusContext: widget.statusContext,
  );

  String? get _phone {
    final phone = widget.order.customer?.phone;
    return phone == null || phone.isEmpty ? null : phone;
  }

  Future<void> _sendViaWhatsApp() async {
    final url = _result?.url;
    final phone = _phone;
    if (url == null || phone == null) return;
    try {
      await _service.shareViaWhatsApp(
        url: url,
        phone: phone,
        message: _message(),
      );
    } catch (_) {
      // WhatsApp missing: offer the system share sheet instead.
      if (mounted) await _shareLink();
    }
  }

  Future<void> _shareLink() async {
    final url = _result?.url;
    if (url == null) return;
    final box = context.findRenderObject() as RenderBox?;
    await _service.shareViaSheet(
      url: url,
      message: _message(),
      subject: '${context.l10n.orderShort} ${widget.order.number ?? ''}',
      sharePositionOrigin: box == null
          ? null
          : box.localToGlobal(Offset.zero) & box.size,
    );
  }

  Future<void> _copyLink() async {
    final url = _result?.url;
    if (url == null) return;
    await _service.copyToClipboard(url);
    if (!mounted) return;
    setState(() => _copied = true);
    _copiedTimer?.cancel();
    _copiedTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  _Access get _access {
    if (_canApprove && _canComment) return _Access.all;
    if (_canApprove) return _Access.approve;
    if (_canComment) return _Access.comment;
    return _Access.view;
  }

  String _accessLabel(_Access access) {
    final l10n = context.l10n;
    switch (access) {
      case _Access.all:
        return l10n.sharePermAll;
      case _Access.approve:
        return l10n.sharePermApprove;
      case _Access.comment:
        return l10n.sharePermComment;
      case _Access.view:
        return l10n.sharePermView;
    }
  }

  Future<void> _openMenu() async {
    final l10n = context.l10n;
    final picked = await showPullDownMenu(
      context,
      groups: [
        PullDownGroup([
          PullDownItem(
            value: 'validity',
            label: l10n.shareValidity,
            icon: CupertinoIcons.clock,
            submenu: true,
          ),
          PullDownItem(
            value: 'access',
            label: l10n.shareWhatCanDo,
            icon: CupertinoIcons.person_crop_circle_badge_checkmark,
            submenu: true,
          ),
        ]),
        PullDownGroup([
          PullDownItem(
            value: 'new',
            label: l10n.shareNewLink,
            icon: CupertinoIcons.arrow_2_circlepath,
          ),
        ]),
        PullDownGroup([
          if (_result?.token != null)
            PullDownItem(
              value: 'revoke',
              label: l10n.shareRevoke,
              icon: CupertinoIcons.nosign,
              destructive: true,
            ),
        ]),
      ],
    );
    if (!mounted || picked == null) return;
    switch (picked) {
      case 'validity':
        await _pickValidity();
      case 'access':
        await _pickAccess();
      case 'new':
        await _generateLink();
      case 'revoke':
        await _confirmRevoke();
    }
  }

  Future<void> _pickValidity() async {
    final days = await pickOne<int>(
      context,
      title: context.l10n.shareValidityTitle,
      selected: _validityOptions.contains(_expiresInDays)
          ? _expiresInDays
          : null,
      options: [
        for (final d in _validityOptions)
          PickerItem(value: d, title: context.l10n.shareValidityDays(d)),
      ],
    );
    if (days == null || !mounted) return;
    _expiresInDays = days;
    await _generateLink();
  }

  Future<void> _pickAccess() async {
    final access = await pickOne<_Access>(
      context,
      title: context.l10n.sharePermissionsTitle,
      selected: _access,
      options: [
        for (final a in _Access.values)
          PickerItem(value: a, title: _accessLabel(a)),
      ],
    );
    if (access == null || !mounted || access == _access) return;
    _canApprove = access == _Access.all || access == _Access.approve;
    _canComment = access == _Access.all || access == _Access.comment;
    await _generateLink();
  }

  Future<void> _confirmRevoke() async {
    final l10n = context.l10n;
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(l10n.shareRevoke),
        content: Text(l10n.shareRevokeConfirm(l10n.orderShort)),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.shareRevoke),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _isLoading = true);
    try {
      await _service.revokeShareToken(widget.order.id!, _result!.token!);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ready = !_isLoading && !_failed && _result != null;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.resolveFrom(context),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadii.button),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
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
                      l10n.shareTitle,
                      style: AppTypography.highlight.copyWith(
                        color: AppColors.text.resolveFrom(context),
                      ),
                    ),
                  ),
                  if (ready)
                    GlassBarButton(
                      key: const Key('shareLinkMenu'),
                      label: l10n.shareMenu,
                      icon: CupertinoIcons.ellipsis,
                      onPressed: _openMenu,
                    ),
                  const SizedBox(width: AppSpacing.sm),
                  GlassBarButton(
                    key: const Key('shareLinkClose'),
                    label: l10n.close,
                    icon: CupertinoIcons.xmark,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: _body(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final l10n = context.l10n;
    final secondary = AppColors.textSecondary.resolveFrom(context);
    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
        child: Column(
          children: [
            const CupertinoActivityIndicator(),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.sharePreparing,
              style: AppTypography.callout.copyWith(color: secondary),
            ),
          ],
        ),
      );
    }
    if (_failed || _result == null) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.shareError,
              style: AppTypography.body.copyWith(
                color: AppColors.danger.resolveFrom(context),
              ),
            ),
            TextLink(label: l10n.tryAgain, onPressed: _loadOrGenerateLink),
          ],
        ),
      );
    }

    final name = widget.order.customer?.name;
    final who = name == null || name.trim().isEmpty
        ? l10n.shareTheCustomer
        : name;
    final order = l10n.orderShort;
    final sentence = switch (_access) {
      _Access.all => l10n.shareCanAll(who, order),
      _Access.approve => l10n.shareCanApprove(who, order),
      _Access.comment => l10n.shareCanComment(who, order),
      _Access.view => l10n.shareCanView(who, order),
    };
    final expires = _result!.expiresAt;
    final hasPhone = _phone != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.sm),
        Text(
          expires == null
              ? sentence
              : '$sentence ${l10n.shareValidUntil(FormatService().formatDayMonthOrDate(expires))}',
          key: const Key('shareLinkSentence'),
          style: AppTypography.callout.copyWith(color: secondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          key: const Key('shareLinkPrimary'),
          label: hasPhone ? l10n.shareSendWhatsApp : l10n.shareSendLink,
          icon: hasPhone
              ? CupertinoIcons.chat_bubble_fill
              : CupertinoIcons.share,
          onPressed: hasPhone ? _sendViaWhatsApp : _shareLink,
        ),
        if (hasPhone) ...[
          const SizedBox(height: AppSpacing.sm),
          _SecondaryButton(
            key: const Key('shareLinkOtherWay'),
            label: l10n.shareSendOtherWay,
            onPressed: _shareLink,
          ),
        ],
        const SizedBox(height: AppSpacing.xs),
        Center(
          child: TextLink(
            key: const Key('shareLinkCopy'),
            label: _copied ? l10n.shareLinkCopied : l10n.shareCopyLink,
            onPressed: _copyLink,
          ),
        ),
      ],
    );
  }
}

/// Grey filled button for the second way to send (design system: other
/// actions use `secondaryFill`).
class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({super.key, required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
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
      onPressed: onPressed,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: AppTypography.bodyStrong.copyWith(
          color: AppColors.accentText.resolveFrom(context),
        ),
      ),
    );
  }
}
