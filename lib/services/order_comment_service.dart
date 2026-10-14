import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:praticos/global.dart';

/// Adds an internal comment to an order, as the comments screen does.
/// Used by "Nova OS" to keep what the customer asked as the first comment.
Future<void> addOrderComment({
  required String companyId,
  required String orderId,
  required String text,
}) {
  final user = Global.currentUser;
  return FirebaseFirestore.instance
      .collection('companies')
      .doc(companyId)
      .collection('orders')
      .doc(orderId)
      .collection('comments')
      .add({
        'text': text,
        'authorType': 'internal',
        'author': {
          'name': user?.displayName ?? 'Equipe',
          'userId': user?.uid,
          'email': user?.email,
        },
        'source': 'app',
        'isInternal': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
}
