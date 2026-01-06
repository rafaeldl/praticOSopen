import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'; // For some icons if needed
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:praticos/models/form/form_definition.dart';
import 'package:praticos/models/form/order_form.dart';
import 'package:praticos/mobx/form_store.dart';
import 'package:praticos/services/photo_service.dart';
import 'package:praticos/widgets/cached_image.dart';
import 'dart:async';

part '_debounced_text_form_field.dart';

class OrderFormScreen extends StatefulWidget {
  final OrderForm orderForm;
  final FormStore formStore;
  final FormDefinition? template; // Passed if available, otherwise we might need to fetch it or rely on structure
  // Actually, OrderForm has items structure mirrored? No, OrderForm only has responses.
  // We need the definition to render the form!
  // But wait, OrderForm doesn't embed the definition.
  // So we need to fetch the definition or pass it.
  // The repository doesn't seem to fetch definition for an order form instance automatically.
  // We can pass the definition if we have it in the store's availableForms list.

  final String orderId;

  const OrderFormScreen({
    Key? key,
    required this.orderForm,
    required this.formStore,
    required this.orderId,
    this.template,
  }) : super(key: key);

  @override
  _OrderFormScreenState createState() => _OrderFormScreenState();
}

class _OrderFormScreenState extends State<OrderFormScreen> {
  late OrderForm _formState;
  FormDefinition? _definition;
  final PhotoService _photoService = PhotoService();

  @override
  void initState() {
    super.initState();
    _formState = widget.orderForm;

    if (widget.template != null) {
      _definition = widget.template;
    } else {
      _loadDefinition();
    }
  }

  Future<void> _loadDefinition() async {
    if (widget.orderForm.formDefinitionId == null) return;

    final def = await widget.formStore.getOrLoadFormDefinition(widget.orderForm.formDefinitionId!);
    if (mounted) {
      setState(() {
        _definition = def;
      });
    }
  }

  void _updateResponse(String itemId, dynamic value) {
    setState(() {
      if (_formState.responses == null) {
        _formState.responses = [];
      }

      final responseIndex = _formState.responses!.indexWhere((r) => r.itemId == itemId);

      if (responseIndex != -1) {
        _formState.responses![responseIndex].value = value;
      } else {
        // Create new response if missing
        _formState.responses!.add(FormResponseItem(itemId: itemId, value: value));
      }
    });
    widget.formStore.saveFormResponse(widget.orderId, _formState);
  }

  Future<void> _addPhoto(String itemId) async {
    // Show action sheet to choose camera or gallery
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: const Text('Adicionar Foto'),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            child: const Text('Câmera'),
            onPressed: () async {
              Navigator.pop(context);
              File? file = await _photoService.takePhoto();
              if (file != null) {
                _uploadAndAddPhoto(itemId, file);
              }
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('Galeria'),
            onPressed: () async {
              Navigator.pop(context);
              File? file = await _photoService.pickImageFromGallery();
              if (file != null) {
                _uploadAndAddPhoto(itemId, file);
              }
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('Cancelar'),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  Future<void> _uploadAndAddPhoto(String itemId, File file) async {
     try {
       String? url = await widget.formStore.uploadPhoto(widget.orderId, _formState.id!, file);
       if (url != null) {
         setState(() {
           final response = _formState.responses?.firstWhere((r) => r.itemId == itemId);
           if (response != null) {
             response.photoUrls ??= [];
             response.photoUrls!.add(url);
           }
         });
         widget.formStore.saveFormResponse(widget.orderId, _formState);
       } else {
         _showError("Falha ao enviar foto. Verifique sua conexão.");
       }
     } catch (e) {
       _showError("Erro ao enviar foto: $e");
     }
  }

  void _showError(String message) {
    if (!mounted) return;
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('Erro'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: Text('OK'),
            onPressed: () => Navigator.pop(ctx),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_definition == null || _definition!.items == null) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(middle: Text('Erro')),
        child: Center(child: Text('Definição do formulário não encontrada.')),
      );
    }

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text(widget.orderForm.title ?? 'Formulário'),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            CupertinoListSection.insetGrouped(
              children: _definition!.items!.map((item) {
                return _buildFormItem(item);
              }).toList(),
            ),
            if (_formState.status != 'completed')
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
                child: CupertinoButton.filled(
                  child: const Text("Finalizar Preenchimento"),
                  onPressed: _completeForm,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _completeForm() {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text("Finalizar Formulário"),
        content: const Text("Deseja marcar este formulário como concluído?"),
        actions: [
          CupertinoDialogAction(
            child: const Text("Cancelar"),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text("Finalizar"),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _formState.status = 'completed';
              });
              widget.formStore.saveFormResponse(widget.orderId, _formState);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFormItem(FormItemDefinition item) {
    final response = _formState.responses?.firstWhere(
      (r) => r.itemId == item.id,
      orElse: () => FormResponseItem(itemId: item.id),
    );

    // If response isn't in list (legacy/migration issue?), create temp one.
    // Ideally we initialized it.

    Widget content;

    switch (item.type) {
      case FormItemType.text:
        content = _DebouncedTextFormField(
          initialValue: response?.value as String?,
          onChanged: (val) => _updateResponse(item.id!, val),
          placeholder: 'Resposta',
        );
        break;
      case FormItemType.number:
        content = _DebouncedTextFormField(
          initialValue: response?.value?.toString(),
          onChanged: (val) => _updateResponse(item.id!, val),
          placeholder: '0',
          keyboardType: TextInputType.number,
        );
        break;
      case FormItemType.boolean:
        content = CupertinoSwitch(
          value: response?.value == true,
          onChanged: (val) => _updateResponse(item.id!, val),
        );
        break;
      case FormItemType.select:
         // Simplified select for MVP
         content = Padding(
           padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
           child: CupertinoSlidingSegmentedControl<String>(
             groupValue: response?.value as String?,
             children: {
               for (var opt in item.options ?? []) opt: Text(opt),
             },
             onValueChanged: (val) => _updateResponse(item.id!, val),
           ),
         );
         break;
      case FormItemType.checklist:
         if (item.options != null && item.options!.isNotEmpty) {
           // Multi-select checklist
           final List<String> selected = (response?.value is List)
               ? List<String>.from(response?.value)
               : [];

           content = Column(
             children: item.options!.map((opt) {
               final isSelected = selected.contains(opt);
               return GestureDetector(
                 onTap: () {
                   final newSelected = List<String>.from(selected);
                   if (isSelected) {
                     newSelected.remove(opt);
                   } else {
                     newSelected.add(opt);
                   }
                   _updateResponse(item.id!, newSelected);
                 },
                 child: Container(
                   color: Colors.transparent,
                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                   child: Row(
                     children: [
                       Icon(
                         isSelected ? CupertinoIcons.check_mark_circle_fill : CupertinoIcons.circle,
                         color: isSelected ? CupertinoColors.activeBlue : CupertinoColors.systemGrey,
                         size: 24,
                       ),
                       const SizedBox(width: 12),
                       Expanded(
                         child: Text(
                           opt,
                           style: TextStyle(
                             color: CupertinoColors.label.resolveFrom(context),
                             fontSize: 16,
                           ),
                         ),
                       ),
                     ],
                   ),
                 ),
               );
             }).toList(),
           );
         } else {
           // Single boolean toggle
           content = Padding(
             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
             child: Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 Text('Concluído', style: TextStyle(color: CupertinoColors.label.resolveFrom(context))),
                 CupertinoSwitch(
                  value: response?.value == true,
                  onChanged: (val) => _updateResponse(item.id!, val),
                 ),
               ],
             ),
           );
         }
         break;
      case FormItemType.photo_only:
        content = Container(); // Just photos
        break;
      default:
        content = Text('Tipo desconhecido');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            item.label ?? '',
            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        content,
        if (item.allowPhotos == true || item.type == FormItemType.photo_only) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SizedBox(
              height: 80,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  GestureDetector(
                    onTap: () => _addPhoto(item.id!),
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey5,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(CupertinoIcons.camera_fill, color: CupertinoColors.systemGrey),
                    ),
                  ),
                  if (response?.photoUrls != null)
                    ...response!.photoUrls!.map((url) => Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedImage(
                          url,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                    )),
                ],
              ),
            ),
          ),
        ],
        Container(height: 1, color: CupertinoColors.separator),
      ],
    );
  }
}
