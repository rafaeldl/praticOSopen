import 'package:json_annotation/json_annotation.dart';

enum PaymentMethod {
  @JsonValue('pix')
  pix,
  @JsonValue('cash')
  cash,
  @JsonValue('creditCard')
  creditCard,
  @JsonValue('debitCard')
  debitCard,
  @JsonValue('transfer')
  transfer,
  @JsonValue('check')
  check,
  @JsonValue('other')
  other,
}
