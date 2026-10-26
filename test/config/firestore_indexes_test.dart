import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards firebase/firestore.indexes.json: composite indexes only deploy
/// from "indexes" (a composite inside "fieldOverrides" is silently dropped),
/// and the order queries of members without viewAllOrders (#456) need one
/// index per filter combination led by createdBy.id.
void main() {
  final json = jsonDecode(
    File('firebase/firestore.indexes.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final indexes = (json['indexes'] as List).cast<Map<String, dynamic>>();
  final overrides =
      (json['fieldOverrides'] as List).cast<Map<String, dynamic>>();

  String signature(Map<String, dynamic> index) {
    final fields = (index['fields'] as List)
        .cast<Map<String, dynamic>>()
        .map((f) => '${f['fieldPath']}:${f['order'] ?? f['arrayConfig']}')
        .join(',');
    return '${index['collectionGroup']}|${index['queryScope']}|$fields';
  }

  test('composite indexes are never inside fieldOverrides', () {
    final misplaced = overrides.where((o) => o.containsKey('fields')).toList();
    expect(misplaced.map(signature), isEmpty);
  });

  test('every fieldOverride is a single-field override', () {
    for (final o in overrides) {
      expect(o['fieldPath'], isA<String>(), reason: o.toString());
    }
  });

  test('orders scoped by createdBy.id have their composite indexes', () {
    const expected = [
      'createdAt:DESCENDING,__name__:DESCENDING',
      'payment:ASCENDING,createdAt:DESCENDING,__name__:DESCENDING',
      'status:ASCENDING,createdAt:DESCENDING,__name__:DESCENDING',
      'status:ASCENDING,dueDate:ASCENDING,__name__:ASCENDING',
      'customer.id:ASCENDING,createdAt:DESCENDING,__name__:DESCENDING',
      'customer.id:ASCENDING,payment:ASCENDING,createdAt:DESCENDING,'
          '__name__:DESCENDING',
      'customer.id:ASCENDING,status:ASCENDING,createdAt:DESCENDING,'
          '__name__:DESCENDING',
      'customer.id:ASCENDING,status:ASCENDING,dueDate:ASCENDING,'
          '__name__:ASCENDING',
      'dueDate:ASCENDING,__name__:ASCENDING',
      'scheduledDate:ASCENDING,__name__:ASCENDING',
    ];
    final deployed = indexes.map(signature).toSet();
    for (final fields in expected) {
      expect(
        deployed,
        contains('orders|COLLECTION|createdBy.id:ASCENDING,$fields'),
      );
    }
  });
}
