import 'package:praticos/models/customer.dart';
import 'package:praticos/repositories/repository.dart';

class CustomerRepository extends Repository<Customer> {
  static String collectionName = 'customers';

  CustomerRepository() : super(collectionName);

  @override
  Customer fromJson(data) => Customer.fromJson(data);

  @override
  Map<String, dynamic> toJson(Customer customer) => customer.toJson();
}
