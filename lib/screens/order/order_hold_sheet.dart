import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/screens/widgets/app_sheet.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/status_style.dart';

/// What the person picked in [showOrderHoldSheet].
typedef OrderHoldChoice = ({String reason, String? note});

/// "Por que parou?": tapping a reason saves right away, so marking an order
/// takes two taps from the order screen. The note is optional, above the
/// reasons so it can be written first. Resolves null when cancelled.
Future<OrderHoldChoice?> showOrderHoldSheet(BuildContext context) {
  return AppSheet.show<OrderHoldChoice>(
    context,
    (_) => const OrderHoldSheet(),
  );
}

class OrderHoldSheet extends StatefulWidget {
  const OrderHoldSheet({super.key});

  /// Same limit as `orderHoldValid` in firestore.rules.
  static const int noteMaxLength = 500;

  @override
  State<OrderHoldSheet> createState() => _OrderHoldSheetState();
}

class _OrderHoldSheetState extends State<OrderHoldSheet> {
  final TextEditingController _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _pick(String reason) {
    final note = _note.text.trim();
    Navigator.of(context).pop<OrderHoldChoice>((
      reason: reason,
      note: note.isEmpty ? null : note,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppSheet(
      title: l10n.orderHoldSheetTitle,
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageMargin,
              AppSpacing.sm,
              AppSpacing.pageMargin,
              0,
            ),
            child: Semantics(
              identifier: 'order_hold_note',
              child: CupertinoTextField(
                key: const ValueKey('order_hold_note'),
                controller: _note,
                placeholder: l10n.orderHoldNoteHint,
                minLines: 1,
                maxLines: 3,
                maxLength: OrderHoldSheet.noteMaxLength,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(color: AppColors.text.resolveFrom(context)),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final reason in OrderHoldReason.values)
            Semantics(
              identifier: 'order_hold_reason_$reason',
              child: AppListRow(
                key: ValueKey('order_hold_reason_$reason'),
                title: OrderHoldStyle.reasonLabel(l10n, reason),
                showChevron: false,
                onTap: () => _pick(reason),
              ),
            ),
        ],
      ),
    );
  }
}
