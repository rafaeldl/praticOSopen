import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Divider, Colors, ReorderableListView, Material, MaterialType;
import 'package:flutter/services.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/mobx/form_template_store.dart';
import 'package:praticos/models/form_definition.dart';

class FormTemplateFormScreen extends StatefulWidget {
  const FormTemplateFormScreen({super.key});

  @override
  State<FormTemplateFormScreen> createState() => _FormTemplateFormScreenState();
}

class _FormTemplateFormScreenState extends State<FormTemplateFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final FormTemplateStore _store = FormTemplateStore();

  FormDefinition? _template;
  List<FormItemDefinition> _items = [];
  bool _isActive = true;
  bool _isLoading = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null && args.containsKey('template')) {
        _template = args['template'] as FormDefinition;
        _items = List.from(_template!.items);
        _isActive = _template!.isActive;
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

  Future<void> _saveTemplate() async {
    if (!_formKey.currentState!.validate()) return;

    if (_items.isEmpty) {
      HapticFeedback.heavyImpact();
      _showAlert(
        context.l10n.addItems,
        context.l10n.pleaseAddAtLeastOneItem,
      );
      return;
    }

    setState(() => _isLoading = true);
    _formKey.currentState!.save();

    try {
      _template!.items = _items;
      _template!.isActive = _isActive;

      if (_isEditing) {
        await _store.updateTemplate(_template!);
      } else {
        await _store.saveTemplate(_template!);
      }

      if (mounted) {
        HapticFeedback.mediumImpact();
        Navigator.pop(context, _template);
      }
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        setState(() => _isLoading = false);
        _showAlert(context.l10n.error, context.l10n.couldNotSaveForm);
      }
    }
  }

  void _showAlert(String title, String message) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _addItem() {
    _showItemEditor(null, (item) {
      setState(() => _items.add(item));
      HapticFeedback.selectionClick();
    });
  }

  void _editItem(int index) {
    _showItemEditor(_items[index], (item) {
      setState(() => _items[index] = item);
      HapticFeedback.selectionClick();
    });
  }

  void _showItemEditor(FormItemDefinition? existingItem, Function(FormItemDefinition) onSave) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => _ItemFormSheet(
        existingItem: existingItem,
        onSave: onSave,
      ),
    );
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
    });
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text(_isEditing ? context.l10n.editOrder : context.l10n.newOrder),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        trailing: Semantics(
          identifier: 'form_form_save_button',
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _isLoading ? null : _saveTemplate,
            child: _isLoading
                ? const CupertinoActivityIndicator()
                : Text(context.l10n.save, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ),
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const SizedBox(height: 20),

              // Header Icon
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey5.resolveFrom(context),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    CupertinoIcons.doc_text,
                    size: 50,
                    color: CupertinoColors.systemGrey.resolveFrom(context),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Basic Info Section
              CupertinoListSection.insetGrouped(
                header: Text(context.l10n.formInformation),
                children: [
                  Semantics(
                    identifier: 'form_form_title_field',
                    child: CupertinoTextFormFieldRow(
                      prefix: Text(context.l10n.title, style: const TextStyle(fontSize: 16)),
                      initialValue: _template?.title,
                      placeholder: context.l10n.companyName,
                      textCapitalization: TextCapitalization.sentences,
                      textAlign: TextAlign.right,
                      onSaved: (val) => _template?.title = val ?? '',
                      validator: (val) =>
                          val == null || val.trim().isEmpty ? context.l10n.required : null,
                    ),
                  ),
                  Semantics(
                    identifier: 'form_form_description_field',
                    child: CupertinoTextFormFieldRow(
                      prefix: Text(context.l10n.description, style: const TextStyle(fontSize: 16)),
                      initialValue: _template?.description,
                      placeholder: context.l10n.optional,
                      textCapitalization: TextCapitalization.sentences,
                      textAlign: TextAlign.right,
                      maxLines: 2,
                      onSaved: (val) => _template?.description =
                          val?.trim().isEmpty == true ? null : val?.trim(),
                    ),
                  ),
                ],
              ),

              // Status Section
              CupertinoListSection.insetGrouped(
                header: Text(context.l10n.formConfiguration),
                children: [
                  CupertinoListTile(
                    title: Text(context.l10n.active),
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

              // Items Section
              _buildItemsSection(),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 24, 32, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'ITENS DO FORMULÁRIO (${_items.length})',
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              if (_items.isNotEmpty)
                Text(
                  'Arraste para reordenar',
                  style: TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.tertiaryLabel.resolveFrom(context),
                    decoration: TextDecoration.none,
                  ),
                ),
            ],
          ),
        ),

        // Items List Container
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: CupertinoColors.systemBackground.resolveFrom(context),
            borderRadius: BorderRadius.circular(10),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              if (_items.isEmpty)
                // Empty State
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    children: [
                      Icon(
                        CupertinoIcons.doc_text_search,
                        size: 40,
                        color: CupertinoColors.systemGrey3.resolveFrom(context),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Nenhum item adicionado',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: CupertinoColors.secondaryLabel.resolveFrom(context),
                          decoration: TextDecoration.none,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Toque em "Adicionar Item" abaixo',
                        style: TextStyle(
                          fontSize: 13,
                          color: CupertinoColors.tertiaryLabel.resolveFrom(context),
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                )
              else
                // Reorderable List
                Material(
                  type: MaterialType.transparency,
                  child: ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: _items.length,
                    onReorder: _onReorder,
                    proxyDecorator: (child, index, animation) {
                      return Material(
                        color: Colors.transparent,
                        elevation: 4,
                        shadowColor: Colors.black26,
                        borderRadius: BorderRadius.circular(10),
                        child: child,
                      );
                    },
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return _buildDismissibleItemTile(
                        key: ValueKey(item.id),
                        item: item,
                        index: index,
                        isLast: index == _items.length - 1,
                      );
                    },
                  ),
                ),

              // Add Button
              CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 14),
                onPressed: _addItem,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      CupertinoIcons.plus_circle_fill,
                      color: CupertinoColors.activeBlue,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Adicionar Item',
                      style: TextStyle(
                        color: CupertinoColors.activeBlue,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Footer hint
        if (_items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 8, 32, 0),
            child: Text(
              'Deslize um item para a esquerda para excluir',
              style: TextStyle(
                fontSize: 12,
                color: CupertinoColors.tertiaryLabel.resolveFrom(context),
                decoration: TextDecoration.none,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDismissibleItemTile({
    required Key key,
    required FormItemDefinition item,
    required int index,
    required bool isLast,
  }) {
    return Dismissible(
      key: key,
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: CupertinoColors.systemRed,
        child: const Icon(
          CupertinoIcons.trash_fill,
          color: CupertinoColors.white,
        ),
      ),
      confirmDismiss: (_) async {
        HapticFeedback.mediumImpact();
        return await showCupertinoDialog<bool>(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: Text(context.l10n.removeItem),
            content: Text('${context.l10n.discard} "${item.label}"?'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(context.l10n.cancel),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(context.l10n.delete),
              ),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (_) {
        setState(() => _items.removeAt(index));
        HapticFeedback.mediumImpact();
      },
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          color: CupertinoColors.systemBackground.resolveFrom(context),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    // Drag Handle
                    ReorderableDragStartListener(
                      index: index,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          CupertinoIcons.line_horizontal_3,
                          size: 20,
                          color: CupertinoColors.systemGrey.resolveFrom(context),
                        ),
                      ),
                    ),

                    // Type Icon
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemTeal.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        _getIconForType(item.type),
                        size: 18,
                        color: CupertinoColors.systemTeal,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Content
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _editItem(index),
                        behavior: HitTestBehavior.opaque,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.label,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: CupertinoColors.label.resolveFrom(context),
                                decoration: TextDecoration.none,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_getTypeLabel(item.type)}${item.required ? ' · Obrigatório' : ''}',
                              style: TextStyle(
                                fontSize: 13,
                                color: CupertinoColors.secondaryLabel.resolveFrom(context),
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Edit chevron
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => _editItem(index),
                      child: Icon(
                        CupertinoIcons.chevron_right,
                        size: 16,
                        color: CupertinoColors.systemGrey3.resolveFrom(context),
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  indent: 68, // Drag handle + icon + spacing
                  color: CupertinoColors.separator.resolveFrom(context),
                ),
            ],
          ),
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
        return CupertinoIcons.checkmark_circle;
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

// ============================================================================
// Item Form Sheet
// ============================================================================

class _ItemFormSheet extends StatefulWidget {
  final FormItemDefinition? existingItem;
  final Function(FormItemDefinition) onSave;

  const _ItemFormSheet({
    this.existingItem,
    required this.onSave,
  });

  @override
  State<_ItemFormSheet> createState() => _ItemFormSheetState();
}

class _ItemFormSheetState extends State<_ItemFormSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late String _label;
  late FormItemType _type;
  late bool _required;
  late bool _allowPhotos;
  late String _optionsText;

  @override
  void initState() {
    super.initState();
    final item = widget.existingItem;
    _label = item?.label ?? '';
    _type = item?.type ?? FormItemType.text;
    _required = item?.required ?? false;
    _allowPhotos = item?.allowPhotos ?? true;
    _optionsText = item?.options?.join('\n') ?? '';
  }

  bool get _needsOptions =>
      _type == FormItemType.select || _type == FormItemType.checklist;

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    List<String>? options;
    if (_needsOptions) {
      options = _optionsText
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      if (options.length < 2) {
        HapticFeedback.heavyImpact();
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: Text(context.l10n.minOptions),
            content: Text(context.l10n.pleaseEnterAtLeast2Options),
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
    }

    final item = FormItemDefinition(
      id: widget.existingItem?.id ??
          FirebaseFirestore.instance.collection('tmp').doc().id,
      label: _label.trim(),
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
    return Material(
      type: MaterialType.transparency,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: CupertinoColors.systemGroupedBackground.resolveFrom(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey3.resolveFrom(context),
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),

            // Navigation bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Semantics(
                    identifier: 'form_item_sheet_cancel_button',
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  Text(
                    widget.existingItem == null ? 'Novo Item' : 'Editar Item',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.label.resolveFrom(context),
                      decoration: TextDecoration.none,
                    ),
                  ),
                  Semantics(
                    identifier: 'form_item_sheet_save_button',
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      onPressed: _save,
                      child: const Text(
                        'Salvar',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

          // Content
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.only(top: 12),
                children: [
                  // Label and Type
                  CupertinoListSection.insetGrouped(
                    header: Text(context.l10n.itemConfiguration),
                    children: [
                      Semantics(
                        identifier: 'form_item_sheet_label_field',
                        child: CupertinoTextFormFieldRow(
                          prefix: Text(context.l10n.label, style: const TextStyle(fontSize: 16)),
                          initialValue: _label,
                          placeholder: context.l10n.itemType,
                          textCapitalization: TextCapitalization.sentences,
                          textAlign: TextAlign.right,
                          onSaved: (val) => _label = val ?? '',
                          validator: (val) =>
                              val == null || val.trim().isEmpty ? context.l10n.required : null,
                        ),
                      ),
                      CupertinoListTile(
                        title: Text(context.l10n.itemType),
                        additionalInfo: Text(_getTypeLabel(_type)),
                        trailing: const CupertinoListTileChevron(),
                        onTap: _showTypePicker,
                      ),
                    ],
                  ),

                  // Options (conditional)
                  if (_needsOptions)
                    CupertinoListSection.insetGrouped(
                      header: Text(context.l10n.optionsHeader),
                      footer: Text(context.l10n.typeOneOptionPerLine),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: CupertinoTextField(
                            placeholder: 'Opção 1\nOpção 2\nOpção 3',
                            maxLines: 5,
                            controller: TextEditingController(text: _optionsText),
                            onChanged: (val) => _optionsText = val,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: BoxDecoration(
                              color: CupertinoColors.systemBackground.resolveFrom(context),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),

                  // Settings
                  CupertinoListSection.insetGrouped(
                    header: Text(context.l10n.optionsHeader),
                    children: [
                      if (_type != FormItemType.photoOnly)
                        CupertinoListTile(
                          title: Text(context.l10n.required),
                          trailing: CupertinoSwitch(
                            value: _required,
                            onChanged: (val) {
                              setState(() => _required = val);
                              HapticFeedback.selectionClick();
                            },
                          ),
                        ),
                      CupertinoListTile(
                        title: Text(context.l10n.allowPhotos),
                        subtitle: Text(context.l10n.userCanAttachPhotos),
                        trailing: CupertinoSwitch(
                          value: _allowPhotos,
                          onChanged: (val) {
                            setState(() => _allowPhotos = val);
                            HapticFeedback.selectionClick();
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }

  void _showTypePicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(context.l10n.selectItemType),
        message: Text(context.l10n.selectResponseType),
        actions: FormItemType.values.map((type) {
          final isSelected = type == _type;
          return CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _type = type);
              Navigator.pop(ctx);
              HapticFeedback.selectionClick();
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _getIconForType(type),
                  size: 20,
                  color: isSelected
                      ? CupertinoColors.activeBlue
                      : CupertinoColors.label.resolveFrom(context),
                ),
                const SizedBox(width: 8),
                Text(
                  _getTypeLabel(type),
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    CupertinoIcons.checkmark,
                    size: 18,
                    color: CupertinoColors.activeBlue,
                  ),
                ],
              ],
            ),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
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
        return CupertinoIcons.checkmark_circle;
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
