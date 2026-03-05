import 'package:praticos/models/recurrence_rule.dart';
import 'package:praticos/repositories/tenant_repository.dart';
import 'package:praticos/repositories/repository.dart';

/// Repository para RecurrenceRules usando subcollections por tenant.
///
/// Path: `/companies/{companyId}/recurrenceRules/{ruleId}`
class TenantRecurrenceRepository extends TenantRepository<RecurrenceRule?> {
  static const String collectionName = 'recurrenceRules';

  TenantRecurrenceRepository() : super(collectionName);

  @override
  RecurrenceRule fromJson(Map<String, dynamic> data) =>
      RecurrenceRule.fromJson(data);

  @override
  Map<String, dynamic> toJson(RecurrenceRule? rule) => rule!.toJson();

  /// Stream all active recurrence rules for a company
  Stream<List<RecurrenceRule?>> streamActiveRules(String companyId) {
    return streamQueryList(
      companyId,
      orderBy: [OrderBy('nextDueDate')],
      args: [QueryArgs('active', true)],
    );
  }

  /// Stream recurrence rules for a specific device
  Stream<List<RecurrenceRule?>> streamRulesByDevice(
    String companyId,
    String deviceId,
  ) {
    return streamQueryList(
      companyId,
      orderBy: [OrderBy('nextDueDate')],
      args: [QueryArgs('deviceIds', deviceId, oper: 'arrayContains')],
    );
  }

  /// Stream all recurrence rules
  Stream<List<RecurrenceRule?>> streamAllRules(String companyId) {
    return streamQueryList(
      companyId,
      orderBy: [OrderBy('createdAt', descending: true)],
    );
  }
}
