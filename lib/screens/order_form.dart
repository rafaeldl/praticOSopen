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
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Lado Esquerdo: Empresa
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
              // Espaço para endereço se houver no futuro
            ],
          ),
          // Lado Direito: Identificação da OS
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

/// Constrói o rodapé com número de página
pw.Widget _buildFooter(pw.Context context, PdfColor darkGray) {
  return pw.Container(
    margin: pw.EdgeInsets.only(top: 20),
    padding: pw.EdgeInsets.only(top: 10),
    decoration: pw.BoxDecoration(
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

/// Constrói o conteúdo do PDF (retorna lista de widgets para MultiPage)
List<pw.Widget> _printLayoutContent(Order order, Customer? customer, Company company, [List<pw.MemoryImage>? photoImages]) {
  DateFormat dateFormat = DateFormat('dd/MM/yyyy');

  // Cores Profissionais
  final PdfColor primaryColor = PdfColor.fromHex('#1565C0'); // Navy Blue
  final PdfColor darkGray = PdfColor.fromHex('#424242');
  final PdfColor lightGray = PdfColor.fromHex('#EEEEEE');

  // Cálculos de Subtotais
  double totalServices = order.services?.fold(0.0, (sum, s) => sum! + (s.value ?? 0)) ?? 0.0;
  double totalProducts = order.products?.fold(0.0, (sum, p) => sum! + (p.total ?? 0)) ?? 0.0;
  double subtotal = totalServices + totalProducts;
  double discount = order.discount ?? 0.0;
  double total = order.total ?? 0.0;

  return [
    // Seção de Informações (Cliente e Veículo lado a lado)
    pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Cliente
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
        // Veículo
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

    // Detalhes da OS (Status, Entrega, Pagamento) em linha única
    pw.Container(
      padding: pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
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

    // Tabelas de Itens
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

    // Resumo Financeiro (Alinhado à direita)
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
                padding: pw.EdgeInsets.all(8),
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

    // Assinatura
    pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.start, // Assinatura à esquerda ou centro
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

    // Fotos
    if (order.photos != null && order.photos!.isNotEmpty) ...[
      pw.Divider(color: PdfColors.grey300),
      pw.SizedBox(height: 10),
      _buildSectionTitle('REGISTRO FOTOGRÁFICO', primaryColor),
      pw.SizedBox(height: 10),
      _printPhotos(order, photoImages),
    ],
  ];
}

// --- Componentes Auxiliares Modernos ---

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
    padding: pw.EdgeInsets.symmetric(vertical: 2),
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
      bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
      horizontalInside: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
    ),
    columnWidths: {
      0: pw.FixedColumnWidth(40), // Qtd
      1: pw.FlexColumnWidth(3),   // Descrição
      2: pw.FixedColumnWidth(70), // Valor Unit
      3: pw.FixedColumnWidth(70), // Total
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
      bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
      horizontalInside: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
    ),
    columnWidths: {
      0: pw.FlexColumnWidth(3),   // Descrição
      1: pw.FixedColumnWidth(80), // Valor
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
    padding: pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8),
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
    padding: pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8),
    child: pw.Text(
      text,
      textAlign: alignRight ? pw.TextAlign.right : (alignCenter ? pw.TextAlign.center : pw.TextAlign.left),
      style: pw.TextStyle(fontSize: 9.0, color: PdfColors.black),
    ),
  );
}

// Funções antigas de InfoCard e Table removidas para limpar o código

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
