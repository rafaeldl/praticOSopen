import 'package:json_annotation/json_annotation.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/services/format_service.dart';

part 'payment_transaction.g.dart';

/// Tipo de transação de pagamento
enum PaymentTransactionType {
  @JsonValue('payment')
  payment,
  @JsonValue('discount')
  discount,
}

/// Modelo para rastrear transações de pagamento e desconto
/// Cada transação representa um pagamento parcial ou um desconto concedido
@JsonSerializable(explicitToJson: true)
class PaymentTransaction {
  String? id;

  /// Tipo da transação: payment ou discount
  PaymentTransactionType type;

  /// Valor da transação (sempre positivo)
  double amount;

  /// Descrição/observação da transação
  String? description;

  /// Data da transação
  DateTime createdAt;

  /// Usuário que registrou a transação
  UserAggr? createdBy;

  PaymentTransaction({
    this.id,
    required this.type,
    required this.amount,
    this.description,
    DateTime? createdAt,
    this.createdBy,
  }) : createdAt = createdAt ?? DateTime.now();

  factory PaymentTransaction.fromJson(Map<String, dynamic> json) =>
      _$PaymentTransactionFromJson(json);
  Map<String, dynamic> toJson() => _$PaymentTransactionToJson(this);

  /// Cria uma transação de pagamento
  factory PaymentTransaction.payment({
    required double amount,
    String? description,
    UserAggr? createdBy,
  }) {
    return PaymentTransaction(
      type: PaymentTransactionType.payment,
      amount: amount,
      description: description,
      createdBy: createdBy,
    );
  }

  /// Cria uma transação de desconto
  factory PaymentTransaction.discount({
    required double amount,
    String? description,
    UserAggr? createdBy,
  }) {
    return PaymentTransaction(
      type: PaymentTransactionType.discount,
      amount: amount,
      description: description,
      createdBy: createdBy,
    );
  }

  /// Retorna o valor formatado com sinal (+ para pagamento, - para desconto)
  String formattedAmount(FormatService formatService) {
    final formatted = formatService.formatCurrency(amount);
    if (type == PaymentTransactionType.discount) {
      return '- $formatted';
    }
    return '+ $formatted';
  }

  /// Retorna o label do tipo de transação localizado
  String typeLabel(AppLocalizations l10n) {
    switch (type) {
      case PaymentTransactionType.payment:
        return l10n.payment;
      case PaymentTransactionType.discount:
        return l10n.discount;
    }
  }
}
