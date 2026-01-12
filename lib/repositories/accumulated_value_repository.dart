import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/accumulated_value.dart';

/// Repository for managing accumulated field values.
///
/// Firestore structure:
/// companies/{companyId}/accumulatedFields/{fieldType}/values/{valueId}
///
/// Example fieldTypes: 'deviceCategory', 'deviceBrand', 'deviceModel',
/// 'serviceCategory', 'productCategory', etc.
class AccumulatedValueRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Returns the collection reference for a specific field type
  CollectionReference<Map<String, dynamic>> _valuesCollection(
    String companyId,
    String fieldType,
  ) {
    return _db
        .collection('companies')
        .doc(companyId)
        .collection('accumulatedFields')
        .doc(fieldType)
        .collection('values');
  }

  /// Searches values by query string.
  /// If [groupId] is provided, filters by that group.
  /// Returns up to [limit] results ordered by usage count.
  Future<List<AccumulatedValue>> search(
    String companyId,
    String fieldType,
    String query, {
    String? groupId,
    int limit = 20,
  }) async {
    final q = query.toLowerCase().trim();

    Query<Map<String, dynamic>> ref = _valuesCollection(companyId, fieldType)
        .orderBy('usageCount', descending: true);

    if (groupId != null) {
      ref = ref.where('groupId', isEqualTo: groupId);
    }

    final snap = await ref.get();

    // Client-side filtering (no index needed for text search)
    var results = snap.docs
        .map((d) => AccumulatedValue.fromJson({...d.data(), 'id': d.id}))
        .where((v) => q.isEmpty || v.searchKey.contains(q))
        .take(limit)
        .toList();

    return results;
  }

  /// Gets all values for a field type.
  /// If [groupId] is provided, filters by that group.
  Future<List<AccumulatedValue>> getAll(
    String companyId,
    String fieldType, {
    String? groupId,
  }) async {
    Query<Map<String, dynamic>> ref = _valuesCollection(companyId, fieldType)
        .orderBy('usageCount', descending: true);

    if (groupId != null) {
      ref = ref.where('groupId', isEqualTo: groupId);
    }

    final snap = await ref.get();

    return snap.docs
        .map((d) => AccumulatedValue.fromJson({...d.data(), 'id': d.id}))
        .toList();
  }

  /// Streams all values for a field type.
  /// If [groupId] is provided, filters by that group.
  Stream<List<AccumulatedValue>> streamAll(
    String companyId,
    String fieldType, {
    String? groupId,
  }) {
    Query<Map<String, dynamic>> ref = _valuesCollection(companyId, fieldType)
        .orderBy('usageCount', descending: true);

    if (groupId != null) {
      ref = ref.where('groupId', isEqualTo: groupId);
    }

    return ref.snapshots().map((snap) => snap.docs
        .map((d) => AccumulatedValue.fromJson({...d.data(), 'id': d.id}))
        .toList());
  }

  /// Adds a new value or increments usage count if it already exists.
  /// Returns the value ID.
  ///
  /// If [groupId] and [groupValue] are provided, associates the value with that group.
  Future<String> addOrIncrement(
    String companyId,
    String fieldType,
    String value, {
    String? groupId,
    String? groupValue,
  }) async {
    final searchKey = value.toLowerCase().trim();
    final collection = _valuesCollection(companyId, fieldType);

    // Build query to check if exists
    Query<Map<String, dynamic>> query =
        collection.where('searchKey', isEqualTo: searchKey);

    // If groupId is provided, also match by group
    if (groupId != null) {
      query = query.where('groupId', isEqualTo: groupId);
    }

    final existing = await query.limit(1).get();

    if (existing.docs.isNotEmpty) {
      // Increment usage counter
      final docRef = existing.docs.first.reference;
      await docRef.update({
        'usageCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    }

    // Create new value
    final newValue = AccumulatedValue(
      value: value.trim(),
      searchKey: searchKey,
      usageCount: 1,
      groupId: groupId,
      groupValue: groupValue,
    );

    final docRef = await collection.add(newValue.toJson());
    return docRef.id;
  }

  /// Gets a single value by ID
  Future<AccumulatedValue?> getById(
    String companyId,
    String fieldType,
    String valueId,
  ) async {
    final doc =
        await _valuesCollection(companyId, fieldType).doc(valueId).get();

    if (!doc.exists) return null;

    return AccumulatedValue.fromJson({...doc.data()!, 'id': doc.id});
  }

  /// Removes a value by ID
  Future<void> remove(
    String companyId,
    String fieldType,
    String valueId,
  ) async {
    await _valuesCollection(companyId, fieldType).doc(valueId).delete();
  }

  /// Removes all values that belong to a specific group.
  /// Useful when deleting a parent value (e.g., removing a brand and all its models).
  Future<void> removeByGroup(
    String companyId,
    String fieldType,
    String groupId,
  ) async {
    final values = await _valuesCollection(companyId, fieldType)
        .where('groupId', isEqualTo: groupId)
        .get();

    final batch = _db.batch();
    for (final doc in values.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  /// Updates a value's text (and recalculates searchKey)
  Future<void> updateValue(
    String companyId,
    String fieldType,
    String valueId,
    String newValue,
  ) async {
    await _valuesCollection(companyId, fieldType).doc(valueId).update({
      'value': newValue.trim(),
      'searchKey': newValue.toLowerCase().trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
