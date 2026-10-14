import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/models/form_definition.dart';
import 'package:praticos/models/order_form.dart';
import 'package:praticos/screens/widgets/glass_bar_button.dart';
import 'package:praticos/screens/widgets/primary_button.dart';
import 'package:praticos/screens/widgets/text_link.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_glass.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';

/// Height of the answer buttons (yes/no and options): bigger than the usual
/// 44 so a tap with a dirty or gloved finger still hits.
const double kAnswerButtonHeight = 64;

/// Whether [item] has an answer: photos for a photo question, a non-empty
/// value (a non-empty list for multiple choice) for the others.
bool isFormItemAnswered(FormItemDefinition item, FormResponse? response) {
  if (response == null) return false;
  if (item.type == FormItemType.photoOnly) return response.photoUrls.isNotEmpty;
  final value = response.value;
  if (value == null) return false;
  if (value is List) return value.isNotEmpty;
  return value.toString().trim().isNotEmpty;
}

/// How many questions of [form] still have no answer ("Faltam N").
int formItemsMissing(OrderForm form) => form.items
    .where((item) => !isFormItemAnswered(item, form.getResponse(item.id)))
    .length;

/// Index of the first question without an answer, or null when all have one.
int? firstUnansweredIndex(OrderForm form) {
  for (var i = 0; i < form.items.length; i++) {
    final item = form.items[i];
    if (!isFormItemAnswered(item, form.getResponse(item.id))) return i;
  }
  return null;
}

/// "Uma pergunta por vez" (checklists spec, boards "Checklists · 2" and "3"):
/// one question per screen, in big letters, under a segmented progress bar
/// and "Faltam N".
///
/// - Yes/No and single choice: big buttons ([kAnswerButtonHeight]); a tap
///   saves and moves to the next question.
/// - Multiple choice: the same buttons with a ✓ on each, and "Pronto".
/// - Text and number: a big field with the keyboard open and "Próxima".
/// - Photo question: "Tirar foto" (or "Próxima" once there is a photo) and
///   "Escolher da galeria".
/// - Any question that allows photos: a glass "Foto" button at the bottom,
///   always in the same place.
/// - "Pular por agora" on every question and "Voltar à anterior".
///
/// Presentational: the screen that opens it ([FormFillScreen]) saves through
/// [onAnswer]/[onAddPhoto] and rebuilds it with the updated [form]. After the
/// last question it calls [onEnd]; "Fechar" calls [onClose].
class FormQuestionSheet extends StatefulWidget {
  const FormQuestionSheet({
    super.key,
    required this.form,
    required this.onAnswer,
    required this.onEnd,
    required this.onClose,
    this.initialIndex = 0,
    this.localeCode,
    this.onAddPhoto,
    this.onOpenPhoto,
    this.uploadingItemId,
  });

  final OrderForm form;
  final int initialIndex;
  final String? localeCode;

  /// Saves [value] as the answer of [item]. Not awaited: the sheet moves on
  /// right away (the screen updates [form] before saving).
  final void Function(FormItemDefinition item, dynamic value) onAnswer;

  /// Takes or picks photos for [item].
  final void Function(FormItemDefinition item, ImageSource source)? onAddPhoto;

  /// Opens photo [index] of [item] in full screen.
  final void Function(FormItemDefinition item, int index)? onOpenPhoto;

  /// Item whose photos are being uploaded.
  final String? uploadingItemId;

  /// After the last question ("Próxima", an answer or "Pular por agora").
  final VoidCallback onEnd;
  final VoidCallback onClose;

  @override
  State<FormQuestionSheet> createState() => _FormQuestionSheetState();
}

class _FormQuestionSheetState extends State<FormQuestionSheet> {
  late int _index = widget.initialIndex.clamp(
    0,
    widget.form.items.isEmpty ? 0 : widget.form.items.length - 1,
  );

  /// What is typed in the text/number field of the current question.
  String? _draft;

  List<FormItemDefinition> get _items => widget.form.items;
  FormItemDefinition get _item => _items[_index];
  FormResponse? _responseOf(FormItemDefinition item) =>
      widget.form.getResponse(item.id);

  void _goTo(int index) {
    setState(() {
      _index = index;
      _draft = null;
    });
  }

  /// Goes to the next question still without an answer (answered ones are
  /// reviewed by "Voltar à anterior"); ends when none is left after this one.
  void _next() {
    for (var i = _index + 1; i < _items.length; i++) {
      if (!isFormItemAnswered(_items[i], _responseOf(_items[i]))) {
        _goTo(i);
        return;
      }
    }
    widget.onEnd();
  }

  /// Saves what was typed and not saved yet (leaving the question by
  /// "Voltar à anterior" or "Fechar" keeps it).
  void _flushDraft() {
    final draft = _draft;
    if (draft == null) return;
    final saved = _responseOf(_item)?.value?.toString() ?? '';
    if (draft.trim() != saved) widget.onAnswer(_item, draft.trim());
    _draft = null;
  }

  void _answerAndNext(dynamic value) {
    HapticFeedback.selectionClick();
    widget.onAnswer(_item, value);
    _next();
  }

  void _submitText(String text) {
    _draft = text;
    _flushDraft();
    _next();
  }

  void _submitMulti(List<String> selected) {
    final saved = _responseOf(_item)?.value;
    final before = saved is List ? saved.map((e) => e.toString()).toList() : [];
    final changed =
        before.length != selected.length || !before.every(selected.contains);
    if (changed) widget.onAnswer(_item, selected);
    _next();
  }

  void _skip() {
    _draft = null;
    _next();
  }

  void _previous() {
    _flushDraft();
    if (_index > 0) _goTo(_index - 1);
  }

  void _close() {
    _flushDraft();
    widget.onClose();
  }

  Future<void> _choosePhotoSource() async {
    final add = widget.onAddPhoto;
    if (add == null) return;
    final item = _item;
    final l10n = context.l10n;
    final source = await showCupertinoModalPopup<ImageSource>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, ImageSource.camera),
            child: Text(l10n.orderAssistantTakePhoto),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
            child: Text(l10n.checklistPickFromGallery),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l10n.cancel),
        ),
      ),
    );
    if (source != null) add(item, source);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_items.isEmpty) {
      return CupertinoPageScaffold(
        backgroundColor: AppColors.background.resolveFrom(context),
        child: SafeArea(child: _topBar(context)),
      );
    }
    final item = _item;
    final response = _responseOf(item);
    final missing = formItemsMissing(widget.form);
    final photos = response?.photoUrls ?? const <String>[];
    final uploading = widget.uploadingItemId == item.id;
    final photoButton =
        item.allowPhotos &&
        item.type != FormItemType.photoOnly &&
        widget.onAddPhoto != null;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background.resolveFrom(context),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _topBar(context),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageMargin,
                AppSpacing.xs,
                AppSpacing.pageMargin,
                0,
              ),
              child: _ProgressSegments(
                answered: [
                  for (final i in _items) isFormItemAnswered(i, _responseOf(i)),
                ],
                current: _index,
                label: l10n.checklistRemaining(missing),
              ),
            ),
            Expanded(
              child: ListView(
                key: ValueKey('question_list_${item.id}'),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.blockMargin,
                  AppSpacing.lg,
                  AppSpacing.blockMargin,
                  AppSpacing.xl,
                ),
                children: [
                  _textPad(
                    Text(
                      l10n.checklistRemaining(missing),
                      key: const ValueKey('question_remaining'),
                      style: AppTypography.callout.copyWith(
                        color: AppColors.textSecondary.resolveFrom(context),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _textPad(
                    Semantics(
                      header: true,
                      child: Text(
                        item.getLocalizedLabel(widget.localeCode),
                        key: const ValueKey('question_label'),
                        style: AppTypography.title.copyWith(
                          color: AppColors.text.resolveFrom(context),
                        ),
                      ),
                    ),
                  ),
                  if (item.required) ...[
                    const SizedBox(height: AppSpacing.xs),
                    _textPad(
                      Text(
                        l10n.checklistQuestionRequired,
                        style: AppTypography.label.copyWith(
                          color: AppColors.textSecondary.resolveFrom(context),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  KeyedSubtree(
                    key: ValueKey('answer_${item.id}'),
                    child: _answer(context, item, response, uploading),
                  ),
                  if (photos.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    _PhotoStrip(
                      photos: photos,
                      onOpen: widget.onOpenPhoto == null
                          ? null
                          : (i) => widget.onOpenPhoto!(item, i),
                    ),
                  ],
                ],
              ),
            ),
            _bottomBar(context, photoButton: photoButton, uploading: uploading),
          ],
        ),
      ),
    );
  }

  Widget _textPad(Widget child) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.pageMargin - AppSpacing.blockMargin,
    ),
    child: child,
  );

  Widget _topBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.blockMargin,
        AppSpacing.md,
        AppSpacing.blockMargin,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          GlassBarButton(
            key: const ValueKey('question_close'),
            label: context.l10n.close,
            icon: CupertinoIcons.xmark,
            onPressed: _close,
          ),
          Expanded(
            child: Text(
              widget.form.getLocalizedTitle(widget.localeCode),
              textAlign: TextAlign.center,
              style: AppTypography.bodyStrong.copyWith(
                color: AppColors.text.resolveFrom(context),
              ),
            ),
          ),
          // Balances the "X" so the title stays centered.
          const SizedBox(width: AppSizes.minTouchTarget),
        ],
      ),
    );
  }

  Widget _answer(
    BuildContext context,
    FormItemDefinition item,
    FormResponse? response,
    bool uploading,
  ) {
    final l10n = context.l10n;
    final value = response?.value;
    switch (item.type) {
      case FormItemType.boolean:
        return Column(
          children: [
            AnswerButton(
              key: const ValueKey('answer_yes'),
              label: l10n.yes,
              selected: value == true,
              onTap: () => _answerAndNext(true),
            ),
            const SizedBox(height: AppSpacing.md),
            AnswerButton(
              key: const ValueKey('answer_no'),
              label: l10n.no,
              selected: value == false,
              onTap: () => _answerAndNext(false),
            ),
          ],
        );
      case FormItemType.select:
        final options = _options(item);
        return Column(
          children: [
            for (var i = 0; i < options.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.md),
              AnswerButton(
                key: ValueKey('answer_option_$i'),
                label: options[i].label,
                selected: value?.toString() == options[i].value,
                // Saves the original option (the template's language).
                onTap: () => _answerAndNext(options[i].value),
              ),
            ],
          ],
        );
      case FormItemType.checklist:
        return _MultiQuestion(
          options: _options(item),
          initial: value is List
              ? value.map((e) => e.toString()).toList()
              : const <String>[],
          onDone: _submitMulti,
        );
      case FormItemType.text:
      case FormItemType.number:
        return _TextQuestion(
          initial: value?.toString() ?? '',
          number: item.type == FormItemType.number,
          onChanged: (text) => _draft = text,
          onSubmit: _submitText,
        );
      case FormItemType.photoOnly:
        final hasPhotos = (response?.photoUrls ?? const []).isNotEmpty;
        final add = widget.onAddPhoto;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (uploading)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CupertinoActivityIndicator(),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        l10n.orderUploading,
                        style: AppTypography.callout.copyWith(
                          color: AppColors.textSecondary.resolveFrom(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            PrimaryButton(
              key: const ValueKey('question_primary'),
              label: hasPhotos
                  ? l10n.checklistQuestionNext
                  : l10n.orderAssistantTakePhoto,
              icon: hasPhotos ? null : CupertinoIcons.camera,
              onPressed: uploading
                  ? null
                  : hasPhotos
                  ? _next
                  : add == null
                  ? null
                  : () => add(item, ImageSource.camera),
            ),
            if (add != null && !uploading) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: AppSpacing.xl,
                children: [
                  if (hasPhotos)
                    TextLink(
                      key: const ValueKey('question_more_photo'),
                      label: l10n.orderAssistantAddPhoto,
                      onPressed: () => add(item, ImageSource.camera),
                    ),
                  TextLink(
                    key: const ValueKey('question_gallery'),
                    label: l10n.checklistPickFromGallery,
                    onPressed: () => add(item, ImageSource.gallery),
                  ),
                ],
              ),
            ],
          ],
        );
    }
  }

  /// Options shown in the user's language, saved in the template's.
  List<({String value, String label})> _options(FormItemDefinition item) {
    final original = item.options ?? const <String>[];
    final localized = item.getLocalizedOptions(widget.localeCode) ?? original;
    return [
      for (var i = 0; i < localized.length; i++)
        (
          value: i < original.length ? original[i] : localized[i],
          label: localized[i],
        ),
    ];
  }

  Widget _bottomBar(
    BuildContext context, {
    required bool photoButton,
    required bool uploading,
  }) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageMargin,
        AppSpacing.sm,
        AppSpacing.pageMargin,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: _index > 0
                  ? TextLink(
                      key: const ValueKey('question_previous'),
                      label: l10n.checklistPreviousQuestion,
                      onPressed: _previous,
                    )
                  : const SizedBox.shrink(),
            ),
          ),
          if (photoButton)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: uploading
                  ? const SizedBox(
                      width: AppSizes.minTouchTarget,
                      height: AppSizes.minTouchTarget,
                      child: CupertinoActivityIndicator(),
                    )
                  : _GlassPhotoButton(
                      label: l10n.orderAssistantPhoto,
                      onPressed: _choosePhotoSource,
                    ),
            ),
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextLink(
                key: const ValueKey('question_skip'),
                label: l10n.checklistSkipForNow,
                onPressed: _skip,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One segment per question: filled in `accent` when answered; the current
/// one is taller. Read as "Faltam N" by screen readers.
class _ProgressSegments extends StatelessWidget {
  const _ProgressSegments({
    required this.answered,
    required this.current,
    required this.label,
  });

  final List<bool> answered;
  final int current;
  final String label;

  @override
  Widget build(BuildContext context) {
    final filled = AppColors.accent.resolveFrom(context);
    final empty = AppColors.separator.resolveFrom(context);
    final currentEmpty = AppColors.textSecondary.resolveFrom(context);
    return Semantics(
      key: const ValueKey('question_progress'),
      label: label,
      excludeSemantics: true,
      child: SizedBox(
        height: 6,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (var i = 0; i < answered.length; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Container(
                  height: i == current ? 6 : 4,
                  decoration: BoxDecoration(
                    color: answered[i]
                        ? filled
                        : (i == current ? currentEmpty : empty),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Big answer button (yes/no, an option): `secondaryFill`, at least
/// [kAnswerButtonHeight] high (it grows with the text), ✓ in `accentText`
/// and an `accent` border when [selected].
class AnswerButton extends StatelessWidget {
  const AnswerButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: kAnswerButtonHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg + AppSpacing.xs,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: AppColors.secondaryFill.resolveFrom(context),
            borderRadius: BorderRadius.circular(AppRadii.button),
            border: Border.all(
              width: 2,
              color: selected
                  ? AppColors.accent.resolveFrom(context)
                  : AppColors.secondaryFill.resolveFrom(context),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.bodyStrong.copyWith(
                    color: AppColors.onSecondaryFill.resolveFrom(context),
                  ),
                ),
              ),
              if (selected) ...[
                const SizedBox(width: AppSpacing.md),
                Icon(
                  CupertinoIcons.checkmark_alt,
                  key: const ValueKey('answer_check'),
                  color: AppColors.accentText.resolveFrom(context),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Multiple choice: tap marks/unmarks (✓), "Pronto" (enabled once something
/// is marked) saves and moves on.
class _MultiQuestion extends StatefulWidget {
  const _MultiQuestion({
    required this.options,
    required this.initial,
    required this.onDone,
  });

  final List<({String value, String label})> options;
  final List<String> initial;
  final ValueChanged<List<String>> onDone;

  @override
  State<_MultiQuestion> createState() => _MultiQuestionState();
}

class _MultiQuestionState extends State<_MultiQuestion> {
  late final List<String> _selected = [...widget.initial];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < widget.options.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.md),
          AnswerButton(
            key: ValueKey('answer_option_$i'),
            label: widget.options[i].label,
            selected: _selected.contains(widget.options[i].value),
            onTap: () {
              HapticFeedback.selectionClick();
              final value = widget.options[i].value;
              setState(() {
                if (!_selected.remove(value)) _selected.add(value);
              });
            },
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        PrimaryButton(
          key: const ValueKey('question_primary'),
          label: context.l10n.checklistQuestionDone,
          // Gray until something is marked; skipping is "Pular por agora".
          onPressed: _selected.isEmpty
              ? null
              : () => widget.onDone([..._selected]),
        ),
      ],
    );
  }
}

/// Text or number: big field with the keyboard open; "Próxima" (button or
/// keyboard) saves and moves on.
class _TextQuestion extends StatefulWidget {
  const _TextQuestion({
    required this.initial,
    required this.number,
    required this.onChanged,
    required this.onSubmit,
  });

  final String initial;
  final bool number;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmit;

  @override
  State<_TextQuestion> createState() => _TextQuestionState();
}

class _TextQuestionState extends State<_TextQuestion> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CupertinoTextField(
          key: const ValueKey('question_field'),
          controller: _controller,
          autofocus: true,
          minLines: 1,
          maxLines: widget.number ? 1 : 4,
          padding: const EdgeInsets.all(AppSpacing.lg),
          placeholder: context.l10n.checklistTextPlaceholder,
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
          keyboardType: widget.number
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.sentences,
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmit,
        ),
        const SizedBox(height: AppSpacing.xl),
        PrimaryButton(
          key: const ValueKey('question_primary'),
          label: context.l10n.checklistQuestionNext,
          onPressed: () => widget.onSubmit(_controller.text),
        ),
      ],
    );
  }
}

/// Photos of the question: a strip of thumbnails; a tap opens it.
class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({required this.photos, this.onOpen});

  final List<String> photos;
  final ValueChanged<int>? onOpen;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pageMargin - AppSpacing.blockMargin,
        ),
        itemCount: photos.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) => FormPhotoThumb(
          url: photos[i],
          size: 88,
          onTap: onOpen == null ? null : () => onOpen!(i),
        ),
      ),
    );
  }
}

/// Square photo thumbnail with rounded corners.
class FormPhotoThumb extends StatelessWidget {
  const FormPhotoThumb({
    super.key,
    required this.url,
    this.size = 64,
    this.onTap,
  });

  final String url;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fill = AppColors.secondaryFill.resolveFrom(context);
    return Semantics(
      image: true,
      button: onTap != null,
      label: context.l10n.photo,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.field),
          child: Image.network(
            url,
            width: size,
            height: size,
            fit: BoxFit.cover,
            loadingBuilder: (ctx, child, progress) => progress == null
                ? child
                : Container(
                    width: size,
                    height: size,
                    color: fill,
                    child: const Center(child: CupertinoActivityIndicator()),
                  ),
            errorBuilder: (ctx, error, stack) => Container(
              width: size,
              height: size,
              color: fill,
              child: Icon(
                CupertinoIcons.exclamationmark_triangle,
                size: 20,
                color: AppColors.textSecondary.resolveFrom(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Glass capsule with a camera and "Foto" (a control, like the OS's photo
/// button), always at the bottom center of the question.
class _GlassPhotoButton extends StatelessWidget {
  const _GlassPhotoButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.text.resolveFrom(context);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: CupertinoButton(
        key: const ValueKey('question_photo'),
        padding: EdgeInsets.zero,
        minimumSize: const Size(
          AppSizes.minTouchTarget,
          AppSizes.minTouchTarget,
        ),
        onPressed: onPressed,
        child: AppGlass(
          elevated: true,
          borderRadius: BorderRadius.circular(AppSizes.minTouchTarget / 2),
          child: Container(
            constraints: const BoxConstraints(
              minHeight: AppSizes.minTouchTarget,
            ),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.camera, size: 20, color: color),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  label,
                  style: AppTypography.callout.copyWith(color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
