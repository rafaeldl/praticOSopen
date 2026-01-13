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
  /// If [group] is provided, filters by that group.
  /// Returns up to [limit] results ordered by usage count.
  Future<List<AccumulatedValue>> search(
    String companyId,
    String fieldType,
    String query, {
    String? group,
    int limit = 20,
  }) async {
    final q = query.toLowerCase().trim();
    final normalizedGroup = group?.toLowerCase().trim();

    Query<Map<String, dynamic>> ref = _valuesCollection(companyId, fieldType);

    if (normalizedGroup != null) {
      ref = ref.where('group', isEqualTo: normalizedGroup);
    }

    final snap = await ref.get();

    // Client-side filtering and sorting (no composite index needed)
    var results = snap.docs
        .map((d) => AccumulatedValue.fromJson({...d.data(), 'id': d.id}))
        .where((v) => q.isEmpty || v.searchKey.contains(q))
        .toList();

    // Sort by usage count on client side
    results.sort((a, b) => b.usageCount.compareTo(a.usageCount));

    return results.take(limit).toList();
  }

  /// Gets all values for a field type.
  /// If [group] is provided, filters by that group.
  Future<List<AccumulatedValue>> getAll(
    String companyId,
    String fieldType, {
    String? group,
  }) async {
    final normalizedGroup = group?.toLowerCase().trim();
    Query<Map<String, dynamic>> ref = _valuesCollection(companyId, fieldType);

    if (normalizedGroup != null) {
      ref = ref.where('group', isEqualTo: normalizedGroup);
    }

    final snap = await ref.get();

    var results = snap.docs
        .map((d) => AccumulatedValue.fromJson({...d.data(), 'id': d.id}))
        .toList();

    // Sort by usage count on client side (no composite index needed)
    results.sort((a, b) => b.usageCount.compareTo(a.usageCount));

    return results;
  }

  /// Streams all values for a field type.
  /// If [group] is provided, filters by that group.
  Stream<List<AccumulatedValue>> streamAll(
    String companyId,
    String fieldType, {
    String? group,
  }) {
    final normalizedGroup = group?.toLowerCase().trim();
    Query<Map<String, dynamic>> ref = _valuesCollection(companyId, fieldType);

    if (normalizedGroup != null) {
      ref = ref.where('group', isEqualTo: normalizedGroup);
    }

    return ref.snapshots().map((snap) {
      var results = snap.docs
          .map((d) => AccumulatedValue.fromJson({...d.data(), 'id': d.id}))
          .toList();

      // Sort by usage count on client side (no composite index needed)
      results.sort((a, b) => b.usageCount.compareTo(a.usageCount));

      return results;
    });
  }

  /// Records usage of a value (adds new or increments count if exists).
  /// Returns the value ID.
  ///
  /// Call this when a user selects or enters a value. It will:
  /// - Create the value if it doesn't exist (with usageCount = 1)
  /// - Increment usageCount if it already exists
  /// - Associate with [group] if provided (for hierarchies)
  Future<String> use(
    String companyId,
    String fieldType,
    String value, {
    String? group,
  }) async {
    final searchKey = value.toLowerCase().trim();
    final normalizedGroup = group?.toLowerCase().trim();
    final collection = _valuesCollection(companyId, fieldType);

    // Build query to check if exists
    Query<Map<String, dynamic>> query =
        collection.where('searchKey', isEqualTo: searchKey);

    // If group is provided, also match by normalized group
    if (normalizedGroup != null) {
      query = query.where('group', isEqualTo: normalizedGroup);
    }

    final existing = await query.limit(1).get();

    if (existing.docs.isNotEmpty) {
      // Increment usage counter
      final docRef = existing.docs.first.reference;
      await docRef.update({
        'usageCount': FieldValue.increment(1),
        'updatedAt': DateTime.now().toIso8601String(),
      });
      return docRef.id;
    }

    // Create new value
    final now = DateTime.now();
    final newValue = AccumulatedValue(
      value: value.trim(),
      searchKey: searchKey,
      usageCount: 1,
      group: normalizedGroup,
      createdAt: now,
      updatedAt: now,
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
    String group,
  ) async {
    final normalizedGroup = group.toLowerCase().trim();
    final values = await _valuesCollection(companyId, fieldType)
        .where('group', isEqualTo: normalizedGroup)
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
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }
}
