import 'package:praticos/models/company.dart';
import 'package:praticos/repositories/repository.dart';

class CompanyRepository extends Repository<Company> {
  static String collectionName = 'companies';

  CompanyRepository() : super(collectionName);

  @override
  Company fromJson(data) => Company.fromJson(data);

  @override
  Map<String, dynamic> toJson(Company company) => company.toJson();
}
