import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, ScaffoldMessenger, SnackBar, Material, MaterialType, Divider; 
// Keeping Material for some specific helpers or if absolutely needed, but main UI is Cupertino.
// Actually, strict HIG means avoiding Material widgets where possible.
// I will try to rely purely on Cupertino for the visual tree.

import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:praticos/mobx/company_store.dart';
import 'package:praticos/mobx/customer_store.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/screens/widgets/order_photos_widget.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/constants/label_keys.dart';

// Formulários Dinâmicos
import 'package:praticos/models/order_form.dart' as of_model; // Alias para evitar conflito com esta classe OrderForm
import 'package:praticos/models/form_definition.dart'; // Para FormItemType e FormItemDefinition
import 'package:praticos/services/forms_service.dart';
import 'package:praticos/screens/forms/form_selection_screen.dart';
import 'package:praticos/screens/forms/form_fill_screen.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class OrderForm extends StatefulWidget {
  @override
  _OrderFormState createState() => _OrderFormState();
}

class _OrderFormState extends State<OrderForm> {
  late OrderStore _store;
  final FormsService _formsService = FormsService();

  @override
  void initState() {
    super.initState();
    _store = OrderStore();

    Future.delayed(Duration.zero, () {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

      if (args != null && args.containsKey('order')) {
        Order orderArg = args['order'];

        if (orderArg.id != null) {
          _store.repository.getSingle(_store.companyId!, orderArg.id!).then((updatedOrder) {
            _store.setOrder(updatedOrder ?? orderArg);
          });
        } else if (orderArg.number != null) {
          _store.repository.getOrderByNumber(_store.companyId!, orderArg.number!).then((
            existingOrder,
          ) {
            _store.setOrder(existingOrder ?? orderArg);
          });
        } else {
          _store.setOrder(orderArg);
        }
      } else {
        _store.loadOrder();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<SegmentConfigProvider>();
    // Using CupertinoPageScaffold for iOS look
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: Material(
        type: MaterialType.transparency,
        child: CustomScrollView(
          slivers: [
            _buildNavigationBar(context, config),
            SliverSafeArea(
              top: false, // Navigation bar handles top safe area
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildPhotosSection(context),
                  _buildClientDeviceSection(context, config),
                  _buildStatusDatesSection(context, config),
                  _buildFormsSection(context, config),
                  _buildServicesSection(context, config),
                  _buildProductsSection(context, config),
                  _buildTotalSection(context, config),
                  const SizedBox(height: 40),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationBar(BuildContext context, SegmentConfigProvider config) {
    return CupertinoSliverNavigationBar(
      largeTitle: Observer(
        builder: (_) {
          Order? os = _store.orderStream?.value;
          return Text(os?.number != null ? "OS #${os!.number}" : config.label(LabelKeys.createServiceOrder));
        },
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            child: const Icon(CupertinoIcons.camera),
            onPressed: () => _showAddPhotoOptions(config),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            child: const Icon(CupertinoIcons.ellipsis_circle),
            onPressed: () => _showActionSheet(context, config),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotosSection(BuildContext context) {
    // Keeping OrderPhotosWidget but wrapping it to look integrated if needed.
    // Ideally, we'd style it more 'Apple-like' here.
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: OrderPhotosWidget(store: _store),
    );
  }

  Widget _buildClientDeviceSection(BuildContext context, SegmentConfigProvider config) {
    return Observer(
      builder: (_) {
        return _buildGroupedSection(
          header: "${config.customer.toUpperCase()} E ${config.device.toUpperCase()}",
          children: [
            _buildListTile(
              context: context,
              icon: CupertinoIcons.person_fill,
              title: config.customer,
              value: _store.customerName,
              placeholder: "Selecionar ${config.customer}",
              onTap: _selectCustomer,
              showChevron: true,
            ),
            _buildListTile(
              context: context,
              icon: config.deviceIcon,
              title: config.device,
              value: _store.deviceName,
              placeholder: "Selecionar ${config.device}",
              onTap: _selectDevice,
              showChevron: true,
              isLast: true,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusDatesSection(BuildContext context, SegmentConfigProvider config) {
    return Observer(
      builder: (_) {
        return _buildGroupedSection(
          header: "DETALHES",
          children: [
            _buildListTile(
              context: context,
              icon: CupertinoIcons.flag_fill,
              title: "Status",
              value: config.getStatus(_store.status),
              onTap: () => _selectStatus(config),
              showChevron: true,
              valueColor: _getStatusColorCupertino(_store.status),
            ),
            _buildListTile(
              context: context,
              icon: CupertinoIcons.calendar,
              title: "Criado em",
              value: _store.formattedCreatedDate,
              onTap: () {}, // Read only
              showChevron: false,
            ),
            _buildListTile(
              context: context,
              icon: CupertinoIcons.time_solid,
              title: "Entrega",
              value: _store.dueDate ?? 'Definir Data',
              placeholder: "Definir Data",
              onTap: _selectDueDate,
              showChevron: true,
              isLast: true,
            ),
          ],
        );
      },
    );
  }

  Widget _buildFormsSection(BuildContext context, SegmentConfigProvider config) {
    return Observer(
      builder: (_) {
        final hasOrder = _store.order?.id != null && _store.companyId != null;

        return StreamBuilder<List<of_model.OrderForm>>(
          stream: _store.formsStream,
          initialData: _store.formsStream?.value,
          builder: (context, snapshot) {
            final isLoading = hasOrder && snapshot.connectionState == ConnectionState.waiting;
            final forms = snapshot.data ?? [];
            
            return Column(
              children: [
                _buildGroupedSection(
                  header: "FORMULÁRIOS E CHECKLISTS",
                  children: [
                    if (isLoading)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: CupertinoActivityIndicator()),
                      )
                    else if (forms.isEmpty)
                      _buildListTile(
                        context: context,
                        title: "Nenhum formulário",
                        value: "",
                        placeholder: "",
                        onTap: () {},
                        showChevron: false,
                        isLast: true,
                        textColor: CupertinoColors.secondaryLabel,
                      )
                    else
                      ...forms.asMap().entries.map((entry) {
                        final index = entry.key;
                        final form = entry.value;
                        return _buildFormRow(context, form, index == forms.length - 1);
                      }),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: CupertinoButton(
                    onPressed: () => _addForm(config),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                         Icon(CupertinoIcons.doc_text_fill),
                         SizedBox(width: 8),
                         Text("Adicionar Formulário"),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildFormRow(BuildContext context, of_model.OrderForm form, bool isLast) {
    // Calculando progresso simples
    final total = form.items.length;
    final answered = form.responses.length; // Assumindo que resposta existe = respondido
    final progress = total > 0 ? (answered / total) : 0.0;
    final percent = (progress * 100).toInt();
    final isCompleted = form.status == of_model.FormStatus.completed;

    return _buildDismissibleItem(
      context: context,
      index: form.id.hashCode, // Usando hash do ID para chave única do Dismissible
      onDelete: () => _confirmDeleteForm(form),
      child: _buildItemRow(
        context: context,
        title: form.title,
        subtitle: isCompleted ? "Concluído" : "$answered de $total respondidos ($percent%)",
        trailing: "", // Poderia usar um Icon check aqui
        onTap: () {
          Navigator.push(
            context,
            CupertinoPageRoute(
              fullscreenDialog: true,
              builder: (context) => FormFillScreen(
                orderId: _store.order!.id!,
                companyId: _store.companyId!,
                orderForm: form,
              ),
            ),
          );
        },
        isLast: isLast,
      ),
    );
  }

  void _confirmDeleteForm(of_model.OrderForm form) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Remover Formulário'),
        content: Text('Deseja remover "${form.title}" desta OS?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              _formsService.deleteOrderForm(_store.companyId!, _store.order!.id!, form.id);
            },
            child: const Text('Remover'),
          ),
        ],
      ),
    );
  }

  void _addForm(SegmentConfigProvider config) async {
    // Se a OS ainda não foi salva, salva automaticamente
    if (_store.order?.id == null) {
      if (_store.companyId == null) return;
      
      await _store.repository.createItem(_store.companyId!, _store.order!);
      _store.setOrder(_store.order); // Atualiza estado com novo ID
    }

    // Double check após salvar
    if (_store.order?.id == null || _store.companyId == null) return;

    final template = await Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => FormSelectionScreen(
          companyId: _store.companyId!,
        ),
      ),
    );

    if (template != null && _store.order?.id != null && _store.companyId != null) {
      final newForm = await _formsService.addFormToOrder(_store.companyId!, _store.order!.id!, template);
      
      if (mounted) {
        Navigator.push(
          context,
          CupertinoPageRoute(
            fullscreenDialog: true,
            builder: (context) => FormFillScreen(
              orderId: _store.order!.id!,
              companyId: _store.companyId!,
              orderForm: newForm,
            ),
          ),
        );
      }
    }
  }

  Widget _buildServicesSection(BuildContext context, SegmentConfigProvider config) {
    return Observer(
      builder: (_) {
        final services = _store.services ?? [];
        return Column(
          children: [
             _buildGroupedSection(
              header: "SERVIÇOS",
              children: [
                if (services.isEmpty)
                  _buildListTile(
                    context: context,
                    title: "Nenhum serviço",
                    value: "",
                    placeholder: "",
                    onTap: () {},
                    showChevron: false,
                    isLast: true,
                    textColor: CupertinoColors.secondaryLabel,
                  )
                else
                  ...services.asMap().entries.map((entry) {
                    final index = entry.key;
                    final service = entry.value;
                    return _buildServiceRow(context, service, index, index == services.length - 1, config);
                  }),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: CupertinoButton(
                onPressed: _addService,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(CupertinoIcons.add_circled_solid),
                    const SizedBox(width: 8),
                    Text(config.label(LabelKeys.createService)),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProductsSection(BuildContext context, SegmentConfigProvider config) {
    return Observer(
      builder: (_) {
        final products = _store.products ?? [];
        return Column(
          children: [
            _buildGroupedSection(
              header: "PEÇAS E PRODUTOS",
              children: [
                if (products.isEmpty)
                  _buildListTile(
                    context: context,
                    title: "Nenhum produto",
                    value: "",
                    placeholder: "",
                    onTap: () {},
                    showChevron: false,
                    isLast: true,
                    textColor: CupertinoColors.secondaryLabel,
                  )
                else
                  ...products.asMap().entries.map((entry) {
                    final index = entry.key;
                    final product = entry.value;
                    return _buildProductRow(context, product, index, index == products.length - 1, config);
                  }),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: CupertinoButton(
                onPressed: _addProduct,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                     const Icon(CupertinoIcons.add_circled_solid),
                     const SizedBox(width: 8),
                     Text(config.label(LabelKeys.createProduct)),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTotalSection(BuildContext context, SegmentConfigProvider config) {
    return Observer(
      builder: (_) {
        final total = _store.total ?? 0.0;
        final discount = _store.discount ?? 0.0;
        final payment = _store.payment ?? '';
        final isPaid = payment == 'Pago';
        
        return _buildGroupedSection(
          header: "TOTALIZAÇÃO",
          children: [
            if (discount > 0)
              _buildListTile(
                context: context,
                title: "Desconto",
                value: "- ${_convertToCurrency(discount)}",
                onTap: () {},
                showChevron: false,
                textColor: CupertinoColors.systemRed,
                valueColor: CupertinoColors.systemRed,
              ),
             _buildListTile(
              context: context,
              title: config.label(LabelKeys.total),
              value: _convertToCurrency(total),
              onTap: () {},
              showChevron: false,
              isBold: true,
              valueColor: CupertinoColors.label.resolveFrom(context),
            ),
             _buildListTile(
              context: context,
              title: "Situação",
              value: isPaid ? "PAGO" : "A RECEBER",
              onTap: () => _showPaymentOptions(config),
              showChevron: true,
              valueColor: isPaid ? CupertinoColors.activeGreen : CupertinoColors.systemOrange,
              isLast: true,
            ),
          ],
        );
      },
    );
  }

  // --- Helper Widgets for iOS Style ---

  Widget _buildGroupedSection({
    required String header,
    required List<Widget> children,
  }) {
    return Builder(
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 24, 16, 8),
            child: Text(
              header,
              style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: CupertinoColors.systemBackground.resolveFrom(context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListTile({
    required BuildContext context,
    IconData? icon,
    required String title,
    String? value,
    String placeholder = "",
    required VoidCallback onTap,
    bool showChevron = true,
    bool isLast = false,
    Color? valueColor,
    Color? textColor,
    bool isBold = false,
  }) {
    final hasValue = value != null && value.isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.transparent, // Hit test
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: CupertinoTheme.of(context).primaryColor, size: 22),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 17,
                        color: textColor ?? CupertinoColors.label.resolveFrom(context),
                        fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                  Text(
                    hasValue ? value : placeholder,
                    style: TextStyle(
                      fontSize: 17,
                      color: hasValue
                          ? (valueColor ?? CupertinoColors.secondaryLabel.resolveFrom(context))
                          : CupertinoColors.placeholderText.resolveFrom(context),
                    ),
                  ),
                  if (showChevron) ...[
                    const SizedBox(width: 6),
                    Icon(
                      CupertinoIcons.chevron_right,
                      size: 16,
                      color: CupertinoColors.systemGrey3.resolveFrom(context),
                    ),
                  ],
                ],
              ),
            ),
            if (!isLast)
              Divider(
                height: 1,
                indent: 50, // Matches standard iOS indent
                color: CupertinoColors.systemGrey5.resolveFrom(context),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildServiceRow(BuildContext context, dynamic service, int index, bool isLast, SegmentConfigProvider config) {
    return _buildDismissibleItem(
      context: context,
      index: index,
      onDelete: () => _confirmDeleteService(index, config),
      child: _buildItemRow(
        context: context,
        title: service.service?.name ?? "Serviço",
        subtitle: service.description,
        trailing: _convertToCurrency(service.value),
        onTap: () => _editService(index),
        isLast: isLast,
      ),
    );
  }

  Widget _buildProductRow(BuildContext context, dynamic product, int index, bool isLast, SegmentConfigProvider config) {
    return _buildDismissibleItem(
      context: context,
      index: index,
      onDelete: () => _confirmDeleteProduct(index, config),
      child: _buildItemRow(
        context: context,
        title: product.product?.name ?? "Produto",
        subtitle: "${product.quantity}x • ${product.description ?? ''}",
        trailing: _convertToCurrency(product.total),
        onTap: () => _editProduct(index),
        isLast: isLast,
      ),
    );
  }

  Widget _buildDismissibleItem({
    required BuildContext context,
    required int index,
    required VoidCallback onDelete,
    required Widget child,
  }) {
    return Dismissible(
      key: ValueKey('item_$index'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        onDelete();
        return false; // Don't auto-dismiss, let the confirmation handle it
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: CupertinoColors.systemRed,
        child: const Icon(
          CupertinoIcons.trash,
          color: CupertinoColors.white,
        ),
      ),
      child: child,
    );
  }

  Widget _buildItemRow({
    required BuildContext context,
    required String title,
    String? subtitle,
    required String trailing,
    required VoidCallback onTap,
    required bool isLast,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.transparent,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 17,
                            color: CupertinoColors.label.resolveFrom(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle != null && subtitle.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2.0),
                            child: Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: 13,
                                color: CupertinoColors.secondaryLabel.resolveFrom(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    trailing,
                    style: TextStyle(
                      fontSize: 15,
                      color: CupertinoColors.label.resolveFrom(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    CupertinoIcons.chevron_right,
                    size: 16,
                    color: CupertinoColors.systemGrey3.resolveFrom(context),
                  ),
                ],
              ),
            ),
            if (!isLast)
              Divider(
                height: 1,
                indent: 16,
                color: CupertinoColors.systemGrey5.resolveFrom(context),
              ),
          ],
        ),
      ),
    );
  }

  // --- Actions ---

  void _showActionSheet(BuildContext context, SegmentConfigProvider config) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: Text('Opções da ${config.serviceOrder}'),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            child: const Text('Compartilhar PDF'),
            onPressed: () {
              Navigator.pop(context);
              _onShare(context, _store.order, config);
            },
          ),
          CupertinoActionSheetAction(
            child: Text(config.label(LabelKeys.addPhoto)),
            onPressed: () {
              Navigator.pop(context);
              _showAddPhotoOptions(config);
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          child: Text('Excluir ${config.serviceOrder}'),
          onPressed: () {
            Navigator.pop(context);
            _showDeleteConfirmation(config);
          },
        ),
      ),
    );
  }

  void _selectCustomer() {
    Navigator.pushNamed(
      context,
      '/customer_list',
      arguments: {'order': _store.order},
    ).then((customer) {
      if (customer != null) {
        _store.setCustomer(customer as Customer);
      }
    });
  }

  void _selectDevice() {
    Navigator.pushNamed(
      context,
      '/device_list',
      arguments: {'order': _store.order},
    ).then((device) {
      if (device != null) {
        _store.setDevice(device as Device);
      }
    });
  }

  void _selectDueDate() {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        height: 216,
        padding: const EdgeInsets.only(top: 6.0),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: SafeArea(
          top: false,
          child: CupertinoDatePicker(
            initialDateTime: (_store.order?.dueDate != null) ? _store.order!.dueDate! : DateTime.now(),
            mode: CupertinoDatePickerMode.date,
            use24hFormat: true,
            onDateTimeChanged: (DateTime newDate) {
              _store.setDueDate(newDate);
            },
          ),
        ),
      ),
    );
  }

  void _selectStatus(SegmentConfigProvider config) {
     // Assuming ModalStatus().showModal returns a Future<String?>
     // We should adapt it to CupertinoActionSheet or keep using it if it's custom.
     // To follow strict HIG, let's use ActionSheet here.
     
     final statusKeys = ['quote', 'approved', 'progress', 'done', 'canceled'];
     
     showCupertinoModalPopup(
       context: context,
       builder: (context) => CupertinoActionSheet(
         title: const Text("Alterar Status"),
         actions: statusKeys.map((key) {
           return CupertinoActionSheetAction(
             child: Text(config.getStatus(key)),
             onPressed: () {
               _store.setStatus(key);
               Navigator.pop(context);
             },
           );
         }).toList(),
         cancelButton: CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(config.label(LabelKeys.cancel)),
          ),
       ),
     );
  }

  void _showPaymentOptions(SegmentConfigProvider config) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text("Pagamento"),
        actions: [
          CupertinoActionSheetAction(
            child: const Text("Marcar como Pago"),
            onPressed: () {
              _store.order!.payment = 'paid';
              _store.updateOrder();
              Navigator.pop(context);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text("Marcar como A Receber"),
            onPressed: () {
              _store.order!.payment = 'unpaid';
              _store.updateOrder();
              Navigator.pop(context);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text("Conceder Desconto"),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(
                context,
                '/payment_form_screen',
                arguments: {'orderStore': _store},
              ).then((value) {
                if (value != null) _store.setDiscount(value as double);
              });
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: Text(config.label(LabelKeys.cancel)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _addService() {
    Navigator.pushNamed(
      context,
      '/service_list',
      arguments: {'orderStore': _store},
    );
  }

  void _editService(int index) {
    Navigator.pushNamed(
      context,
      '/order_service',
      arguments: {
        'orderStore': _store,
        'orderServiceIndex': index,
      },
    );
  }

  void _addProduct() {
    Navigator.pushNamed(
      context,
      '/product_list',
      arguments: {'orderStore': _store},
    );
  }

  void _editProduct(int index) {
    Navigator.pushNamed(
      context,
      '/order_product',
      arguments: {
        'orderStore': _store,
        'orderProductIndex': index,
      },
    );
  }

  void _confirmDeleteService(int index, SegmentConfigProvider config) {
    final service = _store.services?[index];
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('${config.label(LabelKeys.remove)} ${config.label(LabelKeys.editService).split(' ').last}'),
        content: Text('Deseja remover "${service?.service?.name ?? 'este serviço'}" da ${config.serviceOrder}?'),
        actions: [
          CupertinoDialogAction(
            child: Text(config.label(LabelKeys.cancel)),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: Text(config.label(LabelKeys.remove)),
            onPressed: () {
              Navigator.pop(context);
              _store.deleteService(index);
            },
          ),
        ],
      ),
    );
  }

  void _confirmDeleteProduct(int index, SegmentConfigProvider config) {
    final product = _store.products?[index];
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('${config.label(LabelKeys.remove)} ${config.label(LabelKeys.editProduct).split(' ').last}'),
        content: Text('Deseja remover "${product?.product?.name ?? 'este produto'}" da ${config.serviceOrder}?'),
        actions: [
          CupertinoDialogAction(
            child: Text(config.label(LabelKeys.cancel)),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: Text(config.label(LabelKeys.remove)),
            onPressed: () {
              Navigator.pop(context);
              _store.deleteProduct(index);
            },
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(SegmentConfigProvider config) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Excluir ${config.serviceOrder}'),
        content: Text('Tem certeza que deseja excluir esta ${config.serviceOrder}?'),
        actions: [
          CupertinoDialogAction(
            child: Text(config.label(LabelKeys.cancel)),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: Text(config.label(LabelKeys.delete)),
            onPressed: () {
              _store.deleteOrder().then((_) {
                if (mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              });
            },
          ),
        ],
      ),
    );
  }
  
  void _showAddPhotoOptions(SegmentConfigProvider config) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(config.label(LabelKeys.addPhoto)),
        actions: [
           CupertinoActionSheetAction(
            child: const Text("Tirar Foto"),
            onPressed: () async {
              Navigator.pop(context);
              final success = await _store.addPhotoFromCamera();
              if (!success && mounted) {
                 ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Erro ao adicionar foto')),
                  );
              }
            },
          ),
           CupertinoActionSheetAction(
            child: const Text("Escolher da Galeria"),
            onPressed: () async {
              Navigator.pop(context);
              final success = await _store.addPhotoFromGallery();
               if (!success && mounted) {
                 ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Erro ao adicionar foto')),
                  );
              }
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: Text(config.label(LabelKeys.cancel)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  Color _getStatusColorCupertino(String? status) {
    if (status == null) return CupertinoColors.systemGrey;
    switch (status) {
      case 'quote':
        return CupertinoColors.systemOrange;
      case 'approved':
        return CupertinoColors.systemBlue;
      case 'progress':
        return CupertinoColors.systemPurple;
      case 'done':
        return CupertinoColors.systemGreen;
      case 'canceled':
        return CupertinoColors.systemRed;
      default:
        return CupertinoColors.systemGrey;
    }
  }

  String _convertToCurrency(double? total) {
    total ??= 0.0;
    NumberFormat numberFormat = NumberFormat.currency(
      locale: 'pt-BR',
      symbol: 'R\$',
    );
    return numberFormat.format(total);
  }
  
  // PDF Generation Logic (Kept mostly as is, just function signature matches)
  _onShare(BuildContext context, Order? order, SegmentConfigProvider config) async {
    if (order == null) return;

    // Store navigator reference before async operations
    final navigator = Navigator.of(context, rootNavigator: true);

    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return CupertinoAlertDialog(
          content: Column(
            children: const [
              CupertinoActivityIndicator(),
              SizedBox(height: 10),
              Text('Gerando PDF...'),
            ],
          ),
        );
      },
    );

    try {
      CompanyStore companyStore = CompanyStore();
      Company company = await companyStore.retrieveCompany(order.company!.id);

      // Download company logo
      pw.MemoryImage? logoImage;
      if (company.logo != null && company.logo!.isNotEmpty) {
        try {
          final response = await http.get(Uri.parse(company.logo!));
          if (response.statusCode == 200) {
            logoImage = pw.MemoryImage(response.bodyBytes);
          }
        } catch (e) {
          // Logo optional, continue without it
        }
      }

      Customer? customer;
      if (order.customer != null) {
        CustomerStore customerStore = CustomerStore();
        customer = await customerStore.retrieveCustomer(order.customer?.id);
      }

      List<pw.MemoryImage>? photoImages;
      if (order.photos != null && order.photos!.isNotEmpty) {
        photoImages = await _downloadPhotos(order);
      }

      // Buscar formulários da OS
      List<of_model.OrderForm> orderForms = [];
      Map<String, List<pw.MemoryImage>> formPhotos = {};
      if (order.id != null && _store.companyId != null) {
        try {
          orderForms = await _formsService.getOrderForms(_store.companyId!, order.id!).first;
          // Baixar fotos dos formulários
          for (var form in orderForms) {
            formPhotos[form.id] = await _downloadFormPhotos(form);
          }
        } catch (e) {
          // Formulários opcionais, continua sem eles
        }
      }

      // Load fonts with Unicode support for Portuguese characters
      pw.Font baseFont;
      pw.Font boldFont;
      pw.Font lightFont;
      try {
        baseFont = await PdfGoogleFonts.nunitoSansRegular();
        boldFont = await PdfGoogleFonts.nunitoSansBold();
        lightFont = await PdfGoogleFonts.nunitoSansLight();
      } catch (e) {
        // Fallback to Helvetica if Google Fonts fail to load
        baseFont = pw.Font.helvetica();
        boldFont = pw.Font.helveticaBold();
        lightFont = pw.Font.helvetica();
      }

      final doc = pw.Document();

      // Cores do tema profissional
      final PdfColor primaryColor = PdfColor.fromHex('#1a56db'); // Azul profissional
      final PdfColor accentColor = PdfColor.fromHex('#0e9f6e'); // Verde sucesso
      final PdfColor darkColor = PdfColor.fromHex('#1f2937'); // Cinza escuro
      final PdfColor mutedColor = PdfColor.fromHex('#6b7280'); // Cinza médio
      final PdfColor lightBg = PdfColor.fromHex('#f9fafb'); // Fundo claro
      final PdfColor borderColor = PdfColor.fromHex('#e5e7eb'); // Borda sutil

      // Página principal da OS
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (pw.Context ctx) {
            return _buildProfessionalHeader(
              company, order, primaryColor, darkColor, mutedColor,
              baseFont, boldFont, lightFont, config, logoImage
            );
          },
          footer: (pw.Context ctx) {
            return _buildProfessionalFooter(ctx, mutedColor, baseFont, company);
          },
          build: (pw.Context ctx) {
            return _buildProfessionalContent(
              order, customer, company, photoImages,
              baseFont, boldFont, lightFont, config,
              primaryColor, accentColor, darkColor, mutedColor, lightBg, borderColor
            );
          },
        ),
      );

      // Páginas separadas para cada formulário
      for (var form in orderForms) {
        doc.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(32),
            header: (pw.Context ctx) {
              return _buildFormPageHeader(
                form, order, company, darkColor, mutedColor,
                boldFont, lightFont, config, logoImage
              );
            },
            footer: (pw.Context ctx) {
              return _buildProfessionalFooter(ctx, mutedColor, baseFont, company);
            },
            build: (pw.Context ctx) {
              return _buildFormPageContent(
                form, formPhotos[form.id] ?? [],
                baseFont, boldFont, lightFont,
                accentColor, darkColor, mutedColor, lightBg, borderColor
              );
            },
          ),
        );
      }

      if (mounted) {
        navigator.pop();
      }

      await Printing.sharePdf(
        bytes: await doc.save(),
        filename: "${config.serviceOrder}-${order.number ?? 'NOVA'}.pdf",
      );
    } catch (e) {
      if (context.mounted) {
        navigator.pop();

        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Erro'),
            content: Text('Erro ao gerar PDF: $e'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<List<pw.MemoryImage>> _downloadPhotos(Order order) async {
    List<pw.MemoryImage> images = [];
    final photosToDownload = order.photos!.take(9).toList(); // Aumentado para 9 fotos
    for (var photo in photosToDownload) {
      try {
        if (photo.url != null && photo.url!.isNotEmpty) {
          final response = await http.get(Uri.parse(photo.url!));
          if (response.statusCode == 200) {
            final image = pw.MemoryImage(response.bodyBytes);
            images.add(image);
          }
        }
      } catch (e) {
        print('Erro ao baixar foto: $e');
      }
    }
    return images;
  }

  Future<List<pw.MemoryImage>> _downloadFormPhotos(of_model.OrderForm form) async {
    List<pw.MemoryImage> images = [];
    for (var response in form.responses) {
      if (response.photoUrls.isNotEmpty) {
        for (var url in response.photoUrls.take(6)) {
          try {
            final httpResponse = await http.get(Uri.parse(url));
            if (httpResponse.statusCode == 200) {
              images.add(pw.MemoryImage(httpResponse.bodyBytes));
            }
          } catch (e) {
            // Foto opcional, continua sem ela
          }
        }
      }
    }
    return images;
  }
  
  // ============================================================================
  // NOVO DESIGN PROFISSIONAL DO PDF
  // ============================================================================

  PdfColor _getStatusColor(String? status) {
    switch (status) {
      case 'approved':
        return PdfColor.fromHex('#3b82f6'); // Azul
      case 'done':
        return PdfColor.fromHex('#10b981'); // Verde
      case 'canceled':
        return PdfColor.fromHex('#ef4444'); // Vermelho
      case 'quote':
        return PdfColor.fromHex('#f59e0b'); // Laranja
      case 'progress':
        return PdfColor.fromHex('#8b5cf6'); // Roxo
      default:
        return PdfColor.fromHex('#6b7280'); // Cinza
    }
  }

  // Header profissional
  pw.Widget _buildProfessionalHeader(
    Company company,
    Order order,
    PdfColor primaryColor,
    PdfColor darkColor,
    PdfColor mutedColor,
    pw.Font baseFont,
    pw.Font boldFont,
    pw.Font lightFont,
    SegmentConfigProvider config,
    [pw.MemoryImage? logoImage]
  ) {
    final statusColor = _getStatusColor(order.status);
    final statusText = config.getStatus(order.status);

    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 20),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 1)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Logo e informações da empresa
          pw.Expanded(
            flex: 2,
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (logoImage != null) ...[
                  pw.Container(
                    width: 56,
                    height: 56,
                    decoration: pw.BoxDecoration(
                      borderRadius: pw.BorderRadius.circular(8),
                      border: pw.Border.all(color: PdfColors.grey200, width: 1),
                    ),
                    child: pw.ClipRRect(
                      horizontalRadius: 8,
                      verticalRadius: 8,
                      child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                    ),
                  ),
                  pw.SizedBox(width: 14),
                ],
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        company.name ?? '',
                        style: pw.TextStyle(font: boldFont, fontSize: 15, color: darkColor),
                      ),
                      pw.SizedBox(height: 4),
                      if (company.phone != null && company.phone!.isNotEmpty)
                        pw.Row(children: [
                          pw.Text('Tel: ', style: pw.TextStyle(font: lightFont, fontSize: 8, color: mutedColor)),
                          pw.Text(company.phone!, style: pw.TextStyle(font: baseFont, fontSize: 8, color: mutedColor)),
                        ]),
                      if (company.email != null && company.email!.isNotEmpty)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(top: 1),
                          child: pw.Text(company.email!, style: pw.TextStyle(font: baseFont, fontSize: 8, color: mutedColor)),
                        ),
                      if (company.address != null && company.address!.isNotEmpty)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(top: 2),
                          child: pw.Text(company.address!, style: pw.TextStyle(font: lightFont, fontSize: 7, color: mutedColor), maxLines: 2),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Número da OS e Status
          pw.Container(
            width: 140,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                // Badge da OS
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: pw.BoxDecoration(
                    color: primaryColor,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text(
                        config.serviceOrder.toUpperCase(),
                        style: pw.TextStyle(font: lightFont, fontSize: 7, color: PdfColors.white, letterSpacing: 1.5),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        '#${order.number?.toString() ?? "NOVA"}',
                        style: pw.TextStyle(font: boldFont, fontSize: 20, color: PdfColors.white),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 10),
                // Datas
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#f3f4f6'),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.end,
                        children: [
                          pw.Text('Emissao: ', style: pw.TextStyle(font: lightFont, fontSize: 7, color: mutedColor)),
                          pw.Text(
                            DateFormat('dd/MM/yyyy').format(order.createdAt!),
                            style: pw.TextStyle(font: boldFont, fontSize: 8, color: darkColor),
                          ),
                        ],
                      ),
                      if (order.dueDate != null) ...[
                        pw.SizedBox(height: 3),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.end,
                          children: [
                            pw.Text('Previsao: ', style: pw.TextStyle(font: lightFont, fontSize: 7, color: mutedColor)),
                            pw.Text(
                              DateFormat('dd/MM/yyyy').format(order.dueDate!),
                              style: pw.TextStyle(font: boldFont, fontSize: 8, color: darkColor),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                pw.SizedBox(height: 8),
                // Status Badge
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: pw.BoxDecoration(
                    color: statusColor.shade(0.95),
                    borderRadius: pw.BorderRadius.circular(12),
                    border: pw.Border.all(color: statusColor, width: 1),
                  ),
                  child: pw.Row(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.Container(
                        width: 6,
                        height: 6,
                        decoration: pw.BoxDecoration(
                          color: statusColor,
                          shape: pw.BoxShape.circle,
                        ),
                      ),
                      pw.SizedBox(width: 6),
                      pw.Text(
                        statusText.toUpperCase(),
                        style: pw.TextStyle(font: boldFont, fontSize: 7, color: statusColor, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Footer profissional
  pw.Widget _buildProfessionalFooter(pw.Context context, PdfColor mutedColor, pw.Font baseFont, Company company) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 16),
      padding: const pw.EdgeInsets.only(top: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey200, width: 1)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Row(
            children: [
              pw.Container(
                width: 4,
                height: 4,
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#1a56db'),
                  shape: pw.BoxShape.circle,
                ),
              ),
              pw.SizedBox(width: 6),
              pw.Text(
                'PraticOS',
                style: pw.TextStyle(font: baseFont, fontSize: 8, color: PdfColor.fromHex('#1a56db')),
              ),
              pw.Text(
                ' • praticos.web.app',
                style: pw.TextStyle(font: baseFont, fontSize: 7, color: mutedColor),
              ),
            ],
          ),
          pw.Text(
            'Pagina ${context.pageNumber} de ${context.pagesCount}',
            style: pw.TextStyle(font: baseFont, fontSize: 8, color: mutedColor),
          ),
        ],
      ),
    );
  }

  // Conteúdo principal profissional
  List<pw.Widget> _buildProfessionalContent(
    Order order,
    Customer? customer,
    Company company,
    List<pw.MemoryImage>? photoImages,
    pw.Font baseFont,
    pw.Font boldFont,
    pw.Font lightFont,
    SegmentConfigProvider config,
    PdfColor primaryColor,
    PdfColor accentColor,
    PdfColor darkColor,
    PdfColor mutedColor,
    PdfColor lightBg,
    PdfColor borderColor,
  ) {
    double totalServices = order.services?.fold(0.0, (sum, s) => sum! + (s.value ?? 0)) ?? 0.0;
    double totalProducts = order.products?.fold(0.0, (sum, p) => sum! + (p.total ?? 0)) ?? 0.0;
    double subtotal = totalServices + totalProducts;
    double discount = order.discount ?? 0.0;
    double total = order.total ?? 0.0;
    final isPaid = order.payment == 'paid';

    return [
      pw.SizedBox(height: 8),

      // Cards de Cliente e Dispositivo
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Card do Cliente
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: lightBg,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: borderColor, width: 1),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    children: [
                      pw.Container(
                        width: 24,
                        height: 24,
                        decoration: pw.BoxDecoration(
                          color: primaryColor.shade(0.9),
                          borderRadius: pw.BorderRadius.circular(6),
                        ),
                        child: pw.Center(
                          child: pw.Text('👤', style: pw.TextStyle(fontSize: 12)),
                        ),
                      ),
                      pw.SizedBox(width: 8),
                      pw.Text(
                        config.customer.toUpperCase(),
                        style: pw.TextStyle(font: boldFont, fontSize: 8, color: primaryColor, letterSpacing: 1),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    customer?.name ?? 'Nao informado',
                    style: pw.TextStyle(font: boldFont, fontSize: 13, color: darkColor),
                  ),
                  if (customer?.phone != null && customer!.phone!.isNotEmpty) ...[
                    pw.SizedBox(height: 6),
                    pw.Row(
                      children: [
                        pw.Text('Tel: ', style: pw.TextStyle(font: lightFont, fontSize: 9, color: mutedColor)),
                        pw.Text(customer.phone!, style: pw.TextStyle(font: baseFont, fontSize: 9, color: darkColor)),
                      ],
                    ),
                  ],
                  if (customer?.email != null && customer!.email!.isNotEmpty) ...[
                    pw.SizedBox(height: 2),
                    pw.Text(customer.email!, style: pw.TextStyle(font: baseFont, fontSize: 8, color: mutedColor)),
                  ],
                  if (customer?.address != null && customer!.address!.isNotEmpty) ...[
                    pw.SizedBox(height: 4),
                    pw.Text(customer.address!, style: pw.TextStyle(font: lightFont, fontSize: 8, color: mutedColor), maxLines: 2),
                  ],
                ],
              ),
            ),
          ),
          pw.SizedBox(width: 10),
          // Card do Dispositivo
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: lightBg,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: borderColor, width: 1),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    children: [
                      pw.Container(
                        width: 24,
                        height: 24,
                        decoration: pw.BoxDecoration(
                          color: accentColor.shade(0.9),
                          borderRadius: pw.BorderRadius.circular(6),
                        ),
                        child: pw.Center(
                          child: pw.Text('⚙', style: pw.TextStyle(fontSize: 12)),
                        ),
                      ),
                      pw.SizedBox(width: 8),
                      pw.Text(
                        config.device.toUpperCase(),
                        style: pw.TextStyle(font: boldFont, fontSize: 8, color: accentColor, letterSpacing: 1),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    order.device?.name ?? 'Nao informado',
                    style: pw.TextStyle(font: boldFont, fontSize: 13, color: darkColor),
                  ),
                  if (order.device?.serial != null && order.device!.serial!.isNotEmpty) ...[
                    pw.SizedBox(height: 8),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#e5e7eb'),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Row(
                        mainAxisSize: pw.MainAxisSize.min,
                        children: [
                          pw.Text('SN: ', style: pw.TextStyle(font: lightFont, fontSize: 8, color: mutedColor)),
                          pw.Text(
                            order.device!.serial!,
                            style: pw.TextStyle(font: boldFont, fontSize: 9, color: darkColor, letterSpacing: 0.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),

      pw.SizedBox(height: 20),

      // Seção de Serviços
      if (order.services != null && order.services!.isNotEmpty) ...[
        _buildProfessionalSectionHeader('SERVICOS', '${order.services!.length} ${order.services!.length == 1 ? 'item' : 'itens'}', primaryColor, baseFont, boldFont, lightFont),
        pw.SizedBox(height: 10),
        _buildServicesTable(order, baseFont, boldFont, lightFont, darkColor, mutedColor, borderColor),
        pw.SizedBox(height: 20),
      ],

      // Seção de Produtos
      if (order.products != null && order.products!.isNotEmpty) ...[
        _buildProfessionalSectionHeader('PECAS E PRODUTOS', '${order.products!.length} ${order.products!.length == 1 ? 'item' : 'itens'}', accentColor, baseFont, boldFont, lightFont),
        pw.SizedBox(height: 10),
        _buildProductsTable(order, baseFont, boldFont, lightFont, darkColor, mutedColor, borderColor),
        pw.SizedBox(height: 20),
      ],

      // Resumo Financeiro
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Container(
            width: 240,
            decoration: pw.BoxDecoration(
              borderRadius: pw.BorderRadius.circular(10),
              border: pw.Border.all(color: borderColor, width: 1),
            ),
            child: pw.Column(
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.all(14),
                  child: pw.Column(
                    children: [
                      if (totalServices > 0) _buildFinancialRow('Servicos', totalServices, baseFont, lightFont, mutedColor, darkColor),
                      if (totalProducts > 0) _buildFinancialRow('Produtos', totalProducts, baseFont, lightFont, mutedColor, darkColor),
                      if (totalServices > 0 || totalProducts > 0) ...[
                        pw.SizedBox(height: 8),
                        pw.Container(height: 1, color: borderColor),
                        pw.SizedBox(height: 8),
                      ],
                      _buildFinancialRow('Subtotal', subtotal, boldFont, lightFont, mutedColor, darkColor, isBold: true),
                      if (discount > 0) ...[
                        pw.SizedBox(height: 4),
                        _buildFinancialRow('Desconto', -discount, baseFont, lightFont, PdfColors.red600, PdfColors.red600),
                      ],
                    ],
                  ),
                ),
                // Total
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: pw.BoxDecoration(
                    color: isPaid ? accentColor : primaryColor,
                    borderRadius: const pw.BorderRadius.only(
                      bottomLeft: pw.Radius.circular(9),
                      bottomRight: pw.Radius.circular(9),
                    ),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            isPaid ? 'TOTAL PAGO' : 'TOTAL A PAGAR',
                            style: pw.TextStyle(font: boldFont, color: PdfColors.white, fontSize: 8, letterSpacing: 0.5),
                          ),
                          if (isPaid)
                            pw.Text('Pagamento confirmado', style: pw.TextStyle(font: lightFont, color: PdfColors.white, fontSize: 7)),
                        ],
                      ),
                      pw.Text(
                        _convertToCurrency(total),
                        style: pw.TextStyle(font: boldFont, color: PdfColors.white, fontSize: 18),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      pw.SizedBox(height: 32),

      // Área de Assinatura
      pw.Row(
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('ASSINATURA DO ${config.customer.toUpperCase()}',
                  style: pw.TextStyle(font: boldFont, fontSize: 7, color: mutedColor, letterSpacing: 1)),
                pw.SizedBox(height: 30),
                pw.Container(
                  width: 220,
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400, width: 1)),
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(customer?.name ?? '', style: pw.TextStyle(font: baseFont, fontSize: 9, color: darkColor)),
                pw.Text('Data: ____/____/________', style: pw.TextStyle(font: lightFont, fontSize: 8, color: mutedColor)),
              ],
            ),
          ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('ASSINATURA DO RESPONSAVEL',
                  style: pw.TextStyle(font: boldFont, fontSize: 7, color: mutedColor, letterSpacing: 1)),
                pw.SizedBox(height: 30),
                pw.Container(
                  width: 220,
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400, width: 1)),
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(company.name ?? '', style: pw.TextStyle(font: baseFont, fontSize: 9, color: darkColor)),
                pw.Text('Data: ____/____/________', style: pw.TextStyle(font: lightFont, fontSize: 8, color: mutedColor)),
              ],
            ),
          ),
        ],
      ),

      // Seção de Fotos
      if (order.photos != null && order.photos!.isNotEmpty) ...[
        pw.SizedBox(height: 28),
        pw.Container(height: 1, color: borderColor),
        pw.SizedBox(height: 16),
        _buildProfessionalSectionHeader('REGISTRO FOTOGRAFICO', '${order.photos!.length} ${order.photos!.length == 1 ? 'foto' : 'fotos'}', PdfColor.fromHex('#7c3aed'), baseFont, boldFont, lightFont),
        pw.SizedBox(height: 12),
        _buildPhotosGrid(photoImages, borderColor),
      ],
    ];
  }

  pw.Widget _buildProfessionalSectionHeader(String title, String subtitle, PdfColor color, pw.Font baseFont, pw.Font boldFont, pw.Font lightFont) {
    return pw.Row(
      children: [
        pw.Container(
          width: 4,
          height: 16,
          decoration: pw.BoxDecoration(
            color: color,
            borderRadius: pw.BorderRadius.circular(2),
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Text(title, style: pw.TextStyle(font: boldFont, fontSize: 11, color: color, letterSpacing: 0.5)),
        pw.Spacer(),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: pw.BoxDecoration(
            color: color.shade(0.95),
            borderRadius: pw.BorderRadius.circular(10),
          ),
          child: pw.Text(subtitle, style: pw.TextStyle(font: lightFont, fontSize: 8, color: color)),
        ),
      ],
    );
  }

  pw.Widget _buildFinancialRow(String label, double value, pw.Font labelFont, pw.Font lightFont, PdfColor labelColor, PdfColor valueColor, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(font: labelFont, fontSize: 10, color: labelColor)),
          pw.Text(_convertToCurrency(value), style: pw.TextStyle(font: isBold ? labelFont : lightFont, fontSize: 11, color: valueColor)),
        ],
      ),
    );
  }

  pw.Widget _buildServicesTable(Order order, pw.Font baseFont, pw.Font boldFont, pw.Font lightFont, PdfColor darkColor, PdfColor mutedColor, PdfColor borderColor) {
    return pw.Table(
      border: pw.TableBorder(
        horizontalInside: pw.BorderSide(color: borderColor, width: 0.5),
      ),
      columnWidths: {
        0: const pw.FlexColumnWidth(4),
        1: const pw.FixedColumnWidth(90),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColor.fromHex('#f8fafc')),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              child: pw.Text('DESCRICAO', style: pw.TextStyle(font: boldFont, fontSize: 8, color: mutedColor, letterSpacing: 0.5)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              child: pw.Text('VALOR', textAlign: pw.TextAlign.right, style: pw.TextStyle(font: boldFont, fontSize: 8, color: mutedColor, letterSpacing: 0.5)),
            ),
          ],
        ),
        ...order.services!.map((s) {
          final desc = s.description != null && s.description!.isNotEmpty ? ' - ${s.description}' : '';
          return pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(s.service?.name ?? '', style: pw.TextStyle(font: boldFont, fontSize: 10, color: darkColor)),
                    if (desc.isNotEmpty)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 2),
                        child: pw.Text(desc.substring(3), style: pw.TextStyle(font: lightFont, fontSize: 8, color: mutedColor)),
                      ),
                  ],
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                child: pw.Text(_convertToCurrency(s.value), textAlign: pw.TextAlign.right, style: pw.TextStyle(font: baseFont, fontSize: 10, color: darkColor)),
              ),
            ],
          );
        }),
      ],
    );
  }

  pw.Widget _buildProductsTable(Order order, pw.Font baseFont, pw.Font boldFont, pw.Font lightFont, PdfColor darkColor, PdfColor mutedColor, PdfColor borderColor) {
    return pw.Table(
      border: pw.TableBorder(
        horizontalInside: pw.BorderSide(color: borderColor, width: 0.5),
      ),
      columnWidths: {
        0: const pw.FixedColumnWidth(40),
        1: const pw.FlexColumnWidth(4),
        2: const pw.FixedColumnWidth(70),
        3: const pw.FixedColumnWidth(80),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColor.fromHex('#f8fafc')),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              child: pw.Text('QTD', textAlign: pw.TextAlign.center, style: pw.TextStyle(font: boldFont, fontSize: 8, color: mutedColor, letterSpacing: 0.5)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              child: pw.Text('DESCRICAO', style: pw.TextStyle(font: boldFont, fontSize: 8, color: mutedColor, letterSpacing: 0.5)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              child: pw.Text('UNIT.', textAlign: pw.TextAlign.right, style: pw.TextStyle(font: boldFont, fontSize: 8, color: mutedColor, letterSpacing: 0.5)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              child: pw.Text('TOTAL', textAlign: pw.TextAlign.right, style: pw.TextStyle(font: boldFont, fontSize: 8, color: mutedColor, letterSpacing: 0.5)),
            ),
          ],
        ),
        ...order.products!.map((p) {
          final desc = p.description != null && p.description!.isNotEmpty ? ' - ${p.description}' : '';
          return pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#e5e7eb'),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(p.quantity.toString(), textAlign: pw.TextAlign.center, style: pw.TextStyle(font: boldFont, fontSize: 9, color: darkColor)),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(p.product?.name ?? '', style: pw.TextStyle(font: boldFont, fontSize: 10, color: darkColor)),
                    if (desc.isNotEmpty)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 2),
                        child: pw.Text(desc.substring(3), style: pw.TextStyle(font: lightFont, fontSize: 8, color: mutedColor)),
                      ),
                  ],
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                child: pw.Text(_convertToCurrency(p.value), textAlign: pw.TextAlign.right, style: pw.TextStyle(font: lightFont, fontSize: 9, color: mutedColor)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                child: pw.Text(_convertToCurrency(p.total), textAlign: pw.TextAlign.right, style: pw.TextStyle(font: boldFont, fontSize: 10, color: darkColor)),
              ),
            ],
          );
        }),
      ],
    );
  }

  pw.Widget _buildPhotosGrid(List<pw.MemoryImage>? photoImages, PdfColor borderColor) {
    if (photoImages == null || photoImages.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromHex('#faf5ff'),
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(color: PdfColor.fromHex('#e9d5ff'), width: 1),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text('📷 ', style: pw.TextStyle(fontSize: 14)),
            pw.Text(
              'Fotos disponiveis no sistema digital',
              style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#7c3aed'), fontStyle: pw.FontStyle.italic),
            ),
          ],
        ),
      );
    }

    return pw.GridView(
      crossAxisCount: 3,
      childAspectRatio: 1,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: photoImages.map((image) {
        return pw.Container(
          decoration: pw.BoxDecoration(
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(color: borderColor, width: 1),
          ),
          child: pw.ClipRRect(
            verticalRadius: 8,
            horizontalRadius: 8,
            child: pw.Image(image, fit: pw.BoxFit.cover),
          ),
        );
      }).toList(),
    );
  }

  // ============================================================================
  // PÁGINAS DE FORMULÁRIOS DINÂMICOS
  // ============================================================================

  pw.Widget _buildFormPageHeader(
    of_model.OrderForm form,
    Order order,
    Company company,
    PdfColor darkColor,
    PdfColor mutedColor,
    pw.Font boldFont,
    pw.Font lightFont,
    SegmentConfigProvider config,
    [pw.MemoryImage? logoImage]
  ) {
    final statusColor = _getFormStatusColor(form.status);
    final statusText = _getFormStatusText(form.status);

    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 16),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 1)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Cabeçalho com logo e referência da OS
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Row(
                children: [
                  if (logoImage != null) ...[
                    pw.Container(
                      width: 32,
                      height: 32,
                      child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                    ),
                    pw.SizedBox(width: 10),
                  ],
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(company.name ?? '', style: pw.TextStyle(font: boldFont, fontSize: 11, color: darkColor)),
                      pw.Text('${config.serviceOrder} #${order.number ?? "NOVA"}', style: pw.TextStyle(font: lightFont, fontSize: 8, color: mutedColor)),
                    ],
                  ),
                ],
              ),
              // Status do formulário
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: pw.BoxDecoration(
                  color: statusColor.shade(0.95),
                  borderRadius: pw.BorderRadius.circular(12),
                  border: pw.Border.all(color: statusColor, width: 1),
                ),
                child: pw.Row(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.Container(
                      width: 6,
                      height: 6,
                      decoration: pw.BoxDecoration(color: statusColor, shape: pw.BoxShape.circle),
                    ),
                    pw.SizedBox(width: 6),
                    pw.Text(statusText.toUpperCase(), style: pw.TextStyle(font: boldFont, fontSize: 7, color: statusColor, letterSpacing: 0.5)),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 14),
          // Título do formulário
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#fef3c7'),
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: PdfColor.fromHex('#fcd34d'), width: 1),
            ),
            child: pw.Row(
              children: [
                pw.Container(
                  width: 32,
                  height: 32,
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#f59e0b'),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Center(child: pw.Text('📋', style: pw.TextStyle(fontSize: 16))),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('FORMULARIO', style: pw.TextStyle(font: boldFont, fontSize: 7, color: PdfColor.fromHex('#92400e'), letterSpacing: 1)),
                      pw.SizedBox(height: 2),
                      pw.Text(form.title, style: pw.TextStyle(font: boldFont, fontSize: 14, color: PdfColor.fromHex('#78350f'))),
                    ],
                  ),
                ),
                if (form.completedAt != null)
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Finalizado em', style: pw.TextStyle(font: lightFont, fontSize: 7, color: PdfColor.fromHex('#92400e'))),
                      pw.Text(DateFormat('dd/MM/yyyy HH:mm').format(form.completedAt!), style: pw.TextStyle(font: boldFont, fontSize: 9, color: PdfColor.fromHex('#78350f'))),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PdfColor _getFormStatusColor(of_model.FormStatus status) {
    switch (status) {
      case of_model.FormStatus.completed:
        return PdfColor.fromHex('#10b981');
      case of_model.FormStatus.inProgress:
        return PdfColor.fromHex('#3b82f6');
      case of_model.FormStatus.pending:
        return PdfColor.fromHex('#6b7280');
    }
  }

  String _getFormStatusText(of_model.FormStatus status) {
    switch (status) {
      case of_model.FormStatus.completed:
        return 'Concluido';
      case of_model.FormStatus.inProgress:
        return 'Em Andamento';
      case of_model.FormStatus.pending:
        return 'Pendente';
    }
  }

  List<pw.Widget> _buildFormPageContent(
    of_model.OrderForm form,
    List<pw.MemoryImage> formPhotos,
    pw.Font baseFont,
    pw.Font boldFont,
    pw.Font lightFont,
    PdfColor accentColor,
    PdfColor darkColor,
    PdfColor mutedColor,
    PdfColor lightBg,
    PdfColor borderColor,
  ) {
    List<pw.Widget> widgets = [];
    int photoIndex = 0;

    widgets.add(pw.SizedBox(height: 12));

    // Iterar sobre cada item do formulário
    for (int i = 0; i < form.items.length; i++) {
      final item = form.items[i];
      final response = form.getResponse(item.id);

      widgets.add(
        pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 12),
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            color: lightBg,
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(color: borderColor, width: 1),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Cabeçalho do item
              pw.Row(
                children: [
                  pw.Container(
                    width: 24,
                    height: 24,
                    decoration: pw.BoxDecoration(
                      color: _getItemTypeColor(item.type).shade(0.9),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Center(
                      child: pw.Text('${i + 1}', style: pw.TextStyle(font: boldFont, fontSize: 10, color: _getItemTypeColor(item.type))),
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          item.label,
                          style: pw.TextStyle(font: boldFont, fontSize: 11, color: darkColor),
                        ),
                        pw.Text(
                          _getItemTypeLabel(item.type),
                          style: pw.TextStyle(font: lightFont, fontSize: 8, color: mutedColor),
                        ),
                      ],
                    ),
                  ),
                  if (item.required)
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#fef2f2'),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text('Obrigatorio', style: pw.TextStyle(font: boldFont, fontSize: 7, color: PdfColor.fromHex('#dc2626'))),
                    ),
                ],
              ),
              pw.SizedBox(height: 12),
              // Resposta
              _buildFormItemResponse(item, response, baseFont, boldFont, lightFont, darkColor, mutedColor, accentColor),
              // Fotos do item (se houver)
              if (response != null && response.photoUrls.isNotEmpty) ...[
                pw.SizedBox(height: 12),
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#faf5ff'),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        children: [
                          pw.Text('📷 ', style: pw.TextStyle(fontSize: 10)),
                          pw.Text('${response.photoUrls.length} ${response.photoUrls.length == 1 ? 'foto anexada' : 'fotos anexadas'}',
                            style: pw.TextStyle(font: boldFont, fontSize: 8, color: PdfColor.fromHex('#7c3aed'))),
                        ],
                      ),
                      if (formPhotos.isNotEmpty && photoIndex < formPhotos.length) ...[
                        pw.SizedBox(height: 8),
                        pw.Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: response.photoUrls.take(3).map((_) {
                            if (photoIndex < formPhotos.length) {
                              final img = formPhotos[photoIndex++];
                              return pw.Container(
                                width: 80,
                                height: 80,
                                decoration: pw.BoxDecoration(
                                  borderRadius: pw.BorderRadius.circular(6),
                                  border: pw.Border.all(color: PdfColor.fromHex('#e9d5ff'), width: 1),
                                ),
                                child: pw.ClipRRect(
                                  horizontalRadius: 6,
                                  verticalRadius: 6,
                                  child: pw.Image(img, fit: pw.BoxFit.cover),
                                ),
                              );
                            }
                            return pw.SizedBox();
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // Se houver fotos restantes que não foram associadas a itens específicos
    if (photoIndex < formPhotos.length) {
      widgets.add(pw.SizedBox(height: 16));
      widgets.add(
        _buildProfessionalSectionHeader('FOTOS ADICIONAIS', '${formPhotos.length - photoIndex} fotos', PdfColor.fromHex('#7c3aed'), baseFont, boldFont, lightFont),
      );
      widgets.add(pw.SizedBox(height: 12));
      widgets.add(
        pw.GridView(
          crossAxisCount: 3,
          childAspectRatio: 1,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: formPhotos.sublist(photoIndex).map((image) {
            return pw.Container(
              decoration: pw.BoxDecoration(
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: borderColor, width: 1),
              ),
              child: pw.ClipRRect(
                verticalRadius: 8,
                horizontalRadius: 8,
                child: pw.Image(image, fit: pw.BoxFit.cover),
              ),
            );
          }).toList(),
        ),
      );
    }

    return widgets;
  }

  PdfColor _getItemTypeColor(FormItemType type) {
    switch (type) {
      case FormItemType.text:
        return PdfColor.fromHex('#3b82f6');
      case FormItemType.number:
        return PdfColor.fromHex('#8b5cf6');
      case FormItemType.select:
        return PdfColor.fromHex('#f59e0b');
      case FormItemType.checklist:
        return PdfColor.fromHex('#10b981');
      case FormItemType.photoOnly:
        return PdfColor.fromHex('#ec4899');
      case FormItemType.boolean:
        return PdfColor.fromHex('#06b6d4');
    }
  }

  String _getItemTypeLabel(FormItemType type) {
    switch (type) {
      case FormItemType.text:
        return 'Campo de texto';
      case FormItemType.number:
        return 'Campo numerico';
      case FormItemType.select:
        return 'Selecao unica';
      case FormItemType.checklist:
        return 'Lista de verificacao';
      case FormItemType.photoOnly:
        return 'Somente foto';
      case FormItemType.boolean:
        return 'Sim/Nao';
    }
  }

  pw.Widget _buildFormItemResponse(
    FormItemDefinition item,
    of_model.FormResponse? response,
    pw.Font baseFont,
    pw.Font boldFont,
    pw.Font lightFont,
    PdfColor darkColor,
    PdfColor mutedColor,
    PdfColor accentColor,
  ) {
    if (response == null || response.value == null) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromHex('#fef2f2'),
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: PdfColor.fromHex('#fecaca'), width: 1),
        ),
        child: pw.Text('Nao respondido', style: pw.TextStyle(font: lightFont, fontSize: 10, color: PdfColor.fromHex('#dc2626'), fontStyle: pw.FontStyle.italic)),
      );
    }

    switch (item.type) {
      case FormItemType.boolean:
        final isYes = response.value == true || response.value == 'true' || response.value == 'Sim';
        return pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: pw.BoxDecoration(
            color: isYes ? PdfColor.fromHex('#ecfdf5') : PdfColor.fromHex('#fef2f2'),
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: isYes ? accentColor : PdfColor.fromHex('#fecaca'), width: 1),
          ),
          child: pw.Row(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Container(
                width: 18,
                height: 18,
                decoration: pw.BoxDecoration(
                  color: isYes ? accentColor : PdfColor.fromHex('#ef4444'),
                  borderRadius: pw.BorderRadius.circular(9),
                ),
                child: pw.Center(
                  child: pw.Text(isYes ? '✓' : '✕', style: pw.TextStyle(font: boldFont, fontSize: 10, color: PdfColors.white)),
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Text(isYes ? 'SIM' : 'NAO', style: pw.TextStyle(font: boldFont, fontSize: 12, color: isYes ? accentColor : PdfColor.fromHex('#dc2626'))),
            ],
          ),
        );

      case FormItemType.checklist:
        if (response.value is List) {
          final items = (response.value as List).map((e) => e.toString()).toList();
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: items.map((checkedItem) {
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Row(
                  children: [
                    pw.Container(
                      width: 16,
                      height: 16,
                      decoration: pw.BoxDecoration(
                        color: accentColor,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Center(child: pw.Text('✓', style: pw.TextStyle(font: boldFont, fontSize: 10, color: PdfColors.white))),
                    ),
                    pw.SizedBox(width: 10),
                    pw.Text(checkedItem, style: pw.TextStyle(font: baseFont, fontSize: 10, color: darkColor)),
                  ],
                ),
              );
            }).toList(),
          );
        }
        return pw.Text(response.value.toString(), style: pw.TextStyle(font: baseFont, fontSize: 10, color: darkColor));

      case FormItemType.select:
        return pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#fffbeb'),
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: PdfColor.fromHex('#fcd34d'), width: 1),
          ),
          child: pw.Row(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Container(
                width: 8,
                height: 8,
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#f59e0b'),
                  shape: pw.BoxShape.circle,
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Text(response.value.toString(), style: pw.TextStyle(font: boldFont, fontSize: 11, color: PdfColor.fromHex('#92400e'))),
            ],
          ),
        );

      case FormItemType.number:
        return pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#f5f3ff'),
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: PdfColor.fromHex('#c4b5fd'), width: 1),
          ),
          child: pw.Text(response.value.toString(), style: pw.TextStyle(font: boldFont, fontSize: 14, color: PdfColor.fromHex('#7c3aed'))),
        );

      case FormItemType.photoOnly:
        return pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#fdf2f8'),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Text('Ver fotos anexadas abaixo', style: pw.TextStyle(font: lightFont, fontSize: 9, color: PdfColor.fromHex('#be185d'), fontStyle: pw.FontStyle.italic)),
        );

      case FormItemType.text:
      default:
        return pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.white,
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: PdfColor.fromHex('#d1d5db'), width: 1),
          ),
          child: pw.Text(response.value.toString(), style: pw.TextStyle(font: baseFont, fontSize: 10, color: darkColor)),
        );
    }
  }

}
