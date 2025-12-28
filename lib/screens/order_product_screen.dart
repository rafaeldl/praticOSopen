import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/product.dart';
import 'package:praticos/widgets/cached_image.dart';
import 'package:praticos/widgets/grouped_row.dart';
import 'package:praticos/widgets/grouped_section.dart';
import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OrderProductScreen extends StatefulWidget {
  const OrderProductScreen({Key? key}) : super(key: key);

  @override
  State<OrderProductScreen> createState() => _OrderProductScreenState();
}

class _OrderProductScreenState extends State<OrderProductScreen> {
  OrderStore? _orderStore;
  Product? _product;
  OrderProduct _orderProduct = OrderProduct();
  int? orderProductIndex;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _initialized = false;

  final NumberFormat numberFormat = NumberFormat.currency(
    locale: 'pt-BR',
    symbol: 'R\$',
  );

  bool get _isEditing => orderProductIndex != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        if (args.containsKey('orderStore')) {
          _orderStore = args['orderStore'];
        }

        if (args.containsKey('product')) {
          _product = args['product'];
          _orderProduct.product = _product!.toAggr();
        }

        if (args.containsKey('orderProductIndex')) {
          orderProductIndex = args['orderProductIndex'];
          _orderProduct = _orderStore!.order!.products![orderProductIndex!];
        }
      }
      _initialized = true;
    }
  }

  Future<void> _saveProduct() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // iOS grouped background color approximation
    final backgroundColor = isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Produto' : 'Novo Produto'),
        elevation: 0,
        backgroundColor: backgroundColor,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProduct,
            child: Text(
              _isLoading ? 'Salvando...' : 'Salvar',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          children: [
            // Header icon
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: _buildHeaderImage(theme),
              ),
            ),

            GroupedSection(
              children: [
                _buildProductNameRow(theme),
              ],
            ),

            const SizedBox(height: 24),

            GroupedSection(
              children: [
                _buildQuantityRow(theme),
                _buildValueRow(theme),
              ],
            ),

            const SizedBox(height: 24),

            GroupedSection(
              header: const Text('OBSERVAÇÕES'),
              children: [
                _buildDescriptionRow(theme),
              ],
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildProductNameRow(ThemeData theme) {
    final productName = orderProductIndex == null
        ? _product?.name
        : _orderProduct.product?.name;

    return GroupedRow(
      label: 'Produto',
      child: Text(
        productName ?? '',
        style: TextStyle(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w500,
          fontSize: 17,
        ),
        textAlign: TextAlign.right,
      ),
    );
  }

  Widget _buildQuantityRow(ThemeData theme) {
    final initialValue = orderProductIndex != null
        ? _orderProduct.quantity.toString()
        : '1';

    return GroupedRow(
      label: 'Quantidade',
      child: TextFormField(
        initialValue: initialValue,
        textAlign: TextAlign.right,
        decoration: const InputDecoration.collapsed(
          hintText: '1',
        ),
        keyboardType: TextInputType.number,
        style: TextStyle(
          color: theme.colorScheme.primary,
          fontSize: 17,
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Obrigatório';
          }
          final qty = int.tryParse(value);
          if (qty == null || qty <= 0) {
            return 'Inválido';
          }
          return null;
        },
        onSaved: (String? value) {
          _orderProduct.quantity = int.parse(value!);
        },
      ),
    );
  }

  Widget _buildValueRow(ThemeData theme) {
    final initialValue = orderProductIndex == null
        ? _convertToCurrency(_product?.value)
        : _convertToCurrency(_orderProduct.value);

    return GroupedRow(
      label: 'Valor Unitário',
      child: TextFormField(
        initialValue: initialValue,
        textAlign: TextAlign.right,
        decoration: const InputDecoration.collapsed(
          hintText: 'R\$ 0,00',
        ),
        inputFormatters: [
          CurrencyTextInputFormatter.currency(
            locale: 'pt_BR',
            symbol: 'R\$',
            decimalDigits: 2,
          ),
        ],
        keyboardType: TextInputType.number,
        style: TextStyle(
          color: theme.colorScheme.primary,
          fontSize: 17,
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Obrigatório';
          }
          return null;
        },
        onSaved: (String? value) {
          _orderProduct.value = numberFormat.parse(value!) as double?;
        },
      ),
    );
  }

  Widget _buildDescriptionRow(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      constraints: const BoxConstraints(minHeight: 100),
      child: TextFormField(
        initialValue: orderProductIndex != null ? _orderProduct.description : null,
        decoration: const InputDecoration.collapsed(
          hintText: 'Adicione detalhes sobre este item...',
        ),
        style: const TextStyle(fontSize: 17),
        textCapitalization: TextCapitalization.sentences,
        maxLines: 5,
        minLines: 3,
        onSaved: (String? value) {
          _orderProduct.description = value;
        },
      ),
    );
  }

  String _convertToCurrency(double? total) {
    if (total == null) return '';
    return numberFormat.format(total);
  }

  Widget _buildHeaderImage(ThemeData theme) {
    String? photoUrl;
    if (orderProductIndex != null) {
      photoUrl = _orderProduct.photo;
    } else {
      photoUrl = _product?.photo;
    }

    if (photoUrl != null && photoUrl.isNotEmpty) {
      return ClipOval(
        child: CachedImage(
          imageUrl: photoUrl,
          width: 100,
          height: 100,
          fit: BoxFit.cover,
        ),
      );
    }

    return CircleAvatar(
      radius: 50,
      backgroundColor: theme.colorScheme.surface,
      child: Icon(
        Icons.inventory_2,
        size: 50,
        color: theme.colorScheme.primary,
      ),
    );
  }
}
