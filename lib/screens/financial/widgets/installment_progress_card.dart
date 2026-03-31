import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/models/financial_entry.dart';
import 'package:praticos/services/format_service.dart';

/// Expandable card showing installment group progress.
///
/// Collapsed state shows a title, installment count, progress badge,
/// and a linear progress bar. Expanded state lists all installments
/// with status icons and a "PAGAR" button on the next pending one.
class InstallmentProgressCard extends StatefulWidget {
  final List<FinancialEntry> installments;
  final VoidCallback? onPayNext;

  const InstallmentProgressCard({
    super.key,
    required this.installments,
    this.onPayNext,
  });

  @override
  State<InstallmentProgressCard> createState() =>
      _InstallmentProgressCardState();
}

class _InstallmentProgressCardState extends State<InstallmentProgressCard> {
  bool _expanded = false;

  int get _totalCount => widget.installments.length;

  int get _paidCount => widget.installments
      .where((e) => e.status == FinancialEntryStatus.paid)
      .length;

  double get _progress =>
      _totalCount > 0 ? _paidCount / _totalCount : 0;

  String get _title {
    final first = widget.installments.firstOrNull;
    if (first == null || first.description == null) return '';
    // Remove installment suffix like "1/6", "2/6" etc
    return first.description!
        .replaceAll(RegExp(r'\s*\d+/\d+$'), '')
        .trim();
  }

  double get _installmentAmount {
    final first = widget.installments.firstOrNull;
    return first?.amount ?? 0;
  }

  FinancialEntry? get _nextPending {
    for (final entry in widget.installments) {
      if (entry.status == FinancialEntryStatus.pending) {
        return entry;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final secondaryLabelColor =
        CupertinoColors.secondaryLabel.resolveFrom(context);
    final bgColor =
        CupertinoColors.systemBackground.resolveFrom(context);
    final separatorColor = CupertinoColors.separator.resolveFrom(context);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: separatorColor, width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Collapsed header (always visible)
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Title
                      Expanded(
                        child: Text(
                          _title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: labelColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // "Nx R$X"
                      Text(
                        '${_totalCount}x ${FormatService().formatCurrency(_installmentAmount)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: secondaryLabelColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Badge "[Y/N pagas]"
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemGreen.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          context.l10n.parcelsOf(
                            _paidCount.toString(),
                            _totalCount.toString(),
                          ),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: CupertinoColors.systemGreen,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        _expanded
                            ? CupertinoIcons.chevron_up
                            : CupertinoIcons.chevron_down,
                        size: 14,
                        color: secondaryLabelColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: SizedBox(
                      height: 6,
                      child: LinearProgressIndicator(
                        value: _progress,
                        backgroundColor:
                            CupertinoColors.systemGrey5.resolveFrom(context),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          CupertinoColors.systemGreen,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expanded list
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildInstallmentList(
              context,
              labelColor,
              secondaryLabelColor,
              separatorColor,
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _buildInstallmentList(
    BuildContext context,
    Color labelColor,
    Color secondaryLabelColor,
    Color separatorColor,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(height: 0.5, color: separatorColor),
        ...widget.installments.map((entry) {
          final isPaid = entry.status == FinancialEntryStatus.paid;
          final isOverdue = entry.isOverdue;
          final isNextPending =
              entry.id == _nextPending?.id;

          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 8,
            ),
            child: Row(
              children: [
                // Status icon
                _buildStatusIcon(isPaid, isOverdue),
                const SizedBox(width: 10),

                // Installment number + due date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${context.l10n.installment} ${entry.installmentNumber ?? 0}/${entry.installmentTotal ?? 0}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: labelColor,
                        ),
                      ),
                      if (entry.dueDate != null)
                        Text(
                          FormatService().formatDate(entry.dueDate),
                          style: TextStyle(
                            fontSize: 12,
                            color: isOverdue
                                ? CupertinoColors.systemRed
                                : secondaryLabelColor,
                          ),
                        ),
                    ],
                  ),
                ),

                // Amount
                Text(
                  FormatService().formatCurrency(entry.amount ?? 0),
                  style: TextStyle(
                    fontSize: 14,
                    color: isPaid ? CupertinoColors.systemGreen : labelColor,
                  ),
                ),

                // Pay button for next pending
                if (isNextPending && widget.onPayNext != null) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: widget.onPayNext,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGreen,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        context.l10n.payNow.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: CupertinoColors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _buildStatusIcon(bool isPaid, bool isOverdue) {
    if (isPaid) {
      return const Icon(
        CupertinoIcons.checkmark_circle_fill,
        size: 18,
        color: CupertinoColors.systemGreen,
      );
    }
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isOverdue
            ? CupertinoColors.systemRed
            : CupertinoColors.systemGrey,
      ),
    );
  }
}

/// A simple linear progress indicator compatible with Cupertino context.
/// (Flutter's LinearProgressIndicator comes from Material, so we wrap it.)
class LinearProgressIndicator extends StatelessWidget {
  final double value;
  final Color? backgroundColor;
  final Animation<Color?>? valueColor;

  const LinearProgressIndicator({
    super.key,
    required this.value,
    this.backgroundColor,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor =
        backgroundColor ?? CupertinoColors.systemGrey5.resolveFrom(context);
    final fgColor = valueColor is AlwaysStoppedAnimation<Color>
        ? (valueColor as AlwaysStoppedAnimation<Color>).value
        : CupertinoColors.activeBlue;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Stack(
          children: [
            Container(
              width: width,
              height: 6,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Container(
              width: width * value.clamp(0.0, 1.0),
              height: 6,
              decoration: BoxDecoration(
                color: fgColor,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        );
      },
    );
  }
}
