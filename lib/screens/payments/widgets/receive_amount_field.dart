import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:flutter/cupertino.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_typography.dart';

/// Large money input of the "Receber" screen. Currency symbol and separators
/// follow the app locale through [FormatService].
class ReceiveAmountField extends StatelessWidget {
  const ReceiveAmountField({
    super.key,
    required this.controller,
    this.onChanged,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  /// Text to put in the field for [value] (what the formatter would produce).
  static String textFor(double value) => FormatService().formatCurrency(value);

  @override
  Widget build(BuildContext context) {
    final format = FormatService().currencyFormat;
    return CupertinoTextField(
      key: const Key('receiveAmountField'),
      controller: controller,
      autofocus: autofocus,
      onChanged: onChanged,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
        color: AppColors.onAccentSoft.resolveFrom(context),
        fontFeatures: AppTypography.tabular,
      ),
      cursorColor: AppColors.accentText.resolveFrom(context),
    );
  }
}
