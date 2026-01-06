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
    if (_store.order?.id == null) return;

    final segmentId = config.segmentId ?? 'other';

    final template = await Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => FormSelectionScreen(
          segmentId: segmentId,
          companyId: _store.companyId,
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

      // Load fonts with Unicode support for Portuguese characters
      pw.Font baseFont;
      pw.Font boldFont;
      try {
        baseFont = await PdfGoogleFonts.nunitoSansRegular();
        boldFont = await PdfGoogleFonts.nunitoSansBold();
      } catch (e) {
        // Fallback to Helvetica if Google Fonts fail to load
        baseFont = pw.Font.helvetica();
        boldFont = pw.Font.helveticaBold();
      }

      final doc = pw.Document();

      final PdfColor primaryColor = PdfColor.fromHex('#2196F3');
      final PdfColor darkGray = PdfColor.fromHex('#757575');

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          header: (pw.Context context) {
            return _buildHeader(company, order, primaryColor, darkGray, baseFont, boldFont, config, logoImage);
          },
          footer: (pw.Context context) {
            return _buildFooter(context, darkGray, baseFont);
          },
          build: (pw.Context context) {
            return _printLayoutContent(order, customer, company, photoImages, baseFont, boldFont, config);
          },
        ),
      );

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
    final photosToDownload = order.photos!.take(6).toList();
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
  
  // Re-implementing PDF helpers to ensure self-contained file (except models)
  pw.Widget _buildHeader(Company company, Order order, PdfColor primaryColor, PdfColor darkGray, pw.Font baseFont, pw.Font boldFont, SegmentConfigProvider config, [pw.MemoryImage? logoImage]) {
    final statusColor = _getStatusColor(order.status);
    final statusText = config.getStatus(order.status);

    return pw.Column(
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Logo + Company Info
            pw.Expanded(
              flex: 3,
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (logoImage != null) ...[
                    pw.Container(
                      width: 50,
                      height: 50,
                      child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                    ),
                    pw.SizedBox(width: 12),
                  ],
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          company.name ?? '',
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 16.0,
                            color: PdfColors.grey800,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        if (company.phone != null && company.phone!.isNotEmpty)
                          pw.Text(
                            company.phone!,
                            style: pw.TextStyle(font: baseFont, fontSize: 9.0, color: darkGray),
                          ),
                        if (company.email != null && company.email!.isNotEmpty)
                          pw.Text(
                            company.email!,
                            style: pw.TextStyle(font: baseFont, fontSize: 9.0, color: darkGray),
                          ),
                        if (company.address != null && company.address!.isNotEmpty)
                          pw.Text(
                            company.address!,
                            style: pw.TextStyle(font: baseFont, fontSize: 9.0, color: darkGray),
                            maxLines: 2,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // OS Number and Info
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                // OS Badge
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: pw.BoxDecoration(
                    color: primaryColor,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        config.serviceOrder.toUpperCase(),
                        style: pw.TextStyle(
                          font: boldFont,
                          fontSize: 8.0,
                          color: PdfColors.white,
                          letterSpacing: 1,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        '#${order.number?.toString() ?? "NOVA"}',
                        style: pw.TextStyle(
                          font: boldFont,
                          fontSize: 18.0,
                          color: PdfColors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 8),
                // Date
                pw.Text(
                  'Data: ${DateFormat('dd/MM/yyyy').format(order.createdAt!)}',
                  style: pw.TextStyle(font: baseFont, fontSize: 9.0, color: darkGray),
                ),
                if (order.dueDate != null) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Previsao: ${DateFormat('dd/MM/yyyy').format(order.dueDate!)}',
                    style: pw.TextStyle(font: baseFont, fontSize: 9.0, color: darkGray),
                  ),
                ],
                pw.SizedBox(height: 6),
                // Status Badge
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: pw.BoxDecoration(
                    color: statusColor.shade(0.9),
                    borderRadius: pw.BorderRadius.circular(3),
                    border: pw.Border.all(color: statusColor, width: 0.5),
                  ),
                  child: pw.Text(
                    statusText.toUpperCase(),
                    style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 8.0,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Container(
          height: 2,
          decoration: pw.BoxDecoration(
            gradient: pw.LinearGradient(
              colors: [primaryColor, PdfColors.grey300],
              begin: pw.Alignment.centerLeft,
              end: pw.Alignment.centerRight,
            ),
          ),
        ),
        pw.SizedBox(height: 16),
      ],
    );
  }

  PdfColor _getStatusColor(String? status) {
    switch (status) {
      case 'approved':
        return PdfColors.blue700;
      case 'done':
        return PdfColors.green700;
      case 'canceled':
        return PdfColors.red700;
      case 'quote':
        return PdfColors.orange700;
      case 'progress':
        return PdfColors.purple700;
      default:
        return PdfColors.grey600;
    }
  }

  pw.Widget _buildFooter(pw.Context context, PdfColor darkGray, pw.Font baseFont) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 20),
      padding: const pw.EdgeInsets.only(top: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Documento gerado eletronicamente pelo PraticOS - praticos.web.app',
            style: pw.TextStyle(font: baseFont, fontSize: 8, color: darkGray),
          ),
          pw.Text(
            'Pagina ${context.pageNumber} de ${context.pagesCount}',
            style: pw.TextStyle(font: baseFont, fontSize: 8, color: darkGray),
          ),
        ],
      ),
    );
  }

  List<pw.Widget> _printLayoutContent(Order order, Customer? customer, Company company, List<pw.MemoryImage>? photoImages, pw.Font baseFont, pw.Font boldFont, SegmentConfigProvider config) {
    final PdfColor primaryColor = PdfColor.fromHex('#1565C0');
    final PdfColor darkGray = PdfColor.fromHex('#616161');
    final PdfColor lightGray = PdfColor.fromHex('#F8F9FA');
    final PdfColor borderColor = PdfColor.fromHex('#E0E0E0');

    double totalServices = order.services?.fold(0.0, (sum, s) => sum! + (s.value ?? 0)) ?? 0.0;
    double totalProducts = order.products?.fold(0.0, (sum, p) => sum! + (p.total ?? 0)) ?? 0.0;
    double subtotal = totalServices + totalProducts;
    double discount = order.discount ?? 0.0;
    double total = order.total ?? 0.0;

    final isPaid = order.payment == 'paid';

    return [
      // Client & Vehicle Cards
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Client Card
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: lightGray,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: borderColor, width: 0.5),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    config.customer.toUpperCase(),
                    style: pw.TextStyle(font: boldFont, fontSize: 8, color: primaryColor, letterSpacing: 0.5),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    customer?.name ?? 'Nao informado',
                    style: pw.TextStyle(font: boldFont, fontSize: 12, color: PdfColors.grey800),
                  ),
                  if (customer?.phone != null && customer!.phone!.isNotEmpty) ...[
                    pw.SizedBox(height: 4),
                    pw.Text(customer.phone!, style: pw.TextStyle(font: baseFont, fontSize: 9, color: darkGray)),
                  ],
                  if (customer?.email != null && customer!.email!.isNotEmpty) ...[
                    pw.SizedBox(height: 2),
                    pw.Text(customer.email!, style: pw.TextStyle(font: baseFont, fontSize: 9, color: darkGray)),
                  ],
                ],
              ),
            ),
          ),
          pw.SizedBox(width: 12),
          // Vehicle Card
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: lightGray,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: borderColor, width: 0.5),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    config.device.toUpperCase(),
                    style: pw.TextStyle(font: boldFont, fontSize: 8, color: primaryColor, letterSpacing: 0.5),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    order.device?.name ?? 'Nao informado',
                    style: pw.TextStyle(font: boldFont, fontSize: 12, color: PdfColors.grey800),
                  ),
                  if (order.device?.serial != null && order.device!.serial!.isNotEmpty) ...[
                    pw.SizedBox(height: 4),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey300,
                        borderRadius: pw.BorderRadius.circular(3),
                      ),
                      child: pw.Text(
                        order.device!.serial!,
                        style: pw.TextStyle(font: boldFont, fontSize: 10, color: PdfColors.grey800),
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

      // Services Section
      if (order.services != null && order.services!.isNotEmpty) ...[
        _buildSectionHeader('SERVICOS', '${order.services!.length} itens', primaryColor, baseFont, boldFont),
        pw.SizedBox(height: 8),
        _printServices(order, baseFont, boldFont),
        pw.SizedBox(height: 16),
      ],

      // Products Section
      if (order.products != null && order.products!.isNotEmpty) ...[
        _buildSectionHeader('PECAS E PRODUTOS', '${order.products!.length} itens', primaryColor, baseFont, boldFont),
        pw.SizedBox(height: 8),
        _printProduct(order, baseFont, boldFont),
        pw.SizedBox(height: 16),
      ],

      // Summary Section
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Container(
            width: 220,
            decoration: pw.BoxDecoration(
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: borderColor, width: 0.5),
            ),
            child: pw.Column(
              children: [
                // Summary rows
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  child: pw.Column(
                    children: [
                      if (totalServices > 0) _buildSummaryRow('Servicos', totalServices, baseFont, boldFont),
                      if (totalProducts > 0) _buildSummaryRow('Produtos', totalProducts, baseFont, boldFont),
                      pw.Divider(color: borderColor, height: 16),
                      _buildSummaryRow('Subtotal', subtotal, baseFont, boldFont),
                      if (discount > 0) _buildSummaryRow('Desconto', -discount, baseFont, boldFont, color: PdfColors.red600),
                    ],
                  ),
                ),
                // Total
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  decoration: pw.BoxDecoration(
                    color: isPaid ? PdfColors.green700 : primaryColor,
                    borderRadius: const pw.BorderRadius.only(
                      bottomLeft: pw.Radius.circular(5),
                      bottomRight: pw.Radius.circular(5),
                    ),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        isPaid ? 'TOTAL PAGO' : 'TOTAL A PAGAR',
                        style: pw.TextStyle(font: boldFont, color: PdfColors.white, fontSize: 9),
                      ),
                      pw.Text(
                        _convertToCurrency(total),
                        style: pw.TextStyle(font: boldFont, color: PdfColors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      pw.SizedBox(height: 30),

      // Signature Section
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.start,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(width: 250, child: pw.Divider(color: PdfColors.grey600, thickness: 0.5)),
              pw.SizedBox(height: 4),
              pw.Text(customer?.name ?? config.customer, style: pw.TextStyle(font: boldFont, fontSize: 10, color: PdfColors.grey800)),
              pw.Text('Assinatura do ${config.customer}', style: pw.TextStyle(font: baseFont, fontSize: 8, color: PdfColors.grey500)),
            ],
          ),
        ],
      ),

      // Photos Section
      if (order.photos != null && order.photos!.isNotEmpty) ...[
        pw.SizedBox(height: 20),
        pw.Divider(color: borderColor),
        pw.SizedBox(height: 12),
        _buildSectionHeader('REGISTRO FOTOGRAFICO', '${order.photos!.length} fotos', primaryColor, baseFont, boldFont),
        pw.SizedBox(height: 10),
        _printPhotos(order, photoImages),
      ],
    ];
  }

  pw.Widget _buildSectionHeader(String title, String subtitle, PdfColor color, pw.Font baseFont, pw.Font boldFont) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            font: boldFont,
            color: color,
            fontSize: 10,
            letterSpacing: 0.5,
          ),
        ),
        pw.Text(
          subtitle,
          style: pw.TextStyle(
            font: baseFont,
            color: PdfColors.grey500,
            fontSize: 8,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildSummaryRow(String label, double value, pw.Font baseFont, pw.Font boldFont, {bool isBold = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(font: isBold ? boldFont : baseFont, fontSize: 10)),
          pw.Text(_convertToCurrency(value), style: pw.TextStyle(font: isBold ? boldFont : baseFont, fontSize: 10, color: color)),
        ],
      ),
    );
  }
  
  pw.Widget _printProduct(Order order, pw.Font baseFont, pw.Font boldFont) {
  return pw.Table(
    border: pw.TableBorder(
      bottom: const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
      horizontalInside: const pw.BorderSide(color: PdfColors.grey200, width: 0.5),
    ),
    columnWidths: {
      0: const pw.FixedColumnWidth(40),
      1: const pw.FlexColumnWidth(3),
      2: const pw.FixedColumnWidth(70),
      3: const pw.FixedColumnWidth(70),
    },
    children: [
      pw.TableRow(
        decoration: pw.BoxDecoration(color: PdfColor.fromHex('#F5F5F5')),
        children: [
          _modernTableHeader('QTD', boldFont),
          _modernTableHeader('DESCRICAO', boldFont),
          _modernTableHeader('UNIT.', boldFont, alignRight: true),
          _modernTableHeader('TOTAL', boldFont, alignRight: true),
        ],
      ),
      ...order.products!.map((p) {
        return pw.TableRow(
          children: [
            _modernTableCell(p.quantity.toString(), baseFont, alignCenter: true),
            _modernTableCell("${p.product?.name} ${p.description != null ? '- ${p.description}' : ''}", baseFont),
            _modernTableCell(_convertToCurrency(p.value), baseFont, alignRight: true),
            _modernTableCell(_convertToCurrency(p.total), baseFont, alignRight: true),
          ],
        );
      }),
    ],
  );
}

pw.Widget _printServices(Order order, pw.Font baseFont, pw.Font boldFont) {
  return pw.Table(
    border: pw.TableBorder(
      bottom: const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
      horizontalInside: const pw.BorderSide(color: PdfColors.grey200, width: 0.5),
    ),
    columnWidths: {
      0: const pw.FlexColumnWidth(3),
      1: const pw.FixedColumnWidth(80),
    },
    children: [
      pw.TableRow(
        decoration: pw.BoxDecoration(color: PdfColor.fromHex('#F5F5F5')),
        children: [
          _modernTableHeader('DESCRICAO DO SERVICO', boldFont),
          _modernTableHeader('VALOR', boldFont, alignRight: true),
        ],
      ),
      ...order.services!.map((s) {
        return pw.TableRow(
          children: [
            _modernTableCell("${s.service?.name} ${s.description != null ? '- ${s.description}' : ''}", baseFont),
            _modernTableCell(_convertToCurrency(s.value), baseFont, alignRight: true),
          ],
        );
      }),
    ],
  );
}

pw.Widget _modernTableHeader(String text, pw.Font boldFont, {bool alignRight = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8),
    child: pw.Text(
      text,
      textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
      style: pw.TextStyle(
        font: boldFont,
        fontSize: 8.0,
        color: PdfColor.fromHex('#616161'),
      ),
    ),
  );
}

pw.Widget _modernTableCell(String text, pw.Font baseFont, {bool alignRight = false, bool alignCenter = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8),
    child: pw.Text(
      text,
      textAlign: alignRight ? pw.TextAlign.right : (alignCenter ? pw.TextAlign.center : pw.TextAlign.left),
      style: pw.TextStyle(font: baseFont, fontSize: 9.0, color: PdfColors.black),
    ),
  );
}

pw.Widget _printPhotos(Order order, [List<pw.MemoryImage>? photoImages]) {
  if (order.photos == null || order.photos!.isEmpty) {
    return pw.SizedBox();
  }

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        'Fotos Anexadas (${order.photos!.length})',
        style: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          fontSize: 14.0,
          color: PdfColor.fromHex('#1976D2'),
        ),
      ),
      pw.SizedBox(height: 12),

      if (photoImages != null && photoImages.isNotEmpty)
        pw.GridView(
          crossAxisCount: 3,
          childAspectRatio: 1,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          children: photoImages.map((image) {
            return pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300, width: 1),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.ClipRRect(
                verticalRadius: 4,
                horizontalRadius: 4,
                child: pw.Image(image, fit: pw.BoxFit.cover),
              ),
            );
          }).toList(),
        )
      else
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#F5F5F5'),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Row(
            children: [
              pw.Icon(
                const pw.IconData(0xe412),
                size: 16,
                color: PdfColor.fromHex('#757575'),
              ),
              pw.SizedBox(width: 8),
              pw.Text(
                'Fotos disponíveis no sistema digital',
                style: pw.TextStyle(
                  fontSize: 10.0,
                  color: PdfColor.fromHex('#757575'),
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

}
