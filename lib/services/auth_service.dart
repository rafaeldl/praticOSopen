import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
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
  /// 3. If user is the owner of a company, deletes the company and all its data (including subcollections)
  /// 4. Deletes company files from Cloud Storage
  Future<void> deleteUserData(String userId) async {
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
          // Check if user is the owner of the company
          var companyDoc = await _db.collection('companies').doc(companyId).get();

          if (companyDoc.exists) {
            var companyData = companyDoc.data();
            var ownerId = companyData?['ownerId'];

            // If user is the owner, delete the company and all its data
            if (ownerId == userId) {
              // Delete entire company structure (all subcollections and files)
              await _deleteCompanyAndData(companyId);
            } else {
              // If user is not the owner, only delete their membership
              var membershipRef = _db
                  .collection('companies')
                  .doc(companyId)
                  .collection('memberships')
                  .doc(userId);
              await membershipRef.delete();
            }
          }
        }
      }
    }

    // 2. Delete user document
    var userRef = _db.collection('users').doc(userId);
    await userRef.delete();
  }

  /// Deletes a company and all its data recursively
  /// - All subcollections (services, products, customers, orders, etc.)
  /// - All nested documents within those subcollections
  /// - All files in Cloud Storage under tenants/{companyId}/
  Future<void> _deleteCompanyAndData(String companyId) async {
    // 1. Delete all files from Cloud Storage
    try {
      final storageRef = FirebaseStorage.instance.ref('tenants/$companyId');
      await _deleteStorageFolder(storageRef);
    } catch (e) {
      print('Warning: Error deleting company storage: $e');
      // Continue with Firestore deletion even if storage deletion fails
    }

    // 2. Delete all Firestore subcollections recursively
    await _deleteCollectionRecursively(
      _db.collection('companies').doc(companyId),
    );

    // 3. Delete the company document itself
    await _db.collection('companies').doc(companyId).delete();
  }

  /// Recursively deletes all documents in a collection and its subcollections
  Future<void> _deleteCollectionRecursively(
    DocumentReference documentRef,
  ) async {
    // Get all subcollections of the document
    final collections = await documentRef.listCollections().toList();

    for (final collection in collections) {
      // Get all documents in the subcollection
      final docs = await collection.get();

      for (final doc in docs.docs) {
        // Recursively delete subcollections of each document
        await _deleteCollectionRecursively(doc.reference);

        // Delete the document itself
        await doc.reference.delete();
      }
    }
  }

  /// Recursively deletes all files in a Firebase Storage folder
  Future<void> _deleteStorageFolder(Reference folderRef) async {
    try {
      final ListResult listResult = await folderRef.listAll();

      // Delete all files
      for (final Reference file in listResult.items) {
        await file.delete();
      }

      // Recursively delete all folders
      for (final Reference folder in listResult.prefixes) {
        await _deleteStorageFolder(folder);
      }
    } catch (e) {
      print('Warning: Error listing/deleting storage folder: $e');
    }
  }
}
