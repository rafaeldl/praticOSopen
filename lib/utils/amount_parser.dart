class AmountParser {
  /// Parses a currency string to double.
  /// Handles Brazilian format (1.234,56), US format (1,234.56),
  /// and plain numbers (450).
  static double parse(String value) {
    if (value.isEmpty) return 0;

    // Remove currency symbols and whitespace
    final cleaned = value.replaceAll(RegExp(r'[R$€£\s]'), '').trim();
    if (cleaned.isEmpty) return 0;

    // Detect format by last separator position
    final lastComma = cleaned.lastIndexOf(',');
    final lastDot = cleaned.lastIndexOf('.');

    String normalized;
    if (lastComma > lastDot) {
      // Brazilian format: 1.234,56 -> 1234.56
      normalized = cleaned.replaceAll('.', '').replaceAll(',', '.');
    } else if (lastDot > lastComma) {
      // US format: 1,234.56 -> 1234.56
      normalized = cleaned.replaceAll(',', '');
    } else {
      // No separator or only one type
      normalized = cleaned.replaceAll(',', '.');
    }

    return double.tryParse(normalized) ?? 0;
  }
}
