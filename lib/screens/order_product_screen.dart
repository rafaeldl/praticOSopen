import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:praticos/constants/label_keys.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/permission.dart';
import 'package:praticos/models/product.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/screens/catalog/catalog_source.dart';
import 'package:praticos/screens/order/order_item_form.dart';
import 'package:praticos/screens/widgets/app_form_field.dart';
import 'package:praticos/screens/widgets/form_sheet.dart';
import 'package:praticos/screens/widgets/money_field.dart';
import 'package:praticos/services/authorization_service.dart';
import 'package:praticos/services/format_service.dart';
import 'package:provider/provider.dart';

/// Product line of an order, opened pushed (`/order_product`) with the
/// route arguments `orderStore` plus `product` (adding from the catalog) or
/// `orderProductIndex` (editing a line already in the order).
class OrderProductScreen extends StatefulWidget {
  const OrderProductScreen({
    super.key,
    this.canEditMainFields,
    this.canViewPrices,
    this.canManageCatalog,
    this.catalogPriceWriter,
  });

  /// Overrides [AuthorizationService.canEditOrderMainFields] (tests).
  final bool? canEditMainFields;

  /// Overrides the `viewPrices` permission (tests).
  final bool? canViewPrices;

  /// Overrides the `manageProducts` permission (tests).
  final bool? canManageCatalog;

  /// Overrides [writeCatalogPrice] (tests).
  final CatalogPriceWriter? catalogPriceWriter;

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
  final AuthorizationService _authService = AuthorizationService.instance;

  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _valueController = TextEditingController();
  late MoneyInputFormatter _money;
  double _total = 0;

  bool get _isEditing => orderProductIndex != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _money = orderItemMoneyFormatter(context);
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
      }

      // Initialize controllers
      final value = _isEditing ? _orderProduct.value : _product?.value;
      _quantityController.text = _isEditing
          ? _orderProduct.quantity.toString()
          : '1';
      if (value != null) {
        _valueController.text = _money.textFor(value);
      }

      // Real-time total
      _quantityController.addListener(_updateTotal);
      _valueController.addListener(_updateTotal);
      _total = _computeTotal();

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

  double _computeTotal() {
    final quantity = int.tryParse(_quantityController.text.trim()) ?? 0;
    final valueText = _valueController.text;
    final value = valueText.isEmpty ? 0.0 : _money.valueOf(valueText);
    return quantity * value;
  }

  void _updateTotal() => setState(() => _total = _computeTotal());

  bool get _canEditMainFields =>
      widget.canEditMainFields ??
      (_orderStore?.order != null
          ? _authService.canEditOrderMainFields(_orderStore!.order!)
          : true);

  bool get _canViewPrices =>
      widget.canViewPrices ??
      _authService.hasPermission(PermissionType.viewPrices);

  bool get _canManageCatalog =>
      widget.canManageCatalog ??
      _authService.hasPermission(PermissionType.manageProducts);

  Future<void> _saveProduct() async {
    if (_formKey.currentState!.validate()) {
      final previousValue = _orderProduct.value;
      _formKey.currentState!.save();
      await _offerCatalogPrice(previousValue);
      if (!mounted) return;
      setState(() => _isLoading = true);

      final value = _orderProduct.value;
      _orderProduct.total = value == null
          ? null
          : (_orderProduct.quantity ?? 1) * value;

      if (orderProductIndex == null) {
        _orderStore!.addProduct(_orderProduct);
        Navigator.popUntil(context, ModalRoute.withName('/order'));
      } else {
        _orderStore!.updateOrder();
        Navigator.pop(context);
      }
    }
  }

  /// A new unit price for a product of the catalog: only here or always?
  Future<void> _offerCatalogPrice(double? previousValue) async {
    final catalog = _orderProduct.product;
    final newValue = _orderProduct.value;
    final offer = shouldOfferCatalogPrice(
      catalogId: catalog?.id,
      catalogValue: _isEditing ? catalog?.value : _product?.value,
      previousValue: _isEditing ? previousValue : _product?.value,
      newValue: newValue,
      canManageCatalog: _canManageCatalog && _canViewPrices,
    );
    if (!offer) return;
    final always = await askCatalogPrice(
      context,
      entity: context.read<SegmentConfigProvider>().label(
        LabelKeys.productEntity,
      ),
      name: _productName,
      from: _isEditing ? catalog!.value : _product?.value,
      to: newValue!,
    );
    if (!always) return;
    catalog!.value = newValue;
    final write = widget.catalogPriceWriter ?? writeCatalogPrice;
    // Not awaited: offline, Firestore only completes once it syncs.
    unawaited(
      write(CatalogKind.product, catalog.id!, newValue).catchError(
        (Object e) => debugPrint('catalog price not saved: $e'),
      ),
    );
  }

  Future<void> _showMore() async {
    final index = orderProductIndex;
    if (index == null) return;
    final remove = await askRemoveOrderItem(context, _productName);
    if (!remove || !mounted) return;
    _orderStore!.deleteProduct(index);
    Navigator.pop(context);
  }

  String get _productName =>
      (_isEditing ? _orderProduct.product?.name : _product?.name) ?? '';

  @override
  Widget build(BuildContext context) {
    final config = context.watch<SegmentConfigProvider>();
    final l10n = context.l10n;

    // Main fields (quantity, value, device) follow the order permissions;
    // notes can always be edited.
    final canEditMainFields = _canEditMainFields;
    final showValue = _canViewPrices && canEditMainFields;
    final devices = _orderStore?.devices.toList() ?? const [];
    final formatter = _money;
    final format = FormatService()..setLocale(l10n.localeName);

    return Form(
      key: _formKey,
      child: OrderItemScaffold(
        title: _isEditing
            ? config.label(LabelKeys.editProduct)
            : config.label(LabelKeys.createProduct),
        busy: _isLoading,
        onSave: _saveProduct,
        onMore: _isEditing && canEditMainFields ? _showMore : null,
        children: [
          OrderItemHeaderCard(
            name: _productName,
            icon: CupertinoIcons.cube_box,
            photoUrl: _isEditing ? _orderProduct.photo : _product?.photo,
          ),
          FormFieldsCard(
            children: [
              OrderItemQuantityField(
                label: config.label(LabelKeys.quantity),
                controller: _quantityController,
                enabled: canEditMainFields,
                onSaved: (q) => _orderProduct.quantity = q,
              ),
              if (showValue) ...[
                AppFormField(
                  key: const ValueKey('order_item_value'),
                  label: config.label(LabelKeys.unitValue),
                  controller: _valueController,
                  placeholder: formatter.textFor(0),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [formatter],
                  validator: (text) => text.trim().isEmpty
                      ? config.label(LabelKeys.required)
                      : null,
                  onSaved: (text) =>
                      _orderProduct.value = formatter.valueOf(text),
                ),
                OrderItemTotalRow(
                  label: config.label(LabelKeys.total),
                  value: format.formatCurrency(_total),
                ),
              ],
            ],
          ),
          if (devices.length >= 2)
            OrderItemRowsCard(
              children: [
                OrderItemDeviceRow(
                  label: config.device,
                  devices: devices,
                  deviceId: _orderProduct.deviceId,
                  enabled: canEditMainFields,
                  onChanged: (id) =>
                      setState(() => _orderProduct.deviceId = id),
                ),
              ],
            ),
          FormFieldsCard(
            children: [
              AppFormField(
                key: const ValueKey('order_item_notes'),
                label: config.label(LabelKeys.notes),
                initialValue: _isEditing ? _orderProduct.description : null,
                placeholder: l10n.orderItemNotesPlaceholder,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
                onSaved: (text) => _orderProduct.description = text,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
