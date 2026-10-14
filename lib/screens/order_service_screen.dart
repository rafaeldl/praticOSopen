import 'package:flutter/cupertino.dart';
import 'package:praticos/constants/label_keys.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/permission.dart';
import 'package:praticos/models/service.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/screens/order/order_item_form.dart';
import 'package:praticos/screens/widgets/app_form_field.dart';
import 'package:praticos/screens/widgets/form_sheet.dart';
import 'package:praticos/services/authorization_service.dart';
import 'package:provider/provider.dart';

/// Service line of an order, opened pushed (`/order_service`) with the
/// route arguments `orderStore` plus `service` (adding from the catalog) or
/// `orderServiceIndex` (editing a line already in the order).
class OrderServiceScreen extends StatefulWidget {
  const OrderServiceScreen({
    super.key,
    this.canEditMainFields,
    this.canViewPrices,
  });

  /// Overrides [AuthorizationService.canEditOrderMainFields] (tests).
  final bool? canEditMainFields;

  /// Overrides the `viewPrices` permission (tests).
  final bool? canViewPrices;

  @override
  State<OrderServiceScreen> createState() => _OrderServiceScreenState();
}

class _OrderServiceScreenState extends State<OrderServiceScreen> {
  OrderStore? _orderStore;
  Service? _service;
  OrderService _orderService = OrderService();
  int? orderServiceIndex;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _initialized = false;
  final AuthorizationService _authService = AuthorizationService.instance;

  final TextEditingController _valueController = TextEditingController();

  bool get _isEditing => orderServiceIndex != null;

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

        if (args.containsKey('service')) {
          _service = args['service'];
          _orderService.service = _service!.toAggr();
          // Initialize value from service to ensure it's not null if field is hidden
          _orderService.value ??= _service!.value;
        }

        if (args.containsKey('orderServiceIndex')) {
          orderServiceIndex = args['orderServiceIndex'];
          _orderService = _orderStore!.order!.services![orderServiceIndex!];
        }
      }
      final value = _isEditing ? _orderService.value : _service?.value;
      if (value != null) {
        _valueController.text = orderItemMoneyFormatter(context).textFor(value);
      }
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  bool get _canEditMainFields =>
      widget.canEditMainFields ??
      (_orderStore?.order != null
          ? _authService.canEditOrderMainFields(_orderStore!.order!)
          : true);

  bool get _canViewPrices =>
      widget.canViewPrices ??
      _authService.hasPermission(PermissionType.viewPrices);

  Future<void> _saveService() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      _formKey.currentState!.save();

      if (orderServiceIndex == null) {
        _orderStore!.addService(_orderService);
        Navigator.popUntil(context, ModalRoute.withName('/order'));
      } else {
        _orderStore!.updateOrder();
        Navigator.pop(context);
      }
    }
  }

  Future<void> _showMore() async {
    final index = orderServiceIndex;
    if (index == null) return;
    final remove = await askRemoveOrderItem(context, _serviceName);
    if (!remove || !mounted) return;
    _orderStore!.deleteService(index);
    Navigator.pop(context);
  }

  String get _serviceName =>
      (_isEditing ? _orderService.service?.name : _service?.name) ?? '';

  @override
  Widget build(BuildContext context) {
    final config = context.watch<SegmentConfigProvider>();
    final l10n = context.l10n;

    // Main fields (value, device) follow the order permissions; notes can
    // always be edited.
    final canEditMainFields = _canEditMainFields;
    final showValue = _canViewPrices && canEditMainFields;
    final devices = _orderStore?.devices.toList() ?? const [];
    final formatter = orderItemMoneyFormatter(context);

    return Form(
      key: _formKey,
      child: OrderItemScaffold(
        title: _isEditing
            ? config.label(LabelKeys.editService)
            : config.label(LabelKeys.createService),
        busy: _isLoading,
        onSave: _saveService,
        onMore: _isEditing && canEditMainFields ? _showMore : null,
        children: [
          OrderItemHeaderCard(
            name: _serviceName,
            icon: CupertinoIcons.wrench,
            photoUrl: _isEditing ? _orderService.photo : _service?.photo,
          ),
          if (showValue)
            FormFieldsCard(
              children: [
                AppFormField(
                  key: const ValueKey('order_item_value'),
                  label: l10n.value,
                  controller: _valueController,
                  placeholder: formatter.textFor(0),
                  keyboardType: TextInputType.number,
                  inputFormatters: [formatter],
                  validator: (text) => text.trim().isEmpty
                      ? config.label(LabelKeys.required)
                      : null,
                  onSaved: (text) =>
                      _orderService.value = formatter.valueOf(text),
                ),
              ],
            ),
          if (devices.length >= 2)
            OrderItemRowsCard(
              children: [
                OrderItemDeviceRow(
                  label: config.device,
                  devices: devices,
                  deviceId: _orderService.deviceId,
                  enabled: canEditMainFields,
                  onChanged: (id) =>
                      setState(() => _orderService.deviceId = id),
                ),
              ],
            ),
          FormFieldsCard(
            children: [
              AppFormField(
                key: const ValueKey('order_item_notes'),
                label: config.label(LabelKeys.notes),
                initialValue: _isEditing ? _orderService.description : null,
                placeholder: l10n.orderItemNotesPlaceholder,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
                onSaved: (text) => _orderService.description = text,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
