import 'package:flutter/cupertino.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';
import 'package:provider/provider.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/extensions/context_extensions.dart';

/// Widget especializado para campos de telefone com validação real
///
/// Usa phone_numbers_parser para validação baseada no país da empresa
/// e formatação automática de números de telefone internacionais.
class PhoneField extends StatelessWidget {
  final String fieldKey;
  final String? initialValue;
  final FormFieldSetter<String>? onSaved;
  final bool required;
  final Widget? prefix;

  const PhoneField({
    super.key,
    required this.fieldKey,
    this.initialValue,
    this.onSaved,
    this.required = false,
    this.prefix,
  });

  @override
  Widget build(BuildContext context) {
    final config = context.watch<SegmentConfigProvider>();
    final countryCode = config.countryCode ?? 'BR';

    // Converte string para IsoCode
    final isoCode = _getIsoCode(countryCode);

    return CupertinoTextFormFieldRow(
      prefix: prefix ?? Text(config.label(fieldKey)),
      initialValue: initialValue,
      placeholder: _getPlaceholder(countryCode),
      keyboardType: TextInputType.phone,
      textAlign: TextAlign.right,
      onSaved: onSaved,
      validator: (val) {
        // Validação de campo obrigatório
        if (required && (val == null || val.isEmpty)) {
          return context.l10n.required;
        }

        // Se não é obrigatório e está vazio, ok
        if (val == null || val.isEmpty) {
          return null;
        }

        // Validação real do número de telefone
        try {
          final phone = PhoneNumber.parse(
            val,
            callerCountry: isoCode,
          );

          if (!phone.isValid()) {
            return context.l10n.invalidPhone;
          }
        } catch (e) {
          return context.l10n.invalidPhone;
        }

        return null;
      },
    );
  }

  /// Converte código de país (ISO 3166-1 alpha-2) para IsoCode
  IsoCode _getIsoCode(String countryCode) {
    try {
      return IsoCode.values.firstWhere(
        (iso) => iso.name == countryCode,
      );
    } catch (e) {
      // Fallback para Brasil se código inválido
      return IsoCode.BR;
    }
  }

  /// Retorna placeholder baseado no país
  String _getPlaceholder(String countryCode) {
    switch (countryCode) {
      case 'BR':
        return '(11) 98765-4321';
      case 'US':
        return '(555) 123-4567';
      case 'PT':
        return '912 345 678';
      case 'ES':
        return '612 34 56 78';
      case 'MX':
        return '55 1234 5678';
      default:
        return '';
    }
  }
}

