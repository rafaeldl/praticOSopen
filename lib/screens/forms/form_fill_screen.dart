import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/models/form_definition.dart';
import 'package:praticos/models/order_form.dart';
import 'package:praticos/services/authorization_service.dart';
import 'package:praticos/services/forms_service.dart';
import 'package:praticos/services/photo_service.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:provider/provider.dart';

class FormFillScreen extends StatefulWidget {
  final String orderId;
  final String companyId;
  final OrderForm orderForm;
  final List<DeviceAggr>? devices;

  const FormFillScreen({
    super.key,
    required this.orderId,
    required this.companyId,
    required this.orderForm,
    this.devices,
  });

  @override
  _FormFillScreenState createState() => _FormFillScreenState();
}

class _FormFillScreenState extends State<FormFillScreen> {
  final FormsService _formsService = FormsService();
  final PhotoService _photoService = PhotoService();
  final AuthorizationService _authService = AuthorizationService.instance;
  late OrderForm _currentForm;
  bool _isUploading = false;
  bool _isSaving = false;
  String? _uploadingItemId;

  /// Gets the current locale code for i18n (e.g., 'pt', 'en', 'es')
  String? get _localeCode => context.l10n.localeName;

  @override
  void initState() {
    super.initState();
    _currentForm = widget.orderForm;
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

    setState(() {
      final index = _currentForm.responses.indexWhere((r) => r.itemId == itemId);
      if (index >= 0) {
        _currentForm.responses[index] = newResponse;
      } else {
        _currentForm.responses.add(newResponse);
      }
    });

    await _formsService.saveResponse(widget.companyId, widget.orderId, _currentForm.id, newResponse);
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
    setState(() {
      _isUploading = true;
      _uploadingItemId = itemId;
    });

    try {
      final fileName = '${itemId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storagePath = 'tenants/${widget.companyId}/orders/${widget.orderId}/forms/${_currentForm.id}/$fileName';

      final url = await _photoService.uploadImage(
        file: file,
        storagePath: storagePath,
      );

      if (url == null) throw Exception('Falha no upload');

      final currentResponse = _currentForm.getResponse(itemId);
      final List<String> currentPhotos = List.from(currentResponse?.photoUrls ?? []);
      currentPhotos.add(url);

      final newResponse = FormResponse(
        itemId: itemId,
        value: currentResponse?.value,
        photoUrls: currentPhotos,
      );

      await _formsService.saveResponse(widget.companyId, widget.orderId, _currentForm.id, newResponse);

      setState(() {
        final index = _currentForm.responses.indexWhere((r) => r.itemId == itemId);
        if (index >= 0) {
          _currentForm.responses[index] = newResponse;
        } else {
          _currentForm.responses.add(newResponse);
        }
      });

      HapticFeedback.mediumImpact();
    } catch (e) {
      HapticFeedback.heavyImpact();
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: Text(context.l10n.errorSendingPhoto),
            content: Text(context.l10n.couldNotSendPhoto),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(ctx),
                child: Text(context.l10n.ok),
              ),
            ],
          ),
        );
      }
    } finally {
      setState(() {
        _isUploading = false;
        _uploadingItemId = null;
      });
    }
  }

  Future<void> _uploadMultiplePhotos(String itemId, List<File> files) async {
    setState(() {
      _isUploading = true;
      _uploadingItemId = itemId;
    });

    try {
      final currentResponse = _currentForm.getResponse(itemId);
      final List<String> currentPhotos = List.from(currentResponse?.photoUrls ?? []);
      int successCount = 0;

      for (final file in files) {
        try {
          final fileName = '${itemId}_${DateTime.now().millisecondsSinceEpoch}_$successCount.jpg';
          final storagePath = 'tenants/${widget.companyId}/orders/${widget.orderId}/forms/${_currentForm.id}/$fileName';

          final url = await _photoService.uploadImage(
            file: file,
            storagePath: storagePath,
          );

          if (url != null) {
            currentPhotos.add(url);
            successCount++;
          }
        } catch (e) {
          print('Erro ao fazer upload de uma foto: $e');
        }
      }

      if (successCount > 0) {
        final newResponse = FormResponse(
          itemId: itemId,
          value: currentResponse?.value,
          photoUrls: currentPhotos,
        );

        await _formsService.saveResponse(widget.companyId, widget.orderId, _currentForm.id, newResponse);

        setState(() {
          final index = _currentForm.responses.indexWhere((r) => r.itemId == itemId);
          if (index >= 0) {
            _currentForm.responses[index] = newResponse;
          } else {
            _currentForm.responses.add(newResponse);
          }
        });

        HapticFeedback.mediumImpact();
      } else {
        throw Exception('Nenhuma foto foi enviada com sucesso');
      }
    } catch (e) {
      HapticFeedback.heavyImpact();
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: Text(context.l10n.errorSendingPhotos),
            content: Text(context.l10n.couldNotSendPhotos),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(ctx),
                child: Text(context.l10n.ok),
              ),
            ],
          ),
        );
      }
    } finally {
      setState(() {
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

    setState(() {
      final index = _currentForm.responses.indexWhere((r) => r.itemId == itemId);
      _currentForm.responses[index] = newResponse;
    });

    await _formsService.saveResponse(widget.companyId, widget.orderId, _currentForm.id, newResponse);
  }

  Future<void> _finishForm() async {
    final missingRequired = _currentForm.items.where((item) {
      if (!item.required) return false;
      final response = _currentForm.getResponse(item.id);

      if (item.type == FormItemType.photoOnly) {
        return response == null || response.photoUrls.isEmpty;
      }

      return response == null || response.value == null || response.value.toString().isEmpty;
    }).toList();

    if (missingRequired.isNotEmpty) {
      HapticFeedback.heavyImpact();
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: Text(context.l10n.requiredFields),
          content: Text('${context.l10n.pleaseFill}\n${missingRequired.map((e) => "• ${e.getLocalizedLabel(_localeCode)}").join("\n")}'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.l10n.ok),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _formsService.updateStatus(widget.companyId, widget.orderId, _currentForm.id, FormStatus.completed);

      if (mounted) {
        HapticFeedback.mediumImpact();
        setState(() => _isSaving = false);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        setState(() => _isSaving = false);

        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: Text(context.l10n.error),
            content: Text(context.l10n.couldNotCompleteForm),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(ctx),
                child: Text(context.l10n.ok),
              ),
            ],
          ),
        );
      }
    }
  }

  /// Lida com o fechamento da tela (não auto-finaliza o formulário)
  void _handleClose() {
    if (mounted) {
      Navigator.pop(context);
    }
  }

  /// Verifica se o usuário atual pode reabrir procedimentos concluídos
  bool _canReopenForm() {
    return _authService.canReopenCompletedForms;
  }

  Future<void> _reopenForm() async {
    // Verifica se usuário tem permissão (apenas Admin, Manager e Supervisor)
    if (!_authService.canReopenCompletedForms) {
      HapticFeedback.heavyImpact();
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: Text(context.l10n.noPermission),
          content: Text(context.l10n.noPermissionReopenForm),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.l10n.ok),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _formsService.updateStatus(widget.companyId, widget.orderId, _currentForm.id, FormStatus.inProgress);

      if (mounted) {
        HapticFeedback.mediumImpact();
        setState(() {
          _currentForm.status = FormStatus.inProgress;
          _isSaving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        setState(() => _isSaving = false);

        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: Text(context.l10n.error),
            content: Text(context.l10n.couldNotReopenForm),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(ctx),
                child: Text(context.l10n.ok),
              ),
            ],
          ),
        );
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
          onDelete: _currentForm.status == FormStatus.completed
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

  void _showPhotoSourceSheet(String itemId) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _addPhoto(itemId, ImageSource.camera);
            },
            child: Text(context.l10n.takePhoto),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _addPhoto(itemId, ImageSource.gallery);
            },
            child: Text(context.l10n.chooseFromGallery),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: Text(context.l10n.cancel),
        ),
      ),
    );
  }

  void _showOptionsPicker(FormItemDefinition item) {
    final bool isChecklist = item.type == FormItemType.checklist;
    final options = item.getLocalizedOptions(_localeCode) ?? [];
    final originalOptions = item.options ?? [];
    final currentResponse = _currentForm.getResponse(item.id);
    final localizedLabel = item.getLocalizedLabel(_localeCode);

    if (isChecklist) {
      Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (context) => _ChecklistSelectionScreen(
            title: localizedLabel,
            options: options,
            originalOptions: originalOptions,
            initialSelected: List<String>.from(currentResponse?.value ?? []),
          ),
        ),
      ).then((selected) {
        if (selected != null) {
          _saveItemResponse(item.id, selected);
        }
      });
    } else {
      showCupertinoModalPopup(
        context: context,
        builder: (ctx) => CupertinoActionSheet(
          title: Text(localizedLabel),
          actions: List.generate(options.length, (index) {
            final localizedOpt = options[index];
            final originalOpt = index < originalOptions.length ? originalOptions[index] : localizedOpt;
            return CupertinoActionSheetAction(
              onPressed: () {
                // Save the original value for consistency
                _saveItemResponse(item.id, originalOpt);
                Navigator.pop(ctx);
              },
              child: Text(localizedOpt),
            );
          }),
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.cancel),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text(_currentForm.getLocalizedTitle(_localeCode)),
            leading: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _handleClose,
              child: Text(context.l10n.close),
            ),
            trailing: _isSaving
                ? const CupertinoActivityIndicator()
                : _currentForm.status == FormStatus.completed
                    ? _canReopenForm()
                        ? CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: _reopenForm,
                            child: Text(
                              context.l10n.reopen,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          )
                        : null
                    : CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: _finishForm,
                        child: Text(
                          context.l10n.complete,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
          ),
          SliverSafeArea(
            top: false,
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (_currentForm.status == FormStatus.completed)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          CupertinoIcons.checkmark_seal_fill,
                          color: CupertinoColors.systemGreen,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            context.l10n.formCompleted,
                            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                              color: CupertinoColors.systemGreen,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                _buildDeviceBanner(context),
                ..._currentForm.items.map((item) => _buildFormSection(item)),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceBanner(BuildContext context) {
    final deviceId = _currentForm.deviceId;
    if (deviceId == null || widget.devices == null) return const SizedBox.shrink();

    final device = widget.devices!.cast<DeviceAggr?>().firstWhere(
      (d) => d?.id == deviceId,
      orElse: () => null,
    );
    if (device == null) return const SizedBox.shrink();

    final config = context.watch<SegmentConfigProvider>();
    final displayName = device.serial != null && device.serial!.trim().isNotEmpty
        ? '${device.name} - ${device.serial}'
        : device.name ?? '';
    final primaryColor = CupertinoTheme.of(context).primaryColor;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(config.deviceIcon, size: 20, color: primaryColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              displayName,
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                color: primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormSection(FormItemDefinition item) {
    final response = _currentForm.getResponse(item.id);
    final photos = response?.photoUrls ?? [];
    final isUploadingThis = _isUploading && _uploadingItemId == item.id;

    return CupertinoListSection.insetGrouped(
      header: _buildSectionHeader(item, photos.length, isUploadingThis),
      children: [
        _buildInputTile(item, response),
        if (photos.isNotEmpty) _buildPhotosTile(item.id, photos),
      ],
    );
  }

  Widget _buildSectionHeader(FormItemDefinition item, int photoCount, bool isUploading) {
    return Row(
      children: [
        Expanded(
          child: Text.rich(
            TextSpan(
              text: item.getLocalizedLabel(_localeCode),
              children: [
                if (item.required)
                  const TextSpan(
                    text: ' *',
                    style: TextStyle(color: CupertinoColors.systemRed),
                  ),
              ],
            ),
          ),
        ),
        if ((item.allowPhotos || item.type == FormItemType.photoOnly) && _currentForm.status != FormStatus.completed)
          isUploading
              ? const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: CupertinoActivityIndicator(radius: 8),
                )
              : CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => _showPhotoSourceSheet(item.id),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (photoCount > 0)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(
                            '$photoCount',
                            style: TextStyle(
                              fontSize: 13,
                              color: CupertinoColors.secondaryLabel.resolveFrom(context),
                            ),
                          ),
                        ),
                      Icon(
                        CupertinoIcons.camera,
                        size: 18,
                        color: CupertinoColors.activeBlue.resolveFrom(context),
                      ),
                    ],
                  ),
                ),
      ],
    );
  }

  Widget _buildInputTile(FormItemDefinition item, FormResponse? response) {
    final isCompleted = _currentForm.status == FormStatus.completed;

    switch (item.type) {
      case FormItemType.text:
      case FormItemType.number:
        return _TextInputTile(
          item: item,
          response: response,
          onChanged: (val) => _saveItemResponse(item.id, val),
          isReadOnly: isCompleted,
        );

      case FormItemType.boolean:
        return _BooleanInputTile(
          item: item,
          response: response,
          onChanged: (val) => _saveItemResponse(item.id, val),
          isReadOnly: isCompleted,
        );

      case FormItemType.checklist:
      case FormItemType.select:
        return _SelectInputTile(
          item: item,
          response: response,
          onTap: isCompleted ? null : () => _showOptionsPicker(item),
        );

      case FormItemType.photoOnly:
        final photos = response?.photoUrls ?? [];
        if (photos.isEmpty) {
          return CupertinoListTile(
            title: Text(
              isCompleted
                ? context.l10n.noPhotoAdded
                : context.l10n.tapCameraIconToAdd,
              style: TextStyle(
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
                fontSize: 15,
              ),
            ),
          );
        }
        return const SizedBox.shrink();
    }
  }

  Widget _buildPhotosTile(String itemId, List<String> photos) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: SizedBox(
        height: 60,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: photos.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final url = photos[index];
            return GestureDetector(
              onTap: () => _showPhotoPreview(itemId, index),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  url,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  loadingBuilder: (ctx, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      width: 60,
                      height: 60,
                      color: CupertinoColors.systemGrey5.resolveFrom(context),
                      child: const Center(child: CupertinoActivityIndicator()),
                    );
                  },
                  errorBuilder: (ctx, error, stack) {
                    return Container(
                      width: 60,
                      height: 60,
                      color: CupertinoColors.systemGrey5.resolveFrom(context),
                      child: const Icon(CupertinoIcons.exclamationmark_triangle, size: 20),
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
}

/// Campo de texto no padrão iOS
class _TextInputTile extends StatefulWidget {
  final FormItemDefinition item;
  final FormResponse? response;
  final Function(String) onChanged;
  final bool isReadOnly;

  const _TextInputTile({
    required this.item,
    required this.response,
    required this.onChanged,
    this.isReadOnly = false,
  });

  @override
  State<_TextInputTile> createState() => _TextInputTileState();
}

class _TextInputTileState extends State<_TextInputTile> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.response?.value?.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoTextFormFieldRow(
      controller: _controller,
      placeholder: widget.isReadOnly ? '' : context.l10n.type,
      textAlign: TextAlign.right,
      enabled: !widget.isReadOnly,
      style: CupertinoTheme.of(context).textTheme.textStyle,
      placeholderStyle: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
        color: CupertinoColors.placeholderText.resolveFrom(context),
      ),
      keyboardType: widget.item.type == FormItemType.number
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      textInputAction: TextInputAction.next,
      onChanged: widget.isReadOnly ? null : widget.onChanged,
    );
  }
}

/// Campo boolean no padrão iOS
class _BooleanInputTile extends StatelessWidget {
  final FormItemDefinition item;
  final FormResponse? response;
  final Function(bool) onChanged;
  final bool isReadOnly;

  const _BooleanInputTile({
    required this.item,
    required this.response,
    required this.onChanged,
    this.isReadOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final boolValue = response?.value as bool?;

    return CupertinoListTile(
      title: const SizedBox.shrink(),
      trailing: AbsorbPointer(
        absorbing: isReadOnly,
        child: Opacity(
          opacity: isReadOnly ? 0.5 : 1.0,
          child: CupertinoSlidingSegmentedControl<bool>(
            groupValue: boolValue,
            children: {
              true: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Text(
                  context.l10n.yes,
                  style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(fontSize: 14),
                ),
              ),
              false: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Text(
                  context.l10n.no,
                  style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(fontSize: 14),
                ),
              ),
            },
            onValueChanged: (newValue) {
              if (newValue != null && !isReadOnly) onChanged(newValue);
            },
          ),
        ),
      ),
    );
  }
}

/// Campo select/checklist no padrão iOS
class _SelectInputTile extends StatelessWidget {
  final FormItemDefinition item;
  final FormResponse? response;
  final VoidCallback? onTap;

  const _SelectInputTile({
    required this.item,
    required this.response,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isChecklist = item.type == FormItemType.checklist;
    String displayValue = context.l10n.select;
    bool hasValue = false;

    final responseValue = response?.value;
    if (responseValue != null) {
      if (isChecklist && responseValue is List) {
        if (responseValue.isNotEmpty) {
          displayValue = responseValue.join(', ');
          hasValue = true;
        }
      } else {
        displayValue = responseValue.toString();
        hasValue = responseValue.toString().isNotEmpty;
      }
    }

    return CupertinoListTile(
      title: const SizedBox.shrink(),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Text(
              displayValue,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                color: hasValue
                    ? CupertinoColors.label.resolveFrom(context)
                    : CupertinoColors.placeholderText.resolveFrom(context),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            CupertinoIcons.chevron_right,
            size: 16,
            color: onTap == null
                ? CupertinoColors.systemGrey4.resolveFrom(context)
                : CupertinoColors.systemGrey2.resolveFrom(context),
          ),
        ],
      ),
      onTap: onTap == null ? null : () {
        HapticFeedback.selectionClick();
        onTap!();
      },
    );
  }
}

/// Tela de seleção múltipla (Checklist)
class _ChecklistSelectionScreen extends StatefulWidget {
  final String title;
  final List<String> options; // Localized options for display
  final List<String> originalOptions; // Original options for saving
  final List<String> initialSelected;

  const _ChecklistSelectionScreen({
    required this.title,
    required this.options,
    required this.originalOptions,
    required this.initialSelected,
  });

  @override
  _ChecklistSelectionScreenState createState() => _ChecklistSelectionScreenState();
}

class _ChecklistSelectionScreenState extends State<_ChecklistSelectionScreen> {
  late List<String> _selected; // Stores original values

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.initialSelected);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text(widget.title),
            leading: CupertinoButton(
              padding: EdgeInsets.zero,
              child: Text(context.l10n.cancel),
              onPressed: () => Navigator.pop(context),
            ),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.pop(context, _selected),
              child: Text(context.l10n.ok, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          SliverSafeArea(
            top: false,
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                CupertinoListSection.insetGrouped(
                  children: List.generate(widget.options.length, (index) {
                    final localizedOpt = widget.options[index];
                    final originalOpt = index < widget.originalOptions.length
                        ? widget.originalOptions[index]
                        : localizedOpt;
                    final bool isSelected = _selected.contains(originalOpt);
                    return CupertinoListTile(
                      title: Text(
                        localizedOpt,
                        style: CupertinoTheme.of(context).textTheme.textStyle,
                      ),
                      trailing: isSelected
                          ? const Icon(CupertinoIcons.checkmark, color: CupertinoColors.activeBlue)
                          : null,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          if (isSelected) {
                            _selected.remove(originalOpt);
                          } else {
                            _selected.add(originalOpt);
                          }
                        });
                      },
                    );
                  }),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tela de galeria de fotos com navegação
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
          '${_currentIndex + 1} de ${_photos.length}',
          style: const TextStyle(color: CupertinoColors.white),
        ),
        trailing: widget.onDelete != null
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _confirmDelete,
                child: const Icon(CupertinoIcons.trash, color: CupertinoColors.white),
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
                      child: CupertinoActivityIndicator(color: CupertinoColors.white),
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
                            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                              color: CupertinoColors.white,
                            ),
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
