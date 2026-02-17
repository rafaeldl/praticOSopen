import 'package:praticos/models/company.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/models/user_role.dart';
import 'package:json_annotation/json_annotation.dart';

part 'invite.g.dart';

/// Status do convite.
enum InviteStatus { pending, accepted, rejected, cancelled }

/// Canal de origem do convite.
enum InviteChannel { app, whatsapp }

/// Modelo de convite para colaborador.
///
/// Usado para convidar colaboradores tanto via app quanto via WhatsApp.
/// Armazenado em `/links/invites/{token}` para acesso unificado.
///
/// Fluxo:
/// 1. Admin cria convite (app ou bot) → token INV_XXXXXXXX
/// 2. Compartilha link via WhatsApp, copiar, ou share nativo
/// 3. Destinatário aceita via bot OU via app (cross-channel)
/// 4. Vira membro da empresa
@JsonSerializable(explicitToJson: true)
class Invite {
  /// ID do documento (igual ao token para facilitar lookup).
  String? id;

  /// Token único do convite (INV_XXXXXXXX).
  /// Usado como ID do documento no Firestore.
  String? token;

  /// Nome do convidado (opcional, para identificação).
  String? name;

  /// Email do convidado (opcional se phone fornecido).
  String? email;

  /// Telefone do convidado (opcional se email fornecido).
  String? phone;

  /// Empresa que está convidando.
  CompanyAggr? company;

  /// Perfil de acesso que será concedido.
  @JsonKey(unknownEnumValue: RolesType.technician)
  RolesType? role;

  /// Usuário que criou o convite.
  UserAggr? invitedBy;

  /// Data de criação.
  DateTime? createdAt;

  /// Data de expiração (7 dias por padrão).
  DateTime? expiresAt;

  /// Status atual do convite.
  @JsonKey(unknownEnumValue: InviteStatus.pending)
  InviteStatus? status;

  /// Data em que foi aceito.
  DateTime? acceptedAt;

  /// ID do usuário que aceitou.
  String? acceptedByUserId;

  /// Canal de origem do convite.
  @JsonKey(unknownEnumValue: InviteChannel.app)
  InviteChannel? channel;

  Invite();

  /// Verifica se o convite expirou.
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Verifica se o convite pode ser aceito.
  bool get canBeAccepted {
    return status == InviteStatus.pending && !isExpired;
  }

  /// Gera o link de convite para WhatsApp.
  String getWhatsAppLink(String botNumber) {
    final cleanNumber = botNumber.replaceAll(RegExp(r'\D'), '');
    final message = Uri.encodeComponent(token ?? '');
    return 'https://wa.me/$cleanNumber?text=$message';
  }

  factory Invite.fromJson(Map<String, dynamic> json) => _$InviteFromJson(json);
  Map<String, dynamic> toJson() => _$InviteToJson(this);
}
