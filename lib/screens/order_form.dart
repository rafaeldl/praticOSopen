import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, ScaffoldMessenger, SnackBar, Material, MaterialType, Divider; 
// Keeping Material for some specific helpers or if absolutely needed, but main UI is Cupertino.
// Actually, strict HIG means avoiding Material widgets where possible.
// I will try to rely purely on Cupertino for the visual tree.

import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:intl/intl.dart';
import 'package:praticos/mobx/company_store.dart';
import 'package:praticos/mobx/customer_store.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/screens/widgets/order_photos_widget.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class OrderForm extends StatefulWidget {
  @override
  _OrderFormState createState() => _OrderFormState();
}

class _OrderFormState extends State<OrderForm> {
  late OrderStore _store;

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
          _store.repository.getSingle(orderArg.id).then((updatedOrder) {
            _store.setOrder(updatedOrder ?? orderArg);
          });
        } else if (orderArg.number != null) {
          _store.repository.getOrderByNumber(orderArg.number!).then((
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
    // Using CupertinoPageScaffold for iOS look
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: Material(
        type: MaterialType.transparency,
        child: CustomScrollView(
          slivers: [
            _buildNavigationBar(context),
            SliverSafeArea(
              top: false, // Navigation bar handles top safe area
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildPhotosSection(context),
                  _buildClientDeviceSection(context),
                  _buildStatusDatesSection(context),
                  _buildServicesSection(context),
                  _buildProductsSection(context),
                  _buildTotalSection(context),
                  const SizedBox(height: 40),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationBar(BuildContext context) {
    return CupertinoSliverNavigationBar(
      largeTitle: Observer(
        builder: (_) {
          Order? os = _store.orderStream?.value;
          return Text(os?.number != null ? "OS #${os!.number}" : "Nova OS");
        },
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            child: const Icon(CupertinoIcons.camera),
            onPressed: () => _showAddPhotoOptions(),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            child: const Icon(CupertinoIcons.ellipsis_circle),
            onPressed: () => _showActionSheet(context),
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

  Widget _buildClientDeviceSection(BuildContext context) {
    return Observer(
      builder: (_) {
        return _buildGroupedSection(
          header: "CLIENTE E VEÍCULO",
          children: [
            _buildListTile(
              context: context,
              icon: CupertinoIcons.person_fill,
              title: "Cliente",
              value: _store.customerName,
              placeholder: "Selecionar Cliente",
              onTap: _selectCustomer,
              showChevron: true,
            ),
            _buildListTile(
              context: context,
              icon: CupertinoIcons.car_detailed,
              title: "Veículo",
              value: _store.deviceName,
              placeholder: "Selecionar Veículo",
              onTap: _selectDevice,
              showChevron: true,
              isLast: true,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusDatesSection(BuildContext context) {
    return Observer(
      builder: (_) {
        return _buildGroupedSection(
          header: "DETALHES",
          children: [
            _buildListTile(
              context: context,
              icon: CupertinoIcons.flag_fill,
              title: "Status",
              value: Order.statusMap[_store.status] ?? 'Pendente',
              onTap: _selectStatus,
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

  Widget _buildServicesSection(BuildContext context) {
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
                    return _buildServiceRow(context, service, index, index == services.length - 1);
                  }).toList(),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: CupertinoButton(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(CupertinoIcons.add_circled_solid),
                    SizedBox(width: 8),
                    Text("Adicionar Serviço"),
                  ],
                ),
                onPressed: _addService,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProductsSection(BuildContext context) {
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
                    return _buildProductRow(context, product, index, index == products.length - 1);
                  }).toList(),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: CupertinoButton(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                     Icon(CupertinoIcons.add_circled_solid),
                     SizedBox(width: 8),
                     Text("Adicionar Produto"),
                  ],
                ),
                onPressed: _addProduct,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTotalSection(BuildContext context) {
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
              title: "Total",
              value: _convertToCurrency(total),
              onTap: () {},
              showChevron: false,
              isBold: true,
              valueColor: CupertinoColors.black,
            ),
             _buildListTile(
              context: context,
              title: "Situação",
              value: isPaid ? "PAGO" : "A RECEBER",
              onTap: _showPaymentOptions,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 24, 16, 8),
          child: Text(
            header,
            style: const TextStyle(
              fontSize: 13,
              color: CupertinoColors.secondaryLabel,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: CupertinoColors.secondarySystemGroupedBackground,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
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
                        color: textColor ?? CupertinoColors.label,
                        fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                  Text(
                    hasValue ? value : placeholder,
                    style: TextStyle(
                      fontSize: 17,
                      color: hasValue 
                          ? (valueColor ?? CupertinoColors.secondaryLabel)
                          : CupertinoColors.placeholderText,
                    ),
                  ),
                  if (showChevron) ...[
                    const SizedBox(width: 6),
                    const Icon(
                      CupertinoIcons.chevron_right,
                      size: 16,
                      color: CupertinoColors.systemGrey3,
                    ),
                  ],
                ],
              ),
            ),
            if (!isLast)
              const Divider(
                height: 1,
                indent: 50, // Matches standard iOS indent
                color: CupertinoColors.systemGrey5,
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildServiceRow(BuildContext context, dynamic service, int index, bool isLast) {
    return _buildItemRow(
      context: context,
      title: service.service?.name ?? "Serviço",
      subtitle: service.description,
      trailing: _convertToCurrency(service.value),
      onTap: () => _editService(index),
      isLast: isLast,
    );
  }

  Widget _buildProductRow(BuildContext context, dynamic product, int index, bool isLast) {
    return _buildItemRow(
      context: context,
      title: product.product?.name ?? "Produto",
      subtitle: "${product.quantity}x • ${product.description ?? ''}",
      trailing: _convertToCurrency(product.total),
      onTap: () => _editProduct(index),
      isLast: isLast,
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
                          style: const TextStyle(
                            fontSize: 17,
                            color: CupertinoColors.label,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle != null && subtitle.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2.0),
                            child: Text(
                              subtitle,
                              style: const TextStyle(
                                fontSize: 13,
                                color: CupertinoColors.secondaryLabel,
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
                    style: const TextStyle(
                      fontSize: 15,
                      color: CupertinoColors.label,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    CupertinoIcons.chevron_right,
                    size: 16,
                    color: CupertinoColors.systemGrey3,
                  ),
                ],
              ),
            ),
            if (!isLast)
              const Divider(
                height: 1,
                indent: 16,
                color: CupertinoColors.systemGrey5,
              ),
          ],
        ),
      ),
    );
  }

  // --- Actions ---

  void _showActionSheet(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: const Text('Opções da OS'),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            child: const Text('Compartilhar PDF'),
            onPressed: () {
              Navigator.pop(context);
              _onShare(context, _store.order);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('Adicionar Foto'),
            onPressed: () {
              Navigator.pop(context);
              _showAddPhotoOptions();
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          child: const Text('Excluir OS'),
          onPressed: () {
            Navigator.pop(context);
            _showDeleteConfirmation();
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

  void _selectStatus() {
     // Assuming ModalStatus().showModal returns a Future<String?>
     // We should adapt it to CupertinoActionSheet or keep using it if it's custom.
     // To follow strict HIG, let's use ActionSheet here.
     
     final statuses = Order.statusMap;
     
     showCupertinoModalPopup(
       context: context,
       builder: (context) => CupertinoActionSheet(
         title: const Text("Alterar Status"),
         actions: statuses.entries.map((entry) {
           return CupertinoActionSheetAction(
             child: Text(entry.value),
             onPressed: () {
               _store.setStatus(entry.key);
               Navigator.pop(context);
             },
           );
         }).toList(),
         cancelButton: CupertinoActionSheetAction(
            child: const Text('Cancelar'),
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(context);
            },
          ),
       ),
     );
  }

  void _showPaymentOptions() {
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
          child: const Text("Cancelar"),
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

  void _showDeleteConfirmation() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Excluir OS'),
        content: const Text('Tem certeza que deseja excluir esta Ordem de Serviço?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Excluir'),
            onPressed: () {
              _store.deleteOrder().then((_) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              });
            },
          ),
        ],
      ),
    );
  }
  
  void _showAddPhotoOptions() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text("Adicionar Foto"),
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
          child: const Text("Cancelar"),
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
    if (total == null) total = 0.0;
    NumberFormat numberFormat = NumberFormat.currency(
      locale: 'pt-BR',
      symbol: 'R\$',
    );
    return numberFormat.format(total);
  }
  
  // PDF Generation Logic (Kept mostly as is, just function signature matches)
  _onShare(BuildContext context, Order? order) async {
    if (order == null) return;

    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
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

      Customer? customer;
      if (order.customer != null) {
        CustomerStore customerStore = CustomerStore();
        customer = await customerStore.retrieveCustomer(order.customer?.id);
      }

      List<pw.MemoryImage>? photoImages;
      if (order.photos != null && order.photos!.isNotEmpty) {
        photoImages = await _downloadPhotos(order);
      }

      final doc = pw.Document();
      // ... PDF building logic stays the same ...
      // I am simplifying the PDF code part here to save tokens and focus on UI, 
      // assuming I can reuse the previous helpers. 
      // But I must include them to make the file compilable.
      
      final PdfColor primaryColor = PdfColor.fromHex('#2196F3');
      final PdfColor darkGray = PdfColor.fromHex('#757575');

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          header: (pw.Context context) {
            return _buildHeader(company, order, primaryColor, darkGray);
          },
          footer: (pw.Context context) {
            return _buildFooter(context, darkGray);
          },
          build: (pw.Context context) {
            return _printLayoutContent(order, customer, company, photoImages);
          },
        ),
      );

      Navigator.of(context, rootNavigator: true).pop();

      await Printing.sharePdf(
        bytes: await doc.save(),
        filename: "OS-${order.number == null ? 'NOVA' : order.number}.pdf",
      );
    } catch (e) {
      Navigator.of(context, rootNavigator: true).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao gerar PDF: $e')),
      );
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
  pw.Widget _buildHeader(Company company, Order order, PdfColor primaryColor, PdfColor darkGray) {
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  company.name!.toUpperCase(),
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 20.0,
                    color: primaryColor,
                  ),
                ),
                pw.SizedBox(height: 4),
                if (company.phone != null)
                  pw.Text(
                    company.phone!,
                    style: pw.TextStyle(fontSize: 10.0, color: darkGray),
                  ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'ORDEM DE SERVIÇO',
                  style: pw.TextStyle(
                    fontSize: 10.0,
                    letterSpacing: 1.5,
                    fontWeight: pw.FontWeight.bold,
                    color: darkGray,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  '#${order.number?.toString() ?? "NOVA"}',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 24.0,
                    color: PdfColors.black,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  DateFormat('dd/MM/yyyy').format(order.createdAt!),
                  style: pw.TextStyle(fontSize: 10.0, color: darkGray),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 20),
        pw.Divider(color: PdfColors.grey300, thickness: 1),
        pw.SizedBox(height: 20),
      ],
    );
  }

  pw.Widget _buildFooter(pw.Context context, PdfColor darkGray) {
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
            style: pw.TextStyle(fontSize: 8, color: darkGray),
          ),
          pw.Text(
            'Página ${context.pageNumber} de ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 8, color: darkGray),
          ),
        ],
      ),
    );
  }

  List<pw.Widget> _printLayoutContent(Order order, Customer? customer, Company company, [List<pw.MemoryImage>? photoImages]) {
    DateFormat dateFormat = DateFormat('dd/MM/yyyy');
    final PdfColor primaryColor = PdfColor.fromHex('#1565C0');
    final PdfColor darkGray = PdfColor.fromHex('#424242');
    final PdfColor lightGray = PdfColor.fromHex('#EEEEEE');

    double totalServices = order.services?.fold(0.0, (sum, s) => sum! + (s.value ?? 0)) ?? 0.0;
    double totalProducts = order.products?.fold(0.0, (sum, p) => sum! + (p.total ?? 0)) ?? 0.0;
    double subtotal = totalServices + totalProducts;
    double discount = order.discount ?? 0.0;
    double total = order.total ?? 0.0;

    return [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('CLIENTE', primaryColor),
                pw.SizedBox(height: 8),
                pw.Text(
                  customer?.name ?? 'Cliente não informado',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                ),
                if (customer?.phone != null) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(customer!.phone!, style: pw.TextStyle(fontSize: 10, color: darkGray)),
                ],
              ],
            ),
          ),
          pw.SizedBox(width: 20),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('VEÍCULO', primaryColor),
                pw.SizedBox(height: 8),
                pw.Text(
                  order.device?.name ?? 'Veículo não informado',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                ),
                if (order.device?.serial != null) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(order.device!.serial!, style: pw.TextStyle(fontSize: 10, color: darkGray)),
                ],
              ],
            ),
          ),
        ],
      ),

      pw.SizedBox(height: 15),

      pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: pw.BoxDecoration(
          color: lightGray,
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _buildDetailItem('STATUS', Order.statusMap[order.status] ?? 'Pendente'),
            _buildDetailItem('PREVISÃO', order.dueDate != null ? dateFormat.format(order.dueDate!) : '-'),
            _buildDetailItem('SITUAÇÃO PAGTO.', order.payment == 'paid' ? 'PAGO' : 'A RECEBER'),
          ],
        ),
      ),

      pw.SizedBox(height: 25),

      if (order.services != null && order.services!.isNotEmpty) ...[
        _buildSectionTitle('SERVIÇOS REALIZADOS', primaryColor),
        pw.SizedBox(height: 8),
        _printServices(order),
        pw.SizedBox(height: 20),
      ],

      if (order.products != null && order.products!.isNotEmpty) ...[
        _buildSectionTitle('PEÇAS E PRODUTOS', primaryColor),
        pw.SizedBox(height: 8),
        _printProduct(order),
        pw.SizedBox(height: 20),
      ],

      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Container(
            width: 200,
            child: pw.Column(
              children: [
                if (totalServices > 0) _buildSummaryRow('Total Serviços', totalServices),
                if (totalProducts > 0) _buildSummaryRow('Total Produtos', totalProducts),
                pw.Divider(color: PdfColors.grey300),
                _buildSummaryRow('Subtotal', subtotal, isBold: true),
                if (discount > 0) _buildSummaryRow('Desconto', -discount, color: PdfColors.red700),
                pw.SizedBox(height: 8),
                pw.Container(
                  color: primaryColor,
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('TOTAL A PAGAR', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      pw.Text(_convertToCurrency(total), style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      pw.SizedBox(height: 40),

      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.start,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(width: 250, child: pw.Divider(color: PdfColors.black, thickness: 0.5)),
              pw.SizedBox(height: 4),
              pw.Text(customer?.name ?? 'Cliente', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.Text('Assinatura do Cliente', style: pw.TextStyle(fontSize: 8, color: darkGray)),
            ],
          ),
        ],
      ),
      
      if (order.photos != null && order.photos!.isNotEmpty) ...[
        pw.Divider(color: PdfColors.grey300),
        pw.SizedBox(height: 10),
        _buildSectionTitle('REGISTRO FOTOGRÁFICO', primaryColor),
        pw.SizedBox(height: 10),
        _printPhotos(order, photoImages),
      ],
    ];
  }

  pw.Widget _buildSectionTitle(String title, PdfColor color) {
    return pw.Text(
      title,
      style: pw.TextStyle(
        color: color,
        fontSize: 10,
        fontWeight: pw.FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
  }

  pw.Widget _buildDetailItem(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
        pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  pw.Widget _buildSummaryRow(String label, double value, {bool isBold = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 10, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(_convertToCurrency(value), style: pw.TextStyle(fontSize: 10, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color)),
        ],
      ),
    );
  }
  
  pw.Widget _printProduct(Order order) {
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
          _modernTableHeader('QTD'),
          _modernTableHeader('DESCRIÇÃO'),
          _modernTableHeader('UNIT.', alignRight: true),
          _modernTableHeader('TOTAL', alignRight: true),
        ],
      ),
      ...order.products!.map((p) {
        return pw.TableRow(
          children: [
            _modernTableCell(p.quantity.toString(), alignCenter: true),
            _modernTableCell("${p.product?.name} ${p.description != null ? '- ${p.description}' : ''}"),
            _modernTableCell(_convertToCurrency(p.value), alignRight: true),
            _modernTableCell(_convertToCurrency(p.total), alignRight: true),
          ],
        );
      }).toList(),
    ],
  );
}

pw.Widget _printServices(Order order) {
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
          _modernTableHeader('DESCRIÇÃO DO SERVIÇO'),
          _modernTableHeader('VALOR', alignRight: true),
        ],
      ),
      ...order.services!.map((s) {
        return pw.TableRow(
          children: [
            _modernTableCell("${s.service?.name} ${s.description != null ? '- ${s.description}' : ''}"),
            _modernTableCell(_convertToCurrency(s.value), alignRight: true),
          ],
        );
      }).toList(),
    ],
  );
}

pw.Widget _modernTableHeader(String text, {bool alignRight = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8),
    child: pw.Text(
      text,
      textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
      style: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        fontSize: 8.0,
        color: PdfColor.fromHex('#616161'),
      ),
    ),
  );
}

pw.Widget _modernTableCell(String text, {bool alignRight = false, bool alignCenter = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8),
    child: pw.Text(
      text,
      textAlign: alignRight ? pw.TextAlign.right : (alignCenter ? pw.TextAlign.center : pw.TextAlign.left),
      style: const pw.TextStyle(fontSize: 9.0, color: PdfColors.black),
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