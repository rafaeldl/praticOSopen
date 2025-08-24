import 'dart:async';

import 'package:praticos/mobx/company_store.dart';
import 'package:praticos/mobx/customer_store.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/screens/modal_menu.dart';
import 'package:praticos/screens/modal_status.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/order.dart';
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
                        new TextButton(
                          onPressed: () {
                            _store.deleteOrder().then((value) {
                              Navigator.of(
                                context,
                              ).popUntil((route) => route.isFirst);
                            });
                          },
                          child: Text('Sim'),
                        ),
                        new TextButton(
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
                SizedBox(height: 20.0),
                // buildMainPhoto(),
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

  // Widget buildMainPhoto() {
  //   if (order == null) {
  //     return GestureDetector(
  //       onTap: () => print('Snapshot'),
  //       child: Container(
  //         height: 180,
  //         decoration: BoxDecoration(
  //             color: Colors.white,
  //             borderRadius: BorderRadius.circular(4.0),
  //             border: Border.all(color: Colors.grey[350]),
  //             boxShadow: [
  //               BoxShadow(
  //                 color: Colors.grey[200],
  //                 blurRadius: 2.0, // soften the shadow
  //                 spreadRadius: 1.2, //extend the shadow
  //                 offset: Offset(
  //                   5.0, // Move to right 10  horizontally
  //                   5.0, // Move to bottom 10 Vertically
  //                 ),
  //               )
  //             ]),
  //         child: Icon(
  //           Icons.camera_alt,
  //           color: Color(0xFF3498db),
  //           size: 30.0,
  //         ),
  //       ),
  //     );
  //   } else {
  //     return Image(
  //       image: AssetImage('assets/images/car2.jpg'),
  //       // image: AssetImage(_store.order.mainPhoto),
  //       height: 180,
  //       fit: BoxFit.cover,
  //     );
  //   }
  // }

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

  CompanyStore companyStore = CompanyStore();
  Company company = await companyStore.retrieveCompany(order.company!.id);

  Customer? customer;
  if (order.customer != null) {
    CustomerStore customerStore = CustomerStore();
    customer = await customerStore.retrieveCustomer(order.customer?.id);
  }

  final doc = pw.Document();

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return _printLayout(order, customer, company); // Center
      },
    ),
  ); // Page

  await Printing.sharePdf(
    bytes: await doc.save(),
    filename: "OS-${order.number == null ? 'NOVA' : order.number}.pdf",
  );

  // await Printing.layoutPdf(onLayout: (format) => doc.save());

  // var customer = order.customer == null ? '' : order.customer.name;
  // var total = order.total == null ? 'R\$ 0.0' : order.total;
}

_printLayout(Order order, Customer? customer, Company company) {
  DateFormat dateFormat = DateFormat('dd/MM/yyyy');

  return pw.Column(
    children: [
      pw.SizedBox(height: 20.0),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            company.name!,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18.0),
          ),
          pw.Text(
            company.phone == null ? '' : company.phone!,
            style: pw.TextStyle(fontSize: 14.0),
          ),
        ],
      ),
      pw.SizedBox(height: 20.0),
      pw.Table(
        border: pw.TableBorder(),
        children: [
          _addTableRow([
            _tableCellHeader('Data'),
            _tableCell(dateFormat.format(order.createdAt!)),
            _tableCellHeader('OS'),
            _tableCell(order.number.toString()),
          ]),
          _addTableRow([
            _tableCellHeader('Cliente'),
            _tableCell(customer?.name),
            _tableCellHeader('Telefone'),
            _tableCell(customer?.phone),
          ]),
          _addTableRow([
            _tableCellHeader('Modelo'),
            _tableCell(order.device?.name),
            _tableCellHeader('Placa'),
            _tableCell(order.device?.serial),
          ]),
          _addTableRow([
            _tableCellHeader('Status'),
            _tableCell(Order.statusMap[order.status]),
            _tableCellHeader('Previsão de entrega'),
            _tableCell(
              order.dueDate == null ? '' : dateFormat.format(order.dueDate!),
            ),
          ]),
        ],
      ),
      _printServices(order),
      _printProduct(order),
      pw.SizedBox(height: 20.0),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Text(
            "Total: ${_convertToCurrency(order.total)} ${order.payment == 'paid' ? '(PAGO)' : ''}",
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16.0),
          ),
        ],
      ),
      pw.SizedBox(height: 50.0),
      pw.Container(child: pw.Divider(), width: 250.0),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [_tableCell(customer?.name)],
      ),
    ],
  );
}

pw.Widget _printProduct(Order order) {
  if (order.products == null || order.products!.isEmpty) return pw.SizedBox();
  return pw.Column(
    children: [
      pw.SizedBox(height: 20.0),
      pw.Row(
        children: [
          pw.Text(
            "Produtos",
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16.0),
          ),
        ],
      ),
      pw.SizedBox(height: 10.0),
      pw.Table(
        border: pw.TableBorder(),
        children: [
          _addTableRow([
            _tableCellHeader('Quantidade'),
            _tableCellHeader('Produto'),
            _tableCellHeader('Valor'),
            _tableCellHeader('Total'),
          ]),
          ...order.products!
              .map(
                (p) => _addTableRow([
                  _tableCell(p.quantity.toString()),
                  _tableCell("${p.product?.name} - ${p.description}"),
                  _tableCell(_convertToCurrency(p.value)),
                  _tableCell(_convertToCurrency(p.total)),
                ]),
              )
              .toList(),
        ],
      ),
    ],
  );
}

pw.Widget _printServices(Order order) {
  if (order.services == null || order.services!.isEmpty) return pw.SizedBox();

  return pw.Column(
    children: [
      pw.SizedBox(height: 20.0),
      pw.Row(
        children: [
          pw.Text(
            "Serviços",
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16.0),
          ),
        ],
      ),
      pw.SizedBox(height: 10.0),
      pw.Table(
        border: pw.TableBorder(),
        children: [
          _addTableRow([
            _tableCellHeader('Serviço'),
            _tableCellHeader('Valor'),
          ]),
          ...order.services!
              .map(
                (s) => _addTableRow([
                  _tableCell("${s.service?.name} - ${s.description}"),
                  _tableCell(_convertToCurrency(s.value)),
                ]),
              )
              .toList(),
        ],
      ),
    ],
  );
}

pw.TableRow _addTableRow(List<pw.Widget> items) {
  var cells = items
      .map(
        (e) => pw.Padding(
          child: pw.Container(child: e, alignment: pw.Alignment.centerLeft),
          padding: pw.EdgeInsets.all(5.0),
        ),
      )
      .toList();
  return pw.TableRow(children: cells);
}

pw.Text _tableCell(String? text) {
  return pw.Text(text == null ? '' : text);
}

pw.Text _tableCellHeader(String text) {
  return pw.Text(text, style: pw.TextStyle(fontWeight: pw.FontWeight.bold));
}
