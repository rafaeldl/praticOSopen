import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/screens/widgets/app_form_field.dart';
import 'package:praticos/services/format_service.dart';

/// Input formatter that treats typed digits as the smallest currency unit
/// (typing 1 2 3 4 5 gives 123,45) and formats with the locale currency.
class MoneyInputFormatter extends TextInputFormatter {
  MoneyInputFormatter(this.format);

  final NumberFormat format;

  int get _digits => format.decimalDigits ?? 2;

  /// Text shown for [value] in the field.
  String textFor(double value) => format.format(value);

  /// Amount represented by [text] (any text that holds the typed digits).
  double valueOf(String text) {
    final digits = text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 0;
    return int.parse(digits) / math.pow(10, _digits);
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return const TextEditingValue();
    }
    final text = textFor(valueOf(digits));
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Currency input: an [AppFormField] whose mask and reading follow the app
/// locale through [FormatService] (R$ 1.234,56 / $1,234.56 / 1.234,56 €).
class MoneyField extends StatefulWidget {
  const MoneyField({
    super.key,
    required this.label,
    this.initialValue,
    this.placeholder,
    this.hint,
    this.onChanged,
    this.onSaved,
    this.validator,
  });

  final String label;
  final double? initialValue;
  final String? placeholder;
  final String? hint;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onSaved;
  final String? Function(double value)? validator;

  @override
  State<MoneyField> createState() => _MoneyFieldState();
}

class _MoneyFieldState extends State<MoneyField> {
  TextEditingController? _controller;
  MoneyInputFormatter? _formatter;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final service = FormatService()..setLocale(context.l10n.localeName);
    final formatter = MoneyInputFormatter(service.currencyFormat);
    final previous = _controller;
    final amount =
        previous == null ? widget.initialValue : _formatter!.valueOf(previous.text);
    _formatter = formatter;
    final text = amount == null ? '' : formatter.textFor(amount);
    if (previous == null) {
      _controller = TextEditingController(text: text);
    } else if (previous.text != text) {
      previous.text = text; // locale changed: re-render the same amount
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formatter = _formatter!;
    return AppFormField(
      label: widget.label,
      controller: _controller,
      placeholder: widget.placeholder ?? formatter.textFor(0),
      hint: widget.hint,
      keyboardType: TextInputType.number,
      inputFormatters: [formatter],
      validator: widget.validator == null
          ? null
          : (text) => widget.validator!(formatter.valueOf(text)),
      onSaved: widget.onSaved == null
          ? null
          : (text) => widget.onSaved!(formatter.valueOf(text)),
      onChanged: widget.onChanged == null
          ? null
          : (text) => widget.onChanged!(formatter.valueOf(text)),
    );
  }
}
