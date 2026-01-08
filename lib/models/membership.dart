import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/models/user_role.dart';

part 'membership.g.dart';

/// Conversor customizado para Timestamp do Firestore
class TimestampConverter implements JsonConverter<DateTime?, dynamic> {
  const TimestampConverter();

  @override
  DateTime? fromJson(dynamic json) {
    if (json == null) return null;
    if (json is Timestamp) return json.toDate();
    if (json is String) return DateTime.parse(json);
    return null;
  }

  @override
  dynamic toJson(DateTime? date) {
    if (date == null) return FieldValue.serverTimestamp();
    return Timestamp.fromDate(date);
  }
}

/// Modelo para membership (índice reverso de colaboradores por empresa).
///
/// Path: `/companies/{companyId}/memberships/{userId}`
///
/// Esta collection serve como índice para listar rapidamente os colaboradores
/// de uma empresa. O source of truth é `user.companies`.
@JsonSerializable(explicitToJson: true)
class Membership {
  /// ID do usuário (também é o ID do documento)
  @JsonKey(includeFromJson: false, includeToJson: false)
  String? userId;

  /// Dados resumidos do usuário
  UserAggr? user;

  /// Papel do usuário na empresa
  RolesType? role;

  /// Data de entrada na empresa
  @TimestampConverter()
  DateTime? joinedAt;

  Membership({
    this.userId,
    this.user,
    this.role,
    this.joinedAt,
  });

  factory Membership.fromJson(Map<String, dynamic> json) =>
      _$MembershipFromJson(json);

  Map<String, dynamic> toJson() => _$MembershipToJson(this);

  /// Factory para criar a partir de documento do Firestore
  factory Membership.fromFirestore(String odId, Map<String, dynamic> json) {
    final membership = Membership.fromJson(json);
    membership.userId = odId;
    return membership;
  }

  /// Converte para Map incluindo FieldValue.serverTimestamp() para joinedAt
  Map<String, dynamic> toFirestore() {
    return {
      'user': user?.toJson(),
      'role': role?.name,
      'joinedAt': joinedAt != null
          ? Timestamp.fromDate(joinedAt!)
          : FieldValue.serverTimestamp(),
    };
  }
}
