import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobx/mobx.dart';
import 'package:praticos/global.dart';
import 'package:praticos/models/invite.dart';
import 'package:praticos/models/membership.dart';
import 'package:praticos/models/user_role.dart';
import 'package:praticos/repositories/invite_repository.dart';
import 'package:praticos/repositories/user_repository.dart';
import 'package:praticos/services/claims_service.dart';

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
  final UserRepository _userRepository = UserRepository();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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
      pendingInvites.addAll(allInvites);
    } catch (e) {
      errorMessage = e.toString();
      print('[InviteStore] Error loading pending invites: $e');
    } finally {
      isLoading = false;
    }
  }

  /// Aceita um convite e adiciona o usuário como membro da empresa.
  @action
  Future<void> acceptInvite(Invite invite) async {
    if (Global.currentUser == null) return;

    isLoading = true;
    errorMessage = null;

    try {
      final userId = Global.currentUser!.uid;
      final companyId = invite.company?.id;
      final role = invite.role ?? RolesType.technician;

      if (companyId == null) {
        throw Exception('Convite inválido: empresa não encontrada.');
      }

      // 1. Busca o usuário atual
      final user = await _userRepository.findUserById(userId);
      if (user == null) {
        throw Exception('Usuário não encontrado.');
      }

      // 2. Verifica se já é membro
      final alreadyMember = user.companies?.any(
        (c) => c.company?.id == companyId
      ) ?? false;
      if (alreadyMember) {
        // Se já é membro, apenas atualiza status do convite (usa token como ID)
        await _inviteRepository.updateStatus(invite.token!, InviteStatus.accepted);
        await loadPendingInvites();
        return;
      }

      // 3. Usa batch para garantir atomicidade
      final batch = _db.batch();

      // 3a. Atualiza user.companies
      final userRef = _db.collection('users').doc(userId);
      final newCompanyRole = CompanyRoleAggr()
        ..company = invite.company
        ..role = role;

      user.companies ??= [];
      user.companies!.add(newCompanyRole);
      batch.update(userRef, {'companies': user.companies!.map((c) => c.toJson()).toList()});

      // 3b. Cria membership
      final membershipRef = _db
          .collection('companies')
          .doc(companyId)
          .collection('memberships')
          .doc(userId);

      final membership = Membership(
        userId: userId,
        user: user.toAggr(),
        role: role,
      );
      batch.set(membershipRef, membership.toFirestore());

      // 3c. Atualiza status do convite (path: /links/invites/tokens/{token})
      final inviteRef = _db.collection('links').doc('invites').collection('tokens').doc(invite.token);
      batch.update(inviteRef, {
        'status': InviteStatus.accepted.name,
        'acceptedAt': FieldValue.serverTimestamp(),
        'acceptedByUserId': userId,
      });

      // 4. Commit atômico
      await batch.commit();

      // 5. Wait for Cloud Function to update custom claims
      // This prevents "permission denied" errors on first access
      await ClaimsService.instance.waitForCompanyClaim(companyId);

      // 6. Recarrega convites
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
