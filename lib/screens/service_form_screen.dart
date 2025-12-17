import 'package:praticos/mobx/service_store.dart';
import 'package:praticos/models/service.dart';
import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ServiceFormScreen extends StatefulWidget {
  const ServiceFormScreen({Key? key}) : super(key: key);

  @override
  State<ServiceFormScreen> createState() => _ServiceFormScreenState();
}

class _ServiceFormScreenState extends State<ServiceFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  Service? _service;
  final ServiceStore _serviceStore = ServiceStore();
  bool _isLoading = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null && args.containsKey('service')) {
        _service = args['service'];
      } else {
        _service = Service();
      }
      _initialized = true;
    }
  }

  bool get _isEditing => _service?.id != null;

  Future<void> _saveService() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      _formKey.currentState!.save();
      await _serviceStore.saveService(_service!);
      setState(() => _isLoading = false);
      Navigator.pop(context, _service);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? "Editar Serviço" : "Novo Serviço"),
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
                // Form fields
                _buildNameField(),
                const SizedBox(height: 16),
                _buildValueField(),
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

  Widget _buildNameField() {
    return TextFormField(
      initialValue: _service!.name,
      decoration: _inputDecoration(
        label: 'Nome',
        icon: Icons.build_outlined,
        hint: 'Nome do serviço',
      ),
      textCapitalization: TextCapitalization.sentences,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Preencha o nome do serviço';
        }
        return null;
      },
      onSaved: (String? value) {
        _service!.name = value;
      },
    );
  }

  Widget _buildValueField() {
    return TextFormField(
      initialValue: _convertToCurrency(_service!.value),
      decoration: _inputDecoration(
        label: 'Valor',
        icon: Icons.attach_money,
        hint: '0,00',
      ),
      inputFormatters: [
        CurrencyTextInputFormatter.currency(
          locale: 'pt_BR',
          symbol: 'R\$ ',
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
        value = value!
            .replaceAll(RegExp(r'R\$'), '')
            .replaceAll(RegExp(r'\.'), '')
            .replaceAll(RegExp(r','), '.')
            .trim();
        _service!.value = double.tryParse(value) ?? 0;
      },
    );
  }

  String _convertToCurrency(double? total) {
    if (total == null || total == 0) return '';
    NumberFormat numberFormat = NumberFormat.currency(
      locale: 'pt-BR',
      symbol: '',
    );
    return numberFormat.format(total);
  }
}
