import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialType, ReorderableListView;
import 'package:flutter/services.dart';
import 'package:praticos/mobx/form_template_store.dart';
import 'package:praticos/models/form_definition.dart';

class FormTemplateFormScreen extends StatefulWidget {
  @override
  _FormTemplateFormScreenState createState() =>
      _FormTemplateFormScreenState();
}

class _FormTemplateFormScreenState extends State<FormTemplateFormScreen> {
  final FormTemplateStore _store = FormTemplateStore();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  FormDefinition? _existingTemplate;
  List<FormItemDefinition> _items = [];
  bool _isActive = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args =
          ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
      if (args != null && args.containsKey('template')) {
        setState(() {
          _existingTemplate = args['template'] as FormDefinition;
          _titleController.text = _existingTemplate!.title;
          _descriptionController.text = _existingTemplate!.description ?? '';
          _items = List.from(_existingTemplate!.items);
          _isActive = _existingTemplate!.isActive;
        });
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveTemplate() async {
    if (_titleController.text.trim().isEmpty) {
      HapticFeedback.heavyImpact();
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Título obrigatório'),
          content: const Text('Por favor, informe o título do formulário.'),
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

    if (_items.isEmpty) {
      HapticFeedback.heavyImpact();
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Adicione itens'),
          content:
              const Text('Por favor, adicione pelo menos um item ao formulário.'),
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
      final template = FormDefinition(
        id: _existingTemplate?.id ?? FirebaseFirestore.instance.collection('tmp').doc().id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        isActive: _isActive,
        items: _items,
        createdAt: _existingTemplate?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (_existingTemplate != null) {
        await _store.updateTemplate(template);
      } else {
        await _store.saveTemplate(template);
      }

      if (mounted) {
        HapticFeedback.mediumImpact();
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
            content: const Text('Não foi possível salvar o formulário. Tente novamente.'),
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

  void _addItem() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => _ItemFormSheet(
        onSave: (item) {
          setState(() => _items.add(item));
          HapticFeedback.mediumImpact();
        },
      ),
    );
  }

  void _editItem(int index) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => _ItemFormSheet(
        existingItem: _items[index],
        onSave: (item) {
          setState(() => _items[index] = item);
          HapticFeedback.mediumImpact();
        },
      ),
    );
  }

  void _deleteItem(int index) {
    HapticFeedback.mediumImpact();
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Remover item'),
        content: Text('Deseja remover "${_items[index].label}"?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _items.removeAt(index));
            },
            child: const Text('Remover'),
          ),
        ],
      ),
    );
  }

  void _reorderItems() {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => _ReorderItemsScreen(
          items: _items,
          onReorder: (newOrder) {
            setState(() => _items = newOrder);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: Material(
        type: MaterialType.transparency,
        child: CustomScrollView(
          slivers: [
            CupertinoSliverNavigationBar(
              largeTitle: Text(
                  _existingTemplate == null ? 'Novo Formulário' : 'Editar Formulário'),
              leading: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              trailing: _isSaving
                  ? const CupertinoActivityIndicator()
                  : CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _saveTemplate,
                      child: const Text(
                        'Salvar',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
            ),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // Título e Descrição
                  CupertinoListSection.insetGrouped(
                    header: const Text('INFORMAÇÕES BÁSICAS'),
                    children: [
                      CupertinoTextFormFieldRow(
                        controller: _titleController,
                        placeholder: 'Título do formulário',
                        prefix: const Text('Título'),
                        maxLength: 100,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      CupertinoTextFormFieldRow(
                        controller: _descriptionController,
                        placeholder: 'Descrição (opcional)',
                        prefix: const Text('Descrição'),
                        maxLines: 3,
                        maxLength: 500,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      CupertinoListTile(
                        title: const Text('Status'),
                        trailing: CupertinoSwitch(
                          value: _isActive,
                          onChanged: (value) {
                            setState(() => _isActive = value);
                            HapticFeedback.selectionClick();
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Itens
                  CupertinoListSection.insetGrouped(
                    header: Row(
                      children: [
                        const Expanded(child: Text('ITENS DO FORMULÁRIO')),
                        if (_items.length > 1)
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: _reorderItems,
                            child: const Text(
                              'Reordenar',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                      ],
                    ),
                    children: [
                      if (_items.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: Text(
                              'Nenhum item adicionado',
                              style: TextStyle(
                                color: CupertinoColors.secondaryLabel
                                    .resolveFrom(context),
                              ),
                            ),
                          ),
                        )
                      else
                        ..._items.asMap().entries.map((entry) {
                          final index = entry.key;
                          final item = entry.value;
                          return CupertinoListTile(
                            leading: Icon(
                              _getIconForType(item.type),
                              color: CupertinoColors.systemTeal,
                            ),
                            title: Text(item.label),
                            subtitle: Text(
                              _getTypeLabel(item.type) +
                                  (item.required ? ' · Obrigatório' : ''),
                              style: TextStyle(
                                fontSize: 13,
                                color: CupertinoColors.secondaryLabel
                                    .resolveFrom(context),
                              ),
                            ),
                            trailing: Row(
                              children: [
                                CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: () => _editItem(index),
                                  child: const Icon(
                                    CupertinoIcons.pencil,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: () => _deleteItem(index),
                                  child: const Icon(
                                    CupertinoIcons.trash,
                                    size: 20,
                                    color: CupertinoColors.systemRed,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      CupertinoListTile(
                        leading: const Icon(
                          CupertinoIcons.add_circled,
                          color: CupertinoColors.activeBlue,
                        ),
                        title: const Text(
                          'Adicionar Item',
                          style: TextStyle(
                            color: CupertinoColors.activeBlue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        onTap: _addItem,
                      ),
                    ],
                  ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForType(FormItemType type) {
    switch (type) {
      case FormItemType.text:
        return CupertinoIcons.textformat;
      case FormItemType.number:
        return CupertinoIcons.number;
      case FormItemType.boolean:
        return CupertinoIcons.check_mark_circled;
      case FormItemType.select:
        return CupertinoIcons.chevron_down_circle;
      case FormItemType.checklist:
        return CupertinoIcons.checkmark_square;
      case FormItemType.photoOnly:
        return CupertinoIcons.camera;
    }
  }

  String _getTypeLabel(FormItemType type) {
    switch (type) {
      case FormItemType.text:
        return 'Texto';
      case FormItemType.number:
        return 'Número';
      case FormItemType.boolean:
        return 'Sim/Não';
      case FormItemType.select:
        return 'Seleção única';
      case FormItemType.checklist:
        return 'Múltipla escolha';
      case FormItemType.photoOnly:
        return 'Apenas foto';
    }
  }
}

// Sheet para adicionar/editar item
class _ItemFormSheet extends StatefulWidget {
  final FormItemDefinition? existingItem;
  final Function(FormItemDefinition) onSave;

  const _ItemFormSheet({
    this.existingItem,
    required this.onSave,
  });

  @override
  __ItemFormSheetState createState() => __ItemFormSheetState();
}

class __ItemFormSheetState extends State<_ItemFormSheet> {
  final TextEditingController _labelController = TextEditingController();
  final TextEditingController _optionsController = TextEditingController();

  FormItemType _type = FormItemType.text;
  bool _required = false;
  bool _allowPhotos = true;

  @override
  void initState() {
    super.initState();
    if (widget.existingItem != null) {
      _labelController.text = widget.existingItem!.label;
      _type = widget.existingItem!.type;
      _required = widget.existingItem!.required;
      _allowPhotos = widget.existingItem!.allowPhotos;
      if (widget.existingItem!.options != null) {
        _optionsController.text = widget.existingItem!.options!.join('\n');
      }
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _optionsController.dispose();
    super.dispose();
  }

  void _save() {
    if (_labelController.text.trim().isEmpty) {
      HapticFeedback.heavyImpact();
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Label obrigatório'),
          content: const Text('Por favor, informe o label do item.'),
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

    final needsOptions = _type == FormItemType.select || _type == FormItemType.checklist;
    List<String>? options;

    if (needsOptions) {
      final optionsText = _optionsController.text.trim();
      if (optionsText.isEmpty) {
        HapticFeedback.heavyImpact();
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('Opções obrigatórias'),
            content: const Text('Por favor, informe as opções (uma por linha).'),
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

      options = optionsText
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      if (options.length < 2) {
        HapticFeedback.heavyImpact();
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('Mínimo de opções'),
            content: const Text('Por favor, informe pelo menos 2 opções.'),
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
    }

    final item = FormItemDefinition(
      id: widget.existingItem?.id ?? FirebaseFirestore.instance.collection('tmp').doc().id,
      label: _labelController.text.trim(),
      type: _type,
      options: options,
      required: _required,
      allowPhotos: _allowPhotos,
    );

    widget.onSave(item);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final needsOptions = _type == FormItemType.select || _type == FormItemType.checklist;

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        middle: Text(widget.existingItem == null ? 'Novo Item' : 'Editar Item'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _save,
          child: const Text(
            'Salvar',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: ListView(
            children: [
              const SizedBox(height: 20),
              CupertinoListSection.insetGrouped(
                children: [
                  CupertinoTextFormFieldRow(
                    controller: _labelController,
                    placeholder: 'Ex: Temperatura do ambiente',
                    prefix: const Text('Label'),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  CupertinoListTile(
                    title: const Text('Tipo'),
                    trailing: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => _showTypePicker(),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_getTypeLabel(_type)),
                          const SizedBox(width: 4),
                          const Icon(CupertinoIcons.chevron_right, size: 14),
                        ],
                      ),
                    ),
                  ),
                  if (needsOptions)
                    CupertinoTextFormFieldRow(
                      controller: _optionsController,
                      placeholder: 'Uma opção por linha',
                      prefix: const Text('Opções'),
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  if (_type != FormItemType.photoOnly)
                    CupertinoListTile(
                      title: const Text('Obrigatório'),
                      trailing: CupertinoSwitch(
                        value: _required,
                        onChanged: (value) {
                          setState(() => _required = value);
                          HapticFeedback.selectionClick();
                        },
                      ),
                    ),
                  CupertinoListTile(
                    title: const Text('Permitir fotos'),
                    trailing: CupertinoSwitch(
                      value: _allowPhotos,
                      onChanged: (value) {
                        setState(() => _allowPhotos = value);
                        HapticFeedback.selectionClick();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTypePicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Tipo do Item'),
        actions: FormItemType.values.map((type) {
          return CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _type = type);
              Navigator.pop(ctx);
            },
            child: Text(_getTypeLabel(type)),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
      ),
    );
  }

  String _getTypeLabel(FormItemType type) {
    switch (type) {
      case FormItemType.text:
        return 'Texto';
      case FormItemType.number:
        return 'Número';
      case FormItemType.boolean:
        return 'Sim/Não';
      case FormItemType.select:
        return 'Seleção única';
      case FormItemType.checklist:
        return 'Múltipla escolha';
      case FormItemType.photoOnly:
        return 'Apenas foto';
    }
  }
}

// Tela para reordenar itens
class _ReorderItemsScreen extends StatefulWidget {
  final List<FormItemDefinition> items;
  final Function(List<FormItemDefinition>) onReorder;

  const _ReorderItemsScreen({
    required this.items,
    required this.onReorder,
  });

  @override
  __ReorderItemsScreenState createState() => __ReorderItemsScreenState();
}

class __ReorderItemsScreenState extends State<_ReorderItemsScreen> {
  late List<FormItemDefinition> _items;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.items);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        middle: const Text('Reordenar Itens'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            widget.onReorder(_items);
            Navigator.pop(context);
          },
          child: const Text(
            'Concluir',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      child: SafeArea(
        child: ReorderableListView(
          onReorder: (oldIndex, newIndex) {
            setState(() {
              if (newIndex > oldIndex) {
                newIndex -= 1;
              }
              final item = _items.removeAt(oldIndex);
              _items.insert(newIndex, item);
            });
            HapticFeedback.selectionClick();
          },
          children: _items.map((item) {
            return Container(
              key: Key(item.id),
              color: CupertinoColors.systemBackground.resolveFrom(context),
              margin: const EdgeInsets.symmetric(vertical: 1),
              child: CupertinoListTile(
                leading: Icon(
                  CupertinoIcons.bars,
                  color: CupertinoColors.systemGrey.resolveFrom(context),
                ),
                title: Text(item.label),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
