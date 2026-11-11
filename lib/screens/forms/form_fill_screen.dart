import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/models/form_definition.dart';
import 'package:praticos/models/order_form.dart';
import 'package:praticos/screens/forms/form_question_sheet.dart';
import 'package:praticos/screens/forms/form_note_sheet.dart';
import 'package:praticos/screens/widgets/app_toast.dart';
import 'package:praticos/screens/widgets/glass_bar_button.dart';
import 'package:praticos/screens/widgets/primary_button.dart';
import 'package:praticos/screens/widgets/section_label.dart';
import 'package:praticos/screens/widgets/status_dot.dart';
import 'package:praticos/screens/widgets/text_link.dart';
import 'package:praticos/services/authorization_service.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/services/forms_service.dart';
import 'package:praticos/services/photo_service.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';
import 'package:praticos/utils/checklist_reading.dart';
import 'package:praticos/utils/device_reading.dart';
import 'package:provider/provider.dart';

/// A checklist of the OS: the summary of the answers, and the questions one
/// at a time ([FormQuestionSheet]).
///
/// - Top: back.
/// - Header: device, status (dot + text: "Faltam 3 perguntas", "Completo",
///   "Concluído · 2 sem resposta"), "Reabrir" as a link when completed,
///   and the one blue button: "Começar"/"Continuar" (opens the questions at
///   the first one without an answer) or "Concluir checklist".
/// - "Perguntas": a white card with each question and its answer; a tap opens
///   that question or, when completed, says so and offers "Reabrir".
///
/// A question linked to the device's reading ([readingLink],
/// `docs/DEVICE_READING.md`) is also the order's reading: answering it saves
/// both, an order that already has the reading answers it on opening, and a
/// value below the last visit's gets a notice ("Menor que os 102.000 km da
/// última visita. Está certo?") without blocking.
///
/// A checklist with no answer yet opens straight on the first question.
/// Answering the last one with nothing left completes the checklist and goes
/// back to the OS.
class FormFillScreen extends StatefulWidget {
  final String orderId;
  final String companyId;
  final OrderForm orderForm;
  final List<DeviceAggr>? devices;

  /// Links the reading question to the order; null: plain number question.
  final ChecklistReadingLink? readingLink;

  /// Injected in tests (the defaults talk to Firebase).
  final FormsService? formsService;
  final PhotoService? photoService;

  /// Who may reopen a completed checklist; defaults to
  /// [AuthorizationService.canReopenCompletedForms].
  final bool Function()? canReopen;

  /// Opens the questions right away when nothing was answered yet.
  final bool openQuestionsOnStart;

  const FormFillScreen({
    super.key,
    required this.orderId,
    required this.companyId,
    required this.orderForm,
    this.devices,
    this.readingLink,
    this.formsService,
    this.photoService,
    this.canReopen,
    this.openQuestionsOnStart = true,
  });

  @override
  _FormFillScreenState createState() => _FormFillScreenState();
}

class _FormFillScreenState extends State<FormFillScreen> {
  late final FormsService _formsService = widget.formsService ?? FormsService();
  late final PhotoService _photoService = widget.photoService ?? PhotoService();
  late OrderForm _currentForm;
  bool _isUploading = false;
  bool _isSaving = false;
  String? _uploadingItemId;

  /// Bumped on every change, so the open question sheet rebuilds.
  final ValueNotifier<int> _changes = ValueNotifier(0);

  /// Gets the current locale code for i18n (e.g., 'pt', 'en', 'es')
  String? get _localeCode => context.l10n.localeName;

  bool get _isCompleted => _currentForm.status == FormStatus.completed;

  @override
  void initState() {
    super.initState();
    _currentForm = widget.orderForm;
    // The model may come with const lists; answers are added in place.
    _currentForm.responses = List.of(_currentForm.responses);
    final nothingAnswered = _currentForm.responses.isEmpty;
    final prefill = _prefillReading();
    if (widget.openQuestionsOnStart &&
        !_isCompleted &&
        _currentForm.items.isNotEmpty &&
        nothingAnswered) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openQuestions();
      });
    }
    if (prefill.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        for (final (change, before) in prefill) {
          if (!mounted) return;
          await _persistChange(change, before);
        }
      });
    }
  }

  /// The order's reading answers the reading questions still empty: shown
  /// right away, saved after the first frame (returned as the changes to
  /// save, each with the responses before it).
  List<(FormAnswerChange, List<FormResponse>)> _prefillReading() {
    final link = widget.readingLink;
    final value = link?.orderReading();
    if (link == null || value == null) return const [];
    return [
      for (final item in unansweredReadingItems(_currentForm))
        () {
          final before = List.of(_currentForm.responses);
          // Saved as typed answers are (text).
          final change = FormValueChange(item.id, '$value');
          _applyLocally(change);
          return (change, before);
        }(),
    ];
  }

  /// An answer to the reading question is also the order's reading (and
  /// the device's last one). Below the last visit's: a notice, not a block.
  Future<void> _syncReading(String itemId, dynamic value) async {
    final link = widget.readingLink;
    if (link == null) return;
    final item = _currentForm.items.where((i) => i.id == itemId).firstOrNull;
    if (item == null || !item.isReading) return;
    final reading = parseReading(value);
    if (reading == null) return;
    if (reading != link.orderReading()) link.onReading(reading);
    final last = await link.lastVisit;
    if (!mounted || !readingBelowLastVisit(reading, last)) return;
    final format = FormatService()..setLocale(context.l10n.localeName);
    showAppToast(
      context,
      context.l10n.checklistReadingBelowLastVisit(
        formatReading(link.field, last, format) ?? '$last',
      ),
      icon: CupertinoIcons.exclamationmark_triangle_fill,
      duration: const Duration(seconds: 5),
    );
  }

  @override
  void dispose() {
    _changes.dispose();
    super.dispose();
  }

  /// setState that also rebuilds the question sheet.
  void _update(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
    _changes.value++;
  }

  /// Shows [change] on screen right away (only that question changes).
  void _applyLocally(FormAnswerChange change) {
    _currentForm.responses = applyAnswerChange(_currentForm.responses, change);
  }

  /// Saves [change] (only that question, like the web) and shows the
  /// checklist as the server has it after the change, with what the web
  /// answered meanwhile. [before] is the screen's responses before the
  /// change, for the offline queue. Throws when refused.
  Future<void> _saveChange(
    FormAnswerChange change,
    List<FormResponse> before,
  ) async {
    final fresh = await _formsService.saveAnswer(
      widget.companyId,
      widget.orderId,
      _currentForm.id,
      change,
      localKnown: before,
    );
    if (fresh != null) _update(() => _currentForm.responses = fresh);
  }

  Future<void> _saveItemResponse(String itemId, dynamic value) async {
    HapticFeedback.selectionClick();
    final before = List.of(_currentForm.responses);
    final change = FormValueChange(itemId, value);
    _update(() => _applyLocally(change));
    unawaited(_syncReading(itemId, value));
    await _persistChange(change, before);
  }

  /// Saves a change already shown on screen. Offline it is queued (see
  /// [FormsService.saveAnswer]); a refusal is told, never swallowed.
  Future<void> _persistChange(
    FormAnswerChange change,
    List<FormResponse> before,
  ) async {
    try {
      await _saveChange(change, before);
    } catch (e) {
      debugPrint('Could not save the checklist answer: $e');
      if (mounted) showAppToast(context, context.l10n.checklistAnswerSaveFailed);
    }
  }

  Future<void> _addPhoto(String itemId, ImageSource source) async {
    if (source == ImageSource.camera) {
      final file = await _photoService.takePhoto();
      if (file != null) {
        await _uploadSinglePhoto(itemId, file);
      }
    } else {
      final files = await _photoService.pickMultipleImagesFromGallery();
      if (files.isNotEmpty) {
        await _uploadMultiplePhotos(itemId, files);
      }
    }
  }

  Future<void> _uploadSinglePhoto(String itemId, File file) async {
    _update(() {
      _isUploading = true;
      _uploadingItemId = itemId;
    });

    try {
      final fileName = '${itemId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storagePath =
          'tenants/${widget.companyId}/orders/${widget.orderId}/forms/${_currentForm.id}/$fileName';

      final url = await _photoService.uploadImage(
        file: file,
        storagePath: storagePath,
      );

      if (url == null) throw Exception('Falha no upload');

      final before = List.of(_currentForm.responses);
      final change = FormPhotosAdded(itemId, [url]);
      await _saveChange(change, before);
      // Offline the photo is queued: show it already.
      if (_currentForm.getResponse(itemId)?.photoUrls.contains(url) != true) {
        _update(() => _applyLocally(change));
      }

      HapticFeedback.mediumImpact();
    } catch (e) {
      HapticFeedback.heavyImpact();
      if (mounted) {
        _showError(
          context.l10n.errorSendingPhoto,
          context.l10n.couldNotSendPhoto,
        );
      }
    } finally {
      _update(() {
        _isUploading = false;
        _uploadingItemId = null;
      });
    }
  }

  Future<void> _uploadMultiplePhotos(String itemId, List<File> files) async {
    _update(() {
      _isUploading = true;
      _uploadingItemId = itemId;
    });

    try {
      final uploaded = <String>[];
      int successCount = 0;

      for (final file in files) {
        try {
          final fileName =
              '${itemId}_${DateTime.now().millisecondsSinceEpoch}_$successCount.jpg';
          final storagePath =
              'tenants/${widget.companyId}/orders/${widget.orderId}/forms/${_currentForm.id}/$fileName';

          final url = await _photoService.uploadImage(
            file: file,
            storagePath: storagePath,
          );

          if (url != null) {
            uploaded.add(url);
            successCount++;
          }
        } catch (e) {
          debugPrint('Erro ao fazer upload de uma foto: $e');
        }
      }

      if (successCount > 0) {
        final before = List.of(_currentForm.responses);
        final change = FormPhotosAdded(itemId, uploaded);
        await _saveChange(change, before);
        // Offline the photos are queued: show them already.
        final shown = _currentForm.getResponse(itemId)?.photoUrls ?? const [];
        if (!uploaded.every(shown.contains)) {
          _update(() => _applyLocally(change));
        }

        HapticFeedback.mediumImpact();
      } else {
        throw Exception('Nenhuma foto foi enviada com sucesso');
      }
    } catch (e) {
      HapticFeedback.heavyImpact();
      if (mounted) {
        _showError(
          context.l10n.errorSendingPhotos,
          context.l10n.couldNotSendPhotos,
        );
      }
    } finally {
      _update(() {
        _isUploading = false;
        _uploadingItemId = null;
      });
    }
  }

  Future<void> _deletePhoto(String itemId, String url) async {
    HapticFeedback.mediumImpact();

    if (_currentForm.getResponse(itemId) == null) return;
    final before = List.of(_currentForm.responses);
    final note = _currentForm.noteOf(itemId);

    final change = FormPhotoRemoved(itemId, url);
    _update(() {
      _applyLocally(change);
      // The photo's note goes with it (saved in the same write).
      if (note != null) _setNoteLocally(itemId, note.withoutPhoto(url));
    });
    try {
      final fresh = await _formsService.saveAnswer(
        widget.companyId,
        widget.orderId,
        _currentForm.id,
        change,
        localKnown: before,
        localNote: note,
      );
      if (fresh != null) _update(() => _currentForm.responses = fresh);
    } catch (e) {
      debugPrint('Could not save the checklist answer: $e');
      if (mounted) showAppToast(context, context.l10n.checklistAnswerSaveFailed);
    }
  }

  void _setNoteLocally(String itemId, FormItemNote note) {
    _currentForm.notes = {..._currentForm.notes};
    if (note.isEmpty) {
      _currentForm.notes.remove(itemId);
    } else {
      _currentForm.notes[itemId] = note;
    }
  }

  /// Saves the note of a question (only `notes.{itemId}`: the answers are
  /// never rewritten). Shown right away; a refusal is told.
  Future<void> _saveNote(String itemId, FormItemNote note) async {
    _update(() => _setNoteLocally(itemId, note));
    try {
      await _formsService.saveNote(
        widget.companyId,
        widget.orderId,
        _currentForm.id,
        itemId,
        note,
      );
    } catch (e) {
      debugPrint('Could not save the checklist note: $e');
      if (mounted) showAppToast(context, context.l10n.checklistAnswerSaveFailed);
    }
  }

  void _showError(String title, String message) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.ok),
          ),
        ],
      ),
    );
  }

  Future<void> _finishForm() async {
    final missingRequired = _currentForm.items.where((item) {
      if (!item.required) return false;
      final response = _currentForm.getResponse(item.id);

      if (item.type == FormItemType.photoOnly) {
        return response == null || response.photoUrls.isEmpty;
      }

      return response == null ||
          response.value == null ||
          response.value.toString().isEmpty;
    }).toList();

    if (missingRequired.isNotEmpty) {
      HapticFeedback.heavyImpact();
      _showError(
        context.l10n.requiredFields,
        '${context.l10n.pleaseFill}\n${missingRequired.map((e) => "• ${e.getLocalizedLabel(_localeCode)}").join("\n")}',
      );
      return;
    }

    _update(() => _isSaving = true);

    try {
      await _formsService.updateStatus(
        widget.companyId,
        widget.orderId,
        _currentForm.id,
        FormStatus.completed,
      );

      if (mounted) {
        HapticFeedback.mediumImpact();
        _update(() {
          _currentForm.status = FormStatus.completed;
          _isSaving = false;
        });
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        _update(() => _isSaving = false);
        _showError(context.l10n.error, context.l10n.couldNotCompleteForm);
      }
    }
  }

  /// Verifica se o usuário atual pode reabrir procedimentos concluídos
  bool _canReopenForm() {
    final canReopen = widget.canReopen;
    if (canReopen != null) return canReopen();
    return AuthorizationService.instance.canReopenCompletedForms;
  }

  Future<void> _reopenForm() async {
    // Verifica se usuário tem permissão (apenas Admin, Manager e Supervisor)
    if (!_canReopenForm()) {
      HapticFeedback.heavyImpact();
      _showError(
        context.l10n.noPermission,
        context.l10n.noPermissionReopenForm,
      );
      return;
    }

    _update(() => _isSaving = true);

    try {
      await _formsService.updateStatus(
        widget.companyId,
        widget.orderId,
        _currentForm.id,
        FormStatus.inProgress,
      );

      if (mounted) {
        HapticFeedback.mediumImpact();
        _update(() {
          _currentForm.status = FormStatus.inProgress;
          _isSaving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        _update(() => _isSaving = false);
        _showError(context.l10n.error, context.l10n.couldNotReopenForm);
      }
    }
  }

  void _showPhotoPreview(String itemId, int photoIndex) {
    final response = _currentForm.getResponse(itemId);
    final photos = response?.photoUrls ?? [];

    if (photos.isEmpty) return;

    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => ChecklistPhotoGallery(
          photos: photos,
          initialIndex: photoIndex,
          // By url: after a removal the gallery's indexes no longer match
          // the original list.
          onDelete: _isCompleted
              ? null
              : (url) async {
                  await _deletePhoto(itemId, url);
                  return true;
                },
        ),
        fullscreenDialog: true,
      ),
    );
  }

  /// Opens the questions one at a time, at [index] (default: the first one
  /// without an answer).
  Future<void> _openQuestions([int? index]) async {
    if (_currentForm.items.isEmpty || _isCompleted) return;
    final start = index ?? firstUnansweredIndex(_currentForm) ?? 0;
    await Navigator.of(context).push(
      CupertinoSheetRoute<void>(
        builder: (sheetContext) => ValueListenableBuilder<int>(
          valueListenable: _changes,
          builder: (_, _, _) => FormQuestionSheet(
            form: _currentForm,
            initialIndex: start,
            localeCode: _localeCode,
            uploadingItemId: _uploadingItemId,
            onAnswer: (item, value) => _saveItemResponse(item.id, value),
            onAddPhoto: (item, source) => _addPhoto(item.id, source),
            onOpenPhoto: (item, i) => _showPhotoPreview(item.id, i),
            onNote: (item, note) => _saveNote(item.id, note),
            onClose: () => Navigator.of(sheetContext).pop(),
            onEnd: () {
              Navigator.of(sheetContext).pop();
              // Last question answered and nothing left: done.
              if (formItemsMissing(_currentForm) == 0) _finishForm();
            },
          ),
        ),
      ),
    );
  }

  /// A tap on a question of a completed checklist: says it is completed and
  /// offers "Reabrir" (or who can reopen it).
  Future<void> _explainCompleted() async {
    if (_isSaving) return;
    final l10n = context.l10n;
    final canReopen = _canReopenForm();
    final reopen = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(l10n.checklistDoneTitle),
        content: Text(
          canReopen
              ? l10n.checklistDoneReopenBody
              : l10n.checklistDoneAskReopenBody,
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(canReopen ? l10n.cancel : l10n.ok),
          ),
          if (canReopen)
            CupertinoDialogAction(
              key: const ValueKey('form_fill_done_reopen'),
              isDefaultAction: true,
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.reopen),
            ),
        ],
      ),
    );
    if (reopen == true) _reopenForm();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // A record screen: short title in the bar, the checklist name in the
    // header, where it wraps instead of being cut (design system rule 8).
    return CupertinoPageScaffold(
      backgroundColor: AppColors.groupedBackground.resolveFrom(context),
      navigationBar: CupertinoNavigationBar(
        automaticallyImplyLeading: false,
        leading: const GlassBackButton(),
        middle: Text(l10n.checklist),
        backgroundColor: AppColors.groupedBackground
            .resolveFrom(context)
            .withValues(alpha: 0.8),
        border: null,
        trailing: _isSaving ? const CupertinoActivityIndicator() : null,
      ),
      child: CustomScrollView(
        slivers: [
          SliverSafeArea(
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pageMargin,
                    AppSpacing.lg,
                    AppSpacing.pageMargin,
                    AppSpacing.xs,
                  ),
                  child: Text(
                    _currentForm.getLocalizedTitle(_localeCode),
                    key: const ValueKey('form_fill_title'),
                    style: AppTypography.title.copyWith(
                      fontSize: 28,
                      color: AppColors.text.resolveFrom(context),
                    ),
                  ),
                ),
                _buildHeader(context),
                if (_currentForm.items.isNotEmpty) ...[
                  SectionLabel(l10n.checklistQuestionsTitle),
                  _buildQuestionsCard(context),
                ],
                const SizedBox(height: AppSpacing.xxl),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  /// Device, status (dot + text) and the next step button.
  Widget _buildHeader(BuildContext context) {
    final l10n = context.l10n;
    final missing = formItemsMissing(_currentForm);
    final answeredAny = missing < _currentForm.items.length;
    final device = _device();
    final secondary = AppColors.textSecondary.resolveFrom(context);

    final Color dot;
    final String status;
    if (_isCompleted) {
      dot = AppColors.success;
      status = completedChecklistLabel(l10n, _currentForm);
    } else if (missing > 0) {
      dot = AppColors.warning;
      status = l10n.orderChecklistMissing(missing);
    } else {
      dot = AppColors.accentText;
      status = l10n.checklistRemaining(0);
    }

    final requiredMissing = _currentForm.items.any(
      (item) =>
          item.required &&
          !isFormItemAnswered(item, _currentForm.getResponse(item.id)),
    );

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (device != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageMargin,
                0,
                AppSpacing.pageMargin,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Icon(
                    context.watch<SegmentConfigProvider>().deviceIcon,
                    size: 20,
                    color: secondary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      device,
                      key: const ValueKey('form_fill_device'),
                      style: AppTypography.callout.copyWith(color: secondary),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pageMargin,
            ),
            child: Row(
              children: [
                StatusDot(color: dot, size: 10),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    status,
                    key: const ValueKey('form_fill_status'),
                    style: AppTypography.body.copyWith(color: secondary),
                  ),
                ),
              ],
            ),
          ),
          // Reopening in sight, not hidden in a menu.
          if (_isCompleted && _canReopenForm())
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageMargin,
                  AppSpacing.xs,
                  AppSpacing.pageMargin,
                  0,
                ),
                child: TextLink(
                  key: const ValueKey('form_fill_reopen'),
                  label: l10n.reopen,
                  onPressed: _isSaving ? null : _reopenForm,
                ),
              ),
            ),
          if (!_isCompleted && _currentForm.items.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.blockMargin,
              ),
              child: PrimaryButton(
                key: const ValueKey('form_fill_primary'),
                label: missing == 0
                    ? l10n.checklistFinish
                    : answeredAny
                    ? l10n.continue_
                    : l10n.checklistStart,
                onPressed: _isSaving
                    ? null
                    : missing == 0
                    ? _finishForm
                    : () => _openQuestions(),
              ),
            ),
            // Optional questions left: finishing is still possible.
            if (missing > 0 && answeredAny && !requiredMissing)
              Center(
                child: TextLink(
                  key: const ValueKey('form_fill_finish_anyway'),
                  label: l10n.checklistFinishAnyway,
                  onPressed: _isSaving ? null : _finishForm,
                ),
              ),
          ],
        ],
      ),
    );
  }

  String? _device() {
    final deviceId = _currentForm.deviceId;
    if (deviceId == null || widget.devices == null) return null;
    final device = widget.devices!.cast<DeviceAggr?>().firstWhere(
      (d) => d?.id == deviceId,
      orElse: () => null,
    );
    if (device == null) return null;
    return device.serial != null && device.serial!.trim().isNotEmpty
        ? '${device.name} · ${device.serial}'
        : device.name;
  }

  Widget _buildQuestionsCard(BuildContext context) {
    final separator = AppColors.separator.resolveFrom(context);
    final items = _currentForm.items;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.blockMargin),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.block),
        child: ColoredBox(
          color: AppColors.surface.resolveFrom(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0)
                  Container(
                    height: 0.5,
                    margin: const EdgeInsets.only(left: AppSpacing.lg),
                    color: separator,
                  ),
                _buildQuestionRow(context, i),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Question, its answer (or "Sem resposta") and the photos.
  Widget _buildQuestionRow(BuildContext context, int index) {
    final l10n = context.l10n;
    final item = _currentForm.items[index];
    final response = _currentForm.getResponse(item.id);
    final answered = isFormItemAnswered(item, response);
    final photos = response?.photoUrls ?? const <String>[];
    final secondary = AppColors.textSecondary.resolveFrom(context);
    final canOpen = !_isCompleted;
    final isUploadingThis = _isUploading && _uploadingItemId == item.id;

    final answer = _answerText(item, response);
    final subtitle = answered
        ? answer
        : item.required
        ? '${l10n.checklistNoAnswer} · ${l10n.checklistQuestionRequired}'
        : l10n.checklistNoAnswer;

    return Semantics(
      button: true,
      child: GestureDetector(
        key: ValueKey('form_fill_item_${item.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: canOpen ? () => _openQuestions(index) : _explainCompleted,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.minTouchTarget),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.getLocalizedLabel(_localeCode),
                        style: AppTypography.body.copyWith(
                          color: AppColors.text.resolveFrom(context),
                        ),
                      ),
                      if (subtitle != null && subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: AppTypography.callout.copyWith(
                            color: answered
                                ? AppColors.text.resolveFrom(context)
                                : secondary,
                            fontWeight: answered
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                      for (final line in formNoteLines(
                        l10n,
                        item,
                        _currentForm.noteOf(item.id),
                        response,
                        _localeCode,
                      )) ...[
                        const SizedBox(height: 2),
                        Text(
                          line,
                          style: AppTypography.callout.copyWith(
                            color: AppColors.textTertiary.resolveFrom(context),
                          ),
                        ),
                      ],
                      if (isUploadingThis)
                        const Padding(
                          padding: EdgeInsets.only(top: AppSpacing.sm),
                          child: CupertinoActivityIndicator(),
                        ),
                      if (photos.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            for (var p = 0; p < photos.length; p++)
                              FormPhotoThumb(
                                url: photos[p],
                                size: 56,
                                onTap: () => _showPhotoPreview(item.id, p),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (canOpen) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Icon(
                    CupertinoIcons.chevron_forward,
                    size: 18,
                    color: secondary,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The answer in words: "Sim", the option in the user's language, "Óleo,
  /// Filtro", the text, or "2 fotos" for a photo question.
  String? _answerText(FormItemDefinition item, FormResponse? response) {
    final l10n = context.l10n;
    final value = response?.value;
    final photos = response?.photoUrls.length ?? 0;
    String? text;
    switch (item.type) {
      case FormItemType.boolean:
        if (value is bool) text = value ? l10n.yes : l10n.no;
      case FormItemType.select:
        if (value != null) text = _localizedOption(item, value.toString());
      case FormItemType.checklist:
        if (value is List && value.isNotEmpty) {
          text = value
              .map((v) => _localizedOption(item, v.toString()))
              .join(', ');
        }
      case FormItemType.text:
      case FormItemType.number:
        final s = value?.toString().trim();
        if (s != null && s.isNotEmpty) text = s;
      case FormItemType.photoOnly:
        return photos > 0 ? l10n.nPhotosCount(photos) : null;
    }
    return text;
  }

  String _localizedOption(FormItemDefinition item, String original) =>
      localizedOption(item, original, _localeCode);
}

/// Photos of a question in full screen (black, like the iPhone's photo
/// viewer), swipe between them, trash to remove.
class ChecklistPhotoGallery extends StatefulWidget {
  final List<String> photos;
  final int initialIndex;
  final Future<bool> Function(String url)? onDelete;

  const ChecklistPhotoGallery({
    required this.photos,
    required this.initialIndex,
    this.onDelete,
  });

  @override
  _ChecklistPhotoGalleryState createState() => _ChecklistPhotoGalleryState();
}

class _ChecklistPhotoGalleryState extends State<ChecklistPhotoGallery> {
  late PageController _pageController;
  late int _currentIndex;
  late List<String> _photos;

  @override
  void initState() {
    super.initState();
    _photos = List.from(widget.photos);
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.black.withValues(alpha: 0.8),
        border: null,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context),
          child: const Icon(CupertinoIcons.back, color: CupertinoColors.white),
        ),
        middle: Text(
          context.l10n.checklistPhotoPosition(
            _currentIndex + 1,
            _photos.length,
          ),
          style: const TextStyle(color: CupertinoColors.white),
        ),
        trailing: widget.onDelete != null
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _confirmDelete,
                child: const Icon(
                  CupertinoIcons.trash,
                  color: CupertinoColors.white,
                ),
              )
            : null,
      ),
      child: SafeArea(
        child: PageView.builder(
          controller: _pageController,
          itemCount: _photos.length,
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          itemBuilder: (context, index) {
            final url = _photos[index];
            return InteractiveViewer(
              minScale: 0.5,
              maxScale: 3.0,
              child: Center(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  loadingBuilder: (ctx, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                      child: CupertinoActivityIndicator(
                        color: CupertinoColors.white,
                      ),
                    );
                  },
                  errorBuilder: (ctx, error, stack) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            CupertinoIcons.exclamationmark_triangle,
                            color: CupertinoColors.white,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            context.l10n.errorLoadingPhoto,
                            style: CupertinoTheme.of(context)
                                .textTheme
                                .textStyle
                                .copyWith(color: CupertinoColors.white),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _confirmDelete() {
    showCupertinoDialog(
      context: context,
      builder: (dialogContext) {
        return CupertinoAlertDialog(
          title: Text(context.l10n.removePhoto),
          content: Text(context.l10n.cannotUndo),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.l10n.cancel),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () async {
                Navigator.pop(dialogContext);
                if (widget.onDelete != null) {
                  final success = await widget.onDelete!(
                    _photos[_currentIndex],
                  );

                  if (mounted && success) {
                    setState(() {
                      _photos.removeAt(_currentIndex);

                      if (_photos.isEmpty) {
                        Navigator.pop(context);
                      } else {
                        if (_currentIndex >= _photos.length) {
                          _currentIndex = _photos.length - 1;
                          _pageController.jumpToPage(_currentIndex);
                        }
                      }
                    });
                  }
                }
              },
              child: Text(context.l10n.delete),
            ),
          ],
        );
      },
    );
  }
}
