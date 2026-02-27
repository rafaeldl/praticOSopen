import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:praticos/models/custom_field.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/extensions/context_extensions.dart';

/// Renderiza o widget Cupertino apropriado para um [CustomField].
///
/// Suporta os tipos: text, textarea, number, select, date.
/// Segue padrões visuais Cupertino (CupertinoListTile, CupertinoActionSheet, etc).
class DynamicFieldBuilder extends StatelessWidget {
  final CustomField field;
  final dynamic value;
  final ValueChanged<dynamic> onChanged;
  final String locale;

  const DynamicFieldBuilder({
    super.key,
    required this.field,
    required this.value,
    required this.onChanged,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    switch (field.type) {
      case 'text':
        return _buildTextField(context);
      case 'textarea':
        return _buildTextAreaField(context);
      case 'number':
        return _buildNumberField(context);
      case 'select':
        return _buildSelectField(context);
      case 'date':
        return _buildDateField(context);
      default:
        return const SizedBox.shrink();
    }
  }

  // ════════════════════════════════════════════════════════════
  // TEXT
  // ════════════════════════════════════════════════════════════

  Widget _buildTextField(BuildContext context) {
    return CupertinoTextFormFieldRow(
      prefix: Text(
        field.getLabel(locale),
        style: const TextStyle(fontSize: 16),
      ),
      initialValue: value as String?,
      placeholder: field.placeholder,
      textAlign: TextAlign.right,
      style: TextStyle(color: CupertinoColors.label.resolveFrom(context)),
      onChanged: (val) => onChanged(val.isEmpty ? null : val),
      validator: (val) {
        if (field.required && (val == null || val.isEmpty)) {
          return context.l10n.required;
        }
        if (val != null && val.isNotEmpty) {
          if (field.minLength != null && val.length < field.minLength!) {
            return '${context.l10n.minimum} ${field.minLength} ${context.l10n.characters}';
          }
          if (field.pattern != null && !RegExp(field.pattern!).hasMatch(val)) {
            return context.l10n.invalidFormat;
          }
        }
        return null;
      },
    );
  }

  // ════════════════════════════════════════════════════════════
  // TEXTAREA
  // ════════════════════════════════════════════════════════════

  Widget _buildTextAreaField(BuildContext context) {
    return _TextAreaField(
      initialValue: value as String?,
      placeholder: field.placeholder ?? field.getLabel(locale),
      onChanged: (val) => onChanged(val.isEmpty ? null : val),
    );
  }

  // ════════════════════════════════════════════════════════════
  // NUMBER
  // ════════════════════════════════════════════════════════════

  Widget _buildNumberField(BuildContext context) {
    return CupertinoTextFormFieldRow(
      prefix: Text(
        field.getLabel(locale),
        style: const TextStyle(fontSize: 16),
      ),
      initialValue: value?.toString(),
      placeholder: _numberPlaceholder(),
      keyboardType: const TextInputType.numberWithOptions(signed: true),
      textAlign: TextAlign.right,
      style: TextStyle(color: CupertinoColors.label.resolveFrom(context)),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'-?\d*'))],
      onChanged: (val) {
        if (val.isEmpty) {
          onChanged(null);
        } else {
          onChanged(int.tryParse(val));
        }
      },
      validator: (val) {
        if (field.required && (val == null || val.isEmpty)) {
          return context.l10n.required;
        }
        if (val != null && val.isNotEmpty) {
          final num = int.tryParse(val);
          if (num == null) return context.l10n.invalidFormat;
          if (field.min != null && num < field.min!) {
            return '${context.l10n.minimum}: ${field.min!.toInt()}';
          }
          if (field.max != null && num > field.max!) {
            return '${context.l10n.maximum}: ${field.max!.toInt()}';
          }
        }
        return null;
      },
    );
  }

  String _numberPlaceholder() {
    if (field.min != null && field.max != null) {
      return '${field.min!.toInt()} - ${field.max!.toInt()}';
    }
    return '';
  }

  // ════════════════════════════════════════════════════════════
  // SELECT
  // ════════════════════════════════════════════════════════════

  Widget _buildSelectField(BuildContext context) {
    final displayValue = value != null
        ? field.getOptionLabel(value as String, locale)
        : null;

    return CupertinoListTile(
      title: Text(
        field.getLabel(locale),
        style: const TextStyle(fontSize: 16),
      ),
      additionalInfo: Text(
        displayValue ?? context.l10n.select,
        style: TextStyle(
          fontSize: 16,
          color: displayValue != null
              ? CupertinoColors.label.resolveFrom(context)
              : CupertinoColors.placeholderText.resolveFrom(context),
        ),
      ),
      trailing: Icon(
        CupertinoIcons.chevron_right,
        size: 20,
        color: CupertinoColors.systemGrey.resolveFrom(context),
      ),
      onTap: () => _showSelectPicker(context),
    );
  }

  void _showSelectPicker(BuildContext context) {
    final options = field.options ?? [];
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(field.getLabel(locale)),
        actions: [
          ...options.map((option) => CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              onChanged(option);
            },
            child: Text(field.getOptionLabel(option, locale)),
          )),
          if (value != null)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(ctx);
                onChanged(null);
              },
              child: Text(context.l10n.clear),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: Text(context.l10n.cancel),
          onPressed: () => Navigator.pop(ctx),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // DATE
  // ════════════════════════════════════════════════════════════

  Widget _buildDateField(BuildContext context) {
    final dateValue = _parseDate(value);
    final displayValue = dateValue != null
        ? FormatService().formatDate(dateValue)
        : null;

    return CupertinoListTile(
      title: Text(
        field.getLabel(locale),
        style: const TextStyle(fontSize: 16),
      ),
      additionalInfo: Text(
        displayValue ?? context.l10n.select,
        style: TextStyle(
          fontSize: 16,
          color: displayValue != null
              ? CupertinoColors.label.resolveFrom(context)
              : CupertinoColors.placeholderText.resolveFrom(context),
        ),
      ),
      trailing: Icon(
        CupertinoIcons.chevron_right,
        size: 20,
        color: CupertinoColors.systemGrey.resolveFrom(context),
      ),
      onTap: () => _showDatePicker(context, dateValue),
    );
  }

  void _showDatePicker(BuildContext context, DateTime? current) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => Container(
        height: 260,
        padding: const EdgeInsets.only(top: 6.0),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    child: Text(context.l10n.clear),
                    onPressed: () {
                      Navigator.pop(context);
                      onChanged(null);
                    },
                  ),
                  CupertinoButton(
                    child: Text(
                      context.l10n.confirm,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Expanded(
                child: CupertinoDatePicker(
                  initialDateTime: current ?? DateTime.now(),
                  mode: CupertinoDatePickerMode.date,
                  onDateTimeChanged: (DateTime newDate) {
                    onChanged(newDate.toIso8601String());
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

/// StatefulWidget that manages its own TextEditingController
/// to avoid cursor reset on rebuild.
class _TextAreaField extends StatefulWidget {
  final String? initialValue;
  final String? placeholder;
  final ValueChanged<String> onChanged;

  const _TextAreaField({
    this.initialValue,
    this.placeholder,
    required this.onChanged,
  });

  @override
  State<_TextAreaField> createState() => _TextAreaFieldState();
}

class _TextAreaFieldState extends State<_TextAreaField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: CupertinoTextField(
        controller: _controller,
        placeholder: widget.placeholder,
        minLines: 3,
        maxLines: 6,
        textCapitalization: TextCapitalization.sentences,
        style: TextStyle(
          fontSize: 16,
          color: CupertinoColors.label.resolveFrom(context),
        ),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground.resolveFrom(context),
          borderRadius: BorderRadius.circular(8),
        ),
        onChanged: widget.onChanged,
      ),
    );
  }
}
