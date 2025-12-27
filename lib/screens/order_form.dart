import 'dart:async';
import 'package:http/http.dart' as http;

import 'package:praticos/mobx/company_store.dart';
import 'package:praticos/mobx/customer_store.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/screens/modal_menu.dart';
import 'package:praticos/screens/modal_status.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/screens/widgets/order_photos_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:intl/intl.dart';
import '../models/device.dart';
import 'order_item_row.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class OrderForm extends StatefulWidget {
  @override
  _OrderFormState createState() => _OrderFormState();
}

class _OrderFormState extends State<OrderForm> {
  late OrderStore _store;
  Map<String, dynamic>? args;

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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return WillPopScope(
      onWillPop: () async {
        if (_store.order != null && _store.order!.id != null) {
          await _store.repository.updateItem(_store.order);
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Observer(
            builder: (_) {
              Order? os = _store.orderStream?.value;
              return Text(os?.number != null ? "OS #${os!.number}" : "Nova OS");
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_a_photo_outlined),
              tooltip: 'Adicionar foto',
              onPressed: () => _showAddPhotoOptions(),
            ),
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'share') {
                  _onShare(context, _store.order);
                } else if (value == 'delete') {
                  _showDeleteConfirmation();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'share',
                  child: Row(
                    children: [
                      Icon(Icons.share_outlined),
                      SizedBox(width: 8),
                      Text('Compartilhar PDF'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Excluir', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Fotos da OS
                OrderPhotosWidget(store: _store),
                const SizedBox(height: 20),

                // Card de Cliente e Veículo
                _buildClientDeviceSection(theme, colorScheme),
                const SizedBox(height: 16),

                // Card de Status e Datas
                _buildStatusSection(theme, colorScheme),
                const SizedBox(height: 16),

                // Card de Total e Pagamento
                Observer(builder: (_) => _buildTotalSection(theme, colorScheme)),
                const SizedBox(height: 24),

                // Seção de Serviços
                _buildServicesSection(theme, colorScheme),
                const SizedBox(height: 20),

                // Seção de Produtos
                _buildProductsSection(theme, colorScheme),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClientDeviceSection(ThemeData theme, ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Cliente
            Observer(
              builder: (_) => _buildSelectionTile(
                icon: Icons.person_outline,
                label: 'Cliente',
                value: _store.customerName,
                placeholder: 'Selecionar cliente',
                onTap: () => _selectCustomer(),
                colorScheme: colorScheme,
                theme: theme,
              ),
            ),
            const Divider(height: 24),
            // Veículo
            Observer(
              builder: (_) => _buildSelectionTile(
                icon: Icons.directions_car_outlined,
                label: 'Veículo',
                value: _store.deviceName,
                placeholder: 'Selecionar veículo',
                onTap: () => _selectDevice(),
                colorScheme: colorScheme,
                theme: theme,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionTile({
    required IconData icon,
    required String label,
    required String? value,
    required String placeholder,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
    required ThemeData theme,
  }) {
    final hasValue = value != null && value.isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: hasValue
                    ? colorScheme.primaryContainer
                    : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: hasValue
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasValue ? value : placeholder,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: hasValue
                          ? colorScheme.onSurface
                          : colorScheme.onSurfaceVariant,
                      fontWeight: hasValue ? FontWeight.w600 : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSection(ThemeData theme, ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Data de Criação
            Expanded(
              child: Observer(
                builder: (_) => _buildInfoChip(
                  icon: Icons.calendar_today_outlined,
                  label: 'Criado em',
                  value: _store.formattedCreatedDate,
                  onTap: null,
                  colorScheme: colorScheme,
                  theme: theme,
                ),
              ),
            ),
            Container(
              height: 40,
              width: 1,
              color: colorScheme.outlineVariant,
            ),
            // Data de Entrega
            Expanded(
              child: Observer(
                builder: (_) => _buildInfoChip(
                  icon: Icons.event_outlined,
                  label: 'Entrega',
                  value: _store.dueDate ?? 'Definir',
                  onTap: () => _selectDueDate(),
                  colorScheme: colorScheme,
                  theme: theme,
                ),
              ),
            ),
            Container(
              height: 40,
              width: 1,
              color: colorScheme.outlineVariant,
            ),
            // Status
            Expanded(
              child: Observer(
                builder: (_) => _buildInfoChip(
                  icon: Icons.flag_outlined,
                  label: 'Status',
                  value: Order.statusMap[_store.status] ?? 'Pendente',
                  onTap: () => _selectStatus(),
                  colorScheme: colorScheme,
                  theme: theme,
                  isStatus: true,
                  statusKey: _store.status,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback? onTap,
    required ColorScheme colorScheme,
    required ThemeData theme,
    bool isStatus = false,
    String? statusKey,
  }) {
    Color? statusColor;
    if (isStatus && statusKey != null) {
      statusColor = _getStatusColor(statusKey, colorScheme);
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          children: [
            Icon(
              icon,
              size: 20,
              color: statusColor ?? colorScheme.primary,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: statusColor ?? colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status, ColorScheme colorScheme) {
    switch (status) {
      case 'quote':
        return Colors.orange;
      case 'approved':
        return Colors.blue;
      case 'progress':
        return Colors.purple;
      case 'done':
        return Colors.green;
      case 'canceled':
        return Colors.red;
      default:
        return colorScheme.primary;
    }
  }

  Widget _buildTotalSection(ThemeData theme, ColorScheme colorScheme) {
    final total = _store.total ?? 0.0;
    final discount = _store.discount ?? 0.0;
    final payment = _store.payment ?? '';
    final isPaid = payment == 'Pago';

    return Card(
      elevation: 0,
      color: colorScheme.primaryContainer.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.primary.withOpacity(0.3)),
      ),
      child: InkWell(
        onTap: () => _showPaymentOptions(),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isPaid ? Icons.check_circle : Icons.pending,
                          color: isPaid ? Colors.green : Colors.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          payment.isNotEmpty ? payment : 'A receber',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: isPaid ? Colors.green : Colors.orange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (discount > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.local_offer_outlined,
                            size: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Desconto: ${_convertToCurrency(discount)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Total',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    _convertToCurrency(total),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
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

  Widget _buildServicesSection(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.build_outlined,
                  color: colorScheme.primary,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  'Serviços',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            FilledButton.tonalIcon(
              onPressed: () => _addService(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Adicionar'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Observer(
          builder: (_) {
            final services = _store.services ?? [];
            if (services.isEmpty) {
              return _buildEmptyState(
                icon: Icons.build_outlined,
                message: 'Nenhum serviço adicionado',
                buttonLabel: 'Adicionar serviço',
                onPressed: () => _addService(),
                colorScheme: colorScheme,
                theme: theme,
              );
            }
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: services.length,
              itemBuilder: (context, index) {
                final service = services[index];
                return OrderItemRow(
                  title: service.service?.name,
                  description: service.description,
                  value: service.value,
                  photoUrl: service.photo,
                  fallbackIcon: Icons.build_outlined,
                  onTap: () => _editService(index),
                  onDelete: () {
                    _store.deleteService(index);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Serviço removido')),
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildProductsSection(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  color: colorScheme.primary,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  'Produtos',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            FilledButton.tonalIcon(
              onPressed: () => _addProduct(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Adicionar'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Observer(
          builder: (_) {
            final products = _store.products ?? [];
            if (products.isEmpty) {
              return _buildEmptyState(
                icon: Icons.inventory_2_outlined,
                message: 'Nenhum produto adicionado',
                buttonLabel: 'Adicionar produto',
                onPressed: () => _addProduct(),
                colorScheme: colorScheme,
                theme: theme,
              );
            }
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return OrderItemRow(
                  title: product.product?.name,
                  description: product.description,
                  value: product.value,
                  quantity: product.quantity,
                  photoUrl: product.photo,
                  fallbackIcon: Icons.inventory_2_outlined,
                  onTap: () => _editProduct(index),
                  onDelete: () {
                    _store.deleteProduct(index);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Produto removido')),
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    required String buttonLabel,
    required VoidCallback onPressed,
    required ColorScheme colorScheme,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 40,
            color: colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.add, size: 18),
            label: Text(buttonLabel),
          ),
        ],
      ),
    );
  }

  // Navigation methods
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

  void _selectDueDate() async {
    final picked = await showDatePicker(
      context: context,
      helpText: 'Selecione a data de entrega',
      initialDate: DateTime.now(),
      firstDate: DateTime(1970),
      lastDate: DateTime(2050),
    );
    if (picked != null) {
      _store.setDueDate(picked);
    }
  }

  void _selectStatus() {
    ModalStatus().showModal(context).then((value) {
      if (value != null) {
        _store.setStatus(value);
      }
    });
  }

  void _showPaymentOptions() async {
    final options = {
      'discount': {
        'text': 'Conceder desconto',
        'icon': const Icon(Icons.local_offer_outlined),
      },
      'unpaid': {
        'text': 'Marcar como A Receber',
        'icon': const Icon(Icons.money_off),
      },
      'paid': {
        'text': 'Marcar como Pago',
        'icon': const Icon(Icons.check_circle_outline),
      },
    };
    final value = await ModalMenu(options: options).showModal(context);
    if (value == 'unpaid') {
      _store.order!.payment = 'unpaid';
      _store.updateOrder();
    } else if (value == 'paid') {
      _store.order!.payment = 'paid';
      _store.updateOrder();
    } else if (value == 'discount') {
      Navigator.pushNamed(
        context,
        '/payment_form_screen',
        arguments: {'orderStore': _store},
      ).then((value) {
        if (value != null) _store.setDiscount(value as double);
      });
    }
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir OS'),
        content: const Text('Tem certeza que deseja excluir esta Ordem de Serviço?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              _store.deleteOrder().then((_) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              });
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  void _showAddPhotoOptions() {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (modalContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.camera_alt, color: theme.colorScheme.primary),
                  title: const Text('Tirar foto'),
                  onTap: () async {
                    Navigator.pop(modalContext);
                    final success = await _store.addPhotoFromCamera();
                    if (!success && mounted) {
                      scaffoldMessenger.showSnackBar(
                        const SnackBar(content: Text('Erro ao adicionar foto')),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: Icon(Icons.photo_library, color: theme.colorScheme.primary),
                  title: const Text('Escolher da galeria'),
                  onTap: () async {
                    Navigator.pop(modalContext);
                    final success = await _store.addPhotoFromGallery();
                    if (!success && mounted) {
                      scaffoldMessenger.showSnackBar(
                        const SnackBar(content: Text('Erro ao adicionar foto')),
                      );
                    }
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.close, color: Colors.grey),
                  title: const Text('Cancelar'),
                  onTap: () => Navigator.pop(modalContext),
                ),
              ],
            ),
          ),
        );
      },
    );
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

_onShare(BuildContext context, Order? order) async {
  if (order == null) return;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              SizedBox(height: 16),
              Text(
                'Gerando PDF...',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
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

    pw.SizedBox(height: 40),

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
