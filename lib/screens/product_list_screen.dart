import 'package:praticos/mobx/product_store.dart';
import 'package:praticos/models/product.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:intl/intl.dart';

class ProductListScreen extends StatefulWidget {
  @override
  _ProductListScreenState createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  ProductStore productStore = ProductStore();

  Map<String, dynamic>? args;

  @override
  Widget build(BuildContext context) {
    args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;

    return Scaffold(
      appBar: AppBar(
        title: Text('Produtos'),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () {
              Navigator.pushNamed(context, '/product_form');
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Container(
          child: Observer(
            builder: (_) {
              return _buildProductList(productStore);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildProductList(ProductStore productStore) {
    if (productStore.productList == null) {
      return Center(
        child: ElevatedButton(
          onPressed: productStore.retrieveProducts(),
          child: Text('Error'),
        ),
      );
    }

    if (productStore.productList!.hasError) {
      return Center(
        child: ElevatedButton(
          onPressed: productStore.retrieveProducts(),
          child: Text('Error'),
        ),
      );
    }

    List<Product>? list = productStore.productList!.value;
    if (list == null) {
      return Center(
        child: CircularProgressIndicator(),
      );
    }

    return Container(
      padding: EdgeInsets.all(0.0),
      margin: EdgeInsets.all(20.0),
      child: ListView.separated(
        itemCount: list.length,
        itemBuilder: (context, index) {
          Product product = list[index];

          return Dismissible(
            direction: DismissDirection.endToStart,
            key: Key(product.id!),
            onDismissed: (direction) {
              productStore.deleteProduct(product);
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Produto ${product.name} removido")));
            },
            background: Container(color: Colors.red, child: Icon(Icons.cancel)),
            child: ListTile(
              title: Text(product.name!),
              subtitle: Text(_convertToCurrency(product.value)),
              trailing: Icon(Icons.keyboard_arrow_right),
              onTap: () {
                if (args != null && args!.containsKey('orderStore')) {
                  Navigator.pushNamed(context, '/order_product', arguments: {
                    'product': product,
                    'orderStore': args!['orderStore']
                  });
                } else {
                  Navigator.pushNamed(context, '/product_form',
                      arguments: {'product': product});
                }
              },
            ),
          );
        },
        separatorBuilder: (context, index) {
          return Divider();
        },
      ),
    );
  }

  String _convertToCurrency(double? total) {
    if (total == null) return '';
    NumberFormat numberFormat =
        NumberFormat.currency(locale: 'pt-BR', symbol: 'R\$');
    return numberFormat.format(total);
  }
}
