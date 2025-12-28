import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Theme, Icons, Icon, InputDecoration, Colors;
import 'package:intl/intl.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/product.dart';
import 'package:praticos/widgets/cached_image.dart';

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

  late final CurrencyTextInputFormatter _currencyFormatter;
  final TextEditingController _valueController = TextEditingController();

  final NumberFormat numberFormat = NumberFormat.currency(
    locale: 'pt-BR',
    symbol: 'R\$',
  );

  bool get _isEditing => orderProductIndex != null;

  @override
  void initState() {
    super.initState();
    _currencyFormatter = CurrencyTextInputFormatter.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
      decimalDigits: 2,
    );
  }

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

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

      // Initialize value controller
      final initialValue = orderProductIndex == null
        ? _product?.value
        : _orderProduct.value;
      _valueController.text = _convertToCurrency(initialValue);

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
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text(_isEditing ? 'Editar Produto' : 'Novo Produto'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _isLoading ? null : _saveProduct,
          child: _isLoading
              ? const CupertinoActivityIndicator()
              : const Text("Salvar", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const SizedBox(height: 20),

              // Header icon
              Center(
                child: _buildHeaderImage(),
              ),

              const SizedBox(height: 20),

              CupertinoListSection.insetGrouped(
                children: [
                  // Product Name (Read-only)
                  CupertinoTextFormFieldRow(
                    prefix: const Text("Produto", style: TextStyle(fontSize: 16)),
                    initialValue: orderProductIndex == null
                        ? _product?.name
                        : _orderProduct.product?.name,
                    readOnly: true,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: CupertinoColors.systemGrey.resolveFrom(context),
                    ),
                  ),

                  // Quantity
                  CupertinoTextFormFieldRow(
                    prefix: const Text("Quantidade", style: TextStyle(fontSize: 16)),
                    initialValue: orderProductIndex != null
                        ? _orderProduct.quantity.toString()
                        : '1',
                    placeholder: "1",
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.right,
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

                  // Value
                  CupertinoTextFormFieldRow(
                    prefix: const Text("Valor Unitário", style: TextStyle(fontSize: 16)),
                    controller: _valueController,
                    placeholder: "R\$ 0,00",
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.right,
                    inputFormatters: [_currencyFormatter],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Obrigatório';
                      }
                      return null;
                    },
                    onSaved: (String? value) {
                      if (value != null) {
                         // Parse currency back to double
                         final cleanValue = value
                            .replaceAll(RegExp(r'R\$'), '')
                            .replaceAll(RegExp(r'\.'), '')
                            .replaceAll(RegExp(r','), '.')
                            .trim();
                        _orderProduct.value = double.tryParse(cleanValue) ?? 0.0;
                      }
                    },
                  ),
                ],
              ),

              CupertinoListSection.insetGrouped(
                header: const Text('OBSERVAÇÕES'),
                children: [
                   CupertinoTextFormFieldRow(
                    initialValue: orderProductIndex != null ? _orderProduct.description : null,
                    placeholder: "Adicione detalhes sobre este item...",
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 4,
                    minLines: 2,
                    textAlign: TextAlign.start,
                    onSaved: (String? value) {
                      _orderProduct.description = value;
                    },
                  ),
                ],
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  String _convertToCurrency(double? total) {
    if (total == null) return '';
    return numberFormat.format(total);
  }

  Widget _buildHeaderImage() {
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

    // Using generic Icon inside Container for consistent look with ProductFormScreen
    return Builder(
      builder: (context) {
        return Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey5.resolveFrom(context),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.inventory_2, // Material icon is fine, or use CupertinoIcons.cube_box
            size: 50,
            color: CupertinoColors.systemGrey.resolveFrom(context),
          ),
        );
      }
    );
  }
}
