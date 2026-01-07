import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Divider, InkWell, Material, MaterialType;
import 'package:praticos/models/form_definition.dart';
import 'package:praticos/models/product.dart';
import 'package:praticos/models/service.dart';
import 'package:praticos/models/service_bundle.dart';
import 'package:praticos/services/forms_service.dart';
import 'package:praticos/mobx/product_store.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

/// Tela para configurar os bundles (formulários e produtos) de um serviço
class ServiceBundlesScreen extends StatefulWidget {
  final Service service;
  final String companyId;

  const ServiceBundlesScreen({
    super.key,
    required this.service,
    required this.companyId,
  });

  @override
  State<ServiceBundlesScreen> createState() => _ServiceBundlesScreenState();
}

class _ServiceBundlesScreenState extends State<ServiceBundlesScreen> {
  late List<ServiceFormBundle> _formBundles;
  late List<ServiceProductBundle> _productBundles;

  @override
  void initState() {
    super.initState();
    _formBundles = List.from(widget.service.formBundles ?? []);
    _productBundles = List.from(widget.service.productBundles ?? []);
  }

  void _saveAndPop() {
    widget.service.formBundles = _formBundles.isNotEmpty ? _formBundles : null;
    widget.service.productBundles = _productBundles.isNotEmpty ? _productBundles : null;
    Navigator.pop(context, widget.service);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Kit do Serviço'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _saveAndPop,
          child: const Text('Salvar', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            const SizedBox(height: 20),

            // Header explicativo
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Configure os itens que serão adicionados automaticamente à OS quando este serviço for selecionado.',
                style: TextStyle(
                  fontSize: 14,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Seção de Formulários
            _buildFormBundlesSection(context),

            const SizedBox(height: 20),

            // Seção de Produtos
            _buildProductBundlesSection(context),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildFormBundlesSection(BuildContext context) {
    return CupertinoListSection.insetGrouped(
      header: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'FORMULÁRIOS',
            style: TextStyle(
              fontSize: 13,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 0,
            onPressed: () => _addFormBundle(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CupertinoIcons.add,
                  size: 16,
                  color: CupertinoColors.activeBlue.resolveFrom(context),
                ),
                const SizedBox(width: 4),
                Text(
                  'Adicionar',
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.activeBlue.resolveFrom(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      children: _formBundles.isEmpty
          ? [
              CupertinoListTile(
                title: Text(
                  'Nenhum formulário configurado',
                  style: TextStyle(
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ),
            ]
          : _formBundles.asMap().entries.map((entry) {
              final index = entry.key;
              final bundle = entry.value;
              return _buildFormBundleItem(context, bundle, index);
            }).toList(),
    );
  }

  Widget _buildFormBundleItem(BuildContext context, ServiceFormBundle bundle, int index) {
    return CupertinoListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: CupertinoColors.activeBlue.resolveFrom(context).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Icon(
          CupertinoIcons.doc_text,
          size: 18,
          color: CupertinoColors.activeBlue.resolveFrom(context),
        ),
      ),
      title: Text(bundle.formTitle),
      subtitle: Text(
        bundle.isRequired ? 'Preenchimento obrigatório' : 'Preenchimento opcional',
        style: TextStyle(
          fontSize: 12,
          color: bundle.isRequired
              ? CupertinoColors.systemRed.resolveFrom(context)
              : CupertinoColors.secondaryLabel.resolveFrom(context),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 32,
            onPressed: () => _toggleFormRequired(index),
            child: Icon(
              bundle.isRequired
                  ? CupertinoIcons.checkmark_seal_fill
                  : CupertinoIcons.checkmark_seal,
              size: 22,
              color: bundle.isRequired
                  ? CupertinoColors.systemRed.resolveFrom(context)
                  : CupertinoColors.systemGrey.resolveFrom(context),
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 32,
            onPressed: () => _removeFormBundle(index),
            child: Icon(
              CupertinoIcons.minus_circle_fill,
              size: 22,
              color: CupertinoColors.systemRed.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductBundlesSection(BuildContext context) {
    return CupertinoListSection.insetGrouped(
      header: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'PRODUTOS',
            style: TextStyle(
              fontSize: 13,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 0,
            onPressed: () => _addProductBundle(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CupertinoIcons.add,
                  size: 16,
                  color: CupertinoColors.activeBlue.resolveFrom(context),
                ),
                const SizedBox(width: 4),
                Text(
                  'Adicionar',
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.activeBlue.resolveFrom(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      children: _productBundles.isEmpty
          ? [
              CupertinoListTile(
                title: Text(
                  'Nenhum produto configurado',
                  style: TextStyle(
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ),
            ]
          : _productBundles.asMap().entries.map((entry) {
              final index = entry.key;
              final bundle = entry.value;
              return _buildProductBundleItem(context, bundle, index);
            }).toList(),
    );
  }

  Widget _buildProductBundleItem(BuildContext context, ServiceProductBundle bundle, int index) {
    return CupertinoListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: CupertinoColors.activeOrange.resolveFrom(context).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Icon(
          CupertinoIcons.cube_box,
          size: 18,
          color: CupertinoColors.activeOrange.resolveFrom(context),
        ),
      ),
      title: Text(bundle.productName),
      subtitle: Text(
        'Quantidade: ${bundle.quantity}',
        style: TextStyle(
          fontSize: 12,
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 32,
            onPressed: () => _editProductQuantity(context, index),
            child: Icon(
              CupertinoIcons.pencil,
              size: 20,
              color: CupertinoColors.activeBlue.resolveFrom(context),
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 32,
            onPressed: () => _removeProductBundle(index),
            child: Icon(
              CupertinoIcons.minus_circle_fill,
              size: 22,
              color: CupertinoColors.systemRed.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleFormRequired(int index) {
    setState(() {
      _formBundles[index] = ServiceFormBundle(
        formId: _formBundles[index].formId,
        formTitle: _formBundles[index].formTitle,
        isRequired: !_formBundles[index].isRequired,
      );
    });
  }

  void _removeFormBundle(int index) {
    setState(() {
      _formBundles.removeAt(index);
    });
  }

  void _removeProductBundle(int index) {
    setState(() {
      _productBundles.removeAt(index);
    });
  }

  Future<void> _addFormBundle(BuildContext context) async {
    final FormsService formsService = FormsService();
    final templates = await formsService.getCompanyTemplates(widget.companyId);

    if (!mounted) return;

    // Filtra templates já adicionados
    final existingIds = _formBundles.map((b) => b.formId).toSet();
    final availableTemplates = templates.where((t) => !existingIds.contains(t.id)).toList();

    if (availableTemplates.isEmpty) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Sem formulários'),
          content: const Text('Todos os formulários já foram adicionados ou não há formulários cadastrados.'),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
      return;
    }

    final selected = await showCupertinoModalPopup<FormDefinition>(
      context: context,
      builder: (context) => _FormSelectionSheet(templates: availableTemplates),
    );

    if (selected != null && mounted) {
      setState(() {
        _formBundles.add(ServiceFormBundle.fromFormDefinition(selected));
      });
    }
  }

  Future<void> _addProductBundle(BuildContext context) async {
    final ProductStore productStore = ProductStore();

    final selected = await showCupertinoModalPopup<Product>(
      context: context,
      builder: (context) => _ProductSelectionSheet(
        productStore: productStore,
        existingProductIds: _productBundles.map((b) => b.productId).toSet(),
      ),
    );

    if (selected != null && mounted) {
      setState(() {
        _productBundles.add(ServiceProductBundle.fromProduct(selected));
      });
    }
  }

  Future<void> _editProductQuantity(BuildContext context, int index) async {
    final bundle = _productBundles[index];
    final controller = TextEditingController(text: bundle.quantity.toString());

    final newQuantity = await showCupertinoDialog<int>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Quantidade'),
        content: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: CupertinoTextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Cancelar'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Salvar'),
            onPressed: () {
              final qty = int.tryParse(controller.text) ?? 1;
              Navigator.pop(context, qty < 1 ? 1 : qty);
            },
          ),
        ],
      ),
    );

    if (newQuantity != null && mounted) {
      setState(() {
        _productBundles[index] = ServiceProductBundle(
          productId: bundle.productId,
          productName: bundle.productName,
          quantity: newQuantity,
          value: bundle.value,
        );
      });
    }
  }
}

/// Sheet para seleção de formulário
class _FormSelectionSheet extends StatelessWidget {
  final List<FormDefinition> templates;

  const _FormSelectionSheet({required this.templates});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 36,
            height: 5,
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey3.resolveFrom(context),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Selecionar Formulário',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minSize: 0,
                  onPressed: () => Navigator.pop(context),
                  child: const Icon(CupertinoIcons.xmark_circle_fill, size: 28),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: CupertinoColors.systemGrey5.resolveFrom(context)),
          // List
          Expanded(
            child: Material(
              type: MaterialType.transparency,
              child: ListView.separated(
                itemCount: templates.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  indent: 60,
                  color: CupertinoColors.systemGrey5.resolveFrom(context),
                ),
                itemBuilder: (context, index) {
                  final template = templates[index];
                  return InkWell(
                    onTap: () => Navigator.pop(context, template),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: CupertinoColors.activeBlue.resolveFrom(context).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              CupertinoIcons.doc_text,
                              size: 20,
                              color: CupertinoColors.activeBlue.resolveFrom(context),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  template.title,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                ),
                                if (template.description != null && template.description!.isNotEmpty)
                                  Text(
                                    template.description!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: CupertinoColors.secondaryLabel.resolveFrom(context),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sheet para seleção de produto
class _ProductSelectionSheet extends StatefulWidget {
  final ProductStore productStore;
  final Set<String> existingProductIds;

  const _ProductSelectionSheet({
    required this.productStore,
    required this.existingProductIds,
  });

  @override
  State<_ProductSelectionSheet> createState() => _ProductSelectionSheetState();
}

class _ProductSelectionSheetState extends State<_ProductSelectionSheet> {
  @override
  void initState() {
    super.initState();
    widget.productStore.retrieveProducts();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 36,
            height: 5,
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey3.resolveFrom(context),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Selecionar Produto',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minSize: 0,
                  onPressed: () => Navigator.pop(context),
                  child: const Icon(CupertinoIcons.xmark_circle_fill, size: 28),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: CupertinoColors.systemGrey5.resolveFrom(context)),
          // List
          Expanded(
            child: Observer(
              builder: (_) {
                final productList = widget.productStore.productList;
                if (productList == null) {
                  return const Center(child: CupertinoActivityIndicator());
                }

                return StreamBuilder<List<Product?>>(
                  stream: productList,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CupertinoActivityIndicator());
                    }

                    final products = snapshot.data!
                        .whereType<Product>()
                        .where((p) => !widget.existingProductIds.contains(p.id))
                        .toList();

                    if (products.isEmpty) {
                      return Center(
                        child: Text(
                          'Nenhum produto disponível',
                          style: TextStyle(
                            color: CupertinoColors.secondaryLabel.resolveFrom(context),
                          ),
                        ),
                      );
                    }

                    return Material(
                      type: MaterialType.transparency,
                      child: ListView.separated(
                        itemCount: products.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          indent: 60,
                          color: CupertinoColors.systemGrey5.resolveFrom(context),
                        ),
                        itemBuilder: (context, index) {
                          final product = products[index];
                          return InkWell(
                            onTap: () => Navigator.pop(context, product),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: CupertinoColors.activeOrange.resolveFrom(context).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    alignment: Alignment.center,
                                    child: Icon(
                                      CupertinoIcons.cube_box,
                                      size: 20,
                                      color: CupertinoColors.activeOrange.resolveFrom(context),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      product.name ?? '',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
