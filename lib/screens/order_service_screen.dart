import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/service.dart';
import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OrderServiceScreen extends StatelessWidget {
  OrderStore? _orderStore;
  Service? _service = Service();
  OrderService _orderService = OrderService();
  int? orderServiceIndex;
  final GlobalKey<FormState> _formKey = new GlobalKey<FormState>();
  NumberFormat numberFormat = NumberFormat.currency(
    locale: 'pt-BR',
    symbol: 'R\$',
  );

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic>? args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      if (args.containsKey('orderStore')) {
        _orderStore = args['orderStore'];
      }

      if (args.containsKey('service')) {
        _service = args['service'];
        _orderService.service = _service!.toAggr();
        _orderStore!.orderServiceTitle = 'Novo Serviço';
      }

      if (args.containsKey('orderServiceIndex')) {
        orderServiceIndex = args['orderServiceIndex'];
        _orderService = _orderStore!.order!.services![orderServiceIndex!];
        _orderStore!.orderServiceTitle = 'Editar Serviço';
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_orderStore!.orderServiceTitle),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                _formKey.currentState!.save();
                if (orderServiceIndex == null) {
                  _orderStore!.addService(_orderService);
                  Navigator.popUntil(context, ModalRoute.withName('/order'));
                } else {
                  _orderStore!.updateOrder();
                  Navigator.pop(context);
                }
              }
            },
            child: Text("Salvar"),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Container(
          margin: EdgeInsets.fromLTRB(20, 30, 20, 0),
          child: Form(
            key: _formKey,
            child: Column(
              children: <Widget>[
                TextFormField(
                  enabled: false,
                  initialValue: orderServiceIndex == null
                      ? _service!.name
                      : _orderService.service!.name,
                  decoration: const InputDecoration(labelText: 'Serviço'),
                ),
                TextFormField(
                  initialValue: orderServiceIndex != null
                      ? _orderService.description
                      : null,
                  decoration: const InputDecoration(labelText: 'Descrição'),
                  onSaved: (String? value) {
                    _orderService.description = value;
                  },
                ),
                TextFormField(
                  initialValue: orderServiceIndex == null
                      ? _convertToCurrency(_service!.value)
                      : _convertToCurrency(_orderService.value),
                  decoration: const InputDecoration(labelText: 'Valor'),
                  inputFormatters: [
                    CurrencyTextInputFormatter.currency(
                      locale: 'pt_BR',
                      symbol: 'R\$',
                      decimalDigits: 2,
                    ),
                  ],
                  keyboardType: TextInputType.number,
                  onSaved: (String? value) {
                    _orderService.value = numberFormat.parse(value!) as double?;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _convertToCurrency(double? total) {
    if (total == null) return '';
    return numberFormat.format(total);
  }
}
