import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/service.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Serviço' : 'Novo Serviço'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header icon
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(
                      Icons.build,
                      size: 40,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Service name (read-only)
                _buildServiceNameField(theme),
                const SizedBox(height: 16),

                // Description field
                _buildDescriptionField(theme),
                const SizedBox(height: 16),

                // Value field
                _buildValueField(theme),
                const SizedBox(height: 32),

                // Save button
                FilledButton.icon(
                  onPressed: _isLoading ? null : _saveService,
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

  Widget _buildServiceNameField(ThemeData theme) {
    final serviceName = orderServiceIndex == null
        ? _service?.name
        : _orderService.service?.name;

    return TextFormField(
      enabled: false,
      initialValue: serviceName,
      decoration: _inputDecoration(
        label: 'Serviço',
        icon: Icons.build_outlined,
      ),
      style: TextStyle(
        color: theme.colorScheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildDescriptionField(ThemeData theme) {
    return TextFormField(
      initialValue: orderServiceIndex != null ? _orderService.description : null,
      decoration: _inputDecoration(
        label: 'Descrição',
        icon: Icons.description_outlined,
        hint: 'Detalhes adicionais do serviço',
      ),
      textCapitalization: TextCapitalization.sentences,
      maxLines: 3,
      onSaved: (String? value) {
        _orderService.description = value;
      },
    );
  }

  Widget _buildValueField(ThemeData theme) {
    final initialValue = orderServiceIndex == null
        ? _convertToCurrency(_service?.value)
        : _convertToCurrency(_orderService.value);

    return TextFormField(
      initialValue: initialValue,
      decoration: _inputDecoration(
        label: 'Valor',
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
          return 'Preencha o valor do serviço';
        }
        return null;
      },
      onSaved: (String? value) {
        _orderService.value = numberFormat.parse(value!) as double?;
      },
    );
  }

  String _convertToCurrency(double? total) {
    if (total == null) return '';
    return numberFormat.format(total);
  }
}
