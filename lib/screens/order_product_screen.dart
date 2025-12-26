import 'dart:math';

import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/product.dart';
import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:praticos/screens/widgets/order_photos_widget.dart';

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

      if (_orderProduct.id == null) {
        _orderProduct.id = "${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(10000)}";
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

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Produto' : 'Novo Produto'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_a_photo_outlined),
            tooltip: 'Adicionar foto',
            onPressed: () => _showAddPhotoOptions(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_orderStore != null)
                  Observer(
                    builder: (_) => OrderPhotosWidget(
                      store: _orderStore!,
                      itemId: _orderProduct.id,
                    ),
                  ),
                const SizedBox(height: 16),
                // Header icon
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(
                      Icons.inventory_2,
                      size: 40,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Product name (read-only)
                _buildProductNameField(theme),
                const SizedBox(height: 16),

                // Quantity and Value row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 1,
                      child: _buildQuantityField(theme),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: _buildValueField(theme),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Description field
                _buildDescriptionField(theme),
                const SizedBox(height: 32),

                // Save button
                FilledButton.icon(
                  onPressed: _isLoading ? null : _saveProduct,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text(_isLoading ? 'Salvando...' : 'Salvar'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      filled: true,
    );
  }

  Widget _buildProductNameField(ThemeData theme) {
    final productName = orderProductIndex == null
        ? _product?.name
        : _orderProduct.product?.name;

    return TextFormField(
      enabled: false,
      initialValue: productName,
      decoration: _inputDecoration(
        label: 'Produto',
        icon: Icons.inventory_2_outlined,
      ),
      style: TextStyle(
        color: theme.colorScheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildQuantityField(ThemeData theme) {
    final initialValue = orderProductIndex != null
        ? _orderProduct.quantity.toString()
        : '1';

    return TextFormField(
      initialValue: initialValue,
      decoration: _inputDecoration(
        label: 'Qtd',
        icon: Icons.numbers,
        hint: '1',
      ),
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Obrigatório';
        }
        final qty = int.tryParse(value);
        if (qty == null || qty <= 0) {
          return 'Qtd inválida';
        }
        return null;
      },
      onSaved: (String? value) {
        _orderProduct.quantity = int.parse(value!);
      },
    );
  }

  Widget _buildValueField(ThemeData theme) {
    final initialValue = orderProductIndex == null
        ? _convertToCurrency(_product?.value)
        : _convertToCurrency(_orderProduct.value);

    return TextFormField(
      initialValue: initialValue,
      decoration: _inputDecoration(
        label: 'Valor unitário',
        icon: Icons.attach_money,
        hint: 'R\$ 0,00',
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
        if (value == null || value.isEmpty) {
          return 'Preencha o valor';
        }
        return null;
      },
      onSaved: (String? value) {
        _orderProduct.value = numberFormat.parse(value!) as double?;
      },
    );
  }

  Widget _buildDescriptionField(ThemeData theme) {
    return TextFormField(
      initialValue: orderProductIndex != null ? _orderProduct.description : null,
      decoration: _inputDecoration(
        label: 'Descrição',
        icon: Icons.description_outlined,
        hint: 'Observações sobre o produto',
      ),
      textCapitalization: TextCapitalization.sentences,
      maxLines: 3,
      onSaved: (String? value) {
        _orderProduct.description = value;
      },
    );
  }

  String _convertToCurrency(double? total) {
    if (total == null) return '';
    return numberFormat.format(total);
  }

  void _showAddPhotoOptions() {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (modalContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.camera_alt, color: theme.colorScheme.primary),
                  title: const Text('Tirar foto'),
                  onTap: () async {
                    Navigator.pop(modalContext);
                    final success = await _orderStore!.addPhotoFromCamera(itemId: _orderProduct.id);
                    if (!success && mounted) {
                      scaffoldMessenger.showSnackBar(
                        const SnackBar(content: Text('Erro ao adicionar foto')),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: Icon(Icons.photo_library, color: theme.colorScheme.primary),
                  title: const Text('Escolher da galeria'),
                  onTap: () async {
                    Navigator.pop(modalContext);
                    final success = await _orderStore!.addPhotoFromGallery(itemId: _orderProduct.id);
                    if (!success && mounted) {
                      scaffoldMessenger.showSnackBar(
                        const SnackBar(content: Text('Erro ao adicionar foto')),
                      );
                    }
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.close, color: Colors.grey),
                  title: const Text('Cancelar'),
                  onTap: () => Navigator.pop(modalContext),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
