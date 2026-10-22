import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/screens/widgets/app_form_field.dart';
import 'package:praticos/screens/widgets/app_sheet.dart';
import 'package:praticos/screens/widgets/money_field.dart';
import 'package:praticos/screens/widgets/section_label.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';

/// Result of [OrderItemSheet].
class OrderItemEdit {
  const OrderItemEdit({
    this.value,
    this.quantity = 1,
    this.description,
    this.remove = false,
  });

  /// Null means "sem valor" (left out of the total).
  final double? value;
  final int quantity;

  /// What only this line has ("para-choque dianteiro"); null when blank.
  final String? description;

  /// "Tirar da OS".
  final bool remove;
}

/// Adjusts one item of the order: description (which part, which side),
/// price (blank = "sem valor"), quantity (products only) and "Tirar da OS". Pops with an [OrderItemEdit], or null
/// when cancelled.
class OrderItemSheet extends StatefulWidget {
  const OrderItemSheet({
    super.key,
    required this.name,
    required this.value,
    this.description,
    this.quantity,
    this.showPrice = true,
  });

  final String name;
  final double? value;
  final String? description;

  /// Null for services (no quantity).
  final int? quantity;

  /// False without the view-prices permission: only quantity and removal.
  final bool showPrice;

  @override
  State<OrderItemSheet> createState() => _OrderItemSheetState();
}

class _OrderItemSheetState extends State<OrderItemSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late double? _value = widget.value;
  late int _quantity = widget.quantity ?? 1;
  late String? _description = widget.description;

  void _done() {
    _formKey.currentState?.save();
    Navigator.pop(
      context,
      OrderItemEdit(
        value: _value,
        quantity: _quantity,
        description: _description,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = AppColors.text.resolveFrom(context);
    return AppSheet(
      title: widget.name,
      actionLabel: l10n.save,
      onAction: _done,
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.blockMargin,
              ),
              child: AppFormField(
                label: l10n.orderItemDescription,
                initialValue: widget.description,
                hint: l10n.orderItemDescriptionHint,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
                onSaved: (text) =>
                    _description = text.trim().isEmpty ? null : text.trim(),
              ),
            ),
            if (widget.showPrice)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.blockMargin,
                ),
                child: MoneyField(
                  label: l10n.orderItemPrice,
                  initialValue: widget.value,
                  hint: l10n.orderItemPriceHint,
                  onSavedNullable: (v) => _value = v,
                ),
              ),
            if (widget.quantity != null) ...[
              SectionLabel(l10n.orderItemQuantity),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pageMargin,
                ),
                child: Row(
                  children: [
                    CupertinoButton(
                      minimumSize: const Size(44, 44),
                      padding: EdgeInsets.zero,
                      onPressed: _quantity > 1
                          ? () => setState(() => _quantity--)
                          : null,
                      child: Semantics(
                        label: l10n.orderItemLess,
                        child: const Icon(CupertinoIcons.minus_circle),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      child: Text(
                        '$_quantity',
                        style: AppTypography.bodyStrong.copyWith(
                          color: text,
                          fontFeatures: AppTypography.tabular,
                        ),
                      ),
                    ),
                    CupertinoButton(
                      minimumSize: const Size(44, 44),
                      padding: EdgeInsets.zero,
                      onPressed: () => setState(() => _quantity++),
                      child: Semantics(
                        label: l10n.orderItemMore,
                        child: const Icon(CupertinoIcons.plus_circle),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            CupertinoButton(
              onPressed: () =>
                  Navigator.pop(context, const OrderItemEdit(remove: true)),
              child: Text(
                l10n.orderItemRemove,
                style: AppTypography.callout.copyWith(
                  color: AppColors.danger.resolveFrom(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
