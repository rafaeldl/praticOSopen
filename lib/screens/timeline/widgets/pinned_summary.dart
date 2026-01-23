import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/services/segment_config_service.dart';

/// A pinned summary widget that shows order status at the top of the timeline.
class PinnedSummary extends StatelessWidget {
  final Order order;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final int formsCount;
  final int pendingFormsCount;

  const PinnedSummary({
    super.key,
    required this.order,
    required this.onTap,
    required this.onLongPress,
    this.formsCount = 0,
    this.pendingFormsCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final total = order.total ?? 0;
    final isPaid = order.isFullyPaid;

    return GestureDetector(
      onTap: onTap,
      onLongPress: () => _showCopyMenu(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey6.resolveFrom(context),
          border: Border(
            bottom: BorderSide(
              color: CupertinoColors.separator.resolveFrom(context),
              width: 0.5,
            ),
          ),
        ),
        child: DefaultTextStyle(
          style: TextStyle(
            decoration: TextDecoration.none,
            fontSize: 13,
            color: CupertinoColors.label.resolveFrom(context),
          ),
          child: Row(
            children: [
              // Pin icon
              Icon(
                CupertinoIcons.pin_fill,
                size: 14,
                color: CupertinoColors.systemGrey.resolveFrom(context),
              ),
              const SizedBox(width: 8),
              // Content (value/date now in lines)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildLine1(context, total: total, isPaid: isPaid),
                    const SizedBox(height: 2),
                    _buildLine2(context),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              // Chevron
              Icon(
                CupertinoIcons.chevron_right,
                size: 14,
                color: CupertinoColors.tertiaryLabel.resolveFrom(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLine1(BuildContext context, {required double total, required bool isPaid}) {
    final l10n = context.l10n;
    final config = SegmentConfigService();
    final statusText = config.getStatus(order.status);
    final secondaryColor = CupertinoColors.secondaryLabel.resolveFrom(context);

    return Row(
      children: [
        // Conteúdo esquerdo (expandido)
        Expanded(
          child: Row(
            children: [
              // OS number - secondary (não destaque)
              Text(
                '${l10n.orderShort} #${order.number ?? ''}',
                style: TextStyle(
                  fontSize: 13,
                  color: secondaryColor,
                  decoration: TextDecoration.none,
                ),
              ),
              Text(
                ' · ',
                style: TextStyle(
                  fontSize: 13,
                  color: secondaryColor,
                  decoration: TextDecoration.none,
                ),
              ),
              // Status - único elemento colorido
              Flexible(
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _getStatusColor(context, order.status),
                    decoration: TextDecoration.none,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (isPaid)
          Text(
            '${l10n.paid} · ',
            style: TextStyle(
              fontSize: 13,
              color: secondaryColor,
              decoration: TextDecoration.none,
            ),
          ),
        Text(
          FormatService().formatCurrency(total, decimalDigits: 0),
          style: TextStyle(
            fontSize: 13,
            color: secondaryColor,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }

  Widget _buildLine2(BuildContext context) {
    final summaryText = _getSummaryText(context);
    final dateText = _getDeliveryDateText(context);
    final secondaryColor = CupertinoColors.secondaryLabel.resolveFrom(context);
    final isOverdue = _isOverdue();

    return Row(
      children: [
        Expanded(
          child: Text(
            summaryText,
            style: TextStyle(
              fontSize: 12,
              color: secondaryColor,
              decoration: TextDecoration.none,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        if (isOverdue) ...[
          Icon(
            CupertinoIcons.clock,
            size: 12,
            color: CupertinoColors.systemRed.resolveFrom(context),
          ),
          const SizedBox(width: 4),
        ],
        Text(
          dateText,
          style: TextStyle(
            fontSize: 12,
            color: secondaryColor,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }

  bool _isOverdue() {
    if (order.dueDate == null) return false;
    if (order.status == 'done' || order.status == 'canceled') return false;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(
      order.dueDate!.year,
      order.dueDate!.month,
      order.dueDate!.day,
    );

    return dueDay.isBefore(today);
  }

  String _getDeliveryDateText(BuildContext context) {
    if (order.dueDate == null) {
      return context.l10n.dueDateNotDefined;
    }

    final dueDate = order.dueDate!;
    return '${dueDate.day.toString().padLeft(2, '0')}/${dueDate.month.toString().padLeft(2, '0')}';
  }

  String _getSummaryText(BuildContext context) {
    final l10n = context.l10n;
    final servicesCount = order.services?.length ?? 0;
    final productsCount = order.products?.length ?? 0;
    final checklistsCount = formsCount;
    final pendingCount = pendingFormsCount;

    final parts = <String>[];

    if (servicesCount > 0) {
      parts.add('${l10n.services} $servicesCount');
    }

    if (productsCount > 0) {
      parts.add('${l10n.products} $productsCount');
    }

    if (checklistsCount > 0) {
      if (pendingCount > 0) {
        parts.add('${l10n.checklists} $checklistsCount (⚠️$pendingCount)');
      } else {
        parts.add('${l10n.checklists} $checklistsCount');
      }
    }

    if (parts.isEmpty) {
      return l10n.noItemsYet;
    }

    return parts.join(' · ');
  }

  Color _getStatusColor(BuildContext context, String? status) {
    switch (status) {
      case 'quote':
        return CupertinoColors.systemOrange;
      case 'approved':
        return CupertinoColors.activeBlue;
      case 'progress':
        return CupertinoColors.systemPurple;
      case 'done':
        return CupertinoColors.systemGreen;
      case 'canceled':
        return CupertinoColors.systemRed;
      default:
        return CupertinoColors.secondaryLabel.resolveFrom(context);
    }
  }

  void _showCopyMenu(BuildContext context) {
    final l10n = context.l10n;

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            child: Text(l10n.copySummary),
            onPressed: () {
              Navigator.pop(ctx);
              _copySummary(context);
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: Text(l10n.cancel),
          onPressed: () => Navigator.pop(ctx),
        ),
      ),
    );
  }

  void _copySummary(BuildContext context) {
    final l10n = context.l10n;
    final config = SegmentConfigService();
    final statusText = config.getStatus(order.status);
    final dateText = _getDeliveryDateText(context);
    final summaryText = _getSummaryText(context);
    final total = order.total ?? 0;
    final totalText = FormatService().formatCurrency(total);

    final fullSummary =
        '${l10n.orderShort} #${order.number ?? ''} · $statusText · $dateText · $totalText\n$summaryText';

    Clipboard.setData(ClipboardData(text: fullSummary));
  }
}
