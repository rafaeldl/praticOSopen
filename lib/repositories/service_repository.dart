import 'package:praticos/models/service.dart';
import 'package:praticos/repositories/repository.dart';

class ServiceRepository extends Repository<Service> {
  static String collectionName = 'services';

  ServiceRepository() : super(collectionName);

  @override
  Service fromJson(data) => Service.fromJson(data);

  @override
  Map<String, dynamic> toJson(Service service) => service.toJson();
}
