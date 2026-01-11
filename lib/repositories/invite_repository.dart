import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:praticos/models/invite.dart';

/// Repository para convites de colaboradores.
///
/// Path: `/invites/{inviteId}`
///
/// Convites são armazenados em uma collection global para que
/// possam ser buscados pelo email quando o usuário se registrar.
class InviteRepository {
  static const String collectionName = 'invites';
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Valid role values that can be stored in Firestore.
  static const Set<String> _validRoles = {
    'admin',
    'supervisor',
    'manager',
    'consultant',
    'technician',
  };

  CollectionReference<Map<String, dynamic>> get _collection {
    return _db.collection(collectionName);
  }

  // ═══════════════════════════════════════════════════════════════════
  // Read Operations
  // ═══════════════════════════════════════════════════════════════════

  /// Busca um invite pelo ID.
  Future<Invite?> getById(String id) async {
    final doc = await _collection.doc(id).get();
    if (!doc.exists) return null;
    return _fromDoc(doc);
  }

  /// Busca todos os invites pendentes para um email.
  Future<List<Invite>> getPendingByEmail(String email) async {
    final snapshot = await _collection
        .where('email', isEqualTo: email.toLowerCase())
        .where('status', isEqualTo: InviteStatus.pending.name)
        .get();

    return snapshot.docs.map((doc) => _fromDoc(doc)).toList();
  }

  /// Stream de invites pendentes para um email.
  Stream<List<Invite>> streamPendingByEmail(String email) {
    return _collection
        .where('email', isEqualTo: email.toLowerCase())
        .where('status', isEqualTo: InviteStatus.pending.name)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => _fromDoc(doc)).toList());
  }

  /// Lista invites de uma empresa (pendentes).
  Future<List<Invite>> getPendingByCompany(String companyId) async {
    final snapshot = await _collection
        .where('company.id', isEqualTo: companyId)
        .where('status', isEqualTo: InviteStatus.pending.name)
        .get();

    return snapshot.docs.map((doc) => _fromDoc(doc)).toList();
  }

  /// Verifica se já existe um invite pendente para este email nesta empresa.
  Future<bool> existsPendingInvite(String email, String companyId) async {
    final snapshot = await _collection
        .where('email', isEqualTo: email.toLowerCase())
        .where('company.id', isEqualTo: companyId)
        .where('status', isEqualTo: InviteStatus.pending.name)
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  // ═══════════════════════════════════════════════════════════════════
  // Write Operations
  // ═══════════════════════════════════════════════════════════════════

  /// Cria um novo invite.
  Future<Invite> create(Invite invite) async {
    invite.email = invite.email?.toLowerCase();
    invite.createdAt = DateTime.now();
    invite.status = InviteStatus.pending;

    final docRef = await _collection.add(invite.toJson());
    invite.id = docRef.id;

    return invite;
  }

  /// Atualiza o status de um invite.
  Future<void> updateStatus(String id, InviteStatus status) {
    return _collection.doc(id).update({'status': status.name});
  }

  /// Remove um invite.
  Future<void> delete(String id) {
    return _collection.doc(id).delete();
  }

  // ═══════════════════════════════════════════════════════════════════
  // Helper Methods
  // ═══════════════════════════════════════════════════════════════════

  Invite _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;

    // Normalize invalid role values to 'technician'
    final role = data['role'];
    final normalizedData = (role == null || !_validRoles.contains(role))
        ? {...data, 'role': 'technician'}
        : data;

    if (role != null && !_validRoles.contains(role)) {
      print('[InviteRepository] Invalid role "$role" found, falling back to technician');
    }

    final invite = Invite.fromJson(normalizedData);
    invite.id = doc.id;

    // Handle Firestore Timestamp
    if (data['createdAt'] is Timestamp) {
      invite.createdAt = (data['createdAt'] as Timestamp).toDate();
    }

    return invite;
  }
}
