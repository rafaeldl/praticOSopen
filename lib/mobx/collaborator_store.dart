import "package:flutter/foundation.dart";
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:mobx/mobx.dart';
import 'package:praticos/global.dart';
import 'package:praticos/models/collaborator_exception.dart';
import 'package:praticos/models/invite.dart';
import 'package:praticos/models/membership.dart';
import 'package:praticos/models/subscription.dart';
import 'package:praticos/models/user_role.dart';
import 'package:praticos/repositories/invite_repository.dart';
import 'package:praticos/repositories/tenant/tenant_membership_repository.dart';
import 'package:praticos/services/analytics_service.dart';
import 'package:praticos/services/feature_gate_service.dart';
import 'package:praticos/services/invite_api_service.dart';
import 'package:praticos/services/team_api_service.dart';
import 'package:praticos/utils/invite_utils.dart' as invite_utils;

part 'collaborator_store.g.dart';

/// Store para gerenciamento de colaboradores da empresa.
///
/// Arquitetura:
/// - Leitura: índice `/companies/{companyId}/memberships/{userId}`
/// - Escrita: pelo servidor. Convite em `/v1/app/invites`; troca de papel e
///   remoção em `/v1/app/team` (o app não pode gravar `users/{colega}`, e o
///   servidor atualiza membership, `users/{uid}.companies` e o claim juntos).
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
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Server API for role change and removal (replaceable in tests).
  @visibleForTesting
  TeamApiService teamApi = TeamApiService.instance;

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
      debugPrint('[CollaboratorStore] Erro ao refresh token: $e');
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
  /// Retorna [CollaboratorErrorCode] ou null se a operação é permitida.
  CollaboratorErrorCode? validateAdminRequirement(String userId, {RolesType? newRole, bool isRemoval = false}) {
    final membership = collaborators.cast<Membership?>().firstWhere(
      (m) => m?.userId == userId,
      orElse: () => null,
    );

    // Se não é admin, não há problema
    if (membership?.role != RolesType.admin) return null;

    // Se é o único admin
    if (getAdminCount() == 1) {
      if (isRemoval) {
        return CollaboratorErrorCode.cannotRemoveOnlyAdmin;
      }
      if (newRole != null && newRole != RolesType.admin) {
        return CollaboratorErrorCode.cannotChangeOnlyAdminRole;
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
      pendingInvites.addAll(invites.where((i) => !i.isExpired));
    } catch (e) {
      debugPrint('[CollaboratorStore] Erro ao carregar convites: $e');
    }
  }

  /// Finds an existing pending invite matching the given email or phone.
  Invite? findExistingPendingInvite({String? email, String? phone}) {
    return invite_utils.findExistingPendingInvite(
      pendingInvites.toList(),
      email: email,
      phone: phone,
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Write Operations
  // ═══════════════════════════════════════════════════════════════════

  /// Adiciona um colaborador à empresa por convite (criado no servidor).
  ///
  /// Quem já tem conta vê o convite ao entrar e aceita; o servidor registra o
  /// membership e atualiza `user.companies` e os claims ao aceitar.
  ///
  /// Retorna (wasAddedDirectly, inviteToken). `wasAddedDirectly` é sempre
  /// false: o app não grava `users/{colega}` (as regras não deixam).
  ///
  /// Lança [FeatureGateLimitException] se o limite de colaboradores foi atingido.
  @action
  Future<(bool wasAdded, String? token)> addCollaborator(
    String? name,
    String? email,
    String? phone,
    RolesType roleType, {
    Subscription? subscription,
  }) async {
    if (Global.companyAggr?.id == null) {
      debugPrint('[CollaboratorStore] Error: companyAggr is null');
      return (false, null);
    }

    // Verifica limite de colaboradores antes de adicionar
    final sub = subscription ?? Global.subscription;
    final gateResult = FeatureGateService.canAddCollaborator(sub);
    if (!gateResult.isAllowed) {
      debugPrint('[CollaboratorStore] Limite de colaboradores atingido: ${gateResult.currentUsage}/${gateResult.limit}');
      throw FeatureGateLimitException(gateResult);
    }

    isLoading = true;
    try {
      final normalizedEmail = email?.toLowerCase().trim();
      final normalizedPhone = phone?.replaceAll(RegExp(r'\D'), '').trim();

      final inviteToken = await _createInvite(
        name,
        normalizedEmail,
        normalizedPhone,
        roleType,
      );
      AnalyticsService.instance.logCollaboratorInvited(
        method: 'invite',
        role: roleType.name,
      );
      // Atualiza contador (convite conta como colaborador pendente)
      await _updateCollaboratorCounter();
      return (false, inviteToken);
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
    debugPrint('[CollaboratorStore] Creating invite via API - name: $name, email: $email, phone: $phone, role: ${roleType.name}');

    try {
      final result = await InviteApiService.instance.createInvite(
        name: name,
        email: email,
        phone: phone,
        role: roleType.name,
      );

      debugPrint('[CollaboratorStore] Invite created via API - token: ${result.token}');

      // Recarrega lista de convites
      await loadPendingInvites();

      return result.token;
    } on InviteApiException catch (e) {
      debugPrint('[CollaboratorStore] API error: ${e.message}');
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
      // Atualiza contador após cancelar convite
      await _updateCollaboratorCounter();
    } catch (e) {
      errorMessage = e.toString();
      rethrow;
    } finally {
      isLoading = false;
    }
  }

  /// Atualiza o perfil de um colaborador pelo servidor (`PATCH /v1/app/team`).
  ///
  /// Não permite alterar o perfil do único administrador (checado aqui e no
  /// servidor, que também protege o dono da empresa).
  @action
  Future<void> updateCollaboratorRole(String userId, RolesType newRoleType) async {
    if (Global.companyAggr?.id == null) return;

    // Valida se a operação deixaria a empresa sem admin
    final validationError = validateAdminRequirement(userId, newRole: newRoleType);
    if (validationError != null) {
      throw CollaboratorException(validationError);
    }

    isLoading = true;
    try {
      await teamApi.changeRole(userId, newRoleType);

      // Se o usuário afetado for o atual, força refresh do token
      if (userId == Global.currentUser?.uid) {
        await _refreshCurrentUserToken();
      }

      await loadCollaborators();
    } catch (e) {
      errorMessage = e.toString();
      rethrow;
    } finally {
      isLoading = false;
    }
  }

  /// Remove um colaborador da empresa pelo servidor (`DELETE /v1/app/team`).
  ///
  /// Não permite remover a si mesmo nem o único administrador.
  @action
  Future<void> removeCollaborator(String userId) async {
    if (Global.companyAggr?.id == null) return;

    // Não permite remover a si mesmo
    if (userId == Global.currentUser?.uid) {
      throw CollaboratorException(CollaboratorErrorCode.cannotRemoveSelf);
    }

    // Valida se a operação deixaria a empresa sem admin
    final validationError = validateAdminRequirement(userId, isRemoval: true);
    if (validationError != null) {
      throw CollaboratorException(validationError);
    }

    isLoading = true;
    try {
      await teamApi.removeMember(userId);

      // Atualiza contador de colaboradores
      await _updateCollaboratorCounter();

      await loadCollaborators();
    } catch (e) {
      errorMessage = e.toString();
      rethrow;
    } finally {
      isLoading = false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // Feature Gate Counter
  // ═══════════════════════════════════════════════════════════════════

  /// Atualiza o contador de colaboradores no Firestore e localmente.
  ///
  /// Conta membros ativos + convites pendentes como uso atual.
  /// Falha silenciosa - não bloqueia a operação principal.
  Future<void> _updateCollaboratorCounter() async {
    try {
      if (Global.companyAggr?.id == null) {
        return;
      }

      final companyId = Global.companyAggr!.id!;

      // Conta membros ativos na coleção memberships
      final membershipsSnapshot = await _db
          .collection('companies')
          .doc(companyId)
          .collection('memberships')
          .get();
      final memberCount = membershipsSnapshot.docs.length;

      // Conta convites pendentes
      final pendingCount = pendingInvites.where((i) => !i.isExpired).length;

      // Total: membros + convites pendentes
      final totalCollaborators = memberCount + pendingCount;

      // Atualiza no Firestore
      await _db
          .collection(SubscriptionUsagePaths.collection)
          .doc(companyId)
          .update({
            SubscriptionUsagePaths.usersActive: totalCollaborators,
          });

      // Atualiza localmente
      Global.subscription?.usage.usersActive = totalCollaborators;

      debugPrint('[CollaboratorStore] Contador de colaboradores atualizado: $totalCollaborators (membros: $memberCount, convites: $pendingCount)');
    } catch (e) {
      // Falha silenciosa - não bloqueia a operação principal
      debugPrint('[CollaboratorStore] Erro ao atualizar contador de colaboradores: $e');
    }
  }
}
