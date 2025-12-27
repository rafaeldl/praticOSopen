import 'package:praticos/mobx/product_store.dart';
import 'package:praticos/models/product.dart';
import 'package:praticos/widgets/cached_image.dart';
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
        title: const Text('Produtos'),
        elevation: 0,
      ),
      body: Observer(
        builder: (_) => _buildBody(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/product_form');
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    if (productStore.productList == null) {
      return _buildError();
    }

    if (productStore.productList!.hasError) {
      return _buildError();
    }

    List<Product>? productList = productStore.productList!.value;

    if (productList == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (productList.isEmpty) {
      return _buildEmptyState();
    }

    return _buildProductList(productList);
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          const Text(
            'Erro ao carregar produtos',
            style: TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: () => productStore.retrieveProducts(),
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'Nenhum produto cadastrado',
            style: TextStyle(
              fontSize: 18,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Toque no + para adicionar',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductList(List<Product> list) {
    final isSelectionMode = args != null && args!.containsKey('orderStore');

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 88),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final product = list[index];
        return _buildProductCard(product, isSelectionMode);
      },
    );
  }

  Widget _buildProductCard(Product product, bool isSelectionMode) {
    return Dismissible(
      key: Key(product.id!),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirmar exclusão'),
            content: Text('Deseja remover o produto "${product.name}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Remover'),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        productStore.deleteProduct(product);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Produto "${product.name}" removido'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Theme.of(context).colorScheme.error,
        child: Icon(
          Icons.delete_outline,
          color: Theme.of(context).colorScheme.onError,
          size: 28,
        ),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: (product.photo != null && product.photo!.isNotEmpty)
              ? ClipOval(
                  child: CachedImage(
                    imageUrl: product.photo!,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                  ),
                )
              : CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(
                    Icons.inventory_2_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
          title: Text(
            product.name ?? '',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            _convertToCurrency(product.value),
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            if (isSelectionMode) {
              Navigator.pushNamed(context, '/order_product', arguments: {
                'product': product,
                'orderStore': args!['orderStore']
              });
            } else {
              Navigator.pushNamed(
                context,
                '/product_form',
                arguments: {'product': product},
              );
            }
          },
        ),
      ),
    );
  }

  String _convertToCurrency(double? total) {
    if (total == null) return '';
    NumberFormat numberFormat =
        NumberFormat.currency(locale: 'pt-BR', symbol: 'R\$ ');
    return numberFormat.format(total);
  }
}
