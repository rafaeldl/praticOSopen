import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/models/user_role.dart';

/// Serviço de autenticação e signup.
///
/// Arquitetura de dados:
/// - `/users/{userId}` - Documento do usuário com `companies: [CompanyRoleAggr]`
/// - `/companies/{companyId}` - Documento da empresa
/// - `/companies/{companyId}/memberships/{userId}` - Índice reverso de membros
class AuthService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Realiza o cadastro inicial de um usuário, criando:
  /// 1. O documento do Usuário (`/users/{userId}`)
  /// 2. O documento da Empresa (`/companies/{companyId}`)
  /// 3. O documento de Membership (`/companies/{companyId}/memberships/{userId}`)
  ///
  /// Usa batch write para garantir atomicidade.
  Future<void> signup({
    required User user,
    required Company company,
    required RolesType role,
  }) async {
    WriteBatch batch = _db.batch();

    // 1. Criar documento do User
    var userRef = _db.collection('users').doc(user.id);
    batch.set(userRef, user.toJson());

    // 2. Criar documento da Company
    var companyRef = _db.collection('companies').doc(company.id);
    var companyJson = company.toJson();
    companyJson.remove('users'); // Não armazena lista de users na company
    batch.set(companyRef, companyJson);

    // 3. Criar Membership (índice reverso)
    var membershipRef = _db
        .collection('companies')
        .doc(company.id)
        .collection('memberships')
        .doc(user.id); // userId como ID do documento

    batch.set(membershipRef, {
      'user': user.toAggr().toJson(),
      'role': role.name,
      'joinedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Deletes all user data from Firestore before deleting the account.
  /// This includes:
  /// 1. User document (`/users/{userId}`)
  /// 2. User memberships in all companies
  /// 3. If user is the last admin of a company, deletes the company and all its data
  Future<void> deleteUserData(String userId) async {
    WriteBatch batch = _db.batch();

    // 1. Get user document to find all companies
    var userDoc = await _db.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      return; // User doesn't exist in Firestore
    }

    var userData = userDoc.data();
    List<dynamic>? companies = userData?['companies'];

    if (companies != null) {
      for (var companyRole in companies) {
        var companyId = companyRole['company']?['id'];
        if (companyId != null) {
          // Delete membership
          var membershipRef = _db
              .collection('companies')
              .doc(companyId)
              .collection('memberships')
              .doc(userId);
          batch.delete(membershipRef);

          // Check if user is the only admin/owner
          var memberships = await _db
              .collection('companies')
              .doc(companyId)
              .collection('memberships')
              .get();

          var hasOtherAdmins = memberships.docs.any((doc) {
            return doc.id != userId &&
                (doc.data()['role'] == 'admin' ||
                    doc.data()['role'] == 'manager');
          });

          // If no other admins, delete the company and all its data
          if (!hasOtherAdmins) {
            // Delete company subcollections (service_orders, customers, etc.)
            // Note: In production, this should ideally be done via Cloud Functions
            // to handle large datasets and avoid timeout issues

            // Delete the company document
            var companyRef = _db.collection('companies').doc(companyId);
            batch.delete(companyRef);
          }
        }
      }
    }

    // 2. Delete user document
    var userRef = _db.collection('users').doc(userId);
    batch.delete(userRef);

    await batch.commit();
  }
}
