import 'package:flutter/cupertino.dart';
import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/service.dart';
import 'package:praticos/widgets/cached_image.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/constants/label_keys.dart';

class OrderServiceScreen extends StatefulWidget {
  const OrderServiceScreen({super.key});

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

  final NumberFormat numberFormat = NumberFormat.currency(
    locale: 'pt-BR',
    symbol: 'R\$',
  );

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
        }

        if (args.containsKey('orderServiceIndex')) {
          orderServiceIndex = args['orderServiceIndex'];
          _orderService = _orderStore!.order!.services![orderServiceIndex!];
        }
      }
      _initialized = true;
    }
  }

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

  String _convertToCurrency(double? total) {
    if (total == null) return '';
    return numberFormat.format(total);
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<SegmentConfigProvider>();

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text(_isEditing
            ? config.label(LabelKeys.editService)
            : config.label(LabelKeys.createService)),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _isLoading ? null : _saveService,
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
                  _buildServiceNameField(context),
                  _buildValueField(context, config),
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

  Widget _buildServiceNameField(BuildContext context) {
    final serviceName = orderServiceIndex == null
        ? _service?.name
        : _orderService.service?.name;

    return CupertinoListTile(
      title: const SizedBox(
        width: 80,
        child: Text('Serviço', style: TextStyle(fontSize: 16)),
      ),
      additionalInfo: Expanded(
        child: Text(
          serviceName ?? '',
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

  Widget _buildDescriptionField(BuildContext context) {
    return CupertinoTextFormFieldRow(
      initialValue: orderServiceIndex != null ? _orderService.description : null,
      placeholder: 'Detalhes adicionais do serviço',
      textCapitalization: TextCapitalization.sentences,
      maxLines: 3,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      style: TextStyle(color: CupertinoColors.label.resolveFrom(context)),
      onSaved: (String? value) {
        _orderService.description = value;
      },
    );
  }

  Widget _buildValueField(BuildContext context, SegmentConfigProvider config) {
    final initialValue = orderServiceIndex == null
        ? _convertToCurrency(_service?.value)
        : _convertToCurrency(_orderService.value);

    return CupertinoListTile(
      title: const SizedBox(
        width: 80,
        child: Text('Valor', style: TextStyle(fontSize: 16)),
      ),
      additionalInfo: SizedBox(
        width: 150,
        child: CupertinoTextFormFieldRow(
          initialValue: initialValue,
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
            _orderService.value = numberFormat.parse(value!) as double?;
          },
        ),
      ),
    );
  }

  Widget _buildHeaderImage(BuildContext context) {
    String? photoUrl;
    if (orderServiceIndex != null) {
      photoUrl = _orderService.photo;
    } else {
      photoUrl = _service?.photo;
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
        CupertinoIcons.wrench,
        size: 50,
        color: CupertinoColors.systemGrey.resolveFrom(context),
      ),
    );
  }
}
