import 'package:praticos/models/base.dart';
import 'package:praticos/models/user.dart';

abstract class BaseAudit extends Base {
  DateTime? createdAt;
  UserAggr? createdBy;
  DateTime? updatedAt;
  UserAggr? updatedBy;
}
