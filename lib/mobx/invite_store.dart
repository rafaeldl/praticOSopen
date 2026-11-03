import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:mobx/mobx.dart';
import 'package:praticos/global.dart';
import 'package:praticos/models/invite.dart';
import 'package:praticos/repositories/invite_repository.dart';
import 'package:praticos/services/claims_service.dart';
import 'package:praticos/services/analytics_service.dart';
import 'package:praticos/services/invite_api_service.dart';

part 'invite_store.g.dart';

/// Pending, unexpired invites for [email] and [phone], without repeats.
///
/// A failure of the phone query keeps the e-mail invites: the Firestore rules
/// only let the recipient read by verified e-mail, so an account with a linked
/// phone is denied there.
@visibleForTesting
Future<List<Invite>> collectPendingInvites({
  required String? email,
  required String? phone,
  required Future<List<Invite>> Function(String email) byEmail,
  required Future<List<Invite>> Function(String phone) byPhone,
}) async {
  final found = <Invite>[
    if (email != null && email.isNotEmpty) ...await byEmail(email),
  ];
  if (phone != null && phone.isNotEmpty) {
    try {
      found.addAll(await byPhone(phone));
    } catch (e) {
      debugPrint('[InviteStore] phone invites unavailable: $e');
    }
  }

  final seenTokens = <String>{};
  return found
      .where((i) => i.token != null && seenTokens.add(i.token!))
      .where((i) => !i.isExpired)
      .toList();
}

/// Store para gerenciamento de convites recebidos pelo usuário.
///
/// Usado para:
/// - Listar convites pendentes para o usuário atual
/// - Aceitar/rejeitar convites de empresas
class InviteStore extends _InviteStore with _$InviteStore {
  static final InviteStore _instance = InviteStore._internal();
  static InviteStore get instance => _instance;

  InviteStore._internal();
  factory InviteStore() => _instance;
}

abstract class _InviteStore with Store {
  final InviteRepository _inviteRepository = InviteRepository();

  @observable
  ObservableList<Invite> pendingInvites = ObservableList<Invite>();

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  /// Carrega os convites pendentes para o email e/ou telefone do usuário atual.
  @action
  Future<void> loadPendingInvites() async {
    // Usa FirebaseAuth diretamente para evitar race condition com Global.currentUser
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    isLoading = true;
    errorMessage = null;

    try {
      final allInvites = await collectPendingInvites(
        email: currentUser.email,
        phone: currentUser.phoneNumber?.replaceAll(RegExp(r'\D'), ''),
        byEmail: _inviteRepository.getPendingByEmail,
        byPhone: _inviteRepository.getPendingByPhone,
      );

      pendingInvites.clear();
      pendingInvites.addAll(allInvites);
    } catch (e) {
      errorMessage = e.toString();
      print('[InviteStore] Error loading pending invites: $e');
    } finally {
      isLoading = false;
    }
  }

  /// Aceita um convite via API e aguarda claims serem atualizados.
  @action
  Future<void> acceptInvite(Invite invite) async {
    if (Global.currentUser == null) return;

    isLoading = true;
    errorMessage = null;

    try {
      final companyId = invite.company?.id;

      if (companyId == null) {
        throw Exception('invalidInviteCompanyNotFound');
      }

      // 1. Aceita via API (Admin SDK cuida de user.companies + membership + invite status)
      await InviteApiService.instance.acceptInvite(invite.token!);

      // 2. Wait for Cloud Function to update custom claims
      await ClaimsService.instance.waitForCompanyClaim(companyId);

      AnalyticsService.instance.logInviteAccepted(companyId: companyId);

      // 3. Recarrega convites
      await loadPendingInvites();

    } catch (e) {
      errorMessage = e.toString();
      rethrow;
    } finally {
      isLoading = false;
    }
  }

  /// Rejeita um convite.
  @action
  Future<void> rejectInvite(Invite invite) async {
    isLoading = true;
    errorMessage = null;

    try {
      // Usa token como ID do documento
      await _inviteRepository.updateStatus(invite.token!, InviteStatus.rejected);
      await loadPendingInvites();
    } catch (e) {
      errorMessage = e.toString();
      rethrow;
    } finally {
      isLoading = false;
    }
  }

  /// Verifica se o usuário tem convites pendentes.
  @computed
  bool get hasPendingInvites => pendingInvites.isNotEmpty;
}
