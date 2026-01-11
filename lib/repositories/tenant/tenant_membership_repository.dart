import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:praticos/models/membership.dart';
import 'package:praticos/models/user_role.dart';

/// Repository para memberships (índice reverso de colaboradores por empresa).
///
/// Path: `/companies/{companyId}/memberships/{userId}`
///
/// Esta collection serve como índice para listar rapidamente os colaboradores
/// de uma empresa. O source of truth é `user.companies`.
class TenantMembershipRepository {
  static const String collectionName = 'memberships';
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Valid role values that can be stored in Firestore.
  static const Set<String> _validRoles = {
    'admin',
    'supervisor',
    'manager',
    'consultant',
    'technician',
  };

  /// Normalizes role data from Firestore, applying fallback for invalid values.
  /// Returns the original data with role normalized to 'technician' if invalid.
  Map<String, dynamic> _normalizeRoleData(Map<String, dynamic> data) {
    final role = data['role'];
    if (role == null || !_validRoles.contains(role)) {
      // Log para rastrear dados inválidos
      if (role != null) {
        print('[TenantMembershipRepository] Invalid role "$role" found, falling back to technician');
      }
      return {...data, 'role': 'technician'};
    }
    return data;
  }

  /// Retorna a referência da collection de memberships para uma empresa.
  CollectionReference<Map<String, dynamic>> _getCollection(String companyId) {
    return _db.collection('companies').doc(companyId).collection(collectionName);
  }

  // ═══════════════════════════════════════════════════════════════════
  // Read Operations
  // ═══════════════════════════════════════════════════════════════════

  /// Busca membership de um usuário específico.
  Future<Membership?> getMembership(String companyId, String userId) async {
    final doc = await _getCollection(companyId).doc(userId).get();
    if (!doc.exists) return null;
    return Membership.fromFirestore(doc.id, _normalizeRoleData(doc.data()!));
  }

  /// Stream de membership de um usuário específico.
  Stream<Membership?> streamMembership(String companyId, String userId) {
    return _getCollection(companyId).doc(userId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Membership.fromFirestore(doc.id, _normalizeRoleData(doc.data()!));
    });
  }

  /// Lista todos os memberships (colaboradores) de uma empresa.
  Future<List<Membership>> listMemberships(String companyId) async {
    final snapshot = await _getCollection(companyId).get();
    return snapshot.docs
        .map((doc) => Membership.fromFirestore(doc.id, _normalizeRoleData(doc.data())))
        .toList();
  }

  /// Stream de todos os memberships de uma empresa.
  Stream<List<Membership>> streamMemberships(String companyId) {
    return _getCollection(companyId).snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Membership.fromFirestore(doc.id, _normalizeRoleData(doc.data())))
          .toList();
    });
  }

  /// Lista memberships por role.
  Future<List<Membership>> listByRole(String companyId, RolesType role) async {
    final snapshot = await _getCollection(companyId)
        .where('role', isEqualTo: role.name)
        .get();
    return snapshot.docs
        .map((doc) => Membership.fromFirestore(doc.id, _normalizeRoleData(doc.data())))
        .toList();
  }

  // ═══════════════════════════════════════════════════════════════════
  // Write Operations
  // ═══════════════════════════════════════════════════════════════════

  /// Cria ou atualiza membership.
  /// O ID do documento é o userId para garantir unicidade.
  Future<void> setMembership(
    String companyId,
    String userId,
    Membership membership,
  ) {
    return _getCollection(companyId).doc(userId).set(membership.toFirestore());
  }

  /// Atualiza apenas a role de um membership.
  Future<void> updateRole(String companyId, String userId, RolesType role) {
    return _getCollection(companyId).doc(userId).update({
      'role': role.name,
    });
  }

  /// Remove membership.
  Future<void> removeMembership(String companyId, String userId) {
    return _getCollection(companyId).doc(userId).delete();
  }

  // ═══════════════════════════════════════════════════════════════════
  // Utility Methods
  // ═══════════════════════════════════════════════════════════════════

  /// Verifica se um usuário é membro da empresa.
  Future<bool> isMember(String companyId, String userId) async {
    final doc = await _getCollection(companyId).doc(userId).get();
    return doc.exists;
  }

  /// Verifica se um usuário é admin da empresa.
  Future<bool> isAdmin(String companyId, String userId) async {
    final membership = await getMembership(companyId, userId);
    return membership?.role == RolesType.admin;
  }
}
