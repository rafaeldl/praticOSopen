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
    batch.set(userRef, user.toJson(), SetOptions(merge: true));

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
  ///
  /// Business Logic:
  /// - If user is OWNER and has NO OTHER MEMBERS: delete entire company
  /// - If user is OWNER and HAS OTHER MEMBERS: throw error (cannot delete, must transfer ownership first)
  /// - If user is COLLABORATOR: remove membership only
  ///
  /// This includes:
  /// 1. User memberships in all companies
  /// 2. User document (`/users/{userId}`)
  /// 3. If user is sole owner, deletes the company and all its data
  Future<void> deleteUserData(String userId) async {
    print('🗑️  Starting deleteUserData for userId: $userId');

    // 1. Get user document to find all companies
    var userDoc = await _db.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      print('⚠️  User document does not exist');
      return; // User doesn't exist in Firestore
    }

    var userData = userDoc.data();
    List<dynamic>? companies = userData?['companies'];
    print('📋 User has ${companies?.length ?? 0} company associations');

    if (companies != null) {
      for (var companyRole in companies) {
        var companyId = companyRole['company']?['id'];
        if (companyId != null) {
          print('🏢 Processing company: $companyId');

          // Check if user is the owner of the company
          var companyDoc = await _db.collection('companies').doc(companyId).get();

          if (companyDoc.exists) {
            var companyData = companyDoc.data();
            var ownerData = companyData?['owner'];
            var ownerId = ownerData != null ? ownerData['id'] as String? : null;
            print('👤 Company owner: $ownerId, Current user: $userId');

            // If user is the owner
            if (ownerId == userId) {
              print('✓ User is owner of company $companyId');

              // Check if there are other members in the company
              var memberships = await _db
                  .collection('companies')
                  .doc(companyId)
                  .collection('memberships')
                  .get();

              print('👥 Total memberships: ${memberships.docs.length}');

              // Count members excluding the owner (who is leaving)
              var otherMembersCount = memberships.docs
                  .where((doc) => doc.id != userId)
                  .length;

              print('👥 Other members count: $otherMembersCount');

              if (otherMembersCount > 0) {
                // Company has other members - cannot delete
                print('❌ Cannot delete: company has other members');
                throw Exception(
                  'Você é o proprietário de uma empresa com outros membros. '
                  'Transfira a propriedade ou remova os membros antes de excluir sua conta.'
                );
              }

              // User is sole owner - can delete entire company
              print('🗑️  Deleting entire company $companyId (sole owner)');
              await _deleteCompanyAndData(companyId);
              print('✅ Company $companyId deleted successfully');
            } else {
              // If user is not the owner, only delete their membership
              print('🗑️  User is collaborator, removing membership only');
              var membershipRef = _db
                  .collection('companies')
                  .doc(companyId)
                  .collection('memberships')
                  .doc(userId);
              await membershipRef.delete();
              print('✅ Membership removed for company $companyId');
            }
          } else {
            print('⚠️  Company document $companyId does not exist');
          }
        }
      }
    }

    // 2. Delete user document
    print('🗑️  Deleting user document');
    var userRef = _db.collection('users').doc(userId);
    await userRef.delete();
    print('✅ User document deleted');
    print('✅ deleteUserData completed successfully');
  }

  /// Deletes a company and all its data recursively
  /// - All subcollections (services, products, customers, orders, etc.)
  /// - All nested documents within those subcollections
  /// - All files in Cloud Storage under tenants/{companyId}/
  Future<void> _deleteCompanyAndData(String companyId) async {
    print('🗑️  _deleteCompanyAndData started for company: $companyId');

    // 1. Delete all files from Cloud Storage
    print('📦 Deleting Cloud Storage files...');
    try {
      final storageRef = FirebaseStorage.instance.ref('tenants/$companyId');
      await _deleteStorageFolder(storageRef);
      print('✅ Cloud Storage files deleted');
    } catch (e) {
      print('⚠️  Warning: Error deleting company storage: $e');
      // Continue with Firestore deletion even if storage deletion fails
    }

    // 2. Delete all Firestore subcollections recursively
    print('📄 Deleting Firestore subcollections...');
    await _deleteCollectionRecursively(
      _db.collection('companies').doc(companyId),
    );
    print('✅ Firestore subcollections deleted');

    // 3. Delete the company document itself
    print('📄 Deleting company document...');
    await _db.collection('companies').doc(companyId).delete();
    print('✅ Company document deleted');
    print('✅ _deleteCompanyAndData completed for company: $companyId');
  }

  /// Recursively deletes all documents in known company subcollections
  Future<void> _deleteCollectionRecursively(
    DocumentReference documentRef,
  ) async {
    // Known company subcollections to delete
    const subcollections = [
      'services',
      'products',
      'devices',
      'customers',
      'orders',
      'service_orders',
      'memberships',
      'metadata',
      'forms',
      'roles',
      'collaborators',
      'photos',
    ];

    for (final collectionName in subcollections) {
      try {
        final collection = documentRef.collection(collectionName);
        final docs = await collection.get();

        if (docs.docs.isNotEmpty) {
          print('  🗑️  Deleting $collectionName: ${docs.docs.length} documents');
        }

        for (final doc in docs.docs) {
          // Recursively delete subcollections of each document
          await _deleteCollectionRecursively(doc.reference);

          // Delete the document itself
          await doc.reference.delete();
        }

        if (docs.docs.isNotEmpty) {
          print('  ✅ Deleted $collectionName');
        }
      } catch (e) {
        print('  ⚠️  Warning: Error deleting $collectionName: $e');
        // Continue with next collection if one fails
      }
    }
  }

  /// Recursively deletes all files in a Firebase Storage folder
  Future<void> _deleteStorageFolder(Reference folderRef) async {
    try {
      final ListResult listResult = await folderRef.listAll();

      // Delete all files
      if (listResult.items.isNotEmpty) {
        print('  📦 Deleting ${listResult.items.length} files from ${folderRef.fullPath}');
      }
      for (final Reference file in listResult.items) {
        await file.delete();
      }

      // Recursively delete all folders
      for (final Reference folder in listResult.prefixes) {
        await _deleteStorageFolder(folder);
      }

      if (listResult.items.isNotEmpty || listResult.prefixes.isNotEmpty) {
        print('  ✅ Deleted storage folder: ${folderRef.fullPath}');
      }
    } catch (e) {
      print('  ⚠️  Warning: Error listing/deleting storage folder: $e');
    }
  }
}
