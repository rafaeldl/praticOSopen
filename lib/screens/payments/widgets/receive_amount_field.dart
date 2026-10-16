import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:flutter/cupertino.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';

/// Large money input of the "Receber" screens. Currency symbol and separators
/// follow the app locale through [FormatService].
///
/// It looks like a field (opaque `surface` box with an `accentText` border
/// and a pencil at the end) so it is clear the amount can be changed. Tapping
/// anywhere on the box, the pencil included, focuses it with the numeric
/// keyboard. The border gets thicker while editing.
class ReceiveAmountField extends StatefulWidget {
  const ReceiveAmountField({
    super.key,
    required this.controller,
    this.onChanged,
    this.autofocus = false,
    this.semanticLabel,
    this.enabled = true,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  /// What the field asks ("Quanto recebeu"), read by VoiceOver.
  final String? semanticLabel;

  /// False while saving.
  final bool enabled;

  /// Text to put in the field for [value] (what the formatter would produce).
  static String textFor(double value) => FormatService().formatCurrency(value);

  @override
  State<ReceiveAmountField> createState() => _ReceiveAmountFieldState();
}

class _ReceiveAmountFieldState extends State<ReceiveAmountField> {
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _focus.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (mounted) setState(() {});
  }

  void _edit() {
    if (!widget.enabled) return;
    _focus.requestFocus();
    // Cursor at the end: the formatter types from the right.
    final text = widget.controller.text;
    widget.controller.selection = TextSelection.collapsed(offset: text.length);
  }

  @override
  Widget build(BuildContext context) {
    final format = FormatService().currencyFormat;
    final accent = AppColors.accentText.resolveFrom(context);
    final focused = _focus.hasFocus;
    return Semantics(
      label: widget.semanticLabel,
      child: GestureDetector(
        key: const Key('receiveAmountBox'),
        behavior: HitTestBehavior.opaque,
        onTap: _edit,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(minHeight: AppSizes.minTouchTarget),
          decoration: BoxDecoration(
            color: AppColors.surface.resolveFrom(context),
            borderRadius: BorderRadius.circular(AppRadii.field),
            border: Border.all(color: accent, width: focused ? 2 : 1),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md - (focused ? 1 : 0),
            vertical: AppSpacing.sm - (focused ? 1 : 0),
          ),
          child: Row(
            children: [
              Expanded(
                child: CupertinoTextField(
                  key: const Key('receiveAmountField'),
                  controller: widget.controller,
                  focusNode: _focus,
                  autofocus: widget.autofocus,
                  enabled: widget.enabled,
                  onChanged: widget.onChanged,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    CurrencyTextInputFormatter.currency(
                      locale: format.locale,
                      symbol: format.currencySymbol,
                      decimalDigits: 2,
                    ),
                  ],
                  padding: EdgeInsets.zero,
                  decoration: null,
                  style: AppTypography.title.copyWith(
                    color: AppColors.text.resolveFrom(context),
                    fontFeatures: AppTypography.tabular,
                  ),
                  cursorColor: accent,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              ExcludeSemantics(
                child: Icon(
                  CupertinoIcons.pencil,
                  key: const Key('receiveAmountEditIcon'),
                  size: 24,
                  color: accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
