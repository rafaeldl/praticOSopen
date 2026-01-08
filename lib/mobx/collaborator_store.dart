import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:mobx/mobx.dart';
import 'package:praticos/global.dart';
import 'package:praticos/models/invite.dart';
import 'package:praticos/models/membership.dart';
import 'package:praticos/models/user_role.dart';
import 'package:praticos/repositories/invite_repository.dart';
import 'package:praticos/repositories/tenant/tenant_membership_repository.dart';
import 'package:praticos/repositories/user_repository.dart';

part 'collaborator_store.g.dart';

/// Store para gerenciamento de colaboradores da empresa.
///
/// Arquitetura:
/// - Source of Truth: `user.companies` (alimenta os Claims)
/// - Índice Reverso: `/companies/{companyId}/memberships/{userId}`
///
/// Use [CollaboratorStore.instance] para acessar a instância singleton.
class CollaboratorStore extends _CollaboratorStore with _$CollaboratorStore {
  static final CollaboratorStore _instance = CollaboratorStore._internal();
  static CollaboratorStore get instance => _instance;

  CollaboratorStore._internal();
  factory CollaboratorStore() => _instance;
}

abstract class _CollaboratorStore with Store {
  final TenantMembershipRepository _membershipRepo = TenantMembershipRepository();
  final UserRepository _userRepository = UserRepository();
  final InviteRepository _inviteRepository = InviteRepository();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @observable
  ObservableList<Membership> collaborators = ObservableList<Membership>();

  @observable
  ObservableList<Invite> pendingInvites = ObservableList<Invite>();

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  // ═══════════════════════════════════════════════════════════════════
  // Helper Methods
  // ═══════════════════════════════════════════════════════════════════

  /// Força refresh do token do usuário atual para atualizar claims.
  Future<void> _refreshCurrentUserToken() async {
    try {
      await auth.FirebaseAuth.instance.currentUser?.getIdToken(true);
    } catch (e) {
      print('[CollaboratorStore] Erro ao refresh token: $e');
    }
  }

  /// Verifica se o usuário atual é admin da empresa atual.
  bool isCurrentUserAdmin() {
    if (Global.currentUser == null || Global.companyAggr?.id == null) {
      return false;
    }

    final myMembership = collaborators.cast<Membership?>().firstWhere(
      (m) => m?.userId == Global.currentUser!.uid,
      orElse: () => null,
    );

    return myMembership?.role == RolesType.admin;
  }

  /// Verifica se o usuário atual pode gerenciar colaboradores (admin ou manager).
  bool canManageCollaborators() {
    if (Global.currentUser == null || Global.companyAggr?.id == null) {
      return false;
    }

    final myMembership = collaborators.cast<Membership?>().firstWhere(
      (m) => m?.userId == Global.currentUser!.uid,
      orElse: () => null,
    );

    if (myMembership != null) {
      return myMembership.role == RolesType.admin ||
          myMembership.role == RolesType.manager;
    }

    return false;
  }

  // ═══════════════════════════════════════════════════════════════════
  // Load Operations
  // ═══════════════════════════════════════════════════════════════════

  /// Carrega a lista de colaboradores da empresa atual.
  /// Lê do índice reverso `/companies/{companyId}/memberships`.
  @action
  Future<void> loadCollaborators() async {
    if (Global.companyAggr?.id == null) return;

    isLoading = true;
    errorMessage = null;

    try {
      final memberships = await _membershipRepo.listMemberships(
        Global.companyAggr!.id!,
      );

      collaborators.clear();
      collaborators.addAll(memberships);

      // Também carrega os convites pendentes
      await loadPendingInvites();
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
    }
  }

  /// Carrega os convites pendentes da empresa atual.
  @action
  Future<void> loadPendingInvites() async {
    if (Global.companyAggr?.id == null) return;

    try {
      final invites = await _inviteRepository.getPendingByCompany(
        Global.companyAggr!.id!,
      );

      pendingInvites.clear();
      pendingInvites.addAll(invites);
    } catch (e) {
      print('[CollaboratorStore] Erro ao carregar convites: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // Write Operations
  // ═══════════════════════════════════════════════════════════════════

  /// Adiciona um colaborador à empresa.
  ///
  /// Se o usuário já existir no sistema:
  /// 1. Verifica se já é membro (em memberships e user.companies)
  /// 2. Se não for, cria os vínculos necessários (atualiza user.companies e cria membership)
  /// 3. Se houver inconsistência, corrige automaticamente
  ///
  /// Se o usuário não existir:
  /// 1. Cria um convite pendente na collection `/invites`
  /// 2. Quando o usuário se registrar, verá o convite para aceitar
  ///
  /// Retorna `true` se foi adicionado diretamente, `false` se foi criado convite.
  @action
  Future<bool> addCollaborator(String email, RolesType roleType) async {
    if (Global.companyAggr?.id == null) return false;

    isLoading = true;
    try {
      final companyId = Global.companyAggr!.id!;
      final normalizedEmail = email.toLowerCase().trim();

      // 1. Busca o usuário pelo email
      final user = await _userRepository.findUserByEmail(normalizedEmail);

      // Se o usuário não existe, cria um convite
      if (user == null) {
        return await _createInvite(normalizedEmail, roleType);
      }

      // 2. Verifica se já está em ambos os lugares
      final isMemberInMemberships = await _membershipRepo.isMember(companyId, user.id!);
      final alreadyInCompanies = user.companies?.any(
        (c) => c.company?.id == companyId
      ) ?? false;

      // Se está em ambos os lugares, já é colaborador
      if (isMemberInMemberships && alreadyInCompanies) {
        throw Exception('Usuário já é colaborador desta empresa.');
      }

      // 3. Se há inconsistência ou não é membro, corrige e adiciona
      // Usa batch para garantir atomicidade
      final batch = _db.batch();

      // 3a. Atualiza user.companies se não existir (source of truth)
      if (!alreadyInCompanies) {
        final userRef = _db.collection('users').doc(user.id);
        final newCompanyRole = CompanyRoleAggr()
          ..company = Global.companyAggr
          ..role = roleType;

        user.companies ??= [];
        user.companies!.add(newCompanyRole);
        batch.update(userRef, {'companies': user.companies!.map((c) => c.toJson()).toList()});
      }

      // 3b. Cria membership (índice reverso) se não existir
      if (!isMemberInMemberships) {
        final membershipRef = _db
            .collection('companies')
            .doc(companyId)
            .collection('memberships')
            .doc(user.id);

        final membership = Membership(
          userId: user.id!,
          user: user.toAggr(),
          role: roleType,
        );
        batch.set(membershipRef, membership.toFirestore());
      }

      // 4. Commit atômico (mesmo que ambos já existam, não faz mal)
      await batch.commit();

      return true; // Adicionado diretamente

    } catch (e) {
      errorMessage = e.toString();
      rethrow;
    } finally {
      isLoading = false;
      // Sempre recarrega a lista, mesmo em caso de erro
      await loadCollaborators();
    }
  }

  /// Cria um convite para um email que ainda não é usuário do sistema.
  Future<bool> _createInvite(String email, RolesType roleType) async {
    final companyId = Global.companyAggr!.id!;

    // Verifica se já existe um convite pendente para este email nesta empresa
    final existingInvite = await _inviteRepository.existsPendingInvite(
      email,
      companyId,
    );
    if (existingInvite) {
      throw Exception('Já existe um convite pendente para este email.');
    }

    // Cria o convite
    final invite = Invite()
      ..email = email
      ..company = Global.companyAggr
      ..role = roleType
      ..invitedBy = Global.userAggr;

    await _inviteRepository.create(invite);

    // Recarrega lista de convites
    await loadPendingInvites();

    return false; // Convite criado (não adicionado diretamente)
  }

  /// Cancela um convite pendente.
  @action
  Future<void> cancelInvite(String inviteId) async {
    isLoading = true;
    try {
      await _inviteRepository.delete(inviteId);
      await loadPendingInvites();
    } catch (e) {
      errorMessage = e.toString();
      rethrow;
    } finally {
      isLoading = false;
    }
  }

  /// Atualiza a role de um colaborador.
  ///
  /// Atualiza em ambos os lugares atomicamente.
  @action
  Future<void> updateCollaboratorRole(String userId, RolesType newRoleType) async {
    if (Global.companyAggr?.id == null) return;

    isLoading = true;
    try {
      final companyId = Global.companyAggr!.id!;

      // 1. Busca o usuário
      final user = await _userRepository.findUserById(userId);
      if (user == null) {
        throw Exception('Usuário não encontrado.');
      }

      // 2. Usa batch para garantir atomicidade
      final batch = _db.batch();

      // 2a. Atualiza user.companies
      final userRef = _db.collection('users').doc(userId);
      final companyRole = user.companies?.firstWhere(
        (c) => c.company?.id == companyId,
        orElse: () => CompanyRoleAggr(),
      );

      if (companyRole != null && companyRole.company != null) {
        companyRole.role = newRoleType;
        batch.update(userRef, {'companies': user.companies!.map((c) => c.toJson()).toList()});
      }

      // 2b. Atualiza membership
      final membershipRef = _db
          .collection('companies')
          .doc(companyId)
          .collection('memberships')
          .doc(userId);
      batch.update(membershipRef, {'role': newRoleType.name});

      // 3. Commit atômico
      await batch.commit();

      // 4. Se o usuário afetado for o atual, força refresh do token
      if (userId == Global.currentUser?.uid) {
        await _refreshCurrentUserToken();
      }

      // 5. Recarrega lista
      await loadCollaborators();

    } catch (e) {
      errorMessage = e.toString();
      rethrow;
    } finally {
      isLoading = false;
    }
  }

  /// Remove um colaborador da empresa.
  ///
  /// Remove de ambos os lugares atomicamente.
  @action
  Future<void> removeCollaborator(String userId) async {
    if (Global.companyAggr?.id == null) return;

    // Não permite remover a si mesmo
    if (userId == Global.currentUser?.uid) {
      throw Exception('Você não pode remover a si mesmo da empresa.');
    }

    isLoading = true;
    try {
      final companyId = Global.companyAggr!.id!;

      // 1. Busca o usuário
      final user = await _userRepository.findUserById(userId);
      if (user == null) {
        throw Exception('Usuário não encontrado.');
      }

      // 2. Usa batch para garantir atomicidade
      final batch = _db.batch();

      // 2a. Remove de user.companies
      final userRef = _db.collection('users').doc(userId);
      user.companies?.removeWhere((c) => c.company?.id == companyId);
      batch.update(userRef, {'companies': user.companies?.map((c) => c.toJson()).toList() ?? []});

      // 2b. Remove membership
      final membershipRef = _db
          .collection('companies')
          .doc(companyId)
          .collection('memberships')
          .doc(userId);
      batch.delete(membershipRef);

      // 3. Commit atômico
      await batch.commit();

      // 4. Recarrega lista
      await loadCollaborators();

    } catch (e) {
      errorMessage = e.toString();
      rethrow;
    } finally {
      isLoading = false;
    }
  }
}
