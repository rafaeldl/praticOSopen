import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialType, Divider;
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:intl/intl.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/payment_transaction.dart';
import 'package:praticos/screens/payment_form_screen.dart';

class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  bool _initialized = false;
  OrderStore? _store;

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'pt-BR',
    symbol: 'R\$',
  );

  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null && args.containsKey('orderStore')) {
        _store = args['orderStore'];
      }
      _initialized = true;
    }
  }

  void _addPayment() {
    Navigator.pushNamed(
      context,
      '/payment_form_screen',
      arguments: {
        'orderStore': _store,
        'mode': PaymentFormMode.payment,
      },
    );
  }

  void _addDiscount() {
    Navigator.pushNamed(
      context,
      '/payment_form_screen',
      arguments: {
        'orderStore': _store,
        'mode': PaymentFormMode.discount,
      },
    );
  }

  void _confirmDeleteTransaction(int index, PaymentTransaction transaction) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Remover ${transaction.typeLabel}'),
        content: Text(
          'Deseja remover este ${transaction.typeLabel.toLowerCase()} de ${_currencyFormat.format(transaction.amount)}?',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              _store?.removeTransaction(index);
            },
            child: const Text('Remover'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: Material(
        type: MaterialType.transparency,
        child: CustomScrollView(
          slivers: [
            CupertinoSliverNavigationBar(
              largeTitle: const Text('Pagamentos'),
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _showAddOptions,
                child: const Icon(CupertinoIcons.add),
              ),
            ),
            SliverSafeArea(
              top: false,
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Resumo financeiro
                  _buildSummarySection(),
                  const SizedBox(height: 20),
                  // Ações rápidas
                  _buildQuickActionsSection(),
                  const SizedBox(height: 20),
                  // Lista de transações
                  _buildTransactionsSection(),
                  const SizedBox(height: 40),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummarySection() {
    return Observer(
      builder: (_) {
        final total = _store?.total ?? 0.0;
        final paid = _store?.paidAmount ?? 0.0;
        final discount = _store?.discount ?? 0.0;
        final remaining = _store?.remainingBalance ?? 0.0;
        final isFullyPaid = _store?.isFullyPaid ?? false;

        return _buildGroupedSection(
          header: 'RESUMO',
          children: [
            _buildSummaryRow(
              icon: CupertinoIcons.money_dollar_circle_fill,
              iconColor: CupertinoColors.systemBlue,
              label: 'Total da OS',
              value: _currencyFormat.format(total),
              valueColor: CupertinoColors.label.resolveFrom(context),
            ),
            if (discount > 0)
              _buildSummaryRow(
                icon: CupertinoIcons.tag_fill,
                iconColor: CupertinoColors.systemOrange,
                label: 'Descontos',
                value: '- ${_currencyFormat.format(discount)}',
                valueColor: CupertinoColors.systemOrange,
              ),
            _buildSummaryRow(
              icon: CupertinoIcons.checkmark_circle_fill,
              iconColor: CupertinoColors.systemGreen,
              label: 'Já pago',
              value: _currencyFormat.format(paid),
              valueColor: CupertinoColors.systemGreen,
            ),
            _buildSummaryRow(
              icon: isFullyPaid
                  ? CupertinoIcons.checkmark_seal_fill
                  : CupertinoIcons.clock_fill,
              iconColor: isFullyPaid
                  ? CupertinoColors.systemGreen
                  : CupertinoColors.systemOrange,
              label: 'Saldo restante',
              value: _currencyFormat.format(remaining),
              valueColor: isFullyPaid
                  ? CupertinoColors.systemGreen
                  : CupertinoColors.systemOrange,
              isBold: true,
              isLast: true,
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuickActionsSection() {
    return Observer(
      builder: (_) {
        final remaining = _store?.remainingBalance ?? 0.0;
        final isFullyPaid = _store?.isFullyPaid ?? false;

        if (isFullyPaid) {
          return _buildGroupedSection(
            header: '',
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      CupertinoIcons.checkmark_seal_fill,
                      color: CupertinoColors.systemGreen,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Totalmente pago',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.systemGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        return _buildGroupedSection(
          header: 'AÇÕES',
          children: [
            _buildActionRow(
              icon: CupertinoIcons.money_dollar_circle,
              iconColor: CupertinoColors.systemGreen,
              label: 'Registrar pagamento',
              onTap: _addPayment,
            ),
            _buildActionRow(
              icon: CupertinoIcons.tag,
              iconColor: CupertinoColors.systemOrange,
              label: 'Conceder desconto',
              onTap: _addDiscount,
            ),
            _buildActionRow(
              icon: CupertinoIcons.checkmark_circle,
              iconColor: CupertinoColors.systemBlue,
              label: 'Marcar como totalmente pago',
              subtitle: 'Registra ${_currencyFormat.format(remaining)}',
              onTap: () => _confirmMarkAsPaid(remaining),
              isLast: true,
            ),
          ],
        );
      },
    );
  }

  Widget _buildTransactionsSection() {
    return Observer(
      builder: (_) {
        final transactions = _store?.transactions ?? [];

        if (transactions.isEmpty) {
          return _buildGroupedSection(
            header: 'HISTÓRICO',
            children: [
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        CupertinoIcons.doc_text,
                        size: 48,
                        color: CupertinoColors.systemGrey.resolveFrom(context),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Nenhuma transação registrada',
                        style: TextStyle(
                          fontSize: 15,
                          color: CupertinoColors.secondaryLabel
                              .resolveFrom(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        // Ordenar por data decrescente
        final sortedTransactions = List<PaymentTransaction>.from(transactions);
        sortedTransactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        return _buildGroupedSection(
          header: 'HISTÓRICO',
          children: sortedTransactions.asMap().entries.map((entry) {
            final index = transactions.indexOf(entry.value);
            final transaction = entry.value;
            final isLast = entry.key == sortedTransactions.length - 1;
            return _buildTransactionRow(transaction, index, isLast);
          }).toList(),
        );
      },
    );
  }

  Widget _buildTransactionRow(
      PaymentTransaction transaction, int index, bool isLast) {
    final isPayment = transaction.type == PaymentTransactionType.payment;

    return Dismissible(
      key: ValueKey('transaction_${transaction.createdAt.millisecondsSinceEpoch}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        _confirmDeleteTransaction(index, transaction);
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: CupertinoColors.systemRed,
        child: const Icon(
          CupertinoIcons.trash,
          color: CupertinoColors.white,
        ),
      ),
      child: Container(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Ícone
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isPayment
                          ? CupertinoColors.systemGreen.withValues(alpha: 0.15)
                          : CupertinoColors.systemOrange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isPayment
                          ? CupertinoIcons.arrow_down_circle
                          : CupertinoIcons.tag,
                      color: isPayment
                          ? CupertinoColors.systemGreen
                          : CupertinoColors.systemOrange,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Detalhes
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transaction.typeLabel,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                            color: CupertinoColors.label.resolveFrom(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          transaction.description ??
                              _dateFormat.format(transaction.createdAt),
                          style: TextStyle(
                            fontSize: 13,
                            color: CupertinoColors.secondaryLabel
                                .resolveFrom(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (transaction.description != null)
                          Text(
                            _dateFormat.format(transaction.createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: CupertinoColors.tertiaryLabel
                                  .resolveFrom(context),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Valor
                  Text(
                    isPayment
                        ? '+ ${_currencyFormat.format(transaction.amount)}'
                        : '- ${_currencyFormat.format(transaction.amount)}',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: isPayment
                          ? CupertinoColors.systemGreen
                          : CupertinoColors.systemOrange,
                    ),
                  ),
                ],
              ),
            ),
            if (!isLast)
              Divider(
                height: 1,
                indent: 68,
                color: CupertinoColors.systemGrey5.resolveFrom(context),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupedSection({
    required String header,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (header.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 24, 20, 8),
            child: Text(
              header,
              style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
          ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: CupertinoColors.systemBackground.resolveFrom(context),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required Color valueColor,
    bool isBold = false,
    bool isLast = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 17,
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
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
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 50,
            color: CupertinoColors.systemGrey5.resolveFrom(context),
          ),
      ],
    );
  }

  Widget _buildActionRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    String? subtitle,
    required VoidCallback onTap,
    bool isLast = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(icon, color: iconColor, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 17,
                            color: CupertinoTheme.of(context).primaryColor,
                          ),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 13,
                              color: CupertinoColors.secondaryLabel
                                  .resolveFrom(context),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    CupertinoIcons.chevron_right,
                    size: 16,
                    color: CupertinoColors.systemGrey3.resolveFrom(context),
                  ),
                ],
              ),
            ),
            if (!isLast)
              Divider(
                height: 1,
                indent: 50,
                color: CupertinoColors.systemGrey5.resolveFrom(context),
              ),
          ],
        ),
      ),
    );
  }

  void _showAddOptions() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Adicionar'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _addPayment();
            },
            child: const Text('Registrar Pagamento'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _addDiscount();
            },
            child: const Text('Conceder Desconto'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ),
    );
  }

  void _confirmMarkAsPaid(double remaining) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Marcar como pago'),
        content: Text(
          'Registrar pagamento de ${_currencyFormat.format(remaining)} e marcar a OS como totalmente paga?',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(context);
              _store?.markAsFullyPaid();
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }
}
