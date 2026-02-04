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
import 'package:praticos/services/invite_api_service.dart';

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
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  // Note: InviteApiService is used instead of InviteRepository for API-based operations

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

  /// Verifica se o usuário atual pode gerenciar colaboradores (apenas admin).
  /// Conforme RBAC: apenas admin possui PermissionType.manageUsers.
  bool canManageCollaborators() {
    if (Global.currentUser == null || Global.companyAggr?.id == null) {
      return false;
    }

    final myMembership = collaborators.cast<Membership?>().firstWhere(
      (m) => m?.userId == Global.currentUser!.uid,
      orElse: () => null,
    );

    return myMembership?.role == RolesType.admin;
  }

  /// Conta quantos administradores existem na empresa.
  int getAdminCount() {
    return collaborators.where((m) => m.role == RolesType.admin).length;
  }

  /// Verifica se um usuário é o único admin da empresa.
  bool isOnlyAdmin(String userId) {
    final membership = collaborators.cast<Membership?>().firstWhere(
      (m) => m?.userId == userId,
      orElse: () => null,
    );

    if (membership?.role != RolesType.admin) return false;
    return getAdminCount() == 1;
  }

  /// Verifica se a operação deixaria a empresa sem admin.
  /// Retorna mensagem de erro ou null se a operação é permitida.
  String? validateAdminRequirement(String userId, {RolesType? newRole, bool isRemoval = false}) {
    final membership = collaborators.cast<Membership?>().firstWhere(
      (m) => m?.userId == userId,
      orElse: () => null,
    );

    // Se não é admin, não há problema
    if (membership?.role != RolesType.admin) return null;

    // Se é o único admin
    if (getAdminCount() == 1) {
      if (isRemoval) {
        return 'Não é possível remover o único administrador da empresa. '
            'Promova outro colaborador a administrador antes de remover este.';
      }
      if (newRole != null && newRole != RolesType.admin) {
        return 'Não é possível alterar o perfil do único administrador. '
            'Promova outro colaborador a administrador antes de alterar este.';
      }
    }

    return null;
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

  /// Carrega os convites pendentes da empresa atual diretamente do Firestore.
  @action
  Future<void> loadPendingInvites() async {
    if (Global.companyAggr?.id == null) return;

    try {
      final inviteRepo = InviteRepository();
      final invites = await inviteRepo.getPendingByCompany(Global.companyAggr!.id!);

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
  /// 1. Cria um convite pendente na collection `/links/invites/{token}`
  /// 2. Quando o usuário se registrar, verá o convite para aceitar
  ///
  /// Retorna uma tupla (wasAddedDirectly, inviteToken):
  /// - `wasAddedDirectly`: true se foi adicionado diretamente, false se foi criado convite
  /// - `inviteToken`: o token do convite criado (null se adicionado diretamente)
  @action
  Future<(bool wasAdded, String? token)> addCollaborator(
    String? name,
    String? email,
    String? phone,
    RolesType roleType,
  ) async {
    print('[CollaboratorStore] addCollaborator called - name: $name, email: $email, phone: $phone, role: ${roleType.name}');

    if (Global.companyAggr?.id == null) {
      print('[CollaboratorStore] Error: companyAggr is null');
      return (false, null);
    }

    isLoading = true;
    try {
      final companyId = Global.companyAggr!.id!;
      final normalizedEmail = email?.toLowerCase().trim();
      final normalizedPhone = phone?.replaceAll(RegExp(r'\D'), '').trim();
      print('[CollaboratorStore] Normalized - email: $normalizedEmail, phone: $normalizedPhone');

      // 1. Busca o usuário pelo email ou telefone
      dynamic user;
      try {
        if (normalizedEmail != null && normalizedEmail.isNotEmpty) {
          print('[CollaboratorStore] Searching user by email: $normalizedEmail');
          user = await _userRepository.findUserByEmail(normalizedEmail);
        }
        if (user == null && normalizedPhone != null && normalizedPhone.isNotEmpty) {
          print('[CollaboratorStore] Searching user by phone: $normalizedPhone');
          user = await _userRepository.findUserByPhone(normalizedPhone);
        }
        print('[CollaboratorStore] User search result: ${user?.id ?? 'not found'}');
      } catch (e) {
        print('[CollaboratorStore] Error searching user: $e');
        // Se falhar a busca, assume que usuário não existe e cria convite
        user = null;
      }

      // Se o usuário não existe, cria um convite
      if (user == null) {
        print('[CollaboratorStore] User not found, creating invite...');
        final inviteToken = await _createInvite(
          name,
          normalizedEmail,
          normalizedPhone,
          roleType,
        );
        print('[CollaboratorStore] Invite created with token: $inviteToken');
        return (false, inviteToken);
      }

      print('[CollaboratorStore] User found: ${user.id}');

      // 2. Verifica se o usuário já está na empresa
      final existingCompanyIndex = user.companies?.indexWhere(
        (c) => c.company?.id == companyId
      ) ?? -1;
      final alreadyInCompanies = existingCompanyIndex >= 0;

      // 3. Usa batch para garantir atomicidade
      final batch = _db.batch();

      // 3a. Atualiza user.companies (source of truth)
      final userRef = _db.collection('users').doc(user.id);

      if (alreadyInCompanies) {
        // Já existe - apenas atualiza o role
        user.companies![existingCompanyIndex].role = roleType;
      } else {
        // Não existe - adiciona nova entrada
        final newCompanyRole = CompanyRoleAggr()
          ..company = Global.companyAggr
          ..role = roleType;
        user.companies ??= [];
        user.companies!.add(newCompanyRole);
      }
      batch.update(userRef, {'companies': user.companies!.map((c) => c.toJson()).toList()});

      // 3b. Atualiza ou cria membership (índice reverso)
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

      // Usa set com merge para atualizar se existir ou criar se não existir
      batch.set(membershipRef, membership.toFirestore(), SetOptions(merge: true));

      // 4. Commit atômico
      await batch.commit();

      return (true, null); // Adicionado diretamente

    } catch (e) {
      errorMessage = e.toString();
      rethrow;
    } finally {
      isLoading = false;
      // Sempre recarrega a lista, mesmo em caso de erro
      await loadCollaborators();
    }
  }

  /// Cria um convite para um email/telefone que ainda não é usuário do sistema.
  /// Usa a API (Admin SDK) para evitar problemas de permissão do Firestore.
  /// Retorna o token do convite criado.
  Future<String> _createInvite(
    String? name,
    String? email,
    String? phone,
    RolesType roleType,
  ) async {
    print('[CollaboratorStore] Creating invite via API - name: $name, email: $email, phone: $phone, role: ${roleType.name}');

    try {
      final result = await InviteApiService.instance.createInvite(
        name: name,
        email: email,
        phone: phone,
        role: roleType.name,
      );

      print('[CollaboratorStore] Invite created via API - token: ${result.token}');

      // Recarrega lista de convites
      await loadPendingInvites();

      return result.token;
    } on InviteApiException catch (e) {
      print('[CollaboratorStore] API error: ${e.message}');
      throw Exception(e.message);
    }
  }

  /// Cancela um convite pendente via API.
  @action
  Future<void> cancelInvite(String inviteToken) async {
    isLoading = true;
    try {
      await InviteApiService.instance.cancelInvite(inviteToken);
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
  /// Não permite alterar o perfil do único administrador para outro perfil.
  @action
  Future<void> updateCollaboratorRole(String userId, RolesType newRoleType) async {
    if (Global.companyAggr?.id == null) return;

    // Valida se a operação deixaria a empresa sem admin
    final validationError = validateAdminRequirement(userId, newRole: newRoleType);
    if (validationError != null) {
      throw Exception(validationError);
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
  /// Não permite remover o único administrador da empresa.
  @action
  Future<void> removeCollaborator(String userId) async {
    if (Global.companyAggr?.id == null) return;

    // Não permite remover a si mesmo
    if (userId == Global.currentUser?.uid) {
      throw Exception('Você não pode remover a si mesmo da empresa.');
    }

    // Valida se a operação deixaria a empresa sem admin
    final validationError = validateAdminRequirement(userId, isRemoval: true);
    if (validationError != null) {
      throw Exception(validationError);
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
