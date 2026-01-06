import 'dart:io';
import 'package:flutter/cupertino.dart';
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

  @override
  void initState() {
    super.initState();
    _currentForm = widget.orderForm;
  }

  Future<void> _saveItemResponse(String itemId, dynamic value) async {
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

    await _formsService.saveResponse(widget.orderId, _currentForm.id, newResponse);
  }

  Future<void> _addPhoto(String itemId, ImageSource source) async {
    // Usar PhotoService para seleção e tratamento de imagem (HEIC, resize)
    final File? file;
    if (source == ImageSource.camera) {
      file = await _photoService.takePhoto();
    } else {
      file = await _photoService.pickImageFromGallery();
    }

    if (file == null) return;

    setState(() => _isUploading = true);

    try {
      final fileName = '${itemId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storagePath = 'tenants/${widget.companyId}/orders/${widget.orderId}/forms/${_currentForm.id}/$fileName';

      // Upload usando PhotoService (já converte para JPEG se necessário)
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

      await _formsService.saveResponse(widget.orderId, _currentForm.id, newResponse);

      setState(() {
        final index = _currentForm.responses.indexWhere((r) => r.itemId == itemId);
        if (index >= 0) {
          _currentForm.responses[index] = newResponse;
        } else {
          _currentForm.responses.add(newResponse);
        }
      });
    } catch (e) {
      print('Erro ao enviar foto: $e');
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('Erro'),
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
      setState(() => _isUploading = false);
    }
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
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Campos Obrigatórios'),
          content: Text('Por favor preencha:\n${missingRequired.map((e) => "• ${e.label}").join("\n") }'),
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
    await _formsService.updateStatus(widget.orderId, _currentForm.id, FormStatus.completed);
    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.pop(context);
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
            trailing: _isSaving 
              ? const CupertinoActivityIndicator()
              : CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _finishForm,
                  child: const Text('Concluir', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                if (_isUploading)
                  Container(
                    width: double.infinity,
                    color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        CupertinoActivityIndicator(),
                        SizedBox(width: 8),
                        Text("Enviando foto...", style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ..._currentForm.items.map((item) => _buildFormItem(item)),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormItem(FormItemDefinition item) {
    final response = _currentForm.getResponse(item.id);
    
    final labelWidget = Text.rich(
      TextSpan(
        text: item.label,
        style: TextStyle(
          fontSize: 16,
          color: CupertinoColors.label.resolveFrom(context),
        ),
        children: [
          if (item.required)
            const TextSpan(text: ' *', style: TextStyle(color: CupertinoColors.systemRed)),
        ],
      ),
    );

    return CupertinoListSection.insetGrouped(
      header: item.type == FormItemType.photoOnly ? labelWidget : null,
      children: [
        if (item.type != FormItemType.photoOnly)
          _buildInputWidget(item, response, labelWidget),

        if (item.allowPhotos || item.type == FormItemType.photoOnly)
          _buildPhotoRow(item, response),
      ],
    );
  }

  Widget _buildInputWidget(FormItemDefinition item, FormResponse? response, Widget label) {
    switch (item.type) {
      case FormItemType.text:
      case FormItemType.number:
        return CupertinoTextFormFieldRow(
          prefix: label,
          placeholder: 'Digitar',
          initialValue: response?.value?.toString(),
          textAlign: TextAlign.right,
          style: TextStyle(color: CupertinoColors.label.resolveFrom(context)),
          keyboardType: item.type == FormItemType.number 
              ? TextInputType.number 
              : TextInputType.text,
          onChanged: (val) => _saveItemResponse(item.id, val),
        );
      
      case FormItemType.boolean:
        return CupertinoListTile(
          title: label,
          trailing: CupertinoSlidingSegmentedControl<bool>(
            groupValue: response?.value as bool?,
            children: const {
              true: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('Sim', style: TextStyle(fontSize: 14)),
              ),
              false: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('Não', style: TextStyle(fontSize: 14)),
              ),
            },
            onValueChanged: (newValue) {
              if (newValue != null) _saveItemResponse(item.id, newValue);
            },
          ),
        );

      case FormItemType.checklist:
      case FormItemType.select:
        return CupertinoListTile(
          title: label,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                response?.value?.toString() ?? 'Selecionar',
                style: TextStyle(
                  color: response?.value != null 
                      ? CupertinoColors.label.resolveFrom(context) 
                      : CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
              const SizedBox(width: 6),
              Icon(CupertinoIcons.chevron_right, size: 14, color: CupertinoColors.systemGrey3.resolveFrom(context)),
            ],
          ),
          onTap: () => _showOptionsPicker(item),
        );

      default:
        return const SizedBox();
    }
  }

  Widget _buildPhotoRow(FormItemDefinition item, FormResponse? response) {
    final photos = response?.photoUrls ?? [];
    final hasPhotos = photos.isNotEmpty;
    
    // Se não tem fotos e não é obrigatório/exclusivo, mostra botão discreto
    if (!hasPhotos) {
       return Padding(
         padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
         child: GestureDetector(
           onTap: () => _showPhotoSourceSheet(item.id),
           behavior: HitTestBehavior.opaque,
           child: Row(
             children: [
               Icon(CupertinoIcons.camera, size: 20, color: CupertinoColors.activeBlue.resolveFrom(context)),
               const SizedBox(width: 8),
               Text(
                 "Adicionar Foto",
                 style: TextStyle(
                   color: CupertinoColors.activeBlue.resolveFrom(context),
                   fontSize: 15,
                 ),
               ),
             ],
           ),
         ),
       );
    }
    
    // Se tem fotos, mostra lista horizontal compacta
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 0, 12),
      child: SizedBox(
        height: 50,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
             // Botão de Adicionar (+)
             GestureDetector(
                onTap: () => _showPhotoSourceSheet(item.id),
                child: Container(
                  width: 50,
                  height: 50,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey6.resolveFrom(context),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    CupertinoIcons.plus,
                    color: CupertinoColors.activeBlue.resolveFrom(context),
                    size: 24,
                  ),
                ),
              ),
              
            // Lista de Fotos
            ...photos.map((url) => Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  url,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  loadingBuilder: (ctx, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      width: 50, 
                      height: 50, 
                      color: CupertinoColors.systemGrey6.resolveFrom(context),
                      child: const CupertinoActivityIndicator(),
                    );
                  },
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }

  void _showOptionsPicker(FormItemDefinition item) {
    final options = item.options ?? [];
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
}
