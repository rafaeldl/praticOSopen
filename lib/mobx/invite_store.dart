import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobx/mobx.dart';
import 'package:praticos/global.dart';
import 'package:praticos/models/invite.dart';
import 'package:praticos/repositories/invite_repository.dart';
import 'package:praticos/services/claims_service.dart';
import 'package:praticos/services/invite_api_service.dart';

part 'invite_store.g.dart';

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
      final email = currentUser.email;
      final phone = currentUser.phoneNumber?.replaceAll(RegExp(r'\D'), '');

      final Set<String> seenTokens = {};
      final List<Invite> allInvites = [];

      // Busca por email
      if (email != null && email.isNotEmpty) {
        final emailInvites = await _inviteRepository.getPendingByEmail(email);
        for (final invite in emailInvites) {
          if (invite.token != null && !seenTokens.contains(invite.token)) {
            seenTokens.add(invite.token!);
            allInvites.add(invite);
          }
        }
      }

      // Busca por telefone
      if (phone != null && phone.isNotEmpty) {
        final phoneInvites = await _inviteRepository.getPendingByPhone(phone);
        for (final invite in phoneInvites) {
          if (invite.token != null && !seenTokens.contains(invite.token)) {
            seenTokens.add(invite.token!);
            allInvites.add(invite);
          }
        }
      }

      pendingInvites.clear();
      pendingInvites.addAll(allInvites.where((i) => !i.isExpired));
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
