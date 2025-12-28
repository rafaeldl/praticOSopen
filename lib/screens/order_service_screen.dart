import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/service.dart';
import 'package:praticos/widgets/cached_image.dart';
import 'package:praticos/widgets/grouped_row.dart';
import 'package:praticos/widgets/grouped_section.dart';
import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // iOS grouped background color approximation
    final backgroundColor = isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Serviço' : 'Novo Serviço'),
        elevation: 0,
        backgroundColor: backgroundColor,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveService,
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
                _buildServiceNameRow(theme),
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

  Widget _buildServiceNameRow(ThemeData theme) {
    final serviceName = orderServiceIndex == null
        ? _service?.name
        : _orderService.service?.name;

    return GroupedRow(
      label: 'Serviço',
      child: Text(
        serviceName ?? '',
        style: TextStyle(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w500,
          fontSize: 17,
        ),
        textAlign: TextAlign.right,
      ),
    );
  }

  Widget _buildValueRow(ThemeData theme) {
    final initialValue = orderServiceIndex == null
        ? _convertToCurrency(_service?.value)
        : _convertToCurrency(_orderService.value);

    return GroupedRow(
      label: 'Valor',
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
          _orderService.value = numberFormat.parse(value!) as double?;
        },
      ),
    );
  }

  Widget _buildDescriptionRow(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      constraints: const BoxConstraints(minHeight: 100),
      child: TextFormField(
        initialValue: orderServiceIndex != null ? _orderService.description : null,
        decoration: const InputDecoration.collapsed(
          hintText: 'Adicione detalhes sobre este serviço...',
        ),
        style: const TextStyle(fontSize: 17),
        textCapitalization: TextCapitalization.sentences,
        maxLines: 5,
        minLines: 3,
        onSaved: (String? value) {
          _orderService.description = value;
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

    return CircleAvatar(
      radius: 50,
      backgroundColor: theme.colorScheme.surface,
      child: Icon(
        Icons.build,
        size: 50,
        color: theme.colorScheme.primary,
      ),
    );
  }
}
