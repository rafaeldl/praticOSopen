import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:praticos/models/invite.dart';

/// Repository for collaborator invites.
///
/// Path: `/links/invites/{token}`
///
/// Invites are stored in a unified path under /links for easy lookup
/// by token when users access invite links from any channel.
class InviteRepository {
  /// Default expiration time for invites (7 days).
  static const int defaultExpirationDays = 7;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Valid role values that can be stored in Firestore.
  static const Set<String> _validRoles = {
    'admin',
    'supervisor',
    'manager',
    'consultant',
    'technician',
  };

  /// Collection path: /links/invites/tokens/{token}
  CollectionReference<Map<String, dynamic>> get _collection {
    return _db.collection('links').doc('invites').collection('tokens');
  }

  // ═══════════════════════════════════════════════════════════════════
  // Token Generation
  // ═══════════════════════════════════════════════════════════════════

  /// Generates a unique token in format INV_XXXXXXXX.
  /// Uses alphanumeric characters (uppercase letters and digits).
  String generateToken() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    final code = List.generate(8, (_) => chars[random.nextInt(chars.length)]).join();
    return 'INV_$code';
  }

  /// Generates a unique token ensuring it doesn't exist in Firestore.
  Future<String> generateUniqueToken() async {
    String token;
    bool exists;

    do {
      token = generateToken();
      final doc = await _collection.doc(token).get();
      exists = doc.exists;
    } while (exists);

    return token;
  }

  // ═══════════════════════════════════════════════════════════════════
  // Read Operations
  // ═══════════════════════════════════════════════════════════════════

  /// Gets an invite by its ID (which equals the token).
  Future<Invite?> getById(String id) async {
    final doc = await _collection.doc(id).get();
    if (!doc.exists) return null;
    return _fromDoc(doc);
  }

  /// Gets an invite by its token.
  /// This is the primary lookup method for invite links.
  Future<Invite?> getByToken(String token) async {
    final doc = await _collection.doc(token).get();
    if (!doc.exists) return null;
    return _fromDoc(doc);
  }

  /// Gets all pending invites for an email.
  Future<List<Invite>> getPendingByEmail(String email) async {
    final snapshot = await _collection
        .where('email', isEqualTo: email.toLowerCase())
        .where('status', isEqualTo: InviteStatus.pending.name)
        .get();

    return snapshot.docs.map((doc) => _fromDoc(doc)).toList();
  }

  /// Stream of pending invites for an email.
  Stream<List<Invite>> streamPendingByEmail(String email) {
    return _collection
        .where('email', isEqualTo: email.toLowerCase())
        .where('status', isEqualTo: InviteStatus.pending.name)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => _fromDoc(doc)).toList());
  }

  /// Lists pending invites for a company.
  Future<List<Invite>> getPendingByCompany(String companyId) async {
    final snapshot = await _collection
        .where('company.id', isEqualTo: companyId)
        .where('status', isEqualTo: InviteStatus.pending.name)
        .get();

    return snapshot.docs.map((doc) => _fromDoc(doc)).toList();
  }

  /// Lists all invites for a phone number (any status).
  Future<List<Invite>> listByPhone(String phone) async {
    // Normalize phone number (remove non-digits)
    final normalizedPhone = phone.replaceAll(RegExp(r'\D'), '');

    final snapshot = await _collection
        .where('phone', isEqualTo: normalizedPhone)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => _fromDoc(doc)).toList();
  }

  /// Gets pending invites for a phone number.
  Future<List<Invite>> getPendingByPhone(String phone) async {
    final normalizedPhone = phone.replaceAll(RegExp(r'\D'), '');

    final snapshot = await _collection
        .where('phone', isEqualTo: normalizedPhone)
        .where('status', isEqualTo: InviteStatus.pending.name)
        .get();

    return snapshot.docs.map((doc) => _fromDoc(doc)).toList();
  }

  /// Checks if a pending invite exists for this email in this company.
  Future<bool> existsPendingInvite(String email, String companyId) async {
    final snapshot = await _collection
        .where('email', isEqualTo: email.toLowerCase())
        .where('company.id', isEqualTo: companyId)
        .where('status', isEqualTo: InviteStatus.pending.name)
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  /// Checks if a pending invite exists for this phone in this company.
  Future<bool> existsPendingInviteByPhone(String phone, String companyId) async {
    final normalizedPhone = phone.replaceAll(RegExp(r'\D'), '');

    final snapshot = await _collection
        .where('phone', isEqualTo: normalizedPhone)
        .where('company.id', isEqualTo: companyId)
        .where('status', isEqualTo: InviteStatus.pending.name)
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  // ═══════════════════════════════════════════════════════════════════
  // Write Operations
  // ═══════════════════════════════════════════════════════════════════

  /// Creates a new invite with auto-generated token.
  ///
  /// Generates a unique token (INV_XXXXXXXX) and sets:
  /// - token field
  /// - document ID = token
  /// - createdAt = now
  /// - expiresAt = now + 7 days (default)
  /// - status = pending
  Future<Invite> create(Invite invite) async {
    // Generate unique token
    final token = await generateUniqueToken();
    invite.token = token;
    invite.id = token;

    // Normalize email
    invite.email = invite.email?.toLowerCase();

    // Normalize phone (remove non-digits)
    if (invite.phone != null) {
      invite.phone = invite.phone!.replaceAll(RegExp(r'\D'), '');
    }

    // Set timestamps
    final now = DateTime.now();
    invite.createdAt = now;
    invite.expiresAt ??= now.add(Duration(days: defaultExpirationDays));

    // Set default status
    invite.status = InviteStatus.pending;

    // Set default channel if not specified
    invite.channel ??= InviteChannel.app;

    // Convert to JSON and handle DateTime to Timestamp conversion
    final json = invite.toJson();
    json['createdAt'] = Timestamp.fromDate(invite.createdAt!);
    json['expiresAt'] = Timestamp.fromDate(invite.expiresAt!);

    // Use token as document ID for easy lookup
    await _collection.doc(token).set(json);

    return invite;
  }

  /// Updates the status of an invite.
  Future<void> updateStatus(String token, InviteStatus status) {
    return _collection.doc(token).update({'status': status.name});
  }

  /// Marks an invite as accepted.
  Future<void> markAsAccepted(String token, String userId) {
    return _collection.doc(token).update({
      'status': InviteStatus.accepted.name,
      'acceptedAt': Timestamp.fromDate(DateTime.now()),
      'acceptedByUserId': userId,
    });
  }

  /// Marks an invite as cancelled.
  Future<void> cancel(String token) {
    return _collection.doc(token).update({
      'status': InviteStatus.cancelled.name,
    });
  }

  /// Deletes an invite.
  Future<void> delete(String token) {
    return _collection.doc(token).delete();
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
    invite.token = doc.id; // Document ID is the token

    // Handle Firestore Timestamp conversions
    if (data['createdAt'] is Timestamp) {
      invite.createdAt = (data['createdAt'] as Timestamp).toDate();
    }

    if (data['expiresAt'] is Timestamp) {
      invite.expiresAt = (data['expiresAt'] as Timestamp).toDate();
    }

    if (data['acceptedAt'] is Timestamp) {
      invite.acceptedAt = (data['acceptedAt'] as Timestamp).toDate();
    }

    return invite;
  }
}
