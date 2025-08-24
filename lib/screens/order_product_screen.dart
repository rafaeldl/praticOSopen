import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/product.dart';
import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OrderProductScreen extends StatelessWidget {
  OrderStore? _orderStore;
  Product? _product;
  OrderProduct _orderProduct = OrderProduct();
  int? orderProductIndex;
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

      if (args.containsKey('product')) {
        _product = args['product'];
        _orderProduct.product = _product!.toAggr();
        _orderStore!.orderProductTitle = 'Novo Produto';
      }

      if (args.containsKey('orderProductIndex')) {
        orderProductIndex = args['orderProductIndex'];
        _orderProduct = _orderStore!.order!.products![orderProductIndex!];
        _orderStore!.orderProductTitle = 'Editar Produto';
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_orderStore!.orderProductTitle),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              saveProduct(context);
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
                  initialValue: orderProductIndex == null
                      ? _product!.name
                      : _orderProduct.product!.name,
                  decoration: const InputDecoration(labelText: 'Produto'),
                ),
                TextFormField(
                  initialValue: orderProductIndex != null
                      ? _orderProduct.quantity.toString()
                      : "1",
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Quantidade'),
                  onSaved: (String? value) {
                    _orderProduct.quantity = int.parse(value!);
                  },
                ),
                TextFormField(
                  initialValue: orderProductIndex != null
                      ? _orderProduct.description
                      : null,
                  decoration: const InputDecoration(labelText: 'Descrição'),
                  onSaved: (String? value) {
                    _orderProduct.description = value;
                  },
                ),
                TextFormField(
                  initialValue: orderProductIndex == null
                      ? _convertToCurrency(_product!.value)
                      : _convertToCurrency(_orderProduct.value),
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
                    _orderProduct.value = numberFormat.parse(value!) as double?;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void saveProduct(BuildContext context) {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      _orderProduct.total = _orderProduct.quantity! * _orderProduct.value!;
      if (orderProductIndex == null) {
        _orderStore!.addProduct(_orderProduct);
        Navigator.popUntil(context, ModalRoute.withName('/order'));
      } else {
        _orderStore!.updateOrder();
        Navigator.pop(context);
      }
    }
  }

  String _convertToCurrency(double? total) {
    if (total == null) return '';
    return numberFormat.format(total);
  }
}
