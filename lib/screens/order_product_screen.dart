import 'package:flutter/cupertino.dart';
import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:praticos/services/format_service.dart';
import 'package:provider/provider.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/product.dart';
import 'package:praticos/models/permission.dart';
import 'package:praticos/widgets/cached_image.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/constants/label_keys.dart';
import 'package:praticos/services/authorization_service.dart';

class OrderProductScreen extends StatefulWidget {
  const OrderProductScreen({super.key});

  @override
  State<OrderProductScreen> createState() => _OrderProductScreenState();
}

class _OrderProductScreenState extends State<OrderProductScreen> {
  OrderStore? _orderStore;
  Product? _product;
  OrderProduct _orderProduct = OrderProduct();
  int? orderProductIndex;
  String? _returnRoute;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _initialized = false;
  final AuthorizationService _authService = AuthorizationService.instance;

  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _valueController = TextEditingController();
  double _total = 0;

  final format = FormatService();
  late final numberFormat = format.currencyFormat;

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
          // Initialize value and quantity defaults if new product
          _orderProduct.value ??= _product!.value;
          _orderProduct.quantity ??= 1;
        }

        if (args.containsKey('orderProductIndex')) {
          orderProductIndex = args['orderProductIndex'];
          _orderProduct = _orderStore!.order!.products![orderProductIndex!];
        }

        if (args.containsKey('returnRoute')) {
          _returnRoute = args['returnRoute'];
        }
      }

      // Initialize controllers
      if (orderProductIndex != null) {
        _quantityController.text = _orderProduct.quantity.toString();
        _valueController.text = _convertToCurrency(_orderProduct.value);
      } else {
        _quantityController.text = '1';
        _valueController.text = _convertToCurrency(_product?.value);
      }

      // Add listeners for real-time total calculation
      _quantityController.addListener(_updateTotal);
      _valueController.addListener(_updateTotal);

      // Calculate initial total
      _updateTotal();

      _initialized = true;
    }
  }

  @override
  void dispose() {
    _quantityController.removeListener(_updateTotal);
    _valueController.removeListener(_updateTotal);
    _quantityController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  void _updateTotal() {
    final quantity = int.tryParse(_quantityController.text) ?? 0;
    final valueText = _valueController.text;
    double value = 0;
    if (valueText.isNotEmpty) {
      try {
        value = numberFormat.parse(valueText) as double;
      } catch (_) {
        value = 0;
      }
    }
    setState(() {
      _total = quantity * value;
    });
  }

  Future<void> _saveProduct() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      _formKey.currentState!.save();

      _orderProduct.total = _orderProduct.quantity! * _orderProduct.value!;

      if (orderProductIndex == null) {
        _orderStore!.addProduct(_orderProduct);
        Navigator.popUntil(context, ModalRoute.withName(_returnRoute ?? '/order'));
      } else {
        _orderStore!.updateOrder();
        Navigator.pop(context);
      }
    }
  }

  String _convertToCurrency(double? total) {
    if (total == null) return '';
    return format.formatCurrency(total);
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<SegmentConfigProvider>();

    // Verifica se pode editar campos principais (valor, quantidade, produto)
    // Sempre permite editar descrição/observações
    final canEditMainFields = _orderStore?.order != null
        ? _authService.canEditOrderMainFields(_orderStore!.order!)
        : true;

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text(_isEditing ? config.label(LabelKeys.editProduct) : config.label(LabelKeys.createProduct)),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _isLoading ? null : _saveProduct,
          child: _isLoading
              ? const CupertinoActivityIndicator()
              : Text(
                  config.label(LabelKeys.save),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
        ),
      ),
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const SizedBox(height: 20),

              // Photo Section
              Center(child: _buildHeaderImage(context)),
              const SizedBox(height: 20),

              // Form Fields
              CupertinoListSection.insetGrouped(
                children: [
                  _buildProductNameField(context),
                  // Mostrar quantidade (desabilitado se não puder editar)
                  _buildQuantityField(context, config, enabled: canEditMainFields),
                  // Apenas mostrar campos de valores se usuário pode ver preços E pode editar campos principais
                  if (_authService.hasPermission(PermissionType.viewPrices) && canEditMainFields) ...[
                    _buildValueField(context, config),
                    _buildTotalField(context, config),
                  ],
                ],
              ),

              CupertinoListSection.insetGrouped(
                header: Text(
                  config.label(LabelKeys.notes).toUpperCase(),
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
                children: [
                  _buildDescriptionField(context),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductNameField(BuildContext context) {
    final productName = orderProductIndex == null
        ? _product?.name
        : _orderProduct.product?.name;

    return CupertinoListTile(
      title: const SizedBox(
        width: 80,
        child: Text('Produto', style: TextStyle(fontSize: 16)),
      ),
      additionalInfo: Expanded(
        child: Text(
          productName ?? '',
          textAlign: TextAlign.right,
          style: TextStyle(
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
            fontSize: 16,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildQuantityField(BuildContext context, SegmentConfigProvider config, {bool enabled = true}) {
    return CupertinoListTile(
      title: SizedBox(
        width: 100,
        child: Text(config.label(LabelKeys.quantity), style: const TextStyle(fontSize: 16)),
      ),
      additionalInfo: SizedBox(
        width: 80,
        child: CupertinoTextFormFieldRow(
          controller: _quantityController,
          placeholder: '1',
          enabled: enabled,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.right,
          padding: EdgeInsets.zero,
          decoration: null,
          style: TextStyle(
            color: enabled 
                ? CupertinoColors.label.resolveFrom(context)
                : CupertinoColors.secondaryLabel.resolveFrom(context)
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return config.label(LabelKeys.required);
            }
            final qty = int.tryParse(value);
            if (qty == null || qty <= 0) {
              return 'Inválida';
            }
            return null;
          },
          onSaved: (String? value) {
            _orderProduct.quantity = int.parse(value!);
          },
        ),
      ),
    );
  }

  Widget _buildValueField(BuildContext context, SegmentConfigProvider config) {
    return CupertinoListTile(
      title: SizedBox(
        width: 120,
        child: Text(config.label(LabelKeys.unitValue), style: const TextStyle(fontSize: 16)),
      ),
      additionalInfo: SizedBox(
        width: 150,
        child: CupertinoTextFormFieldRow(
          controller: _valueController,
          placeholder: 'R\$ 0,00',
          inputFormatters: [
            CurrencyTextInputFormatter.currency(
              locale: 'pt_BR',
              symbol: 'R\$',
              decimalDigits: 2,
            ),
          ],
          keyboardType: TextInputType.number,
          textAlign: TextAlign.right,
          padding: EdgeInsets.zero,
          decoration: null,
          style: TextStyle(color: CupertinoColors.label.resolveFrom(context)),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return config.label(LabelKeys.required);
            }
            return null;
          },
          onSaved: (String? value) {
            _orderProduct.value = numberFormat.parse(value!) as double?;
          },
        ),
      ),
    );
  }

  Widget _buildTotalField(BuildContext context, SegmentConfigProvider config) {
    return CupertinoListTile(
      title: SizedBox(
        width: 80,
        child: Text(
          config.label(LabelKeys.total),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      additionalInfo: Text(
        _convertToCurrency(_total),
        textAlign: TextAlign.right,
        style: TextStyle(
          color: CupertinoColors.label.resolveFrom(context),
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildDescriptionField(BuildContext context) {
    return CupertinoTextFormFieldRow(
      initialValue: orderProductIndex != null ? _orderProduct.description : null,
      placeholder: 'Observações sobre o produto',
      textCapitalization: TextCapitalization.sentences,
      maxLines: 3,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      style: TextStyle(color: CupertinoColors.label.resolveFrom(context)),
      onSaved: (String? value) {
        _orderProduct.description = value;
      },
    );
  }

  Widget _buildHeaderImage(BuildContext context) {
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

    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey5.resolveFrom(context),
        shape: BoxShape.circle,
      ),
      child: Icon(
        CupertinoIcons.cube_box,
        size: 50,
        color: CupertinoColors.systemGrey.resolveFrom(context),
      ),
    );
  }
}
