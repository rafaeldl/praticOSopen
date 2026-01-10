import 'package:json_annotation/json_annotation.dart';
import 'package:praticos/models/user.dart';

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
  String get formattedAmount {
    if (type == PaymentTransactionType.discount) {
      return '- R\$ ${amount.toStringAsFixed(2)}';
    }
    return '+ R\$ ${amount.toStringAsFixed(2)}';
  }

  /// Retorna o label do tipo de transação
  String get typeLabel {
    switch (type) {
      case PaymentTransactionType.payment:
        return 'Pagamento';
      case PaymentTransactionType.discount:
        return 'Desconto';
    }
  }
}
