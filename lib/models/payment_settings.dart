import 'package:json_annotation/json_annotation.dart';

part 'payment_settings.g.dart';

/// Payment integrations of a company.
///
/// Path: `/companies/{companyId}/settings/payments`. Readable by members,
/// written only by Cloud Functions (connect/disconnect) and the pilot script.
@JsonSerializable()
class PaymentSettings {
  /// Pilot flag, turned on per company by script.
  @JsonKey(defaultValue: false)
  bool asaasEnabled;

  /// An Asaas account is connected.
  @JsonKey(defaultValue: false)
  bool asaasConnected;

  String? asaasAccountName;

  /// 'sandbox' | 'production'
  String? asaasEnvironment;

  PaymentSettings({
    this.asaasEnabled = false,
    this.asaasConnected = false,
    this.asaasAccountName,
    this.asaasEnvironment,
  });

  factory PaymentSettings.fromJson(Map<String, dynamic> json) =>
      _$PaymentSettingsFromJson(json);

  Map<String, dynamic> toJson() => _$PaymentSettingsToJson(this);

  bool get isSandbox => asaasEnvironment == 'sandbox';
}
