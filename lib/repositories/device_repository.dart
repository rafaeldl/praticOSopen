import 'package:praticos/models/device.dart';
import 'package:praticos/repositories/repository.dart';

class DeviceRepository extends Repository<Device> {
  static String collectionName = 'devices';

  DeviceRepository() : super(collectionName);

  @override
  Device fromJson(data) => Device.fromJson(data);

  @override
  Map<String, dynamic> toJson(Device device) => device.toJson();
}
