import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:praticos/mobx/order_store.dart';

class PaymentFormScreen extends StatelessWidget {
  final GlobalKey<FormState> _formKey = new GlobalKey<FormState>();
  Map<String, dynamic>? args;

  NumberFormat numberFormat = NumberFormat.currency(
    locale: 'pt-BR',
    symbol: 'R\$',
  );

  double? value;
  OrderStore? _store;

  @override
  Widget build(BuildContext context) {
    args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    if (args != null && args!.containsKey('orderStore')) {
      _store = args!['orderStore'];
    }

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text("Pagamento"),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  _formKey.currentState!.save();
                  Navigator.pop(context, value);
                }
              },
              child: Text("Salvar"),
            ),
          ],
        ),
        body: Container(
          margin: EdgeInsets.fromLTRB(20, 30, 20, 0),
          child: Form(
            key: _formKey,
            child: Column(
              // mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[_buildValueField()],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildValueField() {
    return TextFormField(
      initialValue: _convertToCurrency(_store!.discount),
      decoration: const InputDecoration(
        icon: Icon(Icons.local_offer),
        labelText: 'Desconto R\$',
      ),
      inputFormatters: [
        CurrencyTextInputFormatter.currency(
          locale: 'pt_BR',
          symbol: 'R\$',
          decimalDigits: 2,
        ),
      ],
      keyboardType: TextInputType.number,
      validator: (value) {
        if (value!.isEmpty) {
          return 'Preencha o valor do desconto';
        }

        value = value
            .replaceAll(RegExp(r'R\$'), '')
            .replaceAll(RegExp(r'BRL'), '')
            .replaceAll(RegExp(r'\.'), '')
            .replaceAll(RegExp(r','), '.');
        double valueDouble = double.parse(value);
        if (valueDouble > _store!.total!) {
          return 'Valor do desconto não pode ser maior que o total.';
        }
        return null;
      },
      onSaved: (String? value) {
        value = value!
            .replaceAll(RegExp(r'R\$'), '')
            .replaceAll(RegExp(r'BRL'), '')
            .replaceAll(RegExp(r'\.'), '')
            .replaceAll(RegExp(r','), '.');

        this.value = double.parse(value);
      },
    );
  }

  String _convertToCurrency(double? total) {
    if (total == null) return '';
    return numberFormat.format(total);
  }
}
