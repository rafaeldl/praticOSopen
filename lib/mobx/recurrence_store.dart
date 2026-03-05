import 'package:praticos/global.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/recurrence_rule.dart';
import 'package:praticos/repositories/tenant/tenant_recurrence_repository.dart';
import 'package:praticos/repositories/tenant/tenant_order_repository.dart';
import 'package:praticos/mobx/user_store.dart';
import 'package:mobx/mobx.dart';

part 'recurrence_store.g.dart';

class RecurrenceStore = _RecurrenceStore with _$RecurrenceStore;

abstract class _RecurrenceStore with Store {
  final TenantRecurrenceRepository repository = TenantRecurrenceRepository();
  final TenantOrderRepository orderRepository = TenantOrderRepository();
  final UserStore userStore = UserStore();

  @observable
  ObservableStream<List<RecurrenceRule?>>? ruleList;

  @observable
  bool isLoading = false;

  String? get companyId => Global.companyAggr?.id;

  @action
  void loadRules() {
    if (companyId == null) return;
    ruleList = repository.streamAllRules(companyId!).asObservable();
  }

  @action
  void loadActiveRules() {
    if (companyId == null) return;
    ruleList = repository.streamActiveRules(companyId!).asObservable();
  }

  @action
  Future<void> saveRule(RecurrenceRule rule) async {
    if (companyId == null) return;
    final user = await userStore.getSingleUserById();

    final isEditing = rule.id != null;

    if (!isEditing) {
      rule.createdAt = DateTime.now();
      rule.createdBy = user?.toAggr();
      rule.generatedCount = 0;
      // Compute initial nextDueDate
      rule.nextDueDate = rule.startDate;
    }

    rule.company = Global.companyAggr;
    rule.updatedAt = DateTime.now();
    rule.updatedBy = user?.toAggr();

    // Sync deviceIds from devices
    if (rule.devices != null && rule.devices!.isNotEmpty) {
      rule.deviceIds = rule.devices!
          .where((d) => d.id != null)
          .map((d) => d.id!)
          .toList();
    }

    if (isEditing) {
      await repository.updateItem(companyId!, rule);
    } else {
      await repository.createItem(companyId!, rule);
    }
  }

  @action
  Future<void> deleteRule(RecurrenceRule rule) async {
    if (companyId == null || rule.id == null) return;
    await repository.removeItem(companyId!, rule.id!);
  }

  @action
  Future<void> toggleActive(RecurrenceRule rule) async {
    rule.active = !(rule.active ?? false);
    await saveRule(rule);
  }

  /// Generate an Order from a recurrence rule
  @action
  Future<Order?> generateOrderFromRule(RecurrenceRule rule) async {
    if (companyId == null) return null;
    final user = await userStore.getSingleUserById();

    final order = Order()
      ..company = Global.companyAggr
      ..status = 'quote'
      ..payment = 'unpaid'
      ..createdAt = DateTime.now()
      ..createdBy = user?.toAggr()
      ..updatedAt = DateTime.now()
      ..updatedBy = user?.toAggr()
      ..customer = rule.customer
      ..devices = rule.devices != null ? List.from(rule.devices!) : null
      ..device = rule.devices?.isNotEmpty == true ? rule.devices!.first : null
      ..services = rule.services != null ? List.from(rule.services!) : null
      ..products = rule.products != null ? List.from(rule.products!) : null
      ..assignedTo = rule.assignedTo;

    // Sync deviceIds
    order.syncDeviceIds();

    await orderRepository.createItem(companyId!, order);

    // Update rule tracking
    rule.lastGeneratedDate = DateTime.now();
    rule.generatedCount = (rule.generatedCount ?? 0) + 1;
    rule.nextDueDate = rule.computeNextDueDate();

    // Deactivate if expired
    if (rule.isExpired) {
      rule.active = false;
    }

    await repository.updateItem(companyId!, rule);

    return order;
  }

  /// Check and generate orders for all due rules (called on app startup)
  @action
  Future<int> checkAndGenerateDueOrders() async {
    if (companyId == null) return 0;
    isLoading = true;

    try {
      final rulesSnapshot = await repository
          .streamActiveRules(companyId!)
          .first;

      final dueRules = rulesSnapshot
          .whereType<RecurrenceRule>()
          .where((r) => r.isDue && r.autoGenerate == true)
          .toList();

      int generated = 0;
      for (final rule in dueRules) {
        await generateOrderFromRule(rule);
        generated++;
      }

      isLoading = false;
      return generated;
    } catch (e) {
      isLoading = false;
      return 0;
    }
  }
}
