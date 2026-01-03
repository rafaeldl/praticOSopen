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
}
