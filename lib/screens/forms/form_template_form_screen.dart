import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show ReorderableListView;
import 'package:flutter/services.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/mobx/form_template_store.dart';
import 'package:praticos/models/form_definition.dart';
import 'package:praticos/screens/menu_navigation/more/more_page.dart';
import 'package:praticos/screens/order/new_order_form.dart';
import 'package:praticos/screens/widgets/add_row.dart';
import 'package:praticos/screens/widgets/app_form_field.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/screens/widgets/app_sheet.dart';
import 'package:praticos/screens/widgets/app_toast.dart';
import 'package:praticos/screens/widgets/form_sheet.dart';
import 'package:praticos/screens/widgets/glass_bar_button.dart';
import 'package:praticos/screens/widgets/more_fields_link.dart';
import 'package:praticos/screens/widgets/primary_button.dart';
import 'package:praticos/screens/widgets/pull_down_menu.dart';
import 'package:praticos/screens/widgets/section_label.dart';
import 'package:praticos/screens/widgets/status_dot.dart';
import 'package:praticos/services/feature_gate_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';
import 'package:praticos/widgets/photo_limit_dialog.dart';

/// How a question is answered, in the user's words.
String formItemTypeLabel(AppLocalizations l10n, FormItemType type) {
  switch (type) {
    case FormItemType.text:
      return l10n.formItemTypeText;
    case FormItemType.number:
      return l10n.formItemTypeNumber;
    case FormItemType.boolean:
      return l10n.formItemTypeBoolean;
    case FormItemType.select:
      return l10n.formItemTypeSelect;
    case FormItemType.checklist:
      return l10n.formItemTypeChecklist;
    case FormItemType.photoOnly:
      return l10n.formItemTypePhoto;
  }
}

/// Second line of a question row: "Sim ou não · obrigatória · com foto".
String formItemSubtitle(AppLocalizations l10n, FormItemDefinition item) => [
  formItemTypeLabel(l10n, item.type),
  if (item.required && item.type != FormItemType.photoOnly)
    l10n.checklistQuestionRequiredShort,
  if (item.allowPhotos && item.type != FormItemType.photoOnly)
    l10n.checklistQuestionWithPhoto,
].join(' · ');

/// New / edit checklist (form template).
///
/// A new one opens as a [FormSheet] (`asSheet: true`, open it with
/// [FormSheet.show]): "X" and "✓" at the top, the name in a white card, the
/// questions in a card below ("Adicionar pergunta", tap one to change it,
/// swipe to remove) and the description in "Mais dados". The "✓" turns blue
/// once it has a name and at least one question.
///
/// An existing one (the `template` route argument, or [template]) opens
/// pushed (prototype "app-checklist-editar"): the name as the large title,
/// "N perguntas" under it, "…" with "Não usar na empresa"/"Voltar a usar" and
/// "Apagar checklist", the name field, the numbered questions (tap opens the
/// question editor, long-press drags to reorder), "Adicionar pergunta", the
/// description in "Mais dados" and the blue "Salvar checklist".
///
/// Pops with the saved [FormDefinition].

/// Answer types in the order the editor offers them: the most common first.
const questionTypeOrder = [
  FormItemType.boolean,
  FormItemType.text,
  FormItemType.number,
  FormItemType.select,
  FormItemType.checklist,
  FormItemType.photoOnly,
];

class FormTemplateFormScreen extends StatefulWidget {
  const FormTemplateFormScreen({
    super.key,
    this.asSheet = false,
    this.template,
    this.onSave,
    this.onUpdate,
    this.onDelete,
    this.onSetActive,
  });

  /// Present as a [FormSheet] (new checklist).
  final bool asSheet;

  /// Checklist to edit; defaults to the `template` route argument.
  final FormDefinition? template;

  /// Saves a new checklist. Defaults to [FormTemplateStore.saveTemplate].
  final Future<void> Function(FormDefinition template)? onSave;

  /// Saves an existing checklist. Defaults to
  /// [FormTemplateStore.updateTemplate].
  final Future<void> Function(FormDefinition template)? onUpdate;

  /// Deletes the checklist. Defaults to [FormTemplateStore.deleteTemplate].
  final Future<void> Function(FormDefinition template)? onDelete;

  /// Turns the checklist on/off in the company right away. Defaults to
  /// [FormTemplateStore.toggleTemplateStatus].
  final Future<void> Function(FormDefinition template, bool active)?
  onSetActive;

  @override
  State<FormTemplateFormScreen> createState() => _FormTemplateFormScreenState();
}

class _FormTemplateFormScreenState extends State<FormTemplateFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  FormTemplateStore? _storeInstance;
  FormTemplateStore get _store => _storeInstance ??= FormTemplateStore();

  FormDefinition? _template;
  List<FormItemDefinition> _items = [];
  bool _isActive = true;
  bool _isLoading = false;
  bool _initialized = false;

  /// Name typed (kept in sync for the "✓" and the large title).
  String _title = '';

  /// Description typed on the pushed screen.
  String? _description;

  /// The questions changed (added, edited, removed or moved).
  bool _itemsChanged = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      final given =
          widget.template ??
          (args != null && args.containsKey('template')
              ? args['template'] as FormDefinition
              : null);
      if (given != null) {
        _template = given;
        _items = List.from(given.items);
        _isActive = given.isActive;
        _title = given.title;
        _description = given.description;
      } else {
        _template = FormDefinition(
          id: FirebaseFirestore.instance.collection('tmp').doc().id,
          title: '',
          isActive: true,
          items: [],
        );
      }
      _initialized = true;
    }
  }

  bool get _isEditing => _template?.createdAt != null;

  bool get _canSave => _title.trim().isNotEmpty && _items.isNotEmpty;

  /// What is missing for the save button, or null when it can save.
  String? get _missingHint {
    if (_canSave) return null;
    final l10n = context.l10n;
    if (_title.trim().isEmpty) {
      return _items.isEmpty
          ? l10n.checklistSaveNeedsNameAndQuestion
          : l10n.customerSaveNeedsName;
    }
    return l10n.checklistSaveNeedsQuestion;
  }

  /// Something was filled since the sheet opened: closing asks first.
  bool get _dirty {
    if (!_isEditing) {
      return _title.trim().isNotEmpty ||
          _items.isNotEmpty ||
          (_template?.description?.trim().isNotEmpty ?? false);
    }
    return _itemsChanged ||
        _title.trim() != _template!.title.trim() ||
        (_description?.trim() ?? '') != (_template!.description?.trim() ?? '');
  }

  Future<void> _saveTemplate() async {
    if (!_canSave || _isLoading) return;
    _formKey.currentState?.save();

    setState(() => _isLoading = true);
    try {
      final template = _template!;
      template.title = _title.trim();
      if (!widget.asSheet || _isEditing) {
        final description = _description?.trim();
        template.description = (description?.isEmpty ?? true)
            ? null
            : description;
      }
      template.items = List.of(_items);
      template.isActive = _isActive;

      if (_isEditing) {
        await (widget.onUpdate ?? _store.updateTemplate)(template);
      } else {
        await (widget.onSave ?? _store.saveTemplate)(template);
      }

      if (mounted) {
        HapticFeedback.mediumImpact();
        Navigator.pop(context, template);
      }
    } on FeatureGateLimitException catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        setState(() => _isLoading = false);
        showFeatureLimitDialog(context, e.result);
      }
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        setState(() => _isLoading = false);
        _showError();
      }
    }
  }

  void _showError() {
    showAppToast(
      context,
      context.l10n.checklistSaveError,
      icon: CupertinoIcons.exclamationmark_circle_fill,
    );
  }

  Future<void> _addItem() async {
    final result = await _QuestionEditor.open(context, null);
    final item = result?.item;
    if (item == null || !mounted) return;
    setState(() {
      _items.add(item);
      _itemsChanged = true;
    });
    HapticFeedback.selectionClick();
  }

  Future<void> _editItem(int index) async {
    final current = _items[index];
    final result = await _QuestionEditor.open(context, current);
    if (result == null || !mounted) return;
    // The list may have changed meanwhile: find the question again.
    final at = _items.indexOf(current);
    if (at < 0) return;
    setState(() {
      if (result.deleted) {
        _items.removeAt(at);
      } else {
        _items[at] = result.item!;
      }
      _itemsChanged = true;
    });
    HapticFeedback.selectionClick();
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
      _itemsChanged = true;
    });
    HapticFeedback.mediumImpact();
  }

  // ─── "…" menu ────────────────────────────────────────────────────────────

  Future<void> _openMenu() async {
    final l10n = context.l10n;
    final choice = await showPullDownMenu(
      context,
      groups: [
        PullDownGroup([
          if (_isActive)
            PullDownItem(
              value: 'off',
              label: l10n.checklistStopUsing,
              icon: CupertinoIcons.pause_circle,
            )
          else
            PullDownItem(
              value: 'on',
              label: l10n.checklistUseAgain,
              icon: CupertinoIcons.play_circle,
            ),
        ]),
        PullDownGroup([
          PullDownItem(
            value: 'delete',
            label: l10n.checklistDelete,
            icon: CupertinoIcons.trash,
            destructive: true,
          ),
        ]),
      ],
    );
    if (!mounted) return;
    switch (choice) {
      case 'off':
        await _setActive(false);
      case 'on':
        await _setActive(true);
      case 'delete':
        await _confirmDelete();
    }
  }

  Future<void> _setActive(bool active) async {
    final template = _template!;
    try {
      final onSetActive = widget.onSetActive;
      if (onSetActive != null) {
        await onSetActive(template, active);
      } else if (template.isActive != active) {
        await _store.toggleTemplateStatus(template);
      }
      template.isActive = active;
      if (mounted) {
        setState(() => _isActive = active);
        HapticFeedback.selectionClick();
      }
    } on FeatureGateLimitException catch (e) {
      if (mounted) showFeatureLimitDialog(context, e.result);
    } catch (_) {
      if (mounted) _showError();
    }
  }

  Future<void> _confirmDelete() async {
    final l10n = context.l10n;
    final name = _template!.title;
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(l10n.checklistDeleteTitle),
        content: Text(l10n.checklistDeleteMessage(name)),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          CupertinoDialogAction(
            key: const ValueKey('checklist_delete_confirm'),
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.checklistDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await (widget.onDelete ?? _store.deleteTemplate)(_template!);
      if (mounted) {
        HapticFeedback.mediumImpact();
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) _showError();
    }
  }

  // ─── Leaving ─────────────────────────────────────────────────────────────

  Future<void> _confirmDiscard() async {
    final l10n = context.l10n;
    final leave = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(l10n.orderDiscardTitle),
        content: Text(l10n.orderDiscardMessage),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.orderKeepEditing),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.discard),
          ),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.pop(context);
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (widget.asSheet && !_isEditing) return _buildSheet();
    return _buildPushed();
  }

  /// Existing checklist (prototype "app-checklist-editar").
  Widget _buildPushed() {
    final l10n = context.l10n;
    final name = _title.trim();
    final hint = _missingHint;
    return PopScope(
      canPop: !_dirty || _isLoading,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: Form(
        key: _formKey,
        child: MorePage(
          title: name.isNotEmpty
              ? name
              : (_isEditing ? l10n.checklist : l10n.checklistNew),
          fitTitle: true,
          previousPageTitle: l10n.checklistsTitle,
          trailing: _isEditing
              ? GlassBarButton(
                  key: const ValueKey('checklist_more'),
                  label: l10n.orderMoreActions,
                  icon: CupertinoIcons.ellipsis,
                  onPressed: _isLoading ? null : _openMenu,
                )
              : null,
          floatingButton: PrimaryButton(
            key: const ValueKey('checklist_save'),
            label: l10n.checklistSave,
            onPressed: _canSave && !_isLoading ? _saveTemplate : null,
          ),
          children: [
            _subtitle(),
            AppFormField(
              label: l10n.checklistNameLabel,
              initialValue: _title,
              placeholder: l10n.checklistNamePlaceholder,
              textCapitalization: TextCapitalization.sentences,
              autofocus: !_isEditing,
              onChanged: (v) => setState(() => _title = v),
            ),
            SectionLabel(l10n.checklistQuestionsTitle),
            _questionList(),
            AddRow(
              key: const ValueKey('checklist_add_question'),
              label: l10n.checklistAddQuestion,
              plain: true,
              onTap: _addItem,
            ),
            if (hint != null)
              Padding(
                key: const ValueKey('checklist_missing'),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageMargin,
                  0,
                  AppSpacing.pageMargin,
                  AppSpacing.sm,
                ),
                child: Text(
                  hint,
                  style: AppTypography.callout.copyWith(
                    color: AppColors.textSecondary.resolveFrom(context),
                  ),
                ),
              ),
            MoreFieldsLink(
              label: l10n.formMoreData,
              initiallyExpanded:
                  _template?.description?.trim().isNotEmpty ?? false,
              children: [
                AppFormField(
                  label: l10n.description,
                  initialValue: _description,
                  placeholder: l10n.optional,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 3,
                  onChanged: (v) => setState(() => _description = v),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// "5 perguntas", or "● Desligado · 5 perguntas" when it is off.
  Widget _subtitle() {
    final l10n = context.l10n;
    final secondary = AppColors.textSecondary.resolveFrom(context);
    final questions = l10n.checklistQuestions(_items.length);
    return Padding(
      key: const ValueKey('checklist_subtitle'),
      // Lined up with the large title, as MorePage.subtitle.
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.blockMargin,
        0,
        AppSpacing.pageMargin,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          if (!_isActive) ...[
            StatusDot(color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.xs + 2),
          ],
          Flexible(
            child: Text(
              _isActive ? questions : '${l10n.checklistOff} · $questions',
              style: AppTypography.callout.copyWith(color: secondary),
            ),
          ),
        ],
      ),
    );
  }

  /// Numbered questions; long-press drags to reorder.
  Widget _questionList() {
    final l10n = context.l10n;
    final separator = AppColors.separator.resolveFrom(context);
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: _items.length,
      onReorder: _onReorder,
      proxyDecorator: (child, index, animation) => DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface.resolveFrom(context),
          boxShadow: [
            BoxShadow(
              color: AppColors.text
                  .resolveFrom(context)
                  .withValues(alpha: 0.12),
              blurRadius: 12,
            ),
          ],
        ),
        child: child,
      ),
      itemBuilder: (context, i) {
        final item = _items[i];
        return Container(
          key: ValueKey('checklist_item_${item.id}'),
          color: AppColors.background.resolveFrom(context),
          child: Column(
            children: [
              if (i > 0)
                Container(
                  height: 0.5,
                  margin: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.pageMargin,
                  ),
                  color: separator,
                ),
              AppListRow(
                title: '${i + 1}. ${item.label}',
                subtitle: formItemSubtitle(l10n, item),
                onTap: () => _editItem(i),
              ),
            ],
          ),
        );
      },
    );
  }

  /// The new-checklist sheet (design system rule 9).
  Widget _buildSheet() {
    final l10n = context.l10n;
    return Form(
      key: _formKey,
      child: FormSheet(
        title: l10n.checklistNew,
        canSave: _canSave,
        missingHint: _missingHint,
        dirty: _dirty,
        busy: _isLoading,
        onSave: _saveTemplate,
        children: [
          FormFieldsCard(
            children: [
              AppFormField(
                label: l10n.name,
                initialValue: _template?.title,
                placeholder: l10n.checklistNamePlaceholder,
                textCapitalization: TextCapitalization.sentences,
                autofocus: true,
                onChanged: (v) => setState(() => _title = v),
              ),
            ],
          ),
          FormCard(
            title: l10n.checklistQuestionsTitle,
            children: [
              for (var i = 0; i < _items.length; i++)
                Dismissible(
                  key: ValueKey('checklist_item_${_items[i].id}'),
                  direction: DismissDirection.endToStart,
                  background: ColoredBox(
                    color: AppColors.danger.resolveFrom(context),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 20),
                        child: Icon(
                          CupertinoIcons.trash,
                          color: AppColors.onAccent.resolveFrom(context),
                        ),
                      ),
                    ),
                  ),
                  onDismissed: (_) => setState(() => _items.removeAt(i)),
                  child: FormRow(
                    title: '${i + 1}. ${_items[i].label}',
                    subtitle: formItemSubtitle(l10n, _items[i]),
                    onTap: () => _editItem(i),
                  ),
                ),
              FormRow(
                key: const ValueKey('checklist_add_question'),
                icon: CupertinoIcons.plus_circle_fill,
                title: l10n.checklistAddQuestion,
                accent: true,
                onTap: _addItem,
              ),
            ],
          ),
          FormMoreCard(
            title: l10n.formMoreData,
            hint: l10n.description,
            children: [
              AppFormField(
                label: l10n.description,
                initialValue: _template?.description,
                placeholder: l10n.optional,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
                onChanged: (v) => setState(
                  () => _template?.description = v.trim().isEmpty
                      ? null
                      : v.trim(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Question editor
// ============================================================================

/// What the question editor resolved with: the saved question, or [deleted].
class _QuestionResult {
  const _QuestionResult.saved(FormItemDefinition this.item) : deleted = false;
  const _QuestionResult.deleted() : item = null, deleted = true;

  final FormItemDefinition? item;
  final bool deleted;
}

/// "Nova pergunta" / "Pergunta" (prototype "app-checklist-pergunta"): small
/// sheet with "Pronto" on the right (gray until the question can be saved,
/// with a line saying what is missing), the question, the answer type as an
/// inline choice with ✓, the options (one per line) for the choice types,
/// the "Obrigatória" and "Pode pôr foto" switches and, when editing,
/// "Apagar pergunta". Nothing is saved until the checklist is saved.
class _QuestionEditor extends StatefulWidget {
  const _QuestionEditor({this.existing});

  final FormItemDefinition? existing;

  static Future<_QuestionResult?> open(
    BuildContext context,
    FormItemDefinition? existing,
  ) {
    return AppSheet.show<_QuestionResult>(
      context,
      (_) => _QuestionEditor(existing: existing),
    );
  }

  @override
  State<_QuestionEditor> createState() => _QuestionEditorState();
}

class _QuestionEditorState extends State<_QuestionEditor> {
  late final TextEditingController _label;
  late final TextEditingController _options;
  late FormItemType _type;
  late bool _required;
  late bool _allowPhotos;

  @override
  void initState() {
    super.initState();
    final item = widget.existing;
    _label = TextEditingController(text: item?.label ?? '')
      ..addListener(_changed);
    _options = TextEditingController(text: item?.options?.join('\n') ?? '')
      ..addListener(_changed);
    _type = item?.type ?? FormItemType.text;
    _required = item?.required ?? false;
    _allowPhotos = item?.allowPhotos ?? true;
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _label.dispose();
    _options.dispose();
    super.dispose();
  }

  bool get _needsOptions =>
      _type == FormItemType.select || _type == FormItemType.checklist;

  List<String> get _optionList => _options.text
      .split('\n')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  String? get _missing {
    final l10n = context.l10n;
    if (_label.text.trim().isEmpty) return l10n.checklistQuestionNeedsLabel;
    if (_needsOptions && _optionList.length < 2) {
      return l10n.checklistQuestionNeedsOptions;
    }
    return null;
  }

  void _done() {
    final existing = widget.existing;
    final label = _label.text.trim();
    final options = _needsOptions ? _optionList : null;
    final item = FormItemDefinition(
      id: existing?.id ?? FirebaseFirestore.instance.collection('tmp').doc().id,
      label: label,
      type: _type,
      options: options,
      required: _type == FormItemType.photoOnly ? false : _required,
      allowPhotos: _allowPhotos,
      // Keep the translations of a ready checklist while the text is the same.
      labelI18n: existing?.label == label ? existing?.labelI18n : null,
      optionsI18n:
          const ListEquality<String>().equals(existing?.options, options)
          ? existing?.optionsI18n
          : null,
    );
    Navigator.pop(context, _QuestionResult.saved(item));
  }

  void _setType(FormItemType type) {
    if (type == _type) return;
    setState(() => _type = type);
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final missing = _missing;
    final secondary = AppColors.textSecondary.resolveFrom(context);
    return AppSheet(
      title: widget.existing == null
          ? l10n.checklistQuestionNew
          : l10n.checklistQuestion,
      actionLabel: l10n.checklistQuestionDone,
      onAction: missing == null ? _done : null,
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: [
          Padding(
            key: const ValueKey('question_missing'),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageMargin,
              AppSpacing.xs,
              AppSpacing.pageMargin,
              0,
            ),
            child: Text(
              missing ?? '',
              style: AppTypography.callout.copyWith(color: secondary),
            ),
          ),
          AppFormField(
            label: l10n.checklistQuestion,
            controller: _label,
            placeholder: l10n.checklistQuestionPlaceholder,
            textCapitalization: TextCapitalization.sentences,
            autofocus: widget.existing == null,
          ),
          SectionLabel(l10n.checklistAnswerType),
          MoreRows(
            rows: [
              for (final type in questionTypeOrder)
                AppListRow(
                  key: ValueKey('question_type_${type.name}'),
                  title: formItemTypeLabel(l10n, type),
                  selected: type == _type,
                  showChevron: false,
                  onTap: () => _setType(type),
                ),
            ],
          ),
          if (_needsOptions) ...[
            const SizedBox(height: AppSpacing.md),
            AppFormField(
              key: const ValueKey('question_options'),
              label: l10n.checklistOptions,
              controller: _options,
              placeholder: l10n.checklistOptionsPlaceholder,
              hint: l10n.typeOneOptionPerLine,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 6,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          MoreRows(
            rows: [
              if (_type != FormItemType.photoOnly)
                MoreSwitchRow(
                  key: const ValueKey('question_required'),
                  title: l10n.checklistQuestionRequired,
                  subtitle: l10n.checklistQuestionRequiredHint,
                  value: _required,
                  onChanged: (v) {
                    setState(() => _required = v);
                    HapticFeedback.selectionClick();
                  },
                ),
              MoreSwitchRow(
                key: const ValueKey('question_photos'),
                title: l10n.checklistQuestionAllowPhotos,
                value: _allowPhotos,
                onChanged: (v) {
                  setState(() => _allowPhotos = v);
                  HapticFeedback.selectionClick();
                },
              ),
            ],
          ),
          if (widget.existing != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pageMargin,
                vertical: AppSpacing.lg,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: CupertinoButton(
                  key: const ValueKey('question_delete'),
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(
                    AppSizes.minTouchTarget,
                    AppSizes.minTouchTarget,
                  ),
                  onPressed: () =>
                      Navigator.pop(context, const _QuestionResult.deleted()),
                  child: Text(
                    l10n.checklistQuestionDelete,
                    style: AppTypography.callout.copyWith(
                      color: AppColors.danger.resolveFrom(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
