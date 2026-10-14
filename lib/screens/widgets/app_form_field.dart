import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';

/// Form field of the app design system: label above, field on
/// `secondaryFill` (radius 12, min height 52), optional hint below and an
/// error line in `danger`. Works inside a [Form] (validator / onSaved).
///
/// The placeholder is an example of the segment ("Ex.: Fiat Uno 2015"),
/// never "Selecionar".
class AppFormField extends StatefulWidget {
  const AppFormField({
    super.key,
    required this.label,
    this.controller,
    this.initialValue,
    this.placeholder,
    this.hint,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction,
    this.inputFormatters,
    this.autofocus = false,
    this.maxLines = 1,
    this.validator,
    this.onSaved,
    this.onChanged,
  });

  final String label;
  final TextEditingController? controller;
  final String? initialValue;
  final String? placeholder;

  /// Help text under the field, replaced by the error when validation fails.
  final String? hint;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final bool autofocus;
  final int maxLines;

  /// Returns the error message, or null when the text is valid.
  final String? Function(String text)? validator;
  final ValueChanged<String>? onSaved;
  final ValueChanged<String>? onChanged;

  @override
  State<AppFormField> createState() => _AppFormFieldState();
}

class _AppFormFieldState extends State<AppFormField> {
  TextEditingController? _own;

  TextEditingController get _controller =>
      widget.controller ?? (_own ??= TextEditingController(text: widget.initialValue));

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = AppColors.text.resolveFrom(context);
    final secondary = AppColors.textSecondary.resolveFrom(context);
    final danger = AppColors.danger.resolveFrom(context);

    return FormField<String>(
      initialValue: _controller.text,
      validator: (_) => widget.validator?.call(_controller.text),
      onSaved: (_) => widget.onSaved?.call(_controller.text),
      builder: (state) {
        final error = state.errorText;
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pageMargin,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text(
                  widget.label,
                  style: AppTypography.label.copyWith(color: secondary),
                ),
              ),
              CupertinoTextField(
                controller: _controller,
                placeholder: widget.placeholder,
                placeholderStyle:
                    AppTypography.body.copyWith(color: secondary),
                style: AppTypography.body.copyWith(color: text),
                keyboardType: widget.keyboardType,
                textCapitalization: widget.textCapitalization,
                textInputAction: widget.textInputAction,
                inputFormatters: widget.inputFormatters,
                autofocus: widget.autofocus,
                minLines: 1,
                maxLines: widget.maxLines,
                clearButtonMode: OverlayVisibilityMode.editing,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md + 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.secondaryFill.resolveFrom(context),
                  borderRadius: BorderRadius.circular(AppRadii.field),
                  border: error == null
                      ? null
                      : Border.all(color: danger, width: 1.5),
                ),
                onChanged: (value) {
                  state.didChange(value);
                  // Once shown, the error follows what is typed.
                  if (state.hasError) state.validate();
                  widget.onChanged?.call(value);
                },
              ),
              if (error != null || widget.hint != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    error ?? widget.hint!,
                    style: AppTypography.label.copyWith(
                      color: error != null ? danger : secondary,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
