import 'package:praticos/services/format_service.dart';

/// Parses the text of a currency input field (e.g. `R$ 1.500,00`).
///
/// First tries the current locale's currency format ([FormatService]); if
/// that fails (the field mask can differ from the app locale), strips the
/// currency symbols and normalizes the decimal separator. Empty or
/// unparseable text returns 0.
double parseCurrencyInput(String text) {
  final value = text.trim();
  if (value.isEmpty) return 0;

  try {
    return FormatService().currencyFormat.parse(value).toDouble();
  } catch (_) {
    final clean = value
        .replaceAll(RegExp(r'[R\$€£¥\s]'), '') // currency symbols and spaces
        .replaceAll(RegExp(r'\.(?=.*,)'), '') // thousands dots (pt-BR)
        .replaceAll(RegExp(r',(?=.*\.)'), '') // thousands commas (en-US)
        .replaceAll(',', '.') // decimal separator
        .trim();
    return double.tryParse(clean) ?? 0;
  }
}
