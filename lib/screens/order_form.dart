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
          // Carrega a OS do repositório se tiver ID
          _store.repository.getSingle(orderArg.id).then((updatedOrder) {
            _store.setOrder(updatedOrder ?? orderArg);
          });
        } else if (orderArg.number != null) {
          // Tenta buscar pelo número se não tiver ID
          _store.repository.getOrderByNumber(orderArg.number!).then((
            existingOrder,
          ) {
            _store.setOrder(existingOrder ?? orderArg);
          });
        } else {
          // Usa a OS passada nos argumentos
          _store.setOrder(orderArg);
        }
      } else {
        // Cria nova OS
        _store.loadOrder();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Garante que a OS seja salva antes de voltar
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
              return Text(os?.number != null ? "OS #${os!.number}" : "NOVA OS");
            },
          ),
          actions: <Widget>[
            IconButton(
              icon: Icon(Icons.more_vert),
              onPressed: () async {
                var options = {
                  'share': {'text': 'Compartilhar', 'icon': Icon(Icons.share)},
                  'delete': {'text': 'Excluir', 'icon': Icon(Icons.delete)},
                };
                String? value = await (ModalMenu(
                  options: options,
                ).showModal(context));

                if (value == 'share') {
                  await _onShare(context, _store.order);
                } else if (value == 'delete') {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) => AlertDialog(
                      content: Text('Excluir Ordem de Serviço ?'),
                      actions: <Widget>[
                        TextButton(
                          onPressed: () {
                            _store.deleteOrder().then((value) {
                              Navigator.of(
                                context,
                              ).popUntil((route) => route.isFirst);
                            });
                          },
                          child: Text('Sim'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: Text('Cancelar'),
                        ),
                      ],
                    ),
                  );
                }
              },
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(height: 10.0),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  child: OrderPhotosWidget(store: _store),
                ),
                SizedBox(height: 10.0),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9.0),
                  ),
                  padding: EdgeInsets.all(10),
                  child: Column(
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Observer(builder: (_) => _buildCustomerName()),
                              SizedBox(height: 10),
                              Observer(builder: (_) => _buildDeviceName()),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: <Widget>[
                              Observer(builder: (_) => buildTotal()),
                              Observer(builder: (_) => buildPayment()),
                            ],
                          ),
                        ],
                      ), // Cabeçalho
                      SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.grey[100]!,
                              width: 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey[200]!,
                                blurRadius: 6.0, // soften the shadow
                                spreadRadius: 2.0, //extend the shadow
                                offset: Offset(
                                  7.0, // Move to right 10  horizontally
                                  7.0, // Move to bottom 10 Vertically
                                ),
                              ),
                            ],
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20.0),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: <Widget>[
                              Observer(builder: (_) => _buildCreatedAt()),
                              VerticalDivider(),
                              Observer(builder: (_) => _buildDueDate()),
                              VerticalDivider(),
                              Observer(builder: (_) => _buildStatus()),
                            ],
                          ),
                        ),
                      ), // Status
                      SizedBox(height: 10), // Cabeçalho
                      Container(
                        child: Column(
                          children: <Widget>[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                Text(
                                  'Serviços',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.add),
                                  onPressed: () {
                                    Navigator.pushNamed(
                                      context,
                                      '/service_list',
                                      arguments: {'orderStore': _store},
                                    ).then((value) {
                                      print("valueee $value");
                                    });
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ), // Serviços
                      Observer(
                        builder: (_) {
                          List<OrderService> services = _store.services!;
                          return ListView.builder(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            itemCount: services.length,
                            itemBuilder: (context, index) {
                              OrderService orderService = services[index];

                              return GestureDetector(
                                onTap: () {
                                  Navigator.pushNamed(
                                    context,
                                    '/order_service',
                                    arguments: {
                                      'orderStore': _store,
                                      'orderServiceIndex': index,
                                    },
                                  );
                                },
                                child: Dismissible(
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    color: Colors.red,
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          right: 10.0,
                                        ),
                                        child: Icon(Icons.delete, size: 30),
                                      ),
                                    ),
                                  ),
                                  key: UniqueKey(),
                                  onDismissed: (direction) {
                                    _store.deleteService(index);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text("Item removido")),
                                    );
                                  },
                                  child: OrderItemRow(
                                    title: orderService.service!.name,
                                    description: orderService.description,
                                    value: orderService.value,
                                  ).buildItem(context),
                                ),
                              );
                            },
                          );
                        },
                      ),
                      Container(
                        child: Column(
                          children: <Widget>[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                Text(
                                  'Produtos',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.add),
                                  onPressed: () {
                                    Navigator.pushNamed(
                                      context,
                                      '/product_list',
                                      arguments: {'orderStore': _store},
                                    ).then((value) {});
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Observer(
                        builder: (_) {
                          List<OrderProduct> products = _store.products!;

                          return ListView.builder(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            itemCount: products.length,
                            itemBuilder: (context, index) {
                              OrderProduct orderProduct = products[index];
                              return GestureDetector(
                                onTap: () {
                                  Navigator.pushNamed(
                                    context,
                                    '/order_product',
                                    arguments: {
                                      'orderStore': _store,
                                      'orderProductIndex': index,
                                    },
                                  );
                                },
                                child: Dismissible(
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    color: Colors.red,
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          right: 10.0,
                                        ),
                                        child: Icon(Icons.delete, size: 30),
                                      ),
                                    ),
                                  ),
                                  key: UniqueKey(),
                                  onDismissed: (direction) {
                                    _store.deleteProduct(index);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text("Item removido")),
                                    );
                                  },
                                  child: OrderItemRow(
                                    title: orderProduct.product!.name,
                                    description: orderProduct.description,
                                    value: orderProduct.value,
                                    quantity: orderProduct.quantity,
                                  ).buildItem(context),
                                ),
                              );
                            },
                          );
                        },
                      ),
                      // Container(
                      //   child: Column(
                      //     children: <Widget>[
                      //       Row(
                      //         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      //         children: <Widget>[
                      //           Text('Comentários',
                      //               style: TextStyle(
                      //                 fontSize: 18,
                      //                 fontWeight: FontWeight.bold,
                      //               )),
                      //           IconButton(
                      //             icon: Icon(Icons.add),
                      //             onPressed: () {
                      //               Navigator.pushNamed(context, '/info_form');
                      //             },
                      //           ),
                      //         ],
                      //       ), // Cabeçalho inforamções
                      //       Column(
                      //         children: <Widget>[
                      //           Container(
                      //             decoration: BoxDecoration(
                      //               border: Border.all(
                      //                 color: Colors.grey[100],
                      //                 width: 1.0,
                      //               ),
                      //               boxShadow: [
                      //                 BoxShadow(
                      //                   color: Colors.grey[200],
                      //                   blurRadius: 6.0, // soften the shadow
                      //                   spreadRadius: 2.0, //extend the shadow
                      //                   offset: Offset(
                      //                     7.0, // Move to right 10  horizontally
                      //                     7.0, // Move to bottom 10 Vertically
                      //                   ),
                      //                 )
                      //               ],
                      //               color: Colors.white,
                      //               borderRadius: BorderRadius.circular(20.0),
                      //             ),
                      //             child: Padding(
                      //               padding: const EdgeInsets.all(8.0),
                      //               child: Column(
                      //                 children: <Widget>[
                      //                   Row(
                      //                     mainAxisAlignment:
                      //                         MainAxisAlignment.spaceBetween,
                      //                     children: <Widget>[
                      //                       CircleAvatar(
                      //                         radius: 30,
                      //                         backgroundImage: NetworkImage(Global.currentUser.photoUrl),
                      //                       ),
                      //                       Padding(
                      //                         padding:
                      //                             const EdgeInsets.all(8.0),
                      //                         child: Column(
                      //                           crossAxisAlignment:
                      //                               CrossAxisAlignment.start,
                      //                           children: <Widget>[
                      //                             Text(
                      //                                 Global.currentUser.displayName),
                      //                             Text('10/05/2020 12:34'),
                      //                           ],
                      //                         ),
                      //                       ),
                      //                       Spacer(),
                      //                       IconButton(
                      //                         icon: Icon(Icons.delete),
                      //                         onPressed: () {
                      //                           showDialog(
                      //                               context: context,
                      //                               builder:
                      //                                   (BuildContext context) {
                      //                                 return AlertDialog(
                      //                                   content: Text(
                      //                                       'Excluir Informação ?'),
                      //                                   actions: <Widget>[
                      //                                     new FlatButton(
                      //                                         onPressed: () {
                      //                                           print('Sim');
                      //                                         },
                      //                                         child:
                      //                                             Text('Sim')),
                      //                                     new FlatButton(
                      //                                         onPressed: () {
                      //                                           Navigator.of(
                      //                                                   context)
                      //                                               .pop();
                      //                                         },
                      //                                         child: Text(
                      //                                             'Cancelar')),
                      //                                   ],
                      //                                 );
                      //                               });
                      //                         },
                      //                       ),
                      //                     ],
                      //                   ), // Cabeçalho (imagem e data)
                      //                   SizedBox(height: 10),
                      //                   // Image(
                      //                   //   image: AssetImage(
                      //                   //       'assets/images/car2.jpg'),
                      //                   // ),
                      //                   SizedBox(height: 10),
                      //                   Text(
                      //                       'Problema na instalção do parachoque traseiro do veículo.')
                      //                 ],
                      //               ),
                      //             ),
                      //           ),
                      //         ],
                      //       ),
                      //     ],
                      //   ),
                      // ), // Informações
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerName() {
    if (_store.customerName != null)
      return GestureDetector(
        onTap: () {
          Navigator.pushNamed(
            context,
            '/customer_list',
            arguments: {'order': _store.order},
          ).then((customer) {
            _store.setCustomer(customer as Customer?);
          });
        },
        child: Text(
          _store.customerName!,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16.0,
            color: Theme.of(context).primaryColor,
            decoration: TextDecoration.underline,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
      );
    else
      return GestureDetector(
        onTap: () {
          Navigator.pushNamed(
            context,
            '/customer_list',
            arguments: {'order': _store.order},
          ).then((customer) {
            _store.setCustomer(customer as Customer?);
          });
        },
        child: Text(
          'Selecione o cliente',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16.0,
            color: Theme.of(context).primaryColor,
            decoration: TextDecoration.underline,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
      );
  }

  Widget _buildDeviceName() {
    if (_store.deviceName != null)
      return Padding(
        padding: const EdgeInsets.only(top: 5),
        child: GestureDetector(
          onTap: () {
            Navigator.pushNamed(
              context,
              '/device_list',
              arguments: {'order': _store.order},
            ).then((device) {
              _store.setDevice(device as Device?);
            });
          },
          child: Text(
            _store.deviceName!,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15.0,
              color: Theme.of(context).primaryColor,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      );
    else
      return Padding(
        padding: const EdgeInsets.only(top: 5),
        child: GestureDetector(
          onTap: () {
            Navigator.pushNamed(
              context,
              '/device_list',
              arguments: {'order': _store.order},
            ).then((device) {
              _store.setDevice(device as Device?);
            });
          },
          child: Text(
            'Selecione o veículo',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16.0,
              color: Theme.of(context).primaryColor,
              decoration: TextDecoration.underline,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      );
  }

  Widget buildTotal() {
    double? total = _store.total;
    double? discount = _store.discount;
    return GestureDetector(
      onTap: () async {
        var options = {
          'discount': {
            'text': 'Conceder desconto',
            'icon': Icon(Icons.local_offer_outlined),
          },
          'unpaid': {
            'text': 'Pagamento a receber',
            'icon': Icon(Icons.money_off),
          },
          'paid': {
            'text': 'Marcar como Pago',
            'icon': Icon(Icons.monetization_on),
          },
        };
        String? value = await (ModalMenu(options: options).showModal(context));
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
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              Text(
                _convertToCurrency(discount),
                style: TextStyle(
                  fontWeight: FontWeight.w300,
                  fontSize: 14.0,
                  letterSpacing: -1.6,
                ),
              ),
              SizedBox(width: 3.0),
              Icon(Icons.local_offer_outlined, size: 14),
            ],
          ),
          Text(
            _convertToCurrency(total),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 24.0,
              letterSpacing: -1.6,
            ),
          ),
        ],
      ),
    );
  }

  Text buildPayment() {
    String payment = _store.payment ?? '';
    return Text(
      payment,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 14.0,
        letterSpacing: -0.5,
        color: payment == 'A receber'
            ? Colors.red[400]
            : Theme.of(context).primaryColor,
      ),
    );
  }

  Widget _buildCreatedAt() {
    // Adicionando log para depuração
    print("Data de criação: ${_store.order?.createdAt}");
    print("Data de criação no store: ${_store.createdAt}");

    return Text(
      _store.formattedCreatedDate,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: Theme.of(context).primaryColor,
        fontSize: 14.0,
      ),
    );
  }

  Widget _buildDueDate() {
    return GestureDetector(
      onTap: () => _buildCalendar(context),
      child: Text(
        _store.dueDate ?? 'Data Entrega',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
          fontSize: 14.0,
        ),
      ),
    );
  }

  _buildCalendar(BuildContext context) {
    DateTime _date = DateTime.now();
    Future<Null> selectDate(BuildContext context) async {
      final DateTime? picked = await showDatePicker(
        helpText: 'Selecione a data de conclusão',
        initialDatePickerMode: DatePickerMode.day,
        context: context,
        initialDate: _date,
        firstDate: DateTime(1970),
        lastDate: DateTime(2050),
      );

      if (picked != null && picked != _date) {
        _date = picked;
        _store.setDueDate(_date);
      }
    }

    selectDate(context);
  }

  Widget _buildStatus() {
    if (_store.status == null) {
      return Container(); // Ou retornar um widget alternativo
    }

    return GestureDetector(
      onTap: () => ModalStatus()
          .showModal(context)
          .then((value) => _store.setStatus(value)),
      child: Text(
        Order.statusMap[_store.status] ?? 'Desconhecido',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
          fontSize: 14.0,
        ),
      ),
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

  // Mostra loading compacto
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
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

    // Baixa as fotos da OS
    List<pw.MemoryImage>? photoImages;
    if (order.photos != null && order.photos!.isNotEmpty) {
      photoImages = await _downloadPhotos(order);
    }

    final doc = pw.Document();

    // Define cores do tema moderno (movido para cá para usar no header/footer)
    final PdfColor primaryColor = PdfColor.fromHex('#2196F3');
    final PdfColor darkGray = PdfColor.fromHex('#757575');

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(40),
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

    // Fecha o loading
    Navigator.of(context, rootNavigator: true).pop();

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: "OS-${order.number == null ? 'NOVA' : order.number}.pdf",
    );
  } catch (e) {
    // Fecha o loading em caso de erro
    Navigator.of(context, rootNavigator: true).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Erro ao gerar PDF: $e')),
    );
  }
}

/// Baixa as fotos da ordem de serviço
Future<List<pw.MemoryImage>> _downloadPhotos(Order order) async {
  List<pw.MemoryImage> images = [];

  // Limita a 6 fotos para não sobrecarregar o PDF
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
      // Continua com as próximas fotos mesmo se uma falhar
    }
  }

  return images;
}

/// Constrói o cabeçalho fixo do PDF
pw.Widget _buildHeader(Company company, Order order, PdfColor primaryColor, PdfColor darkGray) {
  return pw.Column(
    children: [
      pw.Container(
        padding: pw.EdgeInsets.all(20),
        decoration: pw.BoxDecoration(
          color: primaryColor,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  company.name!,
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 22.0,
                    color: PdfColors.white,
                  ),
                ),
                if (company.phone != null && company.phone!.isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    company.phone!,
                    style: pw.TextStyle(
                      fontSize: 12.0,
                      color: PdfColor.fromHex('#E0E0E0'),
                    ),
                  ),
                ],
              ],
            ),
            pw.Container(
              padding: pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'OS Nº',
                    style: pw.TextStyle(
                      fontSize: 10.0,
                      color: darkGray,
                    ),
                  ),
                  pw.Text(
                    order.number?.toString() ?? 'NOVA',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 20.0,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 20),
    ],
  );
}

/// Constrói o rodapé com número de página
pw.Widget _buildFooter(pw.Context context, PdfColor darkGray) {
  return pw.Container(
    alignment: pw.Alignment.centerRight,
    margin: pw.EdgeInsets.only(top: 10),
    child: pw.Text(
      'Página ${context.pageNumber} de ${context.pagesCount}',
      style: pw.TextStyle(fontSize: 10, color: darkGray),
    ),
  );
}

/// Constrói o conteúdo do PDF (retorna lista de widgets para MultiPage)
List<pw.Widget> _printLayoutContent(Order order, Customer? customer, Company company, [List<pw.MemoryImage>? photoImages]) {
  DateFormat dateFormat = DateFormat('dd/MM/yyyy');

  // Define cores do tema moderno
  final PdfColor accentColor = PdfColor.fromHex('#1976D2');
  final PdfColor lightGray = PdfColor.fromHex('#F5F5F5');
  final PdfColor darkGray = PdfColor.fromHex('#757575');

  return [

      // Informações do cliente e veículo em cards
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Card Cliente
          pw.Expanded(
            child: _buildInfoCard(
              'Cliente',
              [
                ['Nome', customer?.name ?? ''],
                ['Telefone', customer?.phone ?? ''],
              ],
              lightGray,
            ),
          ),
          pw.SizedBox(width: 10),
          // Card Veículo
          pw.Expanded(
            child: _buildInfoCard(
              'Veículo',
              [
                ['Modelo', order.device?.name ?? ''],
                ['Placa', order.device?.serial ?? ''],
              ],
              lightGray,
            ),
          ),
        ],
      ),

      pw.SizedBox(height: 10),

      // Card Informações da OS
      pw.Container(
        padding: pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: lightGray,
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _buildInfoItem('Data', dateFormat.format(order.createdAt!)),
            _buildInfoItem('Status', Order.statusMap[order.status] ?? 'Pendente'),
            _buildInfoItem(
              'Entrega',
              order.dueDate == null ? '-' : dateFormat.format(order.dueDate!),
            ),
            _buildInfoItem(
              'Pagamento',
              order.payment == 'paid' ? 'PAGO' : order.payment == 'unpaid' ? 'A RECEBER' : '-',
            ),
          ],
        ),
      ),

      pw.SizedBox(height: 20.0),

      // Serviços e Produtos
      _printServices(order),
      _printProduct(order),

      pw.SizedBox(height: 20.0),

      // Total com destaque
      pw.Container(
        padding: pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(
          color: accentColor,
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'VALOR TOTAL',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 14.0,
                color: PdfColors.white,
              ),
            ),
            pw.Text(
              _convertToCurrency(order.total ?? 0.0),
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 20.0,
                color: PdfColors.white,
              ),
            ),
          ],
        ),
      ),

      pw.SizedBox(height: 40),

      // Assinatura do Cliente
      pw.Container(
        child: pw.Column(
          children: [
            pw.Container(
              child: pw.Divider(color: darkGray),
              width: 250.0,
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              customer?.name ?? '',
              style: pw.TextStyle(fontSize: 10.0, color: darkGray),
            ),
            pw.Text(
              'Assinatura do Cliente',
              style: pw.TextStyle(fontSize: 8.0, color: darkGray),
            ),
          ],
        ),
      ),

      pw.SizedBox(height: 40),

      // Fotos anexadas
      _printPhotos(order, photoImages),
    ];
}

pw.Widget _printProduct(Order order) {
  if (order.products == null || order.products!.isEmpty) return pw.SizedBox();

  final PdfColor headerBg = PdfColor.fromHex('#E3F2FD');
  final PdfColor rowBg = PdfColor.fromHex('#F5F5F5');

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        "Produtos",
        style: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          fontSize: 14.0,
          color: PdfColor.fromHex('#1976D2'),
        ),
      ),
      pw.SizedBox(height: 10.0),
      pw.Table(
        border: pw.TableBorder(
          horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        ),
        columnWidths: {
          0: pw.FixedColumnWidth(50),
          1: pw.FlexColumnWidth(3),
          2: pw.FixedColumnWidth(70),
          3: pw.FixedColumnWidth(70),
        },
        children: [
          // Cabeçalho
          pw.TableRow(
            decoration: pw.BoxDecoration(color: headerBg),
            children: [
              _modernTableHeader('Qtd'),
              _modernTableHeader('Produto'),
              _modernTableHeader('Valor'),
              _modernTableHeader('Total'),
            ],
          ),
          // Linhas de dados
          ...order.products!.asMap().entries.map((entry) {
            final p = entry.value;
            final isEven = entry.key % 2 == 0;
            return pw.TableRow(
              decoration: pw.BoxDecoration(
                color: isEven ? PdfColors.white : rowBg,
              ),
              children: [
                _modernTableCell(p.quantity.toString(), isNumeric: true),
                _modernTableCell("${p.product?.name} - ${p.description}"),
                _modernTableCell(_convertToCurrency(p.value), isNumeric: true),
                _modernTableCell(_convertToCurrency(p.total), isNumeric: true, isBold: true),
              ],
            );
          }).toList(),
        ],
      ),
      pw.SizedBox(height: 20.0),
    ],
  );
}

pw.Widget _printServices(Order order) {
  if (order.services == null || order.services!.isEmpty) return pw.SizedBox();

  final PdfColor headerBg = PdfColor.fromHex('#E3F2FD');
  final PdfColor rowBg = PdfColor.fromHex('#F5F5F5');

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        "Serviços",
        style: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          fontSize: 14.0,
          color: PdfColor.fromHex('#1976D2'),
        ),
      ),
      pw.SizedBox(height: 10.0),
      pw.Table(
        border: pw.TableBorder(
          horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        ),
        columnWidths: {
          0: pw.FlexColumnWidth(3),
          1: pw.FixedColumnWidth(100),
        },
        children: [
          // Cabeçalho
          pw.TableRow(
            decoration: pw.BoxDecoration(color: headerBg),
            children: [
              _modernTableHeader('Serviço'),
              _modernTableHeader('Valor'),
            ],
          ),
          // Linhas de dados
          ...order.services!.asMap().entries.map((entry) {
            final s = entry.value;
            final isEven = entry.key % 2 == 0;
            return pw.TableRow(
              decoration: pw.BoxDecoration(
                color: isEven ? PdfColors.white : rowBg,
              ),
              children: [
                _modernTableCell("${s.service?.name} - ${s.description}"),
                _modernTableCell(_convertToCurrency(s.value), isNumeric: true, isBold: true),
              ],
            );
          }).toList(),
        ],
      ),
      pw.SizedBox(height: 20.0),
    ],
  );
}

// Funções antigas removidas - agora usando _modernTableHeader e _modernTableCell

/// Constrói um card de informações moderno
pw.Widget _buildInfoCard(String title, List<List<String>> items, PdfColor bgColor) {
  return pw.Container(
    padding: pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: bgColor,
      borderRadius: pw.BorderRadius.circular(6),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 12.0,
            color: PdfColor.fromHex('#1976D2'),
          ),
        ),
        pw.SizedBox(height: 8),
        ...items.map((item) => pw.Padding(
          padding: pw.EdgeInsets.only(bottom: 4),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                item[0],
                style: pw.TextStyle(fontSize: 9.0, color: PdfColor.fromHex('#757575')),
              ),
              pw.Text(
                item[1],
                style: pw.TextStyle(fontSize: 10.0, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
        )),
      ],
    ),
  );
}

/// Constrói um item de informação
pw.Widget _buildInfoItem(String label, String value) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        label,
        style: pw.TextStyle(
          fontSize: 8.0,
          color: PdfColor.fromHex('#757575'),
        ),
      ),
      pw.SizedBox(height: 2),
      pw.Text(
        value,
        style: pw.TextStyle(
          fontSize: 10.0,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    ],
  );
}

/// Cabeçalho moderno de tabela
pw.Widget _modernTableHeader(String text) {
  return pw.Padding(
    padding: pw.EdgeInsets.all(8),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        fontSize: 10.0,
        color: PdfColor.fromHex('#1976D2'),
      ),
    ),
  );
}

/// Célula moderna de tabela
pw.Widget _modernTableCell(String text, {bool isNumeric = false, bool isBold = false}) {
  return pw.Padding(
    padding: pw.EdgeInsets.all(8),
    child: pw.Text(
      text,
      textAlign: isNumeric ? pw.TextAlign.right : pw.TextAlign.left,
      style: pw.TextStyle(
        fontSize: 9.0,
        fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    ),
  );
}

/// Constrói a seção de fotos no PDF
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

      // Grid de fotos
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
          padding: pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#F5F5F5'),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Row(
            children: [
              pw.Icon(
                pw.IconData(0xe412), // camera icon
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
