import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/utils/tax_id.dart';

/// Validates a CPF/CNPJ typed with or without punctuation. Supports the
/// alphanumeric CNPJ.
String? validateTaxIdInput(
  AppLocalizations l10n,
  String? value, {
  bool required = false,
}) {
  final id = normalizeTaxId(value ?? '');
  if (id.isEmpty) return required ? l10n.asaasErrorTaxIdRequired : null;
  return isValidTaxId(id) ? null : l10n.invalidTaxId;
}

/// Optional CPF/CNPJ row for Cupertino forms.
///
/// Text keyboard (alphanumeric CNPJ), uppercase input, no mask while typing;
/// the value is formatted for display when the field loses focus. Saves the
/// normalized value (digits / uppercase letters) or null when empty.
class TaxIdFormField extends StatefulWidget {
  const TaxIdFormField({super.key, this.initialValue, this.onSaved});

  final String? initialValue;
  final ValueChanged<String?>? onSaved;

  @override
  State<TaxIdFormField> createState() => _TaxIdFormFieldState();
}

class _TaxIdFormFieldState extends State<TaxIdFormField> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    final initial = widget.initialValue ?? '';
    _controller =
        TextEditingController(text: initial.isEmpty ? '' : formatTaxId(initial));
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      final text = _controller.text;
      final formatted = formatTaxId(text);
      if (formatted != text) _controller.text = formatted;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoTextFormFieldRow(
      key: const Key('taxIdFormField'),
      prefix: Text(context.l10n.cpfCnpj, style: const TextStyle(fontSize: 16)),
      controller: _controller,
      focusNode: _focusNode,
      placeholder: context.l10n.optional,
      keyboardType: TextInputType.text,
      textCapitalization: TextCapitalization.characters,
      autocorrect: false,
      enableSuggestions: false,
      textAlign: TextAlign.right,
      validator: (value) => validateTaxIdInput(context.l10n, value),
      onSaved: (value) {
        final id = normalizeTaxId(value ?? '');
        widget.onSaved?.call(id.isEmpty ? null : id);
      },
    );
  }
}
