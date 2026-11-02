import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/screens/widgets/app_form_field.dart';
import 'package:praticos/services/format_service.dart';

/// Input formatter that reads what is typed as a plain amount: 250 is 250
/// and 250,5 is 250,50, as anyone writes a price. The decimal separator of
/// [format] opens the cents; the digits are formatted with the locale
/// currency as they come in.
class MoneyInputFormatter extends TextInputFormatter {
  MoneyInputFormatter(this.format);

  final NumberFormat format;

  /// Longest whole part accepted, so the amount stays a safe number.
  static const _maxWholeDigits = 12;

  int get _digits => format.decimalDigits ?? 2;
  String get _separator => format.symbols.DECIMAL_SEP;

  /// Text shown for [value] in the field.
  String textFor(double value) => format.format(value);

  /// Amount represented by [text] (the field text or just the typed digits).
  double valueOf(String text) {
    final (whole, cents) = _parts(text);
    if (whole.isEmpty && cents == null) return 0;
    final number = '${whole.isEmpty ? '0' : whole}.${cents ?? ''}0';
    return double.parse(number);
  }

  /// Whole digits and typed cents of [text]; cents are null until the
  /// separator shows up.
  (String, String?) _parts(String text) {
    final clean = text.replaceAll(format.currencySymbol, '');
    final at = _digits == 0 ? -1 : clean.lastIndexOf(_separator);
    String digits(String value) => value.replaceAll(RegExp(r'\D'), '');
    if (at < 0) return (digits(clean), null);
    final cents = digits(clean.substring(at + 1));
    return (
      digits(clean.substring(0, at)),
      cents.substring(0, math.min(cents.length, _digits)),
    );
  }

  /// [whole] and [cents] in the locale currency, with only the cents typed.
  String _render(String whole, String? cents) {
    final amount = whole.isEmpty ? 0 : int.parse(whole);
    final full = format.format(amount);
    if (_digits == 0) return full;
    final zeros = '$_separator${'0' * _digits}';
    final at = full.lastIndexOf(zeros);
    return full.replaceRange(
      at,
      at + zeros.length,
      cents == null ? '' : '$_separator$cents',
    );
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text.replaceAll(format.currencySymbol, '').trim();
    if (text.isEmpty) return const TextEditingValue();
    // The keyboard follows the device, not the app: a final dot or comma is
    // always the separator, never a thousands mark.
    if (text.endsWith('.') || text.endsWith(',')) {
      text = '${text.substring(0, text.length - 1)}$_separator';
    }
    var (whole, cents) = _parts(text);
    // Deleted only the symbol or a space: delete the last typed character.
    if (newValue.text.length < oldValue.text.length &&
        (whole, cents) == _parts(oldValue.text)) {
      if (cents == null) {
        whole = whole.substring(0, math.max(whole.length - 1, 0));
      } else if (cents.isEmpty) {
        cents = null;
      } else {
        cents = cents.substring(0, cents.length - 1);
      }
    }
    if (whole.isEmpty && cents == null) return const TextEditingValue();
    whole = whole.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (whole.length > _maxWholeDigits) return oldValue;
    final rendered = _render(whole, cents);
    // Keeps the caret before a trailing symbol (1.250 €).
    final symbol = rendered.lastIndexOf(format.currencySymbol);
    final caret = symbol > 0 && rendered.trim().endsWith(format.currencySymbol)
        ? rendered.substring(0, symbol).trimRight().length
        : rendered.length;
    return TextEditingValue(
      text: rendered,
      selection: TextSelection.collapsed(offset: caret),
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
    this.onSavedNullable,
    this.validator,
    this.autofocus = false,
  });

  final String label;
  final double? initialValue;
  final String? placeholder;
  final String? hint;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onSaved;

  /// Like [onSaved] but receives null when the field is blank (price left
  /// empty), instead of 0.
  final ValueChanged<double?>? onSavedNullable;
  final String? Function(double value)? validator;
  final bool autofocus;

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
    final amount = previous == null
        ? widget.initialValue
        : _formatter!.valueOf(previous.text);
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
      autofocus: widget.autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [formatter],
      validator: widget.validator == null
          ? null
          : (text) => widget.validator!(formatter.valueOf(text)),
      onSaved: (widget.onSaved == null && widget.onSavedNullable == null)
          ? null
          : (text) {
              widget.onSaved?.call(formatter.valueOf(text));
              widget.onSavedNullable?.call(
                text.trim().isEmpty ? null : formatter.valueOf(text),
              );
            },
      onChanged: widget.onChanged == null
          ? null
          : (text) => widget.onChanged!(formatter.valueOf(text)),
    );
  }
}
