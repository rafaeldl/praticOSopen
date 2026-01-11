import 'package:praticos/models/company.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/models/user_role.dart';
import 'package:json_annotation/json_annotation.dart';

part 'invite.g.dart';

enum InviteStatus { pending, accepted, rejected }

/// Modelo de convite para colaborador.
///
/// Usado quando um admin convida alguém por email e esse
/// alguém ainda não é usuário do sistema.
@JsonSerializable(explicitToJson: true)
class Invite {
  String? id;
  String? email;
  CompanyAggr? company;
  @JsonKey(unknownEnumValue: RolesType.technician)
  RolesType? role;
  UserAggr? invitedBy;
  DateTime? createdAt;
  InviteStatus? status;

  Invite();

  factory Invite.fromJson(Map<String, dynamic> json) => _$InviteFromJson(json);
  Map<String, dynamic> toJson() => _$InviteToJson(this);
}
