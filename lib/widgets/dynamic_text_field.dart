import 'package:easy_mask/easy_mask.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/extensions/context_extensions.dart';

/// Widget genérico para campos de texto customizáveis
///
/// Obtém configurações (máscaras, validações, teclado) do SegmentConfigService
/// baseado no fieldKey fornecido. Suporta máscaras universais e por país.
class DynamicTextField extends StatelessWidget {
  final String fieldKey;
  final String? initialValue;
  final FormFieldSetter<String>? onSaved;
  final bool required;
  final Widget? prefix;
  final String? customPlaceholder;
  final int? maxLines;

  const DynamicTextField({
    super.key,
    required this.fieldKey,
    this.initialValue,
    this.onSaved,
    this.required = false,
    this.prefix,
    this.customPlaceholder,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final config = context.watch<SegmentConfigProvider>();
    final field = config.getField(fieldKey);
    final masks = config.getMasks(fieldKey);

    // Determina o placeholder
    final placeholder = customPlaceholder ?? field?.placeholder;

    // Determina os input formatters
    List<TextInputFormatter>? inputFormatters;
    if (masks.isNotEmpty) {
      // Se há apenas uma máscara, passa como string
      // Se há múltiplas, passa como lista (easy_mask escolhe automaticamente)
      inputFormatters = [
        TextInputMask(mask: masks.length == 1 ? masks.first : masks)
      ];
    }

    return CupertinoTextFormFieldRow(
      prefix: prefix ?? Text(config.label(fieldKey)),
      initialValue: initialValue,
      placeholder: placeholder,
      keyboardType: config.getKeyboardType(fieldKey),
      textCapitalization: config.getTextCapitalization(fieldKey),
      textAlign: TextAlign.right,
      maxLines: maxLines,
      inputFormatters: inputFormatters,
      onSaved: onSaved,
      validator: _buildValidator(context, field),
    );
  }

  /// Constrói validador baseado nas configurações do campo
  FormFieldValidator<String>? _buildValidator(
    BuildContext context,
    dynamic field,
  ) {
    return (String? value) {
      // Validação de campo obrigatório
      if (required && (value == null || value.isEmpty)) {
        return context.l10n.required;
      }

      // Se não é obrigatório e está vazio, ok
      if (value == null || value.isEmpty) {
        return null;
      }

      // Validação customizada por regex (se configurado)
      if (field?.pattern != null) {
        final regex = RegExp(field!.pattern);
        if (!regex.hasMatch(value)) {
          return context.l10n.invalidFormat;
        }
      }

      // Validação de comprimento mínimo
      if (field?.minLength != null && value.length < field!.minLength!) {
        return '${context.l10n.minimum} ${field.minLength} ${context.l10n.characters}';
      }

      // Validação de comprimento máximo
      if (field?.maxLength != null && value.length > field!.maxLength!) {
        return '${context.l10n.maximum} ${field.maxLength} ${context.l10n.characters}';
      }

      return null;
    };
  }
}
