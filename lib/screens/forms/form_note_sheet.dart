import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/form_definition.dart';
import 'package:praticos/models/order_form.dart';
import 'package:praticos/screens/forms/form_question_sheet.dart';
import 'package:praticos/screens/widgets/app_sheet.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';

/// The options of a multiple choice question marked in [response], as saved
/// (the template's original text).
List<String> markedOptions(FormItemDefinition item, FormResponse? response) {
  if (item.type != FormItemType.checklist) return const [];
  final value = response?.value;
  return value is List ? value.map((e) => e.toString()).toList() : const [];
}

/// [original] (an option as saved) in the user's language.
String localizedOption(
  FormItemDefinition item,
  String original,
  String? localeCode,
) {
  final options = item.options ?? const <String>[];
  final localized = item.getLocalizedOptions(localeCode) ?? options;
  final i = options.indexOf(original);
  return i >= 0 && i < localized.length ? localized[i] : original;
}

/// The note of a question in lines, as the list, the PDF and the question
/// show it: the question's note, then "Porta: amassado" for each marked
/// option with a note, then "Foto 2: risco" for each photo with a note.
/// Notes of options no longer marked or photos no longer there are left out.
List<String> formNoteLines(
  AppLocalizations l10n,
  FormItemDefinition item,
  FormItemNote? note,
  FormResponse? response,
  String? localeCode,
) {
  if (note == null) return const [];
  final lines = <String>[];
  final text = note.text?.trim() ?? '';
  if (text.isNotEmpty) lines.add(text);
  for (final option in markedOptions(item, response)) {
    final optionNote = note.optionText(option)?.trim();
    if (optionNote == null || optionNote.isEmpty) continue;
    lines.add(
      l10n.checklistNoteLine(
        localizedOption(item, option, localeCode),
        optionNote,
      ),
    );
  }
  final photos = response?.photoUrls ?? const <String>[];
  for (var i = 0; i < photos.length; i++) {
    final photoNote = note.photoText(photos[i])?.trim();
    if (photoNote == null || photoNote.isEmpty) continue;
    lines.add(
      l10n.checklistNoteLine(l10n.checklistNotePhoto(i + 1), photoNote),
    );
  }
  return lines;
}

/// Small sheet to write the note of a question: one field for the question,
/// one for each marked option (multiple choice only) and one for each photo.
/// "Pronto" pops the note written ([FormItemNote]); "Cancelar" pops null.
/// A text left as it was keeps its `ai` mark; an edited one is the person's.
class FormNoteSheet extends StatefulWidget {
  const FormNoteSheet({
    super.key,
    required this.item,
    this.note,
    this.response,
    this.localeCode,
  });

  final FormItemDefinition item;
  final FormItemNote? note;
  final FormResponse? response;
  final String? localeCode;

  /// Opens the sheet and resolves with the note written (null: cancelled).
  static Future<FormItemNote?> show(
    BuildContext context, {
    required FormItemDefinition item,
    FormItemNote? note,
    FormResponse? response,
    String? localeCode,
  }) {
    return AppSheet.show<FormItemNote>(
      context,
      (_) => FormNoteSheet(
        item: item,
        note: note,
        response: response,
        localeCode: localeCode,
      ),
    );
  }

  @override
  State<FormNoteSheet> createState() => _FormNoteSheetState();
}

class _FormNoteSheetState extends State<FormNoteSheet> {
  late final List<String> _options = markedOptions(
    widget.item,
    widget.response,
  );
  late final List<String> _photos =
      widget.response?.photoUrls ?? const <String>[];

  late final TextEditingController _text = TextEditingController(
    text: widget.note?.text ?? '',
  );
  late final List<TextEditingController> _optionTexts = [
    for (final o in _options)
      TextEditingController(text: widget.note?.optionText(o) ?? ''),
  ];
  late final List<TextEditingController> _photoTexts = [
    for (final p in _photos)
      TextEditingController(text: widget.note?.photoText(p) ?? ''),
  ];

  @override
  void dispose() {
    for (final c in [_text, ..._optionTexts, ..._photoTexts]) {
      c.dispose();
    }
    super.dispose();
  }

  /// `ai` stays only while the text is still the one the AI wrote.
  bool _keepsAi(String text, String? before, bool ai) =>
      ai && before != null && text.trim() == before.trim();

  FormItemNote _result() {
    final before = widget.note;
    final text = _text.text.trim();
    final options = <FormOptionNote>[
      // Notes of options unmarked meanwhile stay (marking it again shows it).
      for (final o in before?.options ?? const <FormOptionNote>[])
        if (!_options.contains(o.option)) o,
      for (var i = 0; i < _options.length; i++)
        if (_optionTexts[i].text.trim().isNotEmpty)
          FormOptionNote(
            option: _options[i],
            text: _optionTexts[i].text.trim(),
            ai: _keepsAi(
              _optionTexts[i].text,
              before?.optionText(_options[i]),
              before?.options.any((o) => o.option == _options[i] && o.ai) ??
                  false,
            ),
          ),
    ];
    final photos = <FormPhotoNote>[
      for (var i = 0; i < _photos.length; i++)
        if (_photoTexts[i].text.trim().isNotEmpty)
          FormPhotoNote(
            url: _photos[i],
            text: _photoTexts[i].text.trim(),
            ai: _keepsAi(
              _photoTexts[i].text,
              before?.photoText(_photos[i]),
              before?.photos.any((p) => p.url == _photos[i] && p.ai) ?? false,
            ),
          ),
    ];
    return FormItemNote(
      text: text.isEmpty ? null : text,
      ai: text.isNotEmpty && _keepsAi(text, before?.text, before?.ai ?? false),
      options: options,
      photos: photos,
    );
  }

  void _done() => Navigator.of(context).pop(_result());

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fieldCount = 1 + _options.length + _photos.length;
    var index = 0;
    Widget field(TextEditingController controller, {Key? key}) {
      final last = ++index == fieldCount;
      return _NoteField(
        key: key,
        controller: controller,
        autofocus: index == 1,
        last: last,
        onDone: _done,
      );
    }

    return AppSheet(
      title: l10n.checklistNote,
      actionLabel: l10n.checklistQuestionDone,
      onAction: _done,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.blockMargin,
          AppSpacing.md,
          AppSpacing.blockMargin,
          AppSpacing.xl,
        ),
        children: [
          Text(
            widget.item.getLocalizedLabel(widget.localeCode),
            style: AppTypography.bodyStrong.copyWith(
              color: AppColors.text.resolveFrom(context),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          field(_text, key: const ValueKey('note_text')),
          for (var i = 0; i < _options.length; i++) ...[
            const SizedBox(height: AppSpacing.lg),
            _FieldLabel(
              localizedOption(widget.item, _options[i], widget.localeCode),
            ),
            field(_optionTexts[i], key: ValueKey('note_option_$i')),
          ],
          for (var i = 0; i < _photos.length; i++) ...[
            const SizedBox(height: AppSpacing.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FormPhotoThumb(url: _photos[i], size: 56),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _FieldLabel(l10n.checklistNotePhoto(i + 1)),
                      field(_photoTexts[i], key: ValueKey('note_photo_$i')),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(
        text,
        style: AppTypography.label.copyWith(
          color: AppColors.textSecondary.resolveFrom(context),
        ),
      ),
    );
  }
}

class _NoteField extends StatelessWidget {
  const _NoteField({
    super.key,
    required this.controller,
    required this.autofocus,
    required this.last,
    required this.onDone,
  });

  final TextEditingController controller;
  final bool autofocus;
  final bool last;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return CupertinoTextField(
      controller: controller,
      autofocus: autofocus,
      minLines: 1,
      maxLines: 4,
      padding: const EdgeInsets.all(AppSpacing.md),
      placeholder: context.l10n.checklistNotePlaceholder,
      style: AppTypography.body.copyWith(
        color: AppColors.text.resolveFrom(context),
      ),
      placeholderStyle: AppTypography.body.copyWith(
        color: AppColors.textSecondary.resolveFrom(context),
      ),
      decoration: BoxDecoration(
        color: AppColors.secondaryFill.resolveFrom(context),
        borderRadius: BorderRadius.circular(AppRadii.field),
      ),
      textCapitalization: TextCapitalization.sentences,
      textInputAction: last ? TextInputAction.done : TextInputAction.next,
      onSubmitted: last ? (_) => onDone() : null,
    );
  }
}

/// Under the answer of a question: the note's lines (tap to edit) or the
/// "+ Observação" link when there is none.
class FormNoteSummary extends StatelessWidget {
  const FormNoteSummary({super.key, required this.lines, this.onEdit});

  final List<String> lines;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (lines.isEmpty) {
      if (onEdit == null) return const SizedBox.shrink();
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: CupertinoButton(
          key: const ValueKey('question_note_add'),
          padding: EdgeInsets.zero,
          minimumSize: const Size(
            AppSizes.minTouchTarget,
            AppSizes.minTouchTarget,
          ),
          onPressed: onEdit,
          child: Text(
            l10n.checklistNoteAdd,
            style: AppTypography.callout.copyWith(
              color: AppColors.accentText.resolveFrom(context),
            ),
          ),
        ),
      );
    }
    return Semantics(
      button: onEdit != null,
      child: GestureDetector(
        key: const ValueKey('question_note'),
        behavior: HitTestBehavior.opaque,
        onTap: onEdit,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.minTouchTarget),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                l10n.checklistNote,
                style: AppTypography.label.copyWith(
                  color: AppColors.textSecondary.resolveFrom(context),
                ),
              ),
              const SizedBox(height: 2),
              for (final line in lines)
                Text(
                  line,
                  style: AppTypography.callout.copyWith(
                    color: AppColors.text.resolveFrom(context),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
