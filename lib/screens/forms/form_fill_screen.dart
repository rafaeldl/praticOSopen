import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/models/form_definition.dart';
import 'package:praticos/models/order_form.dart';
import 'package:praticos/screens/forms/form_question_sheet.dart';
import 'package:praticos/screens/widgets/glass_bar_button.dart';
import 'package:praticos/screens/widgets/primary_button.dart';
import 'package:praticos/screens/widgets/pull_down_menu.dart';
import 'package:praticos/screens/widgets/section_label.dart';
import 'package:praticos/screens/widgets/status_dot.dart';
import 'package:praticos/screens/widgets/text_link.dart';
import 'package:praticos/services/authorization_service.dart';
import 'package:praticos/services/forms_service.dart';
import 'package:praticos/services/photo_service.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';
import 'package:provider/provider.dart';

/// A checklist of the OS: the summary of the answers, and the questions one
/// at a time ([FormQuestionSheet]).
///
/// - Top: back and, for a completed checklist, "…" with "Reabrir".
/// - Header: device, status (dot + text: "Faltam 3 perguntas", "Completo")
///   and the one blue button: "Começar"/"Continuar" (opens the questions at
///   the first one without an answer) or "Concluir checklist".
/// - "Perguntas": a white card with each question and its answer; a tap opens
///   that question.
///
/// A checklist with no answer yet opens straight on the first question.
/// Answering the last one with nothing left completes the checklist and goes
/// back to the OS.
class FormFillScreen extends StatefulWidget {
  final String orderId;
  final String companyId;
  final OrderForm orderForm;
  final List<DeviceAggr>? devices;

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
    if (widget.openQuestionsOnStart &&
        !_isCompleted &&
        _currentForm.items.isNotEmpty &&
        _currentForm.responses.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openQuestions(0);
      });
    }
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

  void _putResponse(FormResponse response) {
    final index = _currentForm.responses.indexWhere(
      (r) => r.itemId == response.itemId,
    );
    if (index >= 0) {
      _currentForm.responses[index] = response;
    } else {
      _currentForm.responses.add(response);
    }
  }

  Future<void> _saveItemResponse(String itemId, dynamic value) async {
    HapticFeedback.selectionClick();

    final currentResponse = _currentForm.getResponse(itemId);
    final photoUrls = currentResponse?.photoUrls ?? [];

    final newResponse = FormResponse(
      itemId: itemId,
      value: value,
      photoUrls: photoUrls,
    );

    _update(() => _putResponse(newResponse));

    await _formsService.saveResponse(
      widget.companyId,
      widget.orderId,
      _currentForm.id,
      newResponse,
    );
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

      final currentResponse = _currentForm.getResponse(itemId);
      final List<String> currentPhotos = List.from(
        currentResponse?.photoUrls ?? [],
      );
      currentPhotos.add(url);

      final newResponse = FormResponse(
        itemId: itemId,
        value: currentResponse?.value,
        photoUrls: currentPhotos,
      );

      await _formsService.saveResponse(
        widget.companyId,
        widget.orderId,
        _currentForm.id,
        newResponse,
      );

      _update(() => _putResponse(newResponse));

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
      final currentResponse = _currentForm.getResponse(itemId);
      final List<String> currentPhotos = List.from(
        currentResponse?.photoUrls ?? [],
      );
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
            currentPhotos.add(url);
            successCount++;
          }
        } catch (e) {
          debugPrint('Erro ao fazer upload de uma foto: $e');
        }
      }

      if (successCount > 0) {
        final newResponse = FormResponse(
          itemId: itemId,
          value: currentResponse?.value,
          photoUrls: currentPhotos,
        );

        await _formsService.saveResponse(
          widget.companyId,
          widget.orderId,
          _currentForm.id,
          newResponse,
        );

        _update(() => _putResponse(newResponse));

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

    final currentResponse = _currentForm.getResponse(itemId);
    if (currentResponse == null) return;

    final List<String> currentPhotos = List.from(currentResponse.photoUrls);
    currentPhotos.remove(url);

    final newResponse = FormResponse(
      itemId: itemId,
      value: currentResponse.value,
      photoUrls: currentPhotos,
    );

    _update(() => _putResponse(newResponse));

    await _formsService.saveResponse(
      widget.companyId,
      widget.orderId,
      _currentForm.id,
      newResponse,
    );
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
        builder: (context) => _PhotoGalleryScreen(
          photos: photos,
          initialIndex: photoIndex,
          onDelete: _isCompleted
              ? null
              : (index) async {
                  final url = photos[index];
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

  Future<void> _showMenu() async {
    final l10n = context.l10n;
    final picked = await showPullDownMenu(
      context,
      groups: [
        PullDownGroup([
          PullDownItem(
            value: 'reopen',
            label: l10n.reopen,
            icon: CupertinoIcons.arrow_counterclockwise,
          ),
        ]),
      ],
    );
    if (picked == 'reopen') _reopenForm();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final showMenu = _isCompleted && !_isSaving && _canReopenForm();
    return CupertinoPageScaffold(
      backgroundColor: AppColors.groupedBackground.resolveFrom(context),
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            automaticallyImplyLeading: false,
            leading: const GlassBackButton(),
            largeTitle: Text(_currentForm.getLocalizedTitle(_localeCode)),
            alwaysShowMiddle: false,
            backgroundColor: AppColors.groupedBackground
                .resolveFrom(context)
                .withValues(alpha: 0.8),
            border: null,
            trailing: _isSaving
                ? const CupertinoActivityIndicator()
                : showMenu
                ? GlassBarButton(
                    key: const ValueKey('form_fill_menu'),
                    label: l10n.orderMoreActions,
                    icon: CupertinoIcons.ellipsis,
                    onPressed: _showMenu,
                  )
                : null,
          ),
          SliverSafeArea(
            top: false,
            sliver: SliverList(
              delegate: SliverChildListDelegate([
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
      status = l10n.checklistStatusDone;
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
      button: canOpen,
      child: GestureDetector(
        key: ValueKey('form_fill_item_${item.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: canOpen ? () => _openQuestions(index) : null,
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

  String _localizedOption(FormItemDefinition item, String original) {
    final options = item.options ?? const <String>[];
    final localized = item.getLocalizedOptions(_localeCode) ?? options;
    final i = options.indexOf(original);
    return i >= 0 && i < localized.length ? localized[i] : original;
  }
}

/// Photos of a question in full screen (black, like the iPhone's photo
/// viewer), swipe between them, trash to remove.
class _PhotoGalleryScreen extends StatefulWidget {
  final List<String> photos;
  final int initialIndex;
  final Future<bool> Function(int index)? onDelete;

  const _PhotoGalleryScreen({
    required this.photos,
    required this.initialIndex,
    this.onDelete,
  });

  @override
  _PhotoGalleryScreenState createState() => _PhotoGalleryScreenState();
}

class _PhotoGalleryScreenState extends State<_PhotoGalleryScreen> {
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
                  final success = await widget.onDelete!(_currentIndex);

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
