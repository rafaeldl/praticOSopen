import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/screens/widgets/app_form_field.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';

/// One suggestion of a [SuggestField].
class SuggestOption<T> {
  const SuggestOption({required this.value, required this.title, this.subtitle});

  final T value;
  final String title;
  final String? subtitle;
}

/// [AppFormField] with suggestions listed under it while typing. Choosing a
/// suggestion fills the text and calls [onSelected] (so the form can fill
/// related fields). When nothing matches the text exactly, a `Usar “texto”`
/// row confirms what was typed.
class SuggestField<T> extends StatefulWidget {
  const SuggestField({
    super.key,
    required this.label,
    required this.controller,
    required this.suggestions,
    required this.onSelected,
    this.placeholder,
    this.textCapitalization = TextCapitalization.words,
    this.textInputAction,
    this.autofocus = false,
    this.validator,
    this.onSaved,
  });

  final String label;
  final TextEditingController controller;
  final String? placeholder;
  final TextCapitalization textCapitalization;
  final TextInputAction? textInputAction;
  final bool autofocus;

  /// Suggestions for the current text.
  final List<SuggestOption<T>> Function(String text) suggestions;
  final ValueChanged<T> onSelected;
  final String? Function(String text)? validator;
  final ValueChanged<String>? onSaved;

  @override
  State<SuggestField<T>> createState() => _SuggestFieldState<T>();
}

class _SuggestFieldState<T> extends State<SuggestField<T>> {
  bool _dismissed = true;

  void _onChanged(String _) => setState(() => _dismissed = false);

  void _select(SuggestOption<T> option) {
    widget.controller.text = option.title;
    widget.controller.selection =
        TextSelection.collapsed(offset: option.title.length);
    widget.onSelected(option.value);
    setState(() => _dismissed = true);
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text.trim();
    final options = _dismissed || text.isEmpty
        ? <SuggestOption<T>>[]
        : widget.suggestions(text);
    final exact = options.any((o) => o.title.toLowerCase() == text.toLowerCase());
    final showUse = !_dismissed && text.isNotEmpty && !exact;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppFormField(
          label: widget.label,
          controller: widget.controller,
          placeholder: widget.placeholder,
          textCapitalization: widget.textCapitalization,
          textInputAction: widget.textInputAction,
          autofocus: widget.autofocus,
          validator: widget.validator,
          onSaved: widget.onSaved,
          onChanged: _onChanged,
        ),
        for (final o in options)
          AppListRow(
            title: o.title,
            subtitle: o.subtitle,
            onTap: () => _select(o),
            showChevron: false,
          ),
        if (showUse)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _dismissed = true),
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(minHeight: AppSizes.minTouchTarget),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pageMargin,
                  vertical: AppSpacing.sm,
                ),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    context.l10n.useValue(text),
                    style: AppTypography.callout.copyWith(
                      color: AppColors.accentText.resolveFrom(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
