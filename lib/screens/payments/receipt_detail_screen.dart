import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/receipt.dart';
import 'package:praticos/screens/payments/receipt_share.dart';
import 'package:praticos/screens/payments/widgets/receipt_image_viewer.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/services/authorization_service.dart';
import 'package:praticos/screens/widgets/app_toast.dart';
import 'package:praticos/screens/widgets/glass_bar_button.dart';
import 'package:praticos/screens/widgets/list_states.dart';
import 'package:praticos/screens/widgets/primary_button.dart';
import 'package:praticos/screens/widgets/pull_down_menu.dart';
import 'package:praticos/services/customer_receipt_service.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/services/pdf/receipt_pdf.dart';
import 'package:praticos/services/photo_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';
import 'package:praticos/utils/order_payment_math.dart';
import 'package:praticos/widgets/permission_widgets.dart';
import 'package:url_launcher/url_launcher.dart';

/// "Recebimento": one payment from a customer that covered one or more
/// orders ([Receipt]). Large title is the amount, then "João · 14/10/2026",
/// one row per order ("OS 185 · R$ 400 · quitada"), the receipt file when
/// there is one, and the one blue action "Mandar recibo para João" (the
/// recibo PDF). "Desfazer recebimento" lives in the "…" menu.
///
/// Pops with `true` after an undo.
class ReceiptDetailScreen extends StatefulWidget {
  const ReceiptDetailScreen({
    super.key,
    required this.receiptId,
    this.service,
    this.onSend,
    this.onOpenOrder,
    this.onViewFile,
    this.canManage,
  });

  final String receiptId;

  /// Injected in tests.
  final CustomerReceiptService? service;

  /// Test seams; default to the recibo share sheet, the order screen and
  /// the receipt file viewer.
  final Future<void> Function(BuildContext context, ReceiptPdfData data)?
  onSend;
  final void Function(BuildContext context, Order order)? onOpenOrder;
  final Future<void> Function(BuildContext context, ReceiptFile file)?
  onViewFile;

  /// Whether the person can undo the receipt and send its recibo. Defaults
  /// to [AuthorizationService.canManageReceipt] (financial access, or the
  /// consultant who registered it). Test seam.
  final bool Function(Receipt receipt)? canManage;

  /// Pushes the screen. Who receives payments opens it
  /// ([AuthorizationService.canReceivePayments]: financial access, or a
  /// consultant, who only reads the receipts they registered); [canView]
  /// overrides it (tests). Completes with true when the receipt was undone.
  static Future<bool> open(
    BuildContext context, {
    required String receiptId,
    bool? canView,
  }) async {
    final undone = await Navigator.of(context, rootNavigator: true).push<bool>(
      CupertinoPageRoute<bool>(
        settings: const RouteSettings(name: '/receipt_detail'),
        builder: (context) {
          final screen = ReceiptDetailScreen(receiptId: receiptId);
          if (canView != null) {
            return canView
                ? screen
                : AccessDeniedScreen(onBack: () => Navigator.of(context).pop());
          }
          return AuthorizationService.instance.canReceivePayments
              ? screen
              : AccessDeniedScreen(onBack: () => Navigator.of(context).pop());
        },
      ),
    );
    return undone ?? false;
  }

  @override
  State<ReceiptDetailScreen> createState() => _ReceiptDetailScreenState();
}

class _ReceiptDetailScreenState extends State<ReceiptDetailScreen> {
  late final CustomerReceiptService _service =
      widget.service ?? CustomerReceiptService();
  late Future<ReceiptDetails?> _future = _service.load(widget.receiptId);
  bool _busy = false;

  bool _canManage(Receipt receipt) =>
      widget.canManage?.call(receipt) ??
      AuthorizationService.instance.canManageReceipt(receipt);

  void _reload() {
    setState(() => _future = _service.load(widget.receiptId));
  }

  String _firstName(String? name) =>
      (name ?? '').trim().split(RegExp(r'\s+')).first;

  Future<void> _send(ReceiptDetails details) async {
    final data = ReceiptPdfData.fromReceipt(details.receipt, details.orders);
    await (widget.onSend ?? shareReceiptPdf)(context, data);
  }

  void _openOrder(Order order) {
    final open = widget.onOpenOrder;
    if (open != null) {
      open(context, order);
      return;
    }
    Navigator.pushNamed(context, '/order', arguments: {'order': order});
  }

  Future<void> _viewFile(ReceiptFile file) async {
    final view = widget.onViewFile;
    if (view != null) {
      await view(context, file);
      return;
    }
    var url = file.url;
    if (file.storagePath != null) {
      url = await PhotoService().getFreshDownloadUrl(file.storagePath!) ?? url;
    }
    if (url == null || !mounted) return;
    if ((file.contentType ?? '').startsWith('image/')) {
      Navigator.of(context).push(
        CupertinoPageRoute<void>(
          builder: (context) => ReceiptImageViewer(
            url: url!,
            title: file.fileName ?? context.l10n.receipt,
          ),
        ),
      );
    } else {
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _showMenu(Receipt receipt) async {
    final l10n = context.l10n;
    final choice = await showPullDownMenu(
      context,
      groups: [
        PullDownGroup([
          PullDownItem(
            value: 'undo',
            label: l10n.receiptUndo,
            icon: CupertinoIcons.arrow_uturn_left,
            destructive: true,
          ),
        ]),
      ],
    );
    if (choice == 'undo' && mounted) _confirmUndo(receipt);
  }

  void _confirmUndo(Receipt receipt) {
    final l10n = context.l10n;
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(
          l10n.receiptUndoTitle(
            FormatService().formatCurrency(receipt.amount ?? 0),
          ),
        ),
        content: Text(
          l10n.receiptUndoMessage(receipt.allocations?.length ?? 0),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          CupertinoDialogAction(
            key: const Key('receiptUndoConfirm'),
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(dialogContext);
              _undo(receipt);
            },
            child: Text(l10n.receiptUndo),
          ),
        ],
      ),
    );
  }

  Future<void> _undo(Receipt receipt) async {
    if (_busy) return;
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      await _service.undo(receipt);
    } on CustomerReceiptException {
      if (!mounted) return;
      setState(() => _busy = false);
      showAppToast(
        context,
        l10n.paymentUpdateFailed,
        icon: CupertinoIcons.exclamationmark_circle,
      );
      return;
    }
    if (!mounted) return;
    showAppToast(
      context,
      l10n.receiptUndone,
      icon: CupertinoIcons.arrow_uturn_left,
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background.resolveFrom(context),
      child: FutureBuilder<ReceiptDetails?>(
        future: _future,
        builder: (context, snapshot) {
          final details = snapshot.data;
          final receipt = details?.receipt;
          final active =
              receipt?.status == ReceiptStatus.active && _canManage(receipt!);
          return CustomScrollView(
            slivers: [
              AppNavBar(
                largeTitle: Text(
                  receipt == null
                      ? context.l10n.receiptTitle
                      : FormatService().formatCurrency(receipt.amount ?? 0),
                  key: const Key('receiptAmount'),
                ),
                trailing: active && !_busy
                    ? GlassBarButton(
                        key: const Key('receiptMenu'),
                        label: context.l10n.receiptActions,
                        icon: CupertinoIcons.ellipsis,
                        onPressed: () => _showMenu(receipt),
                      )
                    : null,
              ),
              ..._body(snapshot),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _body(AsyncSnapshot<ReceiptDetails?> snapshot) {
    final l10n = context.l10n;
    if (snapshot.hasError) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ErrorState(onRetry: _reload),
        ),
      ];
    }
    if (snapshot.connectionState != ConnectionState.done) {
      return const [
        SliverFillRemaining(hasScrollBody: false, child: LoadingState()),
      ];
    }
    final details = snapshot.data;
    if (details == null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: CupertinoIcons.doc_text,
            title: l10n.receiptNotFound,
          ),
        ),
      ];
    }

    final receipt = details.receipt;
    final format = FormatService();
    final secondary = AppColors.textSecondary.resolveFrom(context);
    final active = receipt.status == ReceiptStatus.active;
    final name = (receipt.customer?.name ?? '').trim().isEmpty
        ? l10n.customerWithoutName
        : receipt.customer!.name!.trim();
    final paidAt = receipt.paidAt ?? receipt.createdAt;
    final file = receipt.receiptFile;

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageMargin,
            0,
            AppSpacing.pageMargin,
            AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                [
                  name,
                  if (paidAt != null) format.formatDate(paidAt),
                ].join(' · '),
                key: const Key('receiptSubtitle'),
                style: AppTypography.callout.copyWith(color: secondary),
              ),
              if (!active)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    l10n.receiptCanceled,
                    key: const Key('receiptCanceled'),
                    style: AppTypography.callout.copyWith(
                      color: secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      SliverList(
        delegate: SliverChildListDelegate([
          for (final allocation
              in receipt.allocations ?? const <ReceiptAllocation>[])
            _orderRow(allocation, details.orders[allocation.orderId], format),
          if (file != null)
            AppListRow(
              key: const Key('receiptFile'),
              leading: Icon(
                CupertinoIcons.paperclip,
                color: AppColors.accentText.resolveFrom(context),
              ),
              title: l10n.receiveViewReceipt,
              subtitle: file.fileName,
              onTap: () => _viewFile(file),
            ),
          if (active && _canManage(receipt))
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.blockMargin,
                AppSpacing.lg,
                AppSpacing.blockMargin,
                0,
              ),
              child: _busy
                  ? const SizedBox(
                      height: AppSizes.primaryButtonHeight,
                      child: Center(child: CupertinoActivityIndicator()),
                    )
                  : PrimaryButton(
                      key: const Key('receiptSend'),
                      icon: CupertinoIcons.square_arrow_up,
                      label: l10n.receiptSendTo(_firstName(name)),
                      onPressed: () => _send(details),
                    ),
            ),
        ]),
      ),
    ];
  }

  Widget _orderRow(
    ReceiptAllocation allocation,
    Order? order,
    FormatService format,
  ) {
    final l10n = context.l10n;
    final number = allocation.orderNumber ?? order?.number ?? 0;
    final amount = format.formatCurrency(allocation.amount ?? 0);
    final String title;
    if (order == null) {
      title = '${l10n.receiveCustomerPickRow(number)} · $amount';
    } else {
      final left = OrderPaymentMath.remainingBalance(order);
      title = left > 0
          ? l10n.receiptRowOpen(number, amount, format.formatCurrency(left))
          : l10n.receiptRowSettled(number, amount);
    }
    return AppListRow(
      key: Key('receiptOrder_${allocation.orderId}'),
      title: title,
      onTap: order == null ? null : () => _openOrder(order),
    );
  }
}
