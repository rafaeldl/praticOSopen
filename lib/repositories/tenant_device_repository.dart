import 'package:praticos/models/device.dart';
import 'package:praticos/repositories/tenant_repository.dart';

class TenantDeviceRepository extends TenantRepository<Device> {
  TenantDeviceRepository() : super('devices');

  @override
  Device fromJson(Map<String, dynamic> data) => Device.fromJson(data);

  @override
  Map<String, dynamic> toJson(Device? item) => item!.toJson();
}
