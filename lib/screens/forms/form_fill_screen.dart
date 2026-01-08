import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:praticos/models/form_definition.dart';
import 'package:praticos/models/order_form.dart';
import 'package:praticos/services/forms_service.dart';
import 'package:praticos/services/photo_service.dart';

class FormFillScreen extends StatefulWidget {
  final String orderId;
  final String companyId;
  final OrderForm orderForm;

  const FormFillScreen({
    super.key,
    required this.orderId,
    required this.companyId,
    required this.orderForm,
  });

  @override
  _FormFillScreenState createState() => _FormFillScreenState();
}

class _FormFillScreenState extends State<FormFillScreen> {
  final FormsService _formsService = FormsService();
  final PhotoService _photoService = PhotoService();
  late OrderForm _currentForm;
  bool _isUploading = false;
  bool _isSaving = false;
  String? _uploadingItemId;

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
            title: const Text('Erro ao Enviar Foto'),
            content: const Text('Não foi possível enviar a foto. Tente novamente.'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
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
            title: const Text('Erro ao Enviar Fotos'),
            content: const Text('Não foi possível enviar as fotos. Tente novamente.'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
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
          title: const Text('Campos Obrigatórios'),
          content: Text('Por favor preencha:\n${missingRequired.map((e) => "• ${e.label}").join("\n")}'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
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
            title: const Text('Erro'),
            content: const Text('Não foi possível concluir o procedimento. Tente novamente.'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  /// Verifica se todos os campos obrigatórios foram preenchidos
  bool _isFormComplete() {
    for (final item in _currentForm.items) {
      if (!item.required) continue;

      final response = _currentForm.getResponse(item.id);

      if (item.type == FormItemType.photoOnly) {
        if (response == null || response.photoUrls.isEmpty) return false;
      } else {
        if (response == null || response.value == null || response.value.toString().isEmpty) return false;
      }
    }
    return true;
  }

  /// Lida com o fechamento da tela, auto-concluindo se estiver completo
  Future<void> _handleClose() async {
    // Se já está concluído ou não está completo, apenas fecha
    if (_currentForm.status == FormStatus.completed || !_isFormComplete()) {
      Navigator.pop(context);
      return;
    }

    // Formulário completo mas não marcado como concluído - auto-concluir
    setState(() => _isSaving = true);

    try {
      await _formsService.updateStatus(
        widget.companyId,
        widget.orderId,
        _currentForm.id,
        FormStatus.completed
      );
      HapticFeedback.mediumImpact();
    } catch (e) {
      // Se falhar, apenas fecha sem concluir
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.pop(context, true);
      }
    }
  }

  Future<void> _reopenForm() async {
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
            title: const Text('Erro'),
            content: const Text('Não foi possível reabrir o procedimento. Tente novamente.'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
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
          onDelete: (index) async {
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
            child: const Text('Tirar Foto'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _addPhoto(itemId, ImageSource.gallery);
            },
            child: const Text('Escolher da Galeria'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
      ),
    );
  }

  void _showOptionsPicker(FormItemDefinition item) {
    final bool isChecklist = item.type == FormItemType.checklist;
    final options = item.options ?? [];
    final currentResponse = _currentForm.getResponse(item.id);

    if (isChecklist) {
      Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (context) => _ChecklistSelectionScreen(
            title: item.label,
            options: options,
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
          title: Text(item.label),
          actions: options.map((opt) {
            return CupertinoActionSheetAction(
              onPressed: () {
                _saveItemResponse(item.id, opt);
                Navigator.pop(ctx);
              },
              child: Text(opt),
            );
          }).toList(),
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
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
            largeTitle: Text(_currentForm.title),
            leading: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _handleClose,
              child: const Text('Fechar'),
            ),
            trailing: _isSaving
                ? const CupertinoActivityIndicator()
                : CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _currentForm.status == FormStatus.completed
                        ? _reopenForm
                        : _finishForm,
                    child: Text(
                      _currentForm.status == FormStatus.completed ? 'Reabrir' : 'Concluir',
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
                            'Procedimento concluído',
                            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                              color: CupertinoColors.systemGreen,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ..._currentForm.items.map((item) => _buildFormSection(item)),
                const SizedBox(height: 40),
              ]),
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
              text: item.label,
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
        if (item.allowPhotos || item.type == FormItemType.photoOnly)
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
    switch (item.type) {
      case FormItemType.text:
      case FormItemType.number:
        return _TextInputTile(
          item: item,
          response: response,
          onChanged: (val) => _saveItemResponse(item.id, val),
        );

      case FormItemType.boolean:
        return _BooleanInputTile(
          item: item,
          response: response,
          onChanged: (val) => _saveItemResponse(item.id, val),
        );

      case FormItemType.checklist:
      case FormItemType.select:
        return _SelectInputTile(
          item: item,
          response: response,
          onTap: () => _showOptionsPicker(item),
        );

      case FormItemType.photoOnly:
        final photos = response?.photoUrls ?? [];
        if (photos.isEmpty) {
          return CupertinoListTile(
            title: Text(
              'Toque no ícone da câmera para adicionar',
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

  const _TextInputTile({
    required this.item,
    required this.response,
    required this.onChanged,
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
      placeholder: 'Digitar',
      textAlign: TextAlign.right,
      style: CupertinoTheme.of(context).textTheme.textStyle,
      placeholderStyle: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
        color: CupertinoColors.placeholderText.resolveFrom(context),
      ),
      keyboardType: widget.item.type == FormItemType.number
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      textInputAction: TextInputAction.next,
      onChanged: widget.onChanged,
    );
  }
}

/// Campo boolean no padrão iOS
class _BooleanInputTile extends StatelessWidget {
  final FormItemDefinition item;
  final FormResponse? response;
  final Function(bool) onChanged;

  const _BooleanInputTile({
    required this.item,
    required this.response,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final boolValue = response?.value as bool?;

    return CupertinoListTile(
      title: const SizedBox.shrink(),
      trailing: CupertinoSlidingSegmentedControl<bool>(
        groupValue: boolValue,
        children: {
          true: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(
              'Sim',
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(fontSize: 14),
            ),
          ),
          false: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(
              'Não',
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(fontSize: 14),
            ),
          ),
        },
        onValueChanged: (newValue) {
          if (newValue != null) onChanged(newValue);
        },
      ),
    );
  }
}

/// Campo select/checklist no padrão iOS
class _SelectInputTile extends StatelessWidget {
  final FormItemDefinition item;
  final FormResponse? response;
  final VoidCallback onTap;

  const _SelectInputTile({
    required this.item,
    required this.response,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isChecklist = item.type == FormItemType.checklist;
    String displayValue = 'Selecionar';
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
            color: CupertinoColors.systemGrey2.resolveFrom(context),
          ),
        ],
      ),
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
    );
  }
}

/// Tela de seleção múltipla (Checklist)
class _ChecklistSelectionScreen extends StatefulWidget {
  final String title;
  final List<String> options;
  final List<String> initialSelected;

  const _ChecklistSelectionScreen({
    required this.title,
    required this.options,
    required this.initialSelected,
  });

  @override
  _ChecklistSelectionScreenState createState() => _ChecklistSelectionScreenState();
}

class _ChecklistSelectionScreenState extends State<_ChecklistSelectionScreen> {
  late List<String> _selected;

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
              child: const Text('Cancelar'),
              onPressed: () => Navigator.pop(context),
            ),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.pop(context, _selected),
              child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          SliverSafeArea(
            top: false,
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                CupertinoListSection.insetGrouped(
                  children: widget.options.map((opt) {
                    final bool isSelected = _selected.contains(opt);
                    return CupertinoListTile(
                      title: Text(
                        opt,
                        style: CupertinoTheme.of(context).textTheme.textStyle,
                      ),
                      trailing: isSelected
                          ? const Icon(CupertinoIcons.checkmark, color: CupertinoColors.activeBlue)
                          : null,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          if (isSelected) {
                            _selected.remove(opt);
                          } else {
                            _selected.add(opt);
                          }
                        });
                      },
                    );
                  }).toList(),
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
  final Future<bool> Function(int index) onDelete;

  const _PhotoGalleryScreen({
    required this.photos,
    required this.initialIndex,
    required this.onDelete,
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
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _confirmDelete,
          child: const Icon(CupertinoIcons.trash, color: CupertinoColors.white),
        ),
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
                            'Erro ao carregar foto',
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
          title: const Text('Remover Foto'),
          content: const Text('Tem certeza que deseja remover esta foto?'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () async {
                Navigator.pop(dialogContext);
                final success = await widget.onDelete(_currentIndex);

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
              },
              child: const Text('Remover'),
            ),
          ],
        );
      },
    );
  }
}
