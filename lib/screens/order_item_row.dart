import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OrderItemRow {
  String? title;
  String? description;
  int? quantity;
  double? value;

  NumberFormat numberFormat =
      NumberFormat.currency(locale: 'pt-BR', symbol: 'R\$', decimalDigits: 0);

  OrderItemRow({
    this.title = '',
    this.description = '',
    this.quantity,
    this.value = 0.0,
  });

  Widget buildItem(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          height: 65,
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.grey[100]!,
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey[200]!,
                blurRadius: 30.0, // soften the shadow
                spreadRadius: 2.0, //extend the shadow
                offset: Offset(
                  7.0, // Move to right 10  horizontally
                  7.0, // Move to bottom 10 Vertically
                ),
              )
            ],
            color: Colors.white,
            borderRadius: BorderRadius.circular(25.0),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        title!,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16.0,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        description!,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ),
              VerticalDivider(),
              Container(
                width: 80,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: _itemValue(quantity, value),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 10,
        )
      ],
    );
  }

  List<Widget> _itemValue(int? quantity, double? value) {
    List<Widget> list = [];
    double? total = 0.0;

    if (quantity != null) {
      total = quantity * value!;
      list.add(Text(quantity.toString() + ' x ' + _convertToCurrency(value),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey,
            fontSize: 12.0,
          )));
    } else {
      total = value;
    }

    list.add(Text(_convertToCurrency(total),
        textAlign: TextAlign.center,
        style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey,
            fontSize: 16.0,
            letterSpacing: -0.5)));

    return list;
  }

  String _convertToCurrency(double? total) {
    if (total == null) return '';
    return numberFormat.format(total);
  }
}
