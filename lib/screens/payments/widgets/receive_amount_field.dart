import 'package:praticos/services/format_service.dart';

/// Money text of the "Receber" screens, in the app locale.
class ReceiveAmountField {
  const ReceiveAmountField._();

  /// Text to put in the field for [value] (what the formatter would produce).
  static String textFor(double value) => FormatService().formatCurrency(value);
}
