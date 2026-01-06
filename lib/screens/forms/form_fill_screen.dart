import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'; // Para Icons e alguns widgets auxiliares (se necessário)
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:praticos/models/form_definition.dart';
import 'package:praticos/models/order_form.dart';
import 'package:praticos/services/forms_service.dart';

class FormFillScreen extends StatefulWidget {
  final String orderId;
  final OrderForm orderForm;

  const FormFillScreen({
    super.key,
    required this.orderId,
    required this.orderForm,
  });

  @override
  _FormFillScreenState createState() => _FormFillScreenState();
}

class _FormFillScreenState extends State<FormFillScreen> {
  final FormsService _formsService = FormsService();
  late OrderForm _currentForm;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _currentForm = widget.orderForm;
  }

  // Função para salvar resposta de um item
  Future<void> _saveItemResponse(String itemId, dynamic value) async {
    final currentResponse = _currentForm.getResponse(itemId);
    final photoUrls = currentResponse?.photoUrls ?? [];

    final newResponse = FormResponse(
      itemId: itemId,
      value: value,
      photoUrls: photoUrls,
    );

    // Atualiza localmente para feedback imediato
    setState(() {
      final index = _currentForm.responses.indexWhere((r) => r.itemId == itemId);
      if (index >= 0) {
        _currentForm.responses[index] = newResponse;
      } else {
        _currentForm.responses.add(newResponse);
      }
    });

    // Salva no servidor
    await _formsService.saveResponse(widget.orderId, _currentForm.id, newResponse);
  }

  // Função para adicionar foto
  Future<void> _addPhoto(String itemId, ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 70);

    if (pickedFile == null) return;

    setState(() => _isUploading = true);

    try {
      final file = File(pickedFile.path);
      final ref = FirebaseStorage.instance
          .ref()
          .child('orders')
          .child(widget.orderId)
          .child('forms')
          .child(_currentForm.id)
          .child('${itemId}_${DateTime.now().millisecondsSinceEpoch}.jpg');

      await ref.putFile(file);
      final url = await ref.getDownloadURL();

      final currentResponse = _currentForm.getResponse(itemId);
      final List<String> currentPhotos = List.from(currentResponse?.photoUrls ?? []);
      currentPhotos.add(url);

      final newResponse = FormResponse(
        itemId: itemId,
        value: currentResponse?.value, // Mantém valor anterior
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
      // Mostrar alerta de erro
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _finishForm() async {
    // Validação simples de obrigatórios
    final missingRequired = _currentForm.items.where((item) {
      if (!item.required) return false;
      final response = _currentForm.getResponse(item.id);
      
      // Validação baseada no tipo
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
          content: Text('Por favor preencha: ${missingRequired.map((e) => e.label).join(", ")}'),
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

    await _formsService.updateStatus(widget.orderId, _currentForm.id, FormStatus.completed);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text(_currentForm.title),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _finishForm,
          child: const Text('Concluir'),
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            ListView(
              children: [
                if (_isUploading)
                  const LinearProgressIndicator(backgroundColor: Colors.transparent),
                
                ..._currentForm.items.map((item) {
                  return _buildFormItem(item);
                }), // .toList() removido

                const SizedBox(height: 40),
              ],
            ),
            if (_isUploading)
              Container(
                color: Colors.black12,
                child: const Center(child: CupertinoActivityIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormItem(FormItemDefinition item) {
    final response = _currentForm.getResponse(item.id);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CupertinoListSection.insetGrouped(
          header: Text.rich(
            TextSpan(
              text: item.label,
              children: [
                if (item.required)
                  const TextSpan(text: ' *', style: TextStyle(color: CupertinoColors.systemRed)),
              ],
            ),
          ),
          children: [
            // Input Field
            if (item.type != FormItemType.photoOnly)
              _buildInputWidget(item, response),
            
            // Photo Section
            if (item.allowPhotos || item.type == FormItemType.photoOnly)
              _buildPhotoSection(item, response),
          ],
        ),
      ],
    );
  }

  Widget _buildInputWidget(FormItemDefinition item, FormResponse? response) {
    switch (item.type) {
      case FormItemType.text:
      case FormItemType.number:
        return CupertinoTextFormFieldRow(
          placeholder: 'Digitar...',
          initialValue: response?.value?.toString(),
          keyboardType: item.type == FormItemType.number 
              ? TextInputType.number 
              : TextInputType.text,
          onChanged: (val) {
             _saveItemResponse(item.id, val);
          },
        );
      
      case FormItemType.boolean:
        final bool val = response?.value == true;
        return CupertinoListTile(
          title: Text(val ? 'Sim / Ok' : 'Não'),
          trailing: CupertinoSwitch(
            value: val,
            onChanged: (newValue) => _saveItemResponse(item.id, newValue),
          ),
        );

      case FormItemType.checklist:
      case FormItemType.select:
        return CupertinoListTile(
          title: Text(response?.value?.toString() ?? 'Selecionar'),
          trailing: const Icon(CupertinoIcons.chevron_down, size: 16),
          onTap: () => _showOptionsPicker(item),
        );

      default:
        return const SizedBox();
    }
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

  Widget _buildPhotoSection(FormItemDefinition item, FormResponse? response) {
    final photos = response?.photoUrls ?? [];
    
    return Container(
      padding: const EdgeInsets.all(12),
      color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (photos.isNotEmpty)
            Container(
              height: 80,
              margin: const EdgeInsets.only(bottom: 12),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, index) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      photos[index],
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  );
                },
              ),
            ),
          
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => _showPhotoSourceSheet(item.id),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(CupertinoIcons.camera_fill),
                SizedBox(width: 8),
                Text('Adicionar Foto'),
              ],
            ),
          ),
        ],
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
            child: const Text('Câmera'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _addPhoto(itemId, ImageSource.gallery);
            },
            child: const Text('Galeria'),
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
