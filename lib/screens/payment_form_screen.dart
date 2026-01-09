import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialType, Divider;
import 'package:intl/intl.dart';
import 'package:praticos/mobx/order_store.dart';

enum PaymentFormMode {
  payment,
  discount,
}

class PaymentFormScreen extends StatefulWidget {
  const PaymentFormScreen({super.key});

  @override
  State<PaymentFormScreen> createState() => _PaymentFormScreenState();
}

class _PaymentFormScreenState extends State<PaymentFormScreen> {
  bool _isLoading = false;
  bool _initialized = false;
  final TextEditingController _valueController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  final NumberFormat numberFormat = NumberFormat.currency(
    locale: 'pt-BR',
    symbol: 'R\$',
  );

  PaymentFormMode _mode = PaymentFormMode.payment;
  OrderStore? _store;

  @override
  void dispose() {
    _valueController.dispose();
    _descriptionController.dispose();
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
          _store = args['orderStore'];
        }
        if (args.containsKey('mode')) {
          _mode = args['mode'] as PaymentFormMode;
        }
      }

      // Pré-preenche com valor restante no modo pagamento
      if (_mode == PaymentFormMode.payment && _store != null) {
        final remaining = _store!.remainingBalance;
        if (remaining > 0) {
          _valueController.text = _convertToCurrency(remaining);
        }
      }

      _initialized = true;
    }
  }

  double _parseValue(String value) {
    final cleanValue = value
        .replaceAll(RegExp(r'R\$'), '')
        .replaceAll(RegExp(r'BRL'), '')
        .replaceAll(RegExp(r'\.'), '')
        .replaceAll(RegExp(r','), '.')
        .trim();
    return double.tryParse(cleanValue) ?? 0;
  }

  String? _validateValue(String? value) {
    if (value == null || value.isEmpty) {
      return 'Preencha o valor';
    }

    final valueDouble = _parseValue(value);
    if (valueDouble <= 0) {
      return 'O valor deve ser maior que zero';
    }

    if (_mode == PaymentFormMode.discount) {
      // Desconto não pode ser maior que o saldo restante
      if (_store != null && valueDouble > _store!.remainingBalance) {
        return 'Desconto não pode ser maior que o saldo';
      }
    }

    if (_mode == PaymentFormMode.payment) {
      // Pagamento não pode ser maior que o saldo restante
      if (_store != null && valueDouble > _store!.remainingBalance) {
        return 'Pagamento não pode ser maior que o saldo';
      }
    }

    return null;
  }

  void _save() {
    final error = _validateValue(_valueController.text);
    if (error != null) {
      _showError(error);
      return;
    }

    setState(() => _isLoading = true);

    final value = _parseValue(_valueController.text);
    final description = _descriptionController.text.isNotEmpty
        ? _descriptionController.text
        : null;

    if (_mode == PaymentFormMode.payment) {
      _store?.addPayment(value, description: description);
    } else {
      _store?.addDiscountTransaction(value, description: description);
    }

    Navigator.pop(context, true);
  }

  void _showError(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Atenção'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPayment = _mode == PaymentFormMode.payment;

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text(isPayment ? 'Registrar Pagamento' : 'Conceder Desconto'),
        trailing: _isLoading
            ? const CupertinoActivityIndicator()
            : CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _save,
                child: const Text('Salvar'),
              ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    // Ícone de header
                    _buildHeaderIcon(isPayment),
                    const SizedBox(height: 20),
                    // Card de informação do saldo
                    _buildBalanceCard(),
                    const SizedBox(height: 20),
                    // Formulário
                    _buildFormSection(isPayment),
                    const SizedBox(height: 20),
                    // Botões de ação rápida
                    if (isPayment) _buildQuickActions(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderIcon(bool isPayment) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: isPayment
            ? CupertinoColors.systemGreen.withValues(alpha: 0.15)
            : CupertinoColors.systemOrange.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(
        isPayment ? CupertinoIcons.money_dollar_circle : CupertinoIcons.tag_fill,
        size: 40,
        color: isPayment
            ? CupertinoColors.systemGreen
            : CupertinoColors.systemOrange,
      ),
    );
  }

  Widget _buildBalanceCard() {
    final total = _store?.total ?? 0.0;
    final paid = _store?.paidAmount ?? 0.0;
    final remaining = _store?.remainingBalance ?? 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground.resolveFrom(context),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            _buildInfoRow(
              'Total da OS',
              _convertToCurrency(total),
              CupertinoColors.label.resolveFrom(context),
            ),
            Divider(
              height: 1,
              indent: 16,
              color: CupertinoColors.systemGrey5.resolveFrom(context),
            ),
            _buildInfoRow(
              'Já pago',
              _convertToCurrency(paid),
              CupertinoColors.systemGreen,
            ),
            Divider(
              height: 1,
              indent: 16,
              color: CupertinoColors.systemGrey5.resolveFrom(context),
            ),
            _buildInfoRow(
              'Saldo restante',
              _convertToCurrency(remaining),
              remaining > 0
                  ? CupertinoColors.systemOrange
                  : CupertinoColors.systemGreen,
              isBold: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color valueColor,
      {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 17,
              color: CupertinoColors.label.resolveFrom(context),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormSection(bool isPayment) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground.resolveFrom(context),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Campo de valor
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPayment ? 'Valor do pagamento' : 'Valor do desconto',
                    style: TextStyle(
                      fontSize: 13,
                      color: CupertinoColors.secondaryLabel.resolveFrom(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  CupertinoTextField(
                    controller: _valueController,
                    placeholder: 'R\$ 0,00',
                    prefix: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Icon(
                        isPayment
                            ? CupertinoIcons.money_dollar
                            : CupertinoIcons.tag,
                        color: CupertinoColors.systemGrey.resolveFrom(context),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
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
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: CupertinoColors.label.resolveFrom(context),
                    ),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey6.resolveFrom(context),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              indent: 16,
              color: CupertinoColors.systemGrey5.resolveFrom(context),
            ),
            // Campo de descrição
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Observação (opcional)',
                    style: TextStyle(
                      fontSize: 13,
                      color: CupertinoColors.secondaryLabel.resolveFrom(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  CupertinoTextField(
                    controller: _descriptionController,
                    placeholder: isPayment
                        ? 'Ex: Pagamento em dinheiro'
                        : 'Ex: Desconto de fidelidade',
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    maxLines: 2,
                    style: TextStyle(
                      fontSize: 17,
                      color: CupertinoColors.label.resolveFrom(context),
                    ),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey6.resolveFrom(context),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    final remaining = _store?.remainingBalance ?? 0.0;

    if (remaining <= 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground.resolveFrom(context),
          borderRadius: BorderRadius.circular(10),
        ),
        child: CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          onPressed: () {
            _valueController.text = _convertToCurrency(remaining);
          },
          child: Row(
            children: [
              Icon(
                CupertinoIcons.checkmark_circle,
                color: CupertinoTheme.of(context).primaryColor,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Pagar valor total restante',
                  style: TextStyle(
                    fontSize: 17,
                    color: CupertinoTheme.of(context).primaryColor,
                  ),
                ),
              ),
              Text(
                _convertToCurrency(remaining),
                style: TextStyle(
                  fontSize: 17,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _convertToCurrency(double? total) {
    total ??= 0.0;
    return numberFormat.format(total);
  }
}
