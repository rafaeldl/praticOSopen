import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/models/order_form.dart' as of_model;
import 'package:praticos/screens/widgets/app_form_field.dart';
import 'package:praticos/screens/widgets/app_sheet.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';

/// Questions of a checklist still without an answer.
int checklistMissing(of_model.OrderForm form) {
  final missing = form.items.length - form.responses.length;
  return missing < 0 ? 0 : missing;
}

/// Result of [OrderDateSheet]: a new date, or [remove].
class OrderDatePick {
  const OrderDatePick.date(DateTime this.date) : remove = false;
  const OrderDatePick.remove()
      : date = null,
        remove = true;

  final DateTime? date;
  final bool remove;
}

/// Date and time picker for the order (schedule, due date): "Salvar" on the
/// right; optional [removeLabel] in red to clear the date.
class OrderDateSheet extends StatefulWidget {
  const OrderDateSheet({
    super.key,
    required this.initial,
    this.removeLabel,
  });

  final DateTime initial;
  final String? removeLabel;

  /// Resolves with what was picked, or null when dismissed.
  static Future<OrderDatePick?> show(
    BuildContext context, {
    required DateTime initial,
    String? removeLabel,
  }) {
    return showCupertinoModalPopup<OrderDatePick>(
      context: context,
      builder: (_) => OrderDateSheet(initial: initial, removeLabel: removeLabel),
    );
  }

  @override
  State<OrderDateSheet> createState() => _OrderDateSheetState();
}

class _OrderDateSheetState extends State<OrderDateSheet> {
  late DateTime _picked = widget.initial;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final accent = AppColors.accentText.resolveFrom(context);
    return Container(
      height: 320,
      color: AppColors.surface.resolveFrom(context),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Row(
              children: [
                if (widget.removeLabel != null)
                  CupertinoButton(
                    onPressed: () =>
                        Navigator.pop(context, const OrderDatePick.remove()),
                    child: Text(
                      widget.removeLabel!,
                      style: AppTypography.callout.copyWith(
                        color: AppColors.danger.resolveFrom(context),
                      ),
                    ),
                  ),
                const Spacer(),
                CupertinoButton(
                  onPressed: () =>
                      Navigator.pop(context, OrderDatePick.date(_picked)),
                  child: Text(
                    l10n.save,
                    style: AppTypography.callout.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: CupertinoDatePicker(
                initialDateTime: widget.initial,
                mode: CupertinoDatePickerMode.dateAndTime,
                use24hFormat: true,
                onDateTimeChanged: (d) => _picked = d,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Endereço do atendimento": one field. Pops with the trimmed text (empty
/// means no address), or null when cancelled.
class OrderAddressSheet extends StatefulWidget {
  const OrderAddressSheet({super.key, this.initial});

  final String? initial;

  @override
  State<OrderAddressSheet> createState() => _OrderAddressSheetState();
}

class _OrderAddressSheetState extends State<OrderAddressSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _done() => Navigator.pop(context, _controller.text.trim());

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppSheet(
      title: l10n.orderAddAddress,
      actionLabel: l10n.save,
      onAction: _done,
      child: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.blockMargin,
          vertical: AppSpacing.lg,
        ),
        children: [
          AppFormField(
            label: l10n.address,
            controller: _controller,
            placeholder: l10n.addressPlaceholder,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            autofocus: true,
            maxLines: 3,
          ),
        ],
      ),
    );
  }
}
