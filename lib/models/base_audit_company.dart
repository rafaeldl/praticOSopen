import 'package:praticos/models/base.dart';
import 'package:praticos/models/base_audit.dart';
import 'package:praticos/models/company.dart';

abstract class BaseAuditCompany extends BaseAudit {
  CompanyAggr? company;
}

abstract class BaseAuditCompanyAggr extends Base {}
