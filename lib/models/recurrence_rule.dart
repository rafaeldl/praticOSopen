import 'package:praticos/models/base_audit_company.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/user.dart';
import 'package:json_annotation/json_annotation.dart';

part 'recurrence_rule.g.dart';

@JsonSerializable(explicitToJson: true)
class RecurrenceRule extends BaseAuditCompany {
  String? name;
  String? frequency; // 'daily', 'weekly', 'monthly', 'yearly'
  int? interval; // 1 = every period, 3 = every 3 periods
  DateTime? startDate;
  DateTime? endDate; // null = indefinite
  DateTime? nextDueDate;
  DateTime? lastGeneratedDate;
  int? generatedCount;
  bool? active;
  bool? autoGenerate; // true = creates OS, false = reminder only

  // Template fields (all optional)
  String? templateDescription;
  CustomerAggr? customer;
  List<DeviceAggr>? devices;
  List<String>? deviceIds;
  List<OrderService>? services;
  List<OrderProduct>? products;
  UserAggr? assignedTo;
  int? reminderDaysBefore;

  RecurrenceRule();
  factory RecurrenceRule.fromJson(Map<String, dynamic> json) =>
      _$RecurrenceRuleFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$RecurrenceRuleToJson(this);

  /// Computes the next due date based on frequency and interval
  DateTime? computeNextDueDate() {
    final base = lastGeneratedDate ?? startDate;
    if (base == null) return null;
    final step = interval ?? 1;

    switch (frequency) {
      case 'daily':
        return base.add(Duration(days: step));
      case 'weekly':
        return base.add(Duration(days: 7 * step));
      case 'monthly':
        return DateTime(base.year, base.month + step, base.day);
      case 'yearly':
        return DateTime(base.year + step, base.month, base.day);
      default:
        return null;
    }
  }

  /// Whether the rule is due (nextDueDate <= now and active)
  bool get isDue {
    if (active != true || nextDueDate == null) return false;
    return nextDueDate!.isBefore(DateTime.now()) ||
        nextDueDate!.isAtSameMomentAs(DateTime.now());
  }

  /// Whether the rule has expired (endDate passed)
  bool get isExpired {
    if (endDate == null) return false;
    return endDate!.isBefore(DateTime.now());
  }
}
