import 'package:praticos/models/user.dart';
import 'package:praticos/repositories/repository.dart';

class UserRepository extends Repository<User> {
  static String collectionName = 'users';

  UserRepository() : super(collectionName);

  @override
  User fromJson(data) => User.fromJson(data);

  @override
  Map<String, dynamic> toJson(User user) => user.toJson();

  Future<User?> findUserById(String id) async {
    User? user = await super.getSingle(id);
    return user;
  }
}
