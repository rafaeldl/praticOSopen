import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Theme, Icons, Icon, InputDecoration, Colors;
import 'package:intl/intl.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/service.dart';
import 'package:praticos/widgets/cached_image.dart';

class OrderServiceScreen extends StatefulWidget {
  const OrderServiceScreen({Key? key}) : super(key: key);

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

  late final CurrencyTextInputFormatter _currencyFormatter;
  final TextEditingController _valueController = TextEditingController();

  final NumberFormat numberFormat = NumberFormat.currency(
    locale: 'pt-BR',
    symbol: 'R\$',
  );

  bool get _isEditing => orderServiceIndex != null;

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

        if (args.containsKey('service')) {
          _service = args['service'];
          _orderService.service = _service!.toAggr();
        }

        if (args.containsKey('orderServiceIndex')) {
          orderServiceIndex = args['orderServiceIndex'];
          _orderService = _orderStore!.order!.services![orderServiceIndex!];
        }
      }

      // Initialize value controller
      final initialValue = orderServiceIndex == null
        ? _service?.value
        : _orderService.value;
      _valueController.text = _convertToCurrency(initialValue);

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

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text(_isEditing ? 'Editar Serviço' : 'Novo Serviço'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _isLoading ? null : _saveService,
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
                  // Service Name (Read-only)
                  CupertinoTextFormFieldRow(
                    prefix: const Text("Serviço", style: TextStyle(fontSize: 16)),
                    initialValue: orderServiceIndex == null
                        ? _service?.name
                        : _orderService.service?.name,
                    readOnly: true,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: CupertinoColors.systemGrey.resolveFrom(context),
                    ),
                  ),

                  // Value
                  CupertinoTextFormFieldRow(
                    prefix: const Text("Valor", style: TextStyle(fontSize: 16)),
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
                        _orderService.value = double.tryParse(cleanValue) ?? 0.0;
                      }
                    },
                  ),
                ],
              ),

              CupertinoListSection.insetGrouped(
                header: const Text('OBSERVAÇÕES'),
                children: [
                   CupertinoTextFormFieldRow(
                    initialValue: orderServiceIndex != null ? _orderService.description : null,
                    placeholder: "Adicione detalhes sobre este serviço...",
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 4,
                    minLines: 2,
                    textAlign: TextAlign.start,
                    onSaved: (String? value) {
                      _orderService.description = value;
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
            CupertinoIcons.wrench,
            size: 50,
            color: CupertinoColors.systemGrey.resolveFrom(context),
          ),
        );
      }
    );
  }
}
