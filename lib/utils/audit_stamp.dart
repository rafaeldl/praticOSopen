import 'package:praticos/global.dart';
import 'package:praticos/models/base_audit_company.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/user.dart';

/// The company [companyId] as an aggregate: the current company when it is
/// that one, else the matching entry of [user]'s companies. Never the first
/// company of the list, which is wrong for who belongs to several.
CompanyAggr? companyAggrFor(User? user, String? companyId) {
  if (companyId == null) return null;
  final current = Global.companyAggr;
  if (current?.id == companyId) return current;
  for (final role in user?.companies ?? const []) {
    if (role.company?.id == companyId) return role.company;
  }
  return null;
}

/// Stamps the audit fields before saving [entity] in [companyId].
///
/// Creation fields (`createdAt`, `createdBy`) are set only for a new record
/// (or one that never had them): editing keeps who created it and when.
/// `updatedAt`/`updatedBy` are always the acting user.
void stampAudit(
  BaseAuditCompany entity, {
  required bool isNew,
  required User? user,
  required String companyId,
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  if (isNew || entity.createdAt == null) {
    entity.createdAt = at;
    entity.createdBy = user?.toAggr();
  }
  entity.company = companyAggrFor(user, companyId) ?? entity.company;
  entity.updatedAt = at;
  entity.updatedBy = user?.toAggr();
}
