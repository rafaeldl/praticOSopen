import 'dart:async';
import 'dart:io';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import 'package:praticos/services/analytics_service.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/services/feature_gate_service.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/order_document.dart';
import 'package:praticos/models/order_photo.dart';
import 'package:praticos/models/order_form.dart' as of_model;
import 'package:praticos/models/payment_transaction.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/models/user_role.dart';
import 'package:praticos/utils/order_items.dart';
import 'package:praticos/utils/order_payment_math.dart';
import 'package:praticos/utils/payment_update_failure.dart';
import 'package:praticos/utils/order_scope.dart';
import 'package:praticos/models/permission.dart';
import 'package:praticos/services/authorization_service.dart';
import 'package:praticos/services/forms_service.dart';
import 'package:praticos/repositories/v2/order_repository_v2.dart';
import 'package:praticos/repositories/tenant/tenant_order_repository.dart';
import 'package:praticos/utils/contract_generation.dart';
import 'package:praticos/utils/order_field_diff.dart';
import 'package:praticos/services/photo_service.dart';
import 'package:flutter/foundation.dart'
    show VoidCallback, debugPrint, visibleForTesting;
import 'package:mobx/mobx.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;

import 'package:praticos/global.dart';
import 'package:praticos/services/notification_service.dart';
import 'package:praticos/services/order_reminder_text.dart';
import 'package:praticos/mobx/reminder_store.dart';
import 'package:praticos/utils/financial_summary.dart';
part 'order_store.g.dart';

/// "Em aberto" loads every open order at once: the next-step block, the
/// sections and the "12 em aberto" count must see all of them, not a page.
const int kOpenOrdersLimit = 500;

class OrderStore = _OrderStore with _$OrderStore;

/// Whether [role] may auto-generate the due contract orders (creating orders
/// needs `createOrder`; the manager doesn't have it).
bool canGenerateContractOrders(RolesType? role) =>
    role != null &&
    RolePermissions.hasPermission(role, PermissionType.createOrder);

/// Whether [role] (user [userId]) generates the orders of contract
/// [template]: admin and supervisor (who see every order) generate any;
/// anyone else only from a template they created. A technician assigned to
/// an admin's contract sees the template but leaves it alone, silently.
bool canGenerateFromTemplate({
  required RolesType? role,
  required String? userId,
  required Order template,
}) {
  if (!canGenerateContractOrders(role)) return false;
  if (role == RolesType.admin || role == RolesType.supervisor) return true;
  return userId != null && template.createdBy?.id == userId;
}

abstract class _OrderStore with Store {
  final OrderRepositoryV2 repository = OrderRepositoryV2();
  final PhotoService photoService = PhotoService();
  final FormsService formsService = FormsService();
  final AuthorizationService _authService = AuthorizationService.instance;

  Order? order;

  /// The order's fields as last read from or written to Firestore
  /// ([OrderFieldDiff.snapshotOf]). A save writes only what differs from it.
  Map<String, dynamic>? _savedSnapshot;

  /// Order the snapshot belongs to (null for a new order).
  String? _savedSnapshotId;

  /// Remembers the current order as the saved state (next save writes only
  /// what changes from here).
  @visibleForTesting
  void rememberSaved() {
    _savedSnapshot = order == null ? null : OrderFieldDiff.snapshotOf(order!);
    _savedSnapshotId = order?.id;
  }

  /// Writes the changed fields of an existing order. Replaceable in tests.
  @visibleForTesting
  late Future<void> Function(
    String companyId,
    String orderId,
    Map<String, dynamic> fields,
  )
  writeOrderFields = (companyId, orderId, fields) => repository.updateFields(
    companyId,
    orderId,
    fields,
    actor: Global.userAggr,
  );

  /// Writes a save that touches the money fields: [fields] plus the items
  /// and discount the app changed ([appMoney]), with the total recomputed
  /// from the server copy in a transaction. Offline, [localMoney] (the four
  /// money fields as the app has them) goes instead. Replaceable in tests.
  @visibleForTesting
  late Future<void> Function(
    String companyId,
    String orderId,
    Map<String, dynamic> fields,
    Map<String, dynamic> appMoney,
    Map<String, dynamic> localMoney,
  )
  writeOrderMoney = (companyId, orderId, fields, appMoney, localMoney) =>
      repository.updateMoney(
        companyId,
        orderId,
        fields,
        appMoney: appMoney,
        localMoney: localMoney,
        actor: Global.userAggr,
      );

  /// While true, changes stay local and nothing is written to Firestore.
  /// The new order screen sets it for a blank order and clears it on
  /// "Salvar OS" (then calls [createItem]).
  bool deferSave = false;

  @observable
  ObservableStream<List<Order?>>? orderList;

  @observable
  ObservableStream<Order?>? orderStream;

  /// "Parada" mark of the open order (null when it is not stopped).
  @observable
  OrderHold? hold;

  /// Clock of the "parada" mark, replaceable in tests.
  @visibleForTesting
  DateTime Function() holdClock = DateTime.now;

  /// Writes (or, with null, removes) the mark. Replaceable in tests.
  @visibleForTesting
  late Future<void> Function(String companyId, String orderId, OrderHold? hold)
  writeHold = (companyId, orderId, hold) =>
      repository.setHold(companyId, orderId, hold, actor: Global.userAggr);

  @observable
  ObservableStream<List<of_model.OrderForm>>? formsStream;

  @observable
  String? dueDate;

  @observable
  String? scheduledDate;

  @observable
  String? address;

  @observable
  double? latitude;

  @observable
  double? longitude;

  @observable
  String? status;

  @observable
  DateTime? createdAt;

  @observable
  double? total;

  @observable
  double? discount;

  @observable
  String? payment;

  @observable
  CustomerAggr? customer;

  @observable
  DeviceAggr? device;

  @observable
  ObservableList<DeviceAggr> devices = ObservableList<DeviceAggr>();

  /// Transient state for multi-device picker flow
  String? pendingDeviceId;
  bool pendingDuplicateAll = false;
  List<String>? pendingDeviceIds;

  @computed
  String? get customerName => customer?.name;

  late String orderServiceTitle;

  late String orderProductTitle;

  @observable
  Customer? customerFilter;

  @computed
  String? get deviceName {
    if (device == null) return null;
    final name = device?.name ?? '';
    final serial = device?.serial;

    // Only show serial if it's not null or empty
    if (serial != null && serial.trim().isNotEmpty) {
      return "$name - $serial";
    }
    return name;
  }

  @computed
  String? get devicePhoto => device?.photo;

  @computed
  String? get customerInitials {
    if (customer?.name == null || customer!.name!.isEmpty) return null;
    final parts = customer!.name!.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return parts.first[0].toUpperCase();
  }

  @observable
  ObservableList<OrderService>? services = ObservableList();

  @observable
  ObservableList<OrderProduct>? products = ObservableList();

  @observable
  ObservableList<OrderPhoto> photos = ObservableList();

  @observable
  ObservableList<OrderDocument> documents = ObservableList();

  @observable
  bool isUploadingPhoto = false;

  @observable
  bool isUploadingDocument = false;

  /// Resultado da verificacao de limite de fotos
  @observable
  FeatureGateResult? photoLimitResult;

  @observable
  bool hasContract = false;

  @observable
  ObservableStream<List<Order?>>? childOrders;

  @observable
  double? paidAmount;

  @observable
  ObservableList<PaymentTransaction> transactions = ObservableList();

  @computed
  double get remainingBalance {
    final totalValue = total ?? 0.0;
    final paid = paidAmount ?? 0.0;
    // Rounded: summing item prices leaves float noise (824.4200000000001)
    // that showed "Falta receber R$ 0,00" or refused a payment of the
    // balance shown on screen. Never below zero (paid more than the total).
    return OrderPaymentMath.floorAtZero(
      OrderPaymentMath.roundMoney(totalValue - paid),
    );
  }

  @computed
  bool get isFullyPaid => remainingBalance <= 0;

  @computed
  bool get hasPartialPayment => (paidAmount ?? 0) > 0 && !isFullyPaid;

  @observable
  double totalPaidAmount = 0.0;

  @observable
  double totalUnpaidAmount = 0.0;

  @observable
  double totalRevenue = 0.0;

  @observable
  int totalOrdersCount = 0;

  @observable
  int paidOrdersCount = 0;

  @observable
  ObservableList<Order?> recentOrders = ObservableList<Order?>();

  @observable
  String selectedDashboardPeriod = 'mês';

  @observable
  int periodOffset = 0;

  @observable
  ObservableMap<String, int> orderStatusCounts = ObservableMap<String, int>();

  @observable
  ObservableMap<String, double> paymentStatusCounts =
      ObservableMap<String, double>();

  @observable
  String? paymentFilter;

  @observable
  ObservableList<Order?> orders = ObservableList<Order?>();

  /// Retorna a lista de OS filtrada com base nas permissões do usuário.
  ///
  /// - Admin/Gerente/Supervisor: todas as OS
  /// - Consultor: apenas OS que criou
  /// - Técnico: apenas OS atribuídas
  @computed
  List<Order?> get filteredOrders {
    final ordersList = orders.toList();
    return _authService
        .filterOrdersByPermission(ordersList.whereType<Order>().toList())
        .cast<Order?>();
  }

  /// Verifica se o usuário pode visualizar valores financeiros.
  @computed
  bool get canViewPrices => _authService.canViewPrices;

  /// Verifica se o usuário pode criar novas OS.
  @computed
  bool get canCreateOrder =>
      _authService.hasPermission(PermissionType.createOrder);

  /// Verifica se o usuário pode visualizar o dashboard financeiro.
  @computed
  bool get canViewFinancialDashboard => _authService.canViewFinancialReports;

  @observable
  bool isLoading = false;

  @observable
  bool hasMoreOrders = true;

  /// True when the last Home list fetch failed (shows the retry state).
  @observable
  bool ordersLoadFailed = false;

  firestore.DocumentSnapshot? _lastDocument;
  final int _limit = 10;

  @observable
  ObservableMap<String, double> customerOrderTotals =
      ObservableMap<String, double>();

  @observable
  ObservableMap<String, double> customerUnpaidTotals =
      ObservableMap<String, double>();

  @observable
  ObservableList<Map<String, dynamic>> customerRanking =
      ObservableList<Map<String, dynamic>>();

  @observable
  Map<String, dynamic>? selectedCustomerInRanking;

  @observable
  String rankingSortType = 'total'; // 'total' ou 'unpaid'

  _OrderStore() {
    autorun((_) {
      // Protege contra valores nulos
      if (orderStream == null || orderStream!.data == null || order == null) {
        return;
      }

      // Atualiza o número da OS a partir do stream
      order!.number = orderStream!.data.number;
    });
    reaction<Order?>(
      (_) => orderStream?.value,
      (server) => runInAction(() => applyServerOrder(server)),
    );
  }

  /// Item lists the app adopts from the server when it hasn't changed them
  /// itself (an item added by the web shows up and is kept by the next save).
  static const _serverOwnedLists = ['services', 'products'];

  /// Brings items written elsewhere into the open order, for each list the
  /// app didn't change since its last save.
  @visibleForTesting
  void applyServerOrder(Order? server) {
    final base = _savedSnapshot;
    final local = order;
    if (server == null || local == null || base == null || deferSave) return;
    if (server.id == null || server.id != local.id) return;
    if (_savedSnapshotId != null && _savedSnapshotId != local.id) return;
    final remote = OrderFieldDiff.snapshotOf(server);
    final current = OrderFieldDiff.snapshotOf(local);
    var adopted = false;
    for (final key in _serverOwnedLists) {
      if (!OrderFieldDiff.same(current[key], base[key])) continue;
      if (OrderFieldDiff.same(remote[key], base[key])) continue;
      if (key == 'services') {
        local.services = server.services ?? [];
        services = local.services!.asObservable();
      } else {
        local.products = server.products ?? [];
        products = local.products!.asObservable();
      }
      base[key] = OrderFieldDiff.deepCopy(remote[key]);
      adopted = true;
    }
    if (!adopted) return;
    base['total'] = remote['total'];
    updateTotal();
  }

  String? get companyId => Global.companyAggr?.id;

  @action
  loadOrder({String? id}) {
    if (id == null) {
      order = Order();
      order!.company = Global.companyAggr;
      order!.total = 0.0;
      total = order!.total;
      order!.discount = 0.0;
      discount = order!.discount;
      order!.paidAmount = 0.0;
      paidAmount = order!.paidAmount;
      order!.transactions = [];
      transactions = ObservableList<PaymentTransaction>();
      order!.photos = [];
      photos = ObservableList<OrderPhoto>();
      order!.documents = [];
      documents = ObservableList<OrderDocument>();
      order!.devices = [];
      devices = ObservableList<DeviceAggr>();
      order!.createdAt = DateTime.now();
      createdAt = order!.createdAt;
      order!.createdBy = Global.userAggr;
      order!.status = 'quote';
      status = order!.status;
      address = null;
      latitude = null;
      longitude = null;
      order!.payment = 'unpaid';
      payment = order!.payment;
      updatePayment();
      return;
    }
    if (companyId == null) return;
    repository.getSingle(companyId!, id).then((value) {
      setOrder(value);
    });
  }

  @action
  void setOrder(Order? order) {
    if (order == null) return;

    // Preserva o ID para garantir que não seja perdido
    String? orderId = order.id;

    this.order = order;
    // Before the defaults below: whatever they change goes in the next save.
    rememberSaved();

    // Garante que a order tenha o company setado
    if (this.order!.company == null) {
      this.order!.company = Global.companyAggr;
    }

    // Atualiza a data de criação
    createdAt = order.createdAt;

    // Se não tiver data de criação, define uma
    if (this.order!.createdAt == null) {
      this.order!.createdAt = DateTime.now();
      createdAt = this.order!.createdAt;
    }

    // Configura o stream se tiver ID
    if (orderId != null && companyId != null) {
      this.order!.id = orderId;
      orderStream = repository.streamSingle(companyId!, orderId).asObservable();
      formsStream = formsService
          .getOrderForms(companyId!, orderId)
          .asObservable();
    }

    customer = order.customer;
    devices = order.effectiveDevices.asObservable();
    device = devices.isNotEmpty ? devices.first : null;
    services = order.services?.asObservable() ?? ObservableList<OrderService>();
    products = order.products?.asObservable() ?? ObservableList<OrderProduct>();
    photos = order.photos?.asObservable() ?? ObservableList<OrderPhoto>();
    documents =
        order.documents?.asObservable() ?? ObservableList<OrderDocument>();
    transactions =
        order.transactions?.asObservable() ??
        ObservableList<PaymentTransaction>();
    paidAmount = order.paidAmount ?? 0.0;
    dueDate = order.dueDate != null
        ? FormatService().formatDateTime(order.dueDate!)
        : dateToString(order.dueDate);
    scheduledDate = order.scheduledDate != null
        ? FormatService().formatDateTime(order.scheduledDate!)
        : null;
    status = order.status;
    hold = order.isOnHold ? order.onHold : null;
    address = order.address;
    latitude = order.latitude;
    longitude = order.longitude;
    hasContract = order.contract != null;
    updateTotal();
    updatePayment();
    loadChildOrders();
  }

  @action
  void loadChildOrders() {
    if (companyId == null || order?.id == null || !hasContract) {
      childOrders = null;
      return;
    }
    final tenantRepo = TenantOrderRepository();
    childOrders = tenantRepo
        .streamChildOrders(companyId!, order!.id!)
        .asObservable();
  }

  @action
  setCustomer(Customer? c) {
    if (c == null) return;

    // Evita operações desnecessárias para o mesmo cliente
    if (customer?.id == c.id) return;

    order!.customer = c.toAggr();
    customer = order!.customer;

    // Auto-fill address from customer if OS has no address yet
    if ((address == null || address!.isEmpty) &&
        c.address != null &&
        c.address!.isNotEmpty) {
      setAddress(c.address, lat: c.latitude, lng: c.longitude);
    }

    createItem();
  }

  @action
  setDevice(Device? d) {
    if (d == null) return;
    // If no devices yet, add as first
    if (devices.isEmpty) {
      addDevice(d);
      return;
    }
    // If already has devices, replace the first (legacy behavior)
    final aggr = d.toAggr();
    order!.devices = [aggr, ...order!.devices!.skip(1)];
    devices = order!.devices!.asObservable();
    order!.device = aggr;
    device = aggr;
    order!.syncDeviceIds();
    createItem();
  }

  @action
  void addDevice(Device d) {
    final aggr = d.toAggr();
    if (devices.any((e) => e.id == aggr.id)) return; // Prevent duplicates

    order!.devices ??= [];
    order!.devices!.add(aggr);
    devices.add(aggr);

    // Sync backward compat
    order!.device = order!.devices!.first;
    device = order!.device;
    order!.syncDeviceIds();

    createItem();
  }

  @action
  void removeDevice(String deviceId) {
    order!.devices?.removeWhere((d) => d.id == deviceId);
    devices.removeWhere((d) => d.id == deviceId);

    // Sync backward compat
    order!.device = order!.devices?.isNotEmpty == true
        ? order!.devices!.first
        : null;
    device = order!.device;
    order!.syncDeviceIds();

    // Orphan cleanup: items linked to removed device become global
    for (final s in order!.services ?? <OrderService>[]) {
      if (s.deviceId == deviceId) s.deviceId = null;
    }
    for (final p in order!.products ?? <OrderProduct>[]) {
      if (p.deviceId == deviceId) p.deviceId = null;
    }
    services = order!.services?.asObservable() ?? ObservableList();
    products = order!.products?.asObservable() ?? ObservableList();

    updateTotal();
    createItem();
  }

  /// "Responsável" of the order; null removes it.
  setAssignedTo(UserAggr? user) {
    order!.assignedTo = user;
    createItem();
  }

  setDueDate(DateTime date) {
    order!.dueDate = date;
    dueDate = FormatService().formatDateTime(date);
    createItem();
  }

  @action
  setScheduledDate(DateTime date, {ReminderStore? reminderStore}) {
    order!.scheduledDate = date;
    scheduledDate = FormatService().formatDateTime(date);
    createItem();
    scheduleReminder(reminderStore);
  }

  @action
  void setAddress(String? text, {double? lat, double? lng}) {
    order!.address = text;
    order!.latitude = lat;
    order!.longitude = lng;
    address = text;
    latitude = lat;
    longitude = lng;
    createItem();
  }

  @action
  clearScheduledDate() {
    if (order?.id != null) {
      NotificationService.instance.cancelOrderReminder(order!.id!);
    }
    order!.scheduledDate = null;
    scheduledDate = null;
    createItem();
  }

  // ═══════════════════════════════════════════════════════════════════
  // Contract methods
  // ═══════════════════════════════════════════════════════════════════

  @action
  void toggleContract(bool value) {
    if (order == null) return;
    hasContract = value;
    if (value) {
      order!.contract ??= OrderContract()
        ..frequency = 'monthly'
        ..interval = 1
        ..autoGenerate = true
        ..active = true
        ..reminderDaysBefore = 3
        ..startDate = DateTime.now()
        ..nextDueDate = DateTime(
          DateTime.now().year,
          DateTime.now().month + 1,
          DateTime.now().day,
        )
        ..generatedCount = 0;
      order!.isContract = true;
    } else {
      order!.contract = null;
      order!.isContract = null;
    }
    createItem();
  }

  @action
  void setContractFrequency(String frequency) {
    if (order?.contract == null) return;
    order!.contract!.frequency = frequency;
    // Recompute nextDueDate based on new frequency
    order!.contract!.nextDueDate =
        order!.contract!.computeNextDueDate() ?? order!.contract!.startDate;
    createItem();
  }

  @action
  void setContractInterval(int interval) {
    if (order?.contract == null) return;
    order!.contract!.interval = interval;
    order!.contract!.nextDueDate =
        order!.contract!.computeNextDueDate() ?? order!.contract!.startDate;
    createItem();
  }

  @action
  void setContractStartDate(DateTime date) {
    if (order?.contract == null) return;
    order!.contract!.startDate = date;
    order!.contract!.nextDueDate =
        order!.contract!.computeNextDueDate() ?? date;
    createItem();
  }

  @action
  void setContractEndDate(DateTime? date) {
    if (order?.contract == null) return;
    order!.contract!.endDate = date;
    createItem();
  }

  @action
  void setContractAutoGenerate(bool value) {
    if (order?.contract == null) return;
    order!.contract!.autoGenerate = value;
    createItem();
  }

  @action
  void setContractReminderDays(int days) {
    if (order?.contract == null) return;
    order!.contract!.reminderDaysBefore = days;
    createItem();
  }

  /// Generate an Order from a contract template
  Future<Order?> generateOrderFromContract(Order template) async {
    if (companyId == null || template.id == null) return null;
    final contract = template.contract;
    final due = contract?.nextDueDate;
    if (contract == null || due == null) return null;

    final now = DateTime.now();
    final company = Global.companyAggr;

    // One transaction that reads the template again (the list may come from
    // the cache): the order of this due date is created only if the contract
    // still generates it (not stopped or paused on the web, not moved by
    // another device or the server job) and nobody created it, from the
    // fresh template; only the `contract.*` fields that move are written.
    return TenantOrderRepository().createContractOrder(
      companyId!,
      templateId: template.id!,
      due: due,
      now: now,
      build: (fresh) => buildContractOrder(fresh, now: now, company: company),
    );
  }

  /// Check and auto-generate orders for all due contracts (called on app startup)
  Future<int> checkAndGenerateDueOrders() async {
    if (companyId == null) {
      print('[Contracts] companyId is null, skipping');
      return 0;
    }

    // Generating creates orders: only for who can create them (the manager
    // can't). Consultant and technician generate from their own contracts
    // (the contract query is scoped to them in TenantOrderRepository).
    final role = await _authService.resolveCurrentRole();
    if (!canGenerateContractOrders(role)) return 0;

    try {
      final tenantRepo = TenantOrderRepository();
      final orders = await tenantRepo.streamContractOrders(companyId!).first;
      print('[Contracts] Found ${orders.length} contract orders');

      for (final o in orders.whereType<Order>()) {
        print(
          '[Contracts] Order #${o.number}: isDue=${o.contract?.isDue}, autoGenerate=${o.contract?.autoGenerate}, nextDueDate=${o.contract?.nextDueDate}, active=${o.contract?.active}',
        );
      }

      final userId = Global.currentUser?.uid;
      final dueOrders = orders
          .whereType<Order>()
          .where(
            (o) =>
                o.contract?.isDue == true &&
                o.contract?.autoGenerate == true &&
                canGenerateFromTemplate(
                  role: role,
                  userId: userId,
                  template: o,
                ),
          )
          .toList();

      print('[Contracts] ${dueOrders.length} due orders to generate');

      int generated = 0;
      for (final template in dueOrders) {
        if (await generateOrderFromContract(template) != null) generated++;
      }
      print('[Contracts] Generated $generated orders');
      return generated;
    } catch (e, stack) {
      print('[Contracts] Error: $e');
      print('[Contracts] Stack: $stack');
      return 0;
    }
  }

  /// Schedule a local reminder for the current order. A new order only has
  /// an id after "✓", so the new order screen calls this once it is saved.
  void scheduleReminder(ReminderStore? reminderStore) {
    final orderId = order?.id;
    final date = order?.scheduledDate;
    final minutes = reminderStore?.reminderMinutes ?? 0;
    if (orderId == null || date == null || minutes <= 0) return;

    final text = OrderReminderText.of(order!);
    final companyId = Global.companyAggr?.id;

    NotificationService.instance.scheduleOrderReminder(
      orderId: orderId,
      title: text.title,
      body: text.body,
      scheduledDate: date,
      minutesBefore: minutes,
      companyId: companyId,
    );
  }

  /// Resolves when the server has the new status and fails when it refused
  /// it (never resolves offline). Null when nothing was written.
  @action
  Future<void>? setStatus(String? status) {
    if (status == null) return null;
    final previousPayment = order!.payment;
    _holdBeforeStatus = order!.onHold;
    order!.status = status;
    this.status = status;
    updatePayment();
    final saved = createItem();
    // Done, canceled or back to quote: the "parada" mark no longer applies.
    // If this write fails the mark stays hidden and the order trigger removes
    // it, so there is nothing to undo.
    if (order!.onHold != null && !order!.canBeOnHold) {
      _saveHold(null, undoOnFailure: false);
    }
    // createItem no longer writes `payment`: persist the status-driven change.
    if (order!.id != null && order!.payment != previousPayment) {
      final clear = OrderPaymentMath.orderStatusPaymentUpdate(status);
      if (clear != null) {
        // quote/canceled → payment null: offline-safe, no fresh state needed
        order!.paid = false;
        _queuePaymentFieldUpdate(order!.id!, clear, Global.userAggr);
      } else {
        // Back to an active status: recompute locally, offline-safe
        final update = OrderPaymentMath.activeStatusPaymentUpdate(
          total: order!.total ?? 0.0,
          paidAmount: order!.paidAmount ?? 0.0,
        );
        order!.payment = update['payment'] as String?;
        order!.paid = update['paid'] as bool?;
        _queuePaymentFieldUpdate(order!.id!, update, Global.userAggr);
      }
    }
    return saved;
  }

  /// "Parada" mark before the last [setStatus], for [restoreStatus].
  OrderHold? _holdBeforeStatus;

  /// Puts the status back on screen after the server refused [setStatus]: the
  /// server never took the new one. The "parada" mark [setStatus] took away
  /// comes back too, and is written again, because that separate write may
  /// have gone through.
  @action
  void restoreStatus(String? status) {
    order?.status = status;
    this.status = status;
    updatePayment();
    final mark = _holdBeforeStatus;
    if (mark != null && order?.onHold == null) {
      _saveHold(mark, undoOnFailure: false);
    }
  }

  /// Marks the saved order "parada" from now on. The status stays the same.
  /// [onSaved] runs once the server accepted it; when it refuses, the mark is
  /// undone and [onFailed] runs.
  @action
  void markOnHold({
    required String reason,
    String? note,
    VoidCallback? onSaved,
    VoidCallback? onFailed,
  }) {
    final current = order;
    if (current == null || current.id == null || !current.canBeOnHold) return;
    final text = note?.trim() ?? '';
    _saveHold(
      OrderHold()
        ..reason = reason
        ..note = text.isEmpty ? null : text
        ..since = holdClock().toUtc(),
      onSaved: onSaved,
      onFailed: onFailed,
    );
  }

  /// "Retomar": removes the mark, the status stays the same. [onSaved] and
  /// [onFailed] work as in [markOnHold].
  @action
  void resumeHold({VoidCallback? onSaved, VoidCallback? onFailed}) {
    if (order?.id == null || order?.onHold == null) return;
    _saveHold(null, onSaved: onSaved, onFailed: onFailed);
  }

  /// Updates the screen at once and queues the write without waiting for it:
  /// offline it only resolves when the connection is back, so the mark shows
  /// right away. A refused write brings the previous state back, unless the
  /// mark changed again in the meantime.
  void _saveHold(
    OrderHold? next, {
    VoidCallback? onSaved,
    VoidCallback? onFailed,
    bool undoOnFailure = true,
  }) {
    final target = order;
    final orderId = target?.id;
    final previous = target?.onHold;
    target?.onHold = next;
    hold = next;
    final company = companyId;
    if (orderId == null || company == null) {
      onSaved?.call();
      return;
    }
    Future.sync(() => writeHold(company, orderId, next)).then(
      (_) => onSaved?.call(),
      onError: (Object e) {
        debugPrint('Could not save the order hold mark: $e');
        if (!undoOnFailure) return;
        if (identical(target?.onHold, next)) {
          runInAction(() {
            target?.onHold = previous;
            if (identical(order, target)) {
              hold = target!.isOnHold ? previous : null;
            }
          });
        }
        onFailed?.call();
      },
    );
  }

  String dateToString(DateTime? date) {
    if (date == null) return 'Não definida';
    return FormatService().formatDate(date);
  }

  @action
  updateOrder() {
    services = order!.services!.asObservable();
    products = order!.products!.asObservable();
    updatePayment();
    updateTotal();
    createItem();
  }

  @action
  Future<void> deleteOrder() {
    if (companyId == null) return Future.value();
    return repository.removeItem(companyId!, order!.id);
  }

  /// Computes the payment label shown in the UI (display only).
  /// Persistence of payment fields happens only through updatePayments.
  void updatePayment() {
    if (order == null) return;

    if (['quote', 'canceled'].contains(order!.status)) {
      order!.payment = null;
      payment = '';
      return;
    }

    if (order!.payment == null) {
      order!.payment = 'unpaid';
    }

    // Calcular display do payment baseado no valor pago
    final paid = order!.paidAmount ?? 0.0;
    if (order!.payment == 'paid') {
      payment = 'Pago';
    } else {
      // Se tem pagamento parcial, mostrar "Parcial" na UI
      payment = paid > 0 ? 'Parcial' : 'A receber';
    }
  }

  @action
  loadOrders(String? status) async {
    if (companyId == null) return;

    orderList = repository
        .streamOrders(
          companyId!,
          status: status,
          customerId: customerFilter?.id,
        )
        .asObservable();

    if (orderList!.hasError) {
      print(orderList!.error);
    }

    print(orderList);
  }

  @action
  addService(OrderService orderService) {
    // Copia a foto do serviço se existir
    if (orderService.service?.photo != null) {
      orderService.photo = orderService.service?.photo;
    }

    if (pendingDuplicateAll && devices.isNotEmpty) {
      // Duplicate service for each device
      for (final d in devices) {
        final clone = OrderService()
          ..service = orderService.service
          ..description = orderService.description
          ..value = orderService.value
          ..photo = orderService.photo
          ..deviceId = d.id;
        order!.services!.add(clone);
        services!.add(clone);
      }
      pendingDuplicateAll = false;
      pendingDeviceId = null;
      pendingDeviceIds = null;
    } else if (pendingDeviceIds != null && pendingDeviceIds!.isNotEmpty) {
      // Multi-specific: duplicate for selected devices
      for (final deviceId in pendingDeviceIds!) {
        final clone = OrderService()
          ..service = orderService.service
          ..description = orderService.description
          ..value = orderService.value
          ..photo = orderService.photo
          ..deviceId = deviceId;
        order!.services!.add(clone);
        services!.add(clone);
      }
      pendingDeviceIds = null;
      pendingDeviceId = null;
    } else {
      // Apply pending deviceId if set
      if (pendingDeviceId != null) {
        orderService.deviceId = pendingDeviceId;
        pendingDeviceId = null;
      }
      order!.services!.add(orderService);
      services!.add(orderService);
    }

    updateTotal();
    createItem();
  }

  @action
  addProduct(OrderProduct orderProduct) {
    // Copia a foto do produto se existir
    if (orderProduct.product?.photo != null) {
      orderProduct.photo = orderProduct.product?.photo;
    }

    if (pendingDuplicateAll && devices.isNotEmpty) {
      // Duplicate product for each device
      for (final d in devices) {
        final clone = OrderProduct()
          ..product = orderProduct.product
          ..description = orderProduct.description
          ..value = orderProduct.value
          ..quantity = orderProduct.quantity
          ..total = orderProduct.total
          ..photo = orderProduct.photo
          ..deviceId = d.id;
        order!.products!.add(clone);
        products!.add(clone);
      }
      pendingDuplicateAll = false;
      pendingDeviceId = null;
      pendingDeviceIds = null;
    } else if (pendingDeviceIds != null && pendingDeviceIds!.isNotEmpty) {
      // Multi-specific: duplicate for selected devices
      for (final deviceId in pendingDeviceIds!) {
        final clone = OrderProduct()
          ..product = orderProduct.product
          ..description = orderProduct.description
          ..value = orderProduct.value
          ..quantity = orderProduct.quantity
          ..total = orderProduct.total
          ..photo = orderProduct.photo
          ..deviceId = deviceId;
        order!.products!.add(clone);
        products!.add(clone);
      }
      pendingDeviceIds = null;
      pendingDeviceId = null;
    } else {
      // Apply pending deviceId if set
      if (pendingDeviceId != null) {
        orderProduct.deviceId = pendingDeviceId;
        pendingDeviceId = null;
      }
      order!.products!.add(orderProduct);
      products!.add(orderProduct);
    }

    updateTotal();
    createItem();
  }

  @action
  deleteService(int index) {
    order!.services!.removeAt(index);
    services = order?.services?.asObservable();
    updateTotal();
    createItem();
  }

  @action
  deleteProduct(int index) {
    order!.products!.removeAt(index);
    products = order?.products?.asObservable();
    updateTotal();
    createItem();
  }

  /// After changing a line in place (value, quantity): refreshes the lists,
  /// the total and saves.
  @action
  void refreshLines() {
    services = order?.services?.asObservable();
    products = order?.products?.asObservable();
    updateTotal();
    createItem();
  }

  /// Puts a removed line back where it was ("Desfazer").
  @action
  void insertLine(Object line, int index) {
    if (line is OrderService) {
      final all = order!.services!;
      all.insert(index.clamp(0, all.length), line);
    } else if (line is OrderProduct) {
      final all = order!.products!;
      all.insert(index.clamp(0, all.length), line);
    }
    refreshLines();
  }

  /// Adiciona uma ou mais fotos da galeria
  /// Verifica limite de fotos do plano antes de permitir upload.
  /// Retorna false se limite atingido (photoLimitResult contera detalhes).
  @action
  Future<bool> addPhotoFromGallery() async {
    // Limite de fotos do plano efetivo da empresa (SubscriptionStore ao vivo)
    photoLimitResult = FeatureGateService.canAddPhoto(Global.subscription);
    if (!photoLimitResult!.isAllowed) {
      return false;
    }

    final List<File> files = await photoService.pickMultipleImagesFromGallery();
    if (files.isEmpty) return false;

    // Verificar se quantidade selecionada ultrapassa limite
    if (photoLimitResult != null && !photoLimitResult!.isUnlimited) {
      final remaining =
          photoLimitResult!.limit - photoLimitResult!.currentUsage;
      if (files.length > remaining) {
        // Atualizar resultado com mensagem especifica
        photoLimitResult = FeatureGateResult(
          isAllowed: false,
          currentUsage: photoLimitResult!.currentUsage,
          limit: photoLimitResult!.limit,
          featureType: photoLimitResult!.featureType,
          currentPlan: photoLimitResult!.currentPlan,
          message:
              'Voce selecionou ${files.length} fotos, mas so pode adicionar mais $remaining este mes.',
          suggestedPlan: photoLimitResult!.suggestedPlan,
        );
        return false;
      }
    }

    if (files.length == 1) {
      return await _uploadPhoto(files.first, source: 'gallery');
    } else {
      return await _uploadMultiplePhotos(files);
    }
  }

  /// Adiciona uma foto da câmera
  /// Verifica limite de fotos do plano antes de permitir upload.
  /// Retorna false se limite atingido (photoLimitResult contera detalhes).
  @action
  Future<bool> addPhotoFromCamera() async {
    // Limite de fotos do plano efetivo da empresa (SubscriptionStore ao vivo)
    photoLimitResult = FeatureGateService.canAddPhoto(Global.subscription);
    if (!photoLimitResult!.isAllowed) {
      return false;
    }

    final File? file = await photoService.takePhoto();
    if (file != null) {
      return await _uploadPhoto(file, source: 'camera');
    }
    return false;
  }

  /// Uploads the photos picked in the "Nova OS" sheet before the order
  /// existed. Called once the order has its id.
  Future<bool> uploadPhotoFiles(List<File> files) =>
      _uploadMultiplePhotos(files);

  /// Faz o upload de uma foto
  Future<bool> _uploadPhoto(File file, {String source = 'unknown'}) async {
    if (order == null || companyId == null) return false;

    // Garante que a OS seja salva antes do upload
    if (order!.id == null) {
      await repository.createItem(companyId!, order);
    }

    if (order!.id == null || order!.company?.id == null) return false;

    isUploadingPhoto = true;

    try {
      final OrderPhoto? photo = await photoService.uploadOrderPhoto(
        file: file,
        companyId: order!.company!.id!,
        orderId: order!.id!,
      );

      isUploadingPhoto = false;

      if (photo != null) {
        if (order!.photos == null) {
          order!.photos = [];
        }
        order!.photos!.add(photo);
        photos.add(photo);
        createItem();
        AnalyticsService.instance.logPhotoUploaded(source: source);
        return true;
      }
      return false;
    } catch (e) {
      isUploadingPhoto = false;
      print('Erro no upload da foto: $e');
      return false;
    }
  }

  /// Faz o upload de múltiplas fotos
  Future<bool> _uploadMultiplePhotos(List<File> files) async {
    if (order == null || companyId == null) return false;

    // Garante que a OS seja salva antes do upload
    if (order!.id == null) {
      await repository.createItem(companyId!, order);
    }

    if (order!.id == null || order!.company?.id == null) return false;

    isUploadingPhoto = true;
    int successCount = 0;

    try {
      if (order!.photos == null) {
        order!.photos = [];
      }

      for (final file in files) {
        try {
          final OrderPhoto? photo = await photoService.uploadOrderPhoto(
            file: file,
            companyId: order!.company!.id!,
            orderId: order!.id!,
          );

          if (photo != null) {
            order!.photos!.add(photo);
            photos.add(photo);
            successCount++;
            AnalyticsService.instance.logPhotoUploaded(source: 'gallery');
          }
        } catch (e) {
          print('Erro no upload de uma foto: $e');
        }
      }

      isUploadingPhoto = false;

      if (successCount > 0) {
        createItem();
        return true;
      }
      return false;
    } catch (e) {
      isUploadingPhoto = false;
      print('Erro no upload das fotos: $e');
      return false;
    }
  }

  /// Adds the photos and documents of [saved] (this same order, saved
  /// elsewhere, e.g. files shared from another app) that are not here yet.
  /// The payment fields (a receipt linked to a payment, a new payment) come
  /// from [saved] too: they are never written by a regular save, so taking
  /// the server state does not touch what is being edited. Nothing else
  /// changes, so the next save of this screen no longer drops them.
  @action
  void mergeAttachments(Order saved) {
    if (order == null || saved.id == null || saved.id != order!.id) return;
    if (saved.transactions != null) _applyPaymentState(saved);
    String? keyOf(String? storagePath, String? url, String? id) =>
        storagePath ?? url ?? id;

    for (final p in saved.photos ?? const <OrderPhoto>[]) {
      final key = keyOf(p.storagePath, p.url, p.id);
      if (key == null) continue;
      bool has(OrderPhoto x) => keyOf(x.storagePath, x.url, x.id) == key;
      final local = order!.photos ??= [];
      if (!local.any(has)) local.add(p);
      if (!photos.any(has)) photos.add(p);
    }
    for (final d in saved.documents ?? const <OrderDocument>[]) {
      final key = keyOf(d.storagePath, d.url, d.id);
      if (key == null) continue;
      bool has(OrderDocument x) => keyOf(x.storagePath, x.url, x.id) == key;
      final local = order!.documents ??= [];
      if (!local.any(has)) local.add(d);
      if (!documents.any(has)) documents.add(d);
    }
  }

  /// Remove uma foto pelo índice
  @action
  Future<bool> deletePhoto(int index) async {
    if (order == null ||
        order!.photos == null ||
        index >= order!.photos!.length) {
      return false;
    }

    final OrderPhoto photo = order!.photos![index];

    if (photo.storagePath != null) {
      final bool deleted = await photoService.deletePhoto(photo.storagePath!);
      if (!deleted) return false;
    }

    order!.photos!.removeAt(index);
    photos.removeAt(index);
    createItem();
    return true;
  }

  /// Reordena as fotos (move uma foto para a posição de capa)
  @action
  void setPhotoCover(int index) {
    if (order == null ||
        order!.photos == null ||
        index >= order!.photos!.length) {
      return;
    }

    final OrderPhoto photo = order!.photos!.removeAt(index);
    order!.photos!.insert(0, photo);

    final OrderPhoto observablePhoto = photos.removeAt(index);
    photos.insert(0, observablePhoto);

    createItem();
  }

  // ============================================================
  // DOCUMENT MANAGEMENT
  // ============================================================

  /// Adds a document to the order
  @action
  Future<bool> addDocument(
    File file,
    OrderDocumentType type,
    String contentType,
    String fileName, {
    String? description,
    int? fileSize,
  }) async {
    if (order == null || companyId == null) return false;

    // Ensure order is saved first
    if (order!.id == null) {
      await repository.createItem(companyId!, order);
    }

    if (order!.id == null || order!.company?.id == null) return false;

    isUploadingDocument = true;

    try {
      final OrderDocument? doc = await photoService.uploadOrderDocument(
        file: file,
        companyId: order!.company!.id!,
        orderId: order!.id!,
        contentType: contentType,
        fileName: fileName,
        fileSize: fileSize,
      );

      isUploadingDocument = false;

      if (doc != null) {
        doc.type = type;
        doc.description = description;

        order!.documents ??= [];
        order!.documents!.add(doc);
        documents.add(doc);
        createItem();
        return true;
      }
      return false;
    } catch (e) {
      isUploadingDocument = false;
      print('Erro no upload do documento: $e');
      return false;
    }
  }

  /// Deletes a document by index
  @action
  Future<bool> deleteDocument(int index) async {
    if (order == null ||
        order!.documents == null ||
        index >= order!.documents!.length) {
      return false;
    }

    final doc = order!.documents![index];

    // A customer receipt file is shared with other orders: keep it.
    if (doc.storagePath != null && !doc.isSharedReceiptFile) {
      final deleted = await photoService.deletePhoto(doc.storagePath!);
      if (!deleted) return false;
    }

    order!.documents!.removeAt(index);
    documents.removeAt(index);
    createItem();

    // If this document is a receipt linked to a transaction, clear the reference
    final linkedId = doc.linkedTransactionId;
    if (linkedId != null) {
      final linked = (order!.transactions ?? const <PaymentTransaction>[])
          .where((t) => t.id == linkedId)
          .toList();
      if (linked.isNotEmpty) {
        await _runPaymentUpdate(
          (fresh) => OrderPaymentMath.setReceipt(fresh, linked.first, null),
        );
      }
    }
    return true;
  }

  // ============================================================
  // RECEIPT MANAGEMENT (PAYMENT TRANSACTIONS)
  // ============================================================

  /// Attaches a receipt to a payment transaction as an OrderDocument
  @action
  Future<bool> attachReceiptToTransaction(
    int index,
    File file,
    String contentType,
    String fileName,
  ) async {
    lastPaymentFailure = null;
    if (order == null ||
        companyId == null ||
        order!.id == null ||
        order!.company?.id == null ||
        order!.transactions == null ||
        index >= order!.transactions!.length) {
      lastPaymentFailure = PaymentUpdateFailure.failed;
      return false;
    }

    final transaction = order!.transactions![index];

    isUploadingDocument = true;

    try {
      final doc = await photoService.uploadOrderDocument(
        file: file,
        companyId: order!.company!.id!,
        orderId: order!.id!,
        contentType: contentType,
        fileName: fileName,
      );

      isUploadingDocument = false;
      if (doc == null) {
        lastPaymentFailure = PaymentUpdateFailure.failed;
        return false;
      }

      doc.type = OrderDocumentType.receipt;
      doc.linkedTransactionId = transaction.id;

      // Documents are persisted by the regular order save
      order!.documents ??= [];
      order!.documents!.add(doc);
      documents.add(doc);
      createItem();

      // Transactions are persisted only through updatePayments
      return _runPaymentUpdate(
        (fresh) => OrderPaymentMath.setReceipt(fresh, transaction, doc.id),
      );
    } catch (e, stack) {
      isUploadingDocument = false;
      lastPaymentFailure = classifyPaymentUpdateFailure(e);
      _logPaymentError(e, stack, 'attachReceiptToTransaction');
      return false;
    }
  }

  /// Removes a receipt from a payment transaction
  @action
  Future<bool> removeReceiptFromTransaction(int index) async {
    if (order == null ||
        order!.transactions == null ||
        index >= order!.transactions!.length) {
      return false;
    }

    final transaction = order!.transactions![index];
    final docId = transaction.receiptDocumentId;
    if (docId == null) return false;

    final ok = await _runPaymentUpdate(
      (fresh) => OrderPaymentMath.setReceipt(fresh, transaction, null),
    );
    if (!ok) return false;

    await _deleteOrderDocumentById(docId);
    createItem();
    return true;
  }

  /// Deletes an OrderDocument from storage and from the local lists.
  /// The caller persists the documents list with createItem().
  Future<void> _deleteOrderDocumentById(String docId) async {
    final docIndex = order!.documents?.indexWhere((d) => d.id == docId) ?? -1;
    if (docIndex < 0) return;
    final doc = order!.documents![docIndex];
    // A customer receipt file is shared with other orders: keep it.
    if (doc.storagePath != null && !doc.isSharedReceiptFile) {
      await photoService.deletePhoto(doc.storagePath!);
    }
    order!.documents!.removeAt(docIndex);
    documents.removeWhere((d) => d.id == docId);
  }

  @action
  setDiscount(double value) {
    order!.discount = value;
    discount = value;
    updateTotal();
    createItem();
  }

  // ============================================================
  // PAYMENTS
  // Adding a payment/discount: field transforms (arrayUnion/increment),
  // offline-safe, applied optimistically to the local state.
  // Remove / reset / mark as paid / receipts / status: updatePayments
  // (runTransaction, needs connection).
  // A full order save (createItem) never writes payment fields.
  // ============================================================

  /// Why the last payment operation failed (null when it succeeded).
  /// Read by the UI to pick the error message.
  PaymentUpdateFailure? lastPaymentFailure;

  /// Latest offline-safe payment write. Transactions wait for it (bounded)
  /// so they read a server state that already contains it.
  Future<void>? _pendingPaymentFieldWrite;

  @visibleForTesting
  set pendingPaymentFieldWriteForTest(Future<void>? write) =>
      _pendingPaymentFieldWrite = write;

  /// Transactions added offline whose write the server hasn't acknowledged
  /// yet (by id). Kept when the local state is refreshed from a transaction.
  final Map<String, PaymentTransaction> _pendingTransactions = {};

  String _newTransactionId() =>
      DateTime.now().millisecondsSinceEpoch.toString();

  void _logPaymentError(Object error, StackTrace stack, String operation) {
    print('[OrderStore] $operation failed: $error');
    if (classifyPaymentUpdateFailure(error) != PaymentUpdateFailure.failed) {
      return; // offline / Asaas lock are expected, not bugs
    }
    try {
      FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        reason: 'OrderStore.$operation',
        fatal: false,
      );
    } catch (_) {
      // Crashlytics unavailable (e.g. not initialized): print is enough
    }
  }

  /// Sends an offline-safe payment update without awaiting the server ack
  /// (the Future only resolves when the server confirms, so awaiting it
  /// would hang offline). Returns false only if the write couldn't be queued.
  bool _queuePaymentFieldUpdate(
    String orderId,
    Map<String, dynamic> update,
    UserAggr? actor, {
    PaymentTransaction? transaction,
  }) {
    final pendingId = transaction?.id;
    try {
      if (pendingId != null) _pendingTransactions[pendingId] = transaction!;
      final write = repository
          .applyPaymentFieldUpdate(companyId!, orderId, update, actor: actor)
          .catchError((Object e, StackTrace stack) {
            _logPaymentError(e, stack, 'applyPaymentFieldUpdate');
          })
          .whenComplete(() {
            if (pendingId != null) _pendingTransactions.remove(pendingId);
          });
      _pendingPaymentFieldWrite = write;
      return true;
    } catch (e, stack) {
      if (pendingId != null) _pendingTransactions.remove(pendingId);
      lastPaymentFailure = classifyPaymentUpdateFailure(e);
      _logPaymentError(e, stack, 'applyPaymentFieldUpdate');
      return false;
    }
  }

  /// Runs [mutate] on the fresh order inside a Firestore transaction and
  /// refreshes the local state from the result. Returns false when it can't
  /// be saved; [lastPaymentFailure] says why (offline → requiresConnection).
  Future<bool> _runPaymentUpdate(Order Function(Order fresh) mutate) async {
    lastPaymentFailure = null;
    if (order == null || companyId == null) {
      lastPaymentFailure = PaymentUpdateFailure.failed;
      return false;
    }
    try {
      if (order!.id == null) {
        // New order not saved yet: save it before touching payments
        await repository.createItem(companyId!, order);
      }

      // An offline write not acknowledged in time means no connection:
      // stop here instead of reading a server state without it.
      final notAcked = await waitForPendingPaymentWrite(
        _pendingPaymentFieldWrite,
      );
      if (notAcked != null) {
        lastPaymentFailure = notAcked;
        return false;
      }

      final fresh = await repository.updatePayments(
        companyId!,
        order!.id!,
        mutate,
        actor: Global.userAggr,
      );
      if (fresh == null) {
        lastPaymentFailure = PaymentUpdateFailure.failed;
        return false;
      }
      _applyPaymentState(fresh);
      return true;
    } catch (e, stack) {
      lastPaymentFailure = classifyPaymentUpdateFailure(e);
      _logPaymentError(e, stack, 'updatePayments');
      return false;
    }
  }

  /// Reads the order from the server. Test seam for [reloadPayments].
  late Future<Order?> Function(String companyId, String orderId)
  fetchOrderFromServer = repository.getFromServer;

  /// Re-reads the order from the server and refreshes the local payment
  /// state (transactions, paidAmount, paid, payment, discount and total).
  ///
  /// [orderStream] doesn't refresh the payment fields, so the screen calls
  /// this when an Asaas charge is paid or refunded by the webhook.
  /// Returns false when it couldn't read (offline, missing order) or the
  /// store moved to another order meanwhile.
  @action
  Future<bool> reloadPayments() async {
    final orderId = order?.id;
    final company = companyId;
    if (orderId == null || company == null) return false;
    try {
      // Same wait as _runPaymentUpdate: reading before an offline write is
      // acknowledged would revert it locally. Not acknowledged in time →
      // skip this reload (the local state already has the write).
      if (await waitForPendingPaymentWrite(_pendingPaymentFieldWrite) != null) {
        return false;
      }
      final fresh = await fetchOrderFromServer(company, orderId);
      if (fresh == null || order?.id != orderId) return false;
      _applyPaymentState(fresh);
      return true;
    } catch (e, stack) {
      _logPaymentError(e, stack, 'reloadPayments');
      return false;
    }
  }

  /// Copies the payment fields of [fresh] into the local order and observables.
  /// Transactions added offline and not yet acknowledged are kept (see
  /// [OrderPaymentMath.mergePendingTransactions]).
  void _applyPaymentState(Order fresh) {
    if (order == null) return;
    OrderPaymentMath.mergePendingTransactions(
      fresh,
      _pendingTransactions.values.toList(),
    );
    order!.transactions = fresh.transactions ?? [];
    order!.paidAmount = fresh.paidAmount ?? 0.0;
    order!.paid = fresh.paid;
    order!.payment = fresh.payment;
    order!.discount = fresh.discount ?? 0.0;
    _syncPaymentObservables();
  }

  /// Refreshes the payment observables from the local order.
  void _syncPaymentObservables() {
    runInAction(() {
      if (order == null) return;
      transactions = ObservableList<PaymentTransaction>.of(
        order!.transactions ?? const <PaymentTransaction>[],
      );
      paidAmount = order!.paidAmount ?? 0.0;
      updateTotal();
      updatePayment();
    });
  }

  /// Adiciona um pagamento parcial. Funciona offline: grava com
  /// arrayUnion/increment e atualiza o estado local na hora. Retorna a
  /// transação criada, ou null se não foi possível registrar. [paidAt] é o
  /// dia em que o dinheiro entrou ("Quando"), escolhido na tela.
  @action
  Future<PaymentTransaction?> addPayment(
    double amount, {
    String? description,
    DateTime? paidAt,
    String? paymentMethod,
  }) async {
    lastPaymentFailure = null;
    if (order == null || companyId == null || amount <= 0) return null;
    // Same rule as the API (PAYMENT_EXCEEDS_BALANCE), on the order the app
    // has: never more than what is left to receive.
    try {
      OrderPaymentMath.assertPaymentWithinBalance(order!, amount);
    } on PaymentExceedsBalanceException {
      lastPaymentFailure = PaymentUpdateFailure.exceedsBalance;
      return null;
    }

    final actor = Global.userAggr;
    final transaction = PaymentTransaction.payment(
      amount: amount,
      description: description,
      createdBy: actor,
      paidAt: paidAt,
      paymentMethod: paymentMethod,
    );
    transaction.id = _newTransactionId();

    final orderId = order!.id;
    if (orderId != null) {
      // Update map is computed from the state before the local change
      final update = OrderPaymentMath.addPaymentUpdate(
        current: order!,
        tx: transaction,
      );
      if (!_queuePaymentFieldUpdate(
        orderId,
        update,
        actor,
        transaction: transaction,
      )) {
        return null;
      }
    }

    OrderPaymentMath.addPayment(order!, transaction);
    _syncPaymentObservables();
    // New order (not saved yet): the first full save includes the payment
    if (orderId == null) createItem();

    AnalyticsService.instance.logPaymentAdded(amount: amount);
    return transaction;
  }

  /// Adiciona um desconto como transação (reduz o total da OS).
  /// Funciona offline, como [addPayment].
  @action
  Future<bool> addDiscountTransaction(
    double amount, {
    String? description,
  }) async {
    lastPaymentFailure = null;
    if (order == null || companyId == null || amount <= 0) return false;

    final actor = Global.userAggr;
    final transaction = PaymentTransaction.discount(
      amount: amount,
      description: description,
      createdBy: actor,
    );
    transaction.id = _newTransactionId();

    final orderId = order!.id;
    if (orderId != null) {
      final update = OrderPaymentMath.addDiscountUpdate(
        current: order!,
        tx: transaction,
      );
      if (!_queuePaymentFieldUpdate(
        orderId,
        update,
        actor,
        transaction: transaction,
      )) {
        return false;
      }
    }

    OrderPaymentMath.addDiscount(order!, transaction);
    _syncPaymentObservables();
    if (orderId == null) createItem();
    return true;
  }

  /// Marca como totalmente pago (lança o saldo restante como pagamento).
  /// Precisa de conexão.
  @action
  Future<bool> markAsFullyPaid({String? description}) async {
    if (order == null) return false;

    final transactionId = _newTransactionId();
    final createdBy = Global.userAggr;

    return _runPaymentUpdate(
      (fresh) => OrderPaymentMath.markAsFullyPaid(fresh, (remaining) {
        final transaction = PaymentTransaction.payment(
          amount: remaining,
          description: description ?? 'Pagamento total',
          createdBy: createdBy,
        );
        transaction.id = transactionId;
        return transaction;
      }),
    );
  }

  /// Remove uma transação pelo índice. Transações do Asaas (`asaas_*`) não
  /// podem ser removidas aqui: o estorno é feito no Asaas. Precisa de conexão.
  @action
  Future<bool> removeTransaction(int index) async {
    lastPaymentFailure = null;
    if (order == null ||
        order!.transactions == null ||
        index >= order!.transactions!.length) {
      return false;
    }

    final transaction = order!.transactions![index];
    if (OrderPaymentMath.isAsaasTransaction(transaction)) {
      lastPaymentFailure = PaymentUpdateFailure.asaasLocked;
      return false;
    }

    final ok = await _runPaymentUpdate(
      (fresh) => OrderPaymentMath.removeTransaction(fresh, transaction),
    );
    if (!ok) return false;

    // Delete the receipt only after the transaction is gone
    final receiptId = transaction.receiptDocumentId;
    if (receiptId != null) {
      await _deleteOrderDocumentById(receiptId);
      createItem();
    }
    return true;
  }

  /// Resets all manual payments and discounts (and their receipts).
  /// Payments received through Asaas are kept. Precisa de conexão.
  @action
  Future<bool> resetAllPayments() async {
    if (order == null) return false;

    final removable = (order!.transactions ?? const <PaymentTransaction>[])
        .where((t) => !OrderPaymentMath.isAsaasTransaction(t))
        .toList();

    final ok = await _runPaymentUpdate(OrderPaymentMath.resetPayments);
    if (!ok) return false;

    var removedDocument = false;
    for (final transaction in removable) {
      final receiptId = transaction.receiptDocumentId;
      if (receiptId != null) {
        await _deleteOrderDocumentById(receiptId);
        removedDocument = true;
      }
    }
    if (removedDocument) createItem();
    return true;
  }

  updateTotal() {
    // Items without a price (null, "sem valor") are left out of the total.
    double temp = 0.0;
    order?.services?.forEach((s) {
      temp += s.value ?? 0;
    });

    order?.products?.forEach((p) {
      temp += productLineTotal(p) ?? 0;
    });

    if (order?.discount == null) order!.discount = 0.0;
    discount = order?.discount;
    temp -= order!.discount!;
    // A discount above the items leaves the total at 0, never negative.
    temp = OrderPaymentMath.floorAtZero(OrderPaymentMath.roundMoney(temp));

    final changed = order?.total != null && order!.total != temp;
    order?.total = temp;
    total = temp;
    if (changed) _refreshPaymentStatusAfterTotalChange();
  }

  /// A paid order whose items grew owes again (and a partly paid one whose
  /// items shrank is paid): the label follows the new total. Display only:
  /// a full save never writes `payment`/`paid`, the server recomputes them
  /// when `total` changes (onOrderUpdatedAsaas).
  void _refreshPaymentStatusAfterTotalChange() {
    final current = order;
    if (current == null || current.id == null || current.paidAmount == null) {
      return;
    }
    if (['quote', 'canceled'].contains(current.status)) return;
    final status = OrderPaymentMath.paymentStatusFor(
      total: current.total ?? 0.0,
      paidAmount: current.paidAmount ?? 0.0,
    );
    if (status == current.payment) return;
    current.payment = status;
    current.paid = status == 'paid';
    updatePayment();
  }

  /// [onCreated] runs once a new order has its id (used to add the
  /// customer's request as the first comment). On an existing order, resolves
  /// when the update reached the server.
  Future<void>? createItem({
    void Function(String orderId)? onCreated,
    void Function(Object error)? onError,
  }) {
    if (deferSave || order == null || companyId == null) return null;
    order!.syncDeviceIds();

    if (order!.id == null) {
      // The new-order sheet has already closed: errors go to [onError]
      // (and Crashlytics) instead of being lost.
      _createNewOrder(onCreated).catchError((Object e, StackTrace stack) {
        _logSaveError(e, stack, 'createOrder');
        onError?.call(e);
      });
    } else {
      // Atualiza OS existente: só os campos que mudaram desde a última
      // leitura ou gravação, para não apagar o que outro lado gravou.
      return _saveChangedFields().then((_) {
        if (orderStream == null || orderStream!.value?.id != order!.id) {
          orderStream = streamOrder(companyId!, order!.id).asObservable();
        }
      });
    }
    return null;
  }

  /// Creates the order (or reuses the one with the same number) and starts
  /// listening to it. Errors propagate to [createItem].
  Future<void> _createNewOrder(void Function(String orderId)? onCreated) async {
    final company = companyId!;
    final current = order!;
    if (current.number != null) {
      final existing = await findOrderByNumber(company, current.number!);
      if (existing != null) {
        current.id = existing.id;
        await repository.updateItem(company, current);
        _afterOrderCreated(company, current, onCreated, created: false);
        return;
      }
    }
    await createOrderDoc(company, current);
    _afterOrderCreated(company, current, onCreated, created: true);
  }

  void _afterOrderCreated(
    String company,
    Order saved,
    void Function(String orderId)? onCreated, {
    required bool created,
  }) {
    final id = saved.id;
    if (id == null) return;
    if (identical(order, saved)) {
      rememberSaved();
      orderStream = streamOrder(company, id).asObservable();
    }
    if (created) _logOrderCreated();
    onCreated?.call(id);
  }

  /// Live copy of a saved order. Replaceable in tests.
  @visibleForTesting
  late Stream<Order?> Function(String companyId, String? orderId) streamOrder =
      repository.streamSingle;

  /// Finds an order by number. Replaceable in tests.
  @visibleForTesting
  late Future<Order?> Function(String companyId, int number)
  findOrderByNumber = repository.getOrderByNumber;

  /// Writes a new order. Replaceable in tests.
  @visibleForTesting
  late Future<void> Function(String companyId, Order order) createOrderDoc =
      (companyId, order) => repository.createItem(companyId, order);

  void _logSaveError(Object e, StackTrace stack, String where) {
    debugPrint('OrderStore.$where failed: $e');
    try {
      unawaited(
        FirebaseCrashlytics.instance
            .recordError(e, stack, reason: 'OrderStore.$where', fatal: false)
            .catchError((_) {}),
      );
    } catch (_) {}
  }

  /// Writes the fields that differ from [_savedSnapshot]. Without a snapshot
  /// (order never read here), falls back to the full save. A refused write
  /// puts its fields back as unsaved, so the next save retries them.
  Future<void> _saveChangedFields() {
    // Only a snapshot of this same order is a base (the order may have been
    // swapped without setOrder): otherwise fall back to the full save.
    final orderId = order!.id!;
    final base = _savedSnapshotId == orderId ? _savedSnapshot : null;
    if (base == null) {
      return repository.updateItem(companyId!, order).then((_) {
        rememberSaved();
      });
    }
    final current = OrderFieldDiff.snapshotOf(order!);
    final changed = OrderFieldDiff.changedFields(base, current);
    if (changed.isEmpty) return Future.value();
    final previous = {
      for (final key in changed.keys)
        if (base.containsKey(key)) key: base[key],
    };
    _savedSnapshot = current;

    final Future<void> write;
    if (changed.keys.any(OrderFieldDiff.moneyFields.contains)) {
      // Items, discount and total go together, with the total recomputed
      // from what the server has (see TenantOrderRepository.updateMoney).
      final fields = Map.of(changed)
        ..removeWhere((key, _) => OrderFieldDiff.moneyFields.contains(key));
      final appMoney = {
        for (final key in OrderFieldDiff.moneyInputs)
          if (changed.containsKey(key)) key: changed[key],
      };
      final localMoney = {
        for (final key in OrderFieldDiff.moneyFields) key: current[key],
      };
      write = writeOrderMoney(
        companyId!,
        orderId,
        fields,
        appMoney,
        localMoney,
      );
    } else {
      write = writeOrderFields(companyId!, orderId, changed);
    }
    return write.catchError((Object e) {
      // A refusal can arrive late (offline, at sync): it only puts the
      // fields back as unsaved when the store still holds this order.
      final snapshot = _savedSnapshot;
      if (snapshot != null && _savedSnapshotId == orderId) {
        for (final key in changed.keys) {
          if (previous.containsKey(key)) {
            snapshot[key] = previous[key];
          } else {
            snapshot.remove(key);
          }
        }
      }
      throw e;
    });
  }

  void _logOrderCreated() {
    AnalyticsService.instance.logOrderCreated(
      orderId: order?.id,
      customerId: order?.customer?.id,
      deviceCount: order?.devices?.length ?? 0,
      itemCount:
          (order?.services?.length ?? 0) + (order?.products?.length ?? 0),
      totalValue: order?.total,
    );
  }

  @action
  setCustomerFilter(Customer? customerFilter) {
    this.customerFilter = customerFilter;
  }

  @action
  void setDashboardPeriod(String period) {
    selectedDashboardPeriod = period;
    periodOffset = 0;
    loadOrdersForDashboard();
  }

  @observable
  DateTime? customStartDate;

  @observable
  DateTime? customEndDate;

  @action
  void setCustomPeriod(String period, int offset) {
    selectedDashboardPeriod = period;
    periodOffset = offset;
    customStartDate = null;
    customEndDate = null;
    loadOrdersForDashboard();
  }

  @action
  void setCustomDateRange(DateTime start, DateTime end) {
    selectedDashboardPeriod = 'custom';
    periodOffset = 0;
    customStartDate = start;
    customEndDate = end;
    loadOrdersForDashboardCustomRange(start, end);
  }

  @action
  Future<void> loadOrdersForDashboardCustomRange(
    DateTime start,
    DateTime end,
  ) async {
    if (companyId == null) return;
    try {
      final orders = await repository.getOrdersByDateRange(
        companyId!,
        start,
        end,
      );

      // Sem orçamentos nem canceladas: mesma regra do Vendido
      var filteredOrders = orders.where(FinancialSummary.isSold).toList();

      // Aplicar filtro por cliente selecionado no ranking
      if (selectedCustomerInRanking != null) {
        String customerId = selectedCustomerInRanking!['id'];
        if (customerId == 'sem-cliente') {
          filteredOrders = filteredOrders
              .where((order) => order?.customer?.id == null)
              .toList();
        } else {
          filteredOrders = filteredOrders
              .where((order) => order?.customer?.id == customerId)
              .toList();
        }
      }

      // Calcular totais baseados nas ordens filtradas
      totalOrdersCount = filteredOrders.length;
      paidOrdersCount = filteredOrders
          .where((order) => order?.payment == 'paid')
          .length;

      // Calcular o faturamento total (soma de todos os valores)
      totalRevenue = filteredOrders.fold(
        0.0,
        (sum, order) => sum + (order?.total ?? 0.0),
      );

      // Calcular valores pagos e a receber (considerando pagamentos parciais)
      // Retrocompatibilidade: OSs antigas com payment='paid' mas sem paidAmount
      totalPaidAmount = filteredOrders.fold(0.0, (sum, order) {
        if (order?.payment == 'paid') {
          // Se está pago, usar paidAmount ou total (retrocompatibilidade)
          return sum + (order?.paidAmount ?? order?.total ?? 0.0);
        }
        return sum + (order?.paidAmount ?? 0.0);
      });

      totalUnpaidAmount = filteredOrders
          .where((order) => order?.payment != 'paid')
          .fold(0.0, (sum, order) {
            final total = order?.total ?? 0.0;
            final paid = order?.paidAmount ?? 0.0;
            return sum + (total - paid);
          });

      // Atualizar paymentStatusCounts para o gráfico
      paymentStatusCounts.clear();
      paymentStatusCounts['paid'] = totalPaidAmount;
      paymentStatusCounts['unpaid'] = totalUnpaidAmount;

      // Calcular os totais por cliente
      customerOrderTotals.clear();
      customerUnpaidTotals.clear();

      double semClienteTotal = 0.0;
      double semClienteUnpaid = 0.0;

      for (var order in filteredOrders) {
        if (order?.total != null) {
          final orderTotal = order!.total!;
          final orderPaid = order.paidAmount ?? 0.0;
          final orderUnpaid = order.payment != 'paid'
              ? (orderTotal - orderPaid)
              : 0.0;

          if (order.customer?.id != null) {
            String customerId = order.customer!.id!;
            double currentTotal = customerOrderTotals[customerId] ?? 0.0;
            customerOrderTotals[customerId] = currentTotal + orderTotal;

            if (orderUnpaid > 0) {
              double currentUnpaid = customerUnpaidTotals[customerId] ?? 0.0;
              customerUnpaidTotals[customerId] = currentUnpaid + orderUnpaid;
            }
          } else {
            semClienteTotal += orderTotal;
            if (orderUnpaid > 0) {
              semClienteUnpaid += orderUnpaid;
            }
          }
        }
      }

      // Gerar o ranking de clientes
      customerRanking.clear();

      if (semClienteTotal > 0) {
        customerRanking.add({
          'id': 'sem-cliente',
          'name': 'Sem Cliente',
          'total': semClienteTotal,
          'unpaidTotal': semClienteUnpaid,
        });
      }

      customerOrderTotals.forEach((customerId, total) {
        if (total > 0) {
          var customerName =
              filteredOrders
                  .firstWhere(
                    (order) => order?.customer?.id == customerId,
                    orElse: () => null,
                  )
                  ?.customer
                  ?.name ??
              'Cliente sem nome';

          customerRanking.add({
            'id': customerId,
            'name': customerName,
            'total': total,
            'unpaidTotal': customerUnpaidTotals[customerId] ?? 0.0,
          });
        }
      });

      sortCustomerRanking();

      // Aplicar filtro de pagamento nas ordens recentes
      if (paymentFilter != null) {
        filteredOrders = filteredOrders
            .where((order) => order?.payment == paymentFilter)
            .toList();
      }

      // Ordenar ordens por data de atualização
      filteredOrders.sort((a, b) {
        if (a?.updatedAt == null || b?.updatedAt == null) return 0;
        return b!.updatedAt!.compareTo(a!.updatedAt!);
      });

      recentOrders.clear();
      recentOrders.addAll(filteredOrders);
    } catch (e) {
      print('Erro ao carregar dados para dashboard (custom range): $e');
    }
  }

  @action
  void setPaymentFilter(String? filter) {
    paymentFilter = filter;
    loadOrdersForDashboard();
  }

  @action
  Future<void> loadOrdersForDashboard() async {
    if (companyId == null) return;
    // Filters, customer and pull-to-refresh reload the chosen dates, not the
    // current month.
    final start = customStartDate;
    final end = customEndDate;
    if (selectedDashboardPeriod == 'custom' && start != null && end != null) {
      return loadOrdersForDashboardCustomRange(start, end);
    }
    try {
      final orders = await repository.getOrdersByCustomPeriod(
        companyId!,
        selectedDashboardPeriod,
        periodOffset,
      );

      // Sem orçamentos nem canceladas: mesma regra do Vendido
      var filteredOrders = orders.where(FinancialSummary.isSold).toList();

      // Aplicar filtro por cliente selecionado no ranking
      if (selectedCustomerInRanking != null) {
        String customerId = selectedCustomerInRanking!['id'];
        if (customerId == 'sem-cliente') {
          filteredOrders = filteredOrders
              .where((order) => order?.customer?.id == null)
              .toList();
        } else {
          filteredOrders = filteredOrders
              .where((order) => order?.customer?.id == customerId)
              .toList();
        }
      }

      // Calcular totais baseados nas ordens filtradas
      totalOrdersCount = filteredOrders.length;
      paidOrdersCount = filteredOrders
          .where((order) => order?.payment == 'paid')
          .length;

      // Calcular o faturamento total (soma de todos os valores)
      totalRevenue = filteredOrders.fold(
        0.0,
        (sum, order) => sum + (order?.total ?? 0.0),
      );

      // Calcular valores pagos e a receber (considerando pagamentos parciais)
      // Retrocompatibilidade: OSs antigas com payment='paid' mas sem paidAmount
      totalPaidAmount = filteredOrders.fold(0.0, (sum, order) {
        if (order?.payment == 'paid') {
          // Se está pago, usar paidAmount ou total (retrocompatibilidade)
          return sum + (order?.paidAmount ?? order?.total ?? 0.0);
        }
        return sum + (order?.paidAmount ?? 0.0);
      });

      totalUnpaidAmount = filteredOrders
          .where((order) => order?.payment != 'paid')
          .fold(0.0, (sum, order) {
            final total = order?.total ?? 0.0;
            final paid = order?.paidAmount ?? 0.0;
            return sum + (total - paid);
          });

      // Atualizar paymentStatusCounts para o gráfico
      paymentStatusCounts.clear();
      paymentStatusCounts['paid'] = totalPaidAmount;
      paymentStatusCounts['unpaid'] = totalUnpaidAmount;

      // Calcular os totais por cliente usando as mesmas ordens filtradas
      customerOrderTotals.clear();
      customerUnpaidTotals.clear();

      // Inicializar totais para ordens sem cliente
      double semClienteTotal = 0.0;
      double semClienteUnpaid = 0.0;

      for (var order in filteredOrders) {
        if (order?.total != null) {
          final orderTotal = order!.total!;
          final orderPaid = order.paidAmount ?? 0.0;
          final orderUnpaid = order.payment != 'paid'
              ? (orderTotal - orderPaid)
              : 0.0;

          if (order.customer?.id != null) {
            String customerId = order.customer!.id!;
            double currentTotal = customerOrderTotals[customerId] ?? 0.0;
            customerOrderTotals[customerId] = currentTotal + orderTotal;

            if (orderUnpaid > 0) {
              double currentUnpaid = customerUnpaidTotals[customerId] ?? 0.0;
              customerUnpaidTotals[customerId] = currentUnpaid + orderUnpaid;
            }
          } else {
            semClienteTotal += orderTotal;
            if (orderUnpaid > 0) {
              semClienteUnpaid += orderUnpaid;
            }
          }
        }
      }

      // Gerar o ranking de clientes
      customerRanking.clear();

      if (semClienteTotal > 0) {
        customerRanking.add({
          'id': 'sem-cliente',
          'name': 'Sem Cliente',
          'total': semClienteTotal,
          'unpaidTotal': semClienteUnpaid,
        });
      }

      customerOrderTotals.forEach((customerId, total) {
        if (total > 0) {
          var customerName =
              filteredOrders
                  .firstWhere(
                    (order) => order?.customer?.id == customerId,
                    orElse: () => null,
                  )
                  ?.customer
                  ?.name ??
              'Cliente sem nome';

          customerRanking.add({
            'id': customerId,
            'name': customerName,
            'total': total,
            'unpaidTotal': customerUnpaidTotals[customerId] ?? 0.0,
          });
        }
      });

      sortCustomerRanking();

      // Aplicar filtro de pagamento nas ordens recentes
      if (paymentFilter != null) {
        filteredOrders = filteredOrders
            .where((order) => order?.payment == paymentFilter)
            .toList();
      }

      // Ordenar ordens por data de atualização
      filteredOrders.sort((a, b) {
        if (a?.updatedAt == null || b?.updatedAt == null) return 0;
        return b!.updatedAt!.compareTo(a!.updatedAt!);
      });

      recentOrders.clear();
      recentOrders.addAll(filteredOrders);
    } catch (e) {
      print('Erro ao carregar dados para dashboard: $e');
    }
  }

  @action
  void sortCustomerRanking() {
    // Sempre ordenar por valor total, independente do rankingSortType
    customerRanking.sort(
      (a, b) => (b['total'] as double).compareTo(a['total'] as double),
    );
  }

  @action
  void setRankingSortType(String sortType) {
    rankingSortType = sortType;
    sortCustomerRanking();
  }

  @action
  void selectCustomerInRanking(Map<String, dynamic>? customerData) {
    selectedCustomerInRanking = customerData;
    loadOrdersForDashboard();
  }

  @action
  void clearCustomerRankingSelection() {
    selectedCustomerInRanking = null;
    loadOrdersForDashboard();
  }

  // Métodos para scroll infinito na Home
  @action
  Future<void> loadOrdersInfinite(String? status) async {
    final generation = ++_ordersGeneration;
    isLoading = true;
    _lastDocument = null;
    hasMoreOrders = true;
    ordersLoadFailed = false;
    orders.clear();

    // Resolved alongside the page's own query (same wait), to know which
    // `createdBy.id` filter the page was read with.
    final scope = TenantOrderRepository.creatorScope();
    await _fetchOrdersInfinite(status, generation);
    final usedScope = await scope;

    if (generation == _ordersGeneration) {
      isLoading = false;
      _reloadWhenScopeChanges(status, usedScope);
    }
  }

  StreamSubscription<OrderScope?>? _scopeWatch;

  /// The page may have been read with the provisional `createdBy.id` filter
  /// (role not loaded in time). When the role arrives and the filter is
  /// different, reload instead of keeping owner/admin filtered.
  void _reloadWhenScopeChanges(String? status, OrderScope? usedScope) {
    _scopeWatch?.cancel();
    _scopeWatch = TenantOrderRepository.creatorScopeChanges()
        .where((scope) => scope != usedScope)
        .listen((_) {
          _scopeWatch?.cancel();
          _scopeWatch = null;
          loadOrdersInfinite(status);
        });
  }

  @action
  Future<void> loadMoreOrdersInfinite(String? status) async {
    if (isLoading || !hasMoreOrders) return;

    final generation = _ordersGeneration;
    isLoading = true;
    await _fetchOrdersInfinite(status, generation);
    if (generation == _ordersGeneration) isLoading = false;
  }

  /// Bumped by every fresh [loadOrdersInfinite]. A fetch that started under
  /// an older generation is dropped, so two loads in flight (the Início
  /// reloads on every dependency change) can't both append their page.
  int _ordersGeneration = 0;

  /// One page of the Início list; replaceable in tests.
  Future<({List<Order> orders, firestore.DocumentSnapshot? last})> Function(
    String companyId,
    String? status,
    String? customerId,
    int limit,
    firestore.DocumentSnapshot? startAfter,
  )
  fetchOrdersPage = _fetchOrdersPageFromFirestore;

  static Future<({List<Order> orders, firestore.DocumentSnapshot? last})>
  _fetchOrdersPageFromFirestore(
    String companyId,
    String? status,
    String? customerId,
    int limit,
    firestore.DocumentSnapshot? startAfter,
  ) async {
    final snapshot = await OrderRepositoryV2().getOrdersWithPagination(
      companyId,
      status: status,
      customerId: customerId,
      limit: limit,
      startAfterDocument: startAfter,
    );
    final orders = snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return Order.fromJson(data);
    }).toList();
    return (
      orders: orders,
      last: snapshot.docs.isEmpty ? null : snapshot.docs.last,
    );
  }

  Future<void> _fetchOrdersInfinite(String? status, int generation) async {
    if (companyId == null) return;

    final limit = status == 'open' ? kOpenOrdersLimit : _limit;
    try {
      final page = await fetchOrdersPage(
        companyId!,
        status,
        customerFilter?.id,
        limit,
        _lastDocument,
      );
      if (generation != _ordersGeneration) return;

      if (page.orders.isEmpty) {
        hasMoreOrders = false;
        return;
      }

      _lastDocument = page.last;
      final newOrders = page.orders;

      final known = orders.map((o) => o?.id).toSet();
      orders.addAll(newOrders.where((o) => !known.contains(o.id)));

      // Verificar se há mais resultados
      if (newOrders.length < limit) {
        hasMoreOrders = false;
      }
    } catch (e) {
      if (generation != _ordersGeneration) return;
      print('Erro ao buscar ordens: $e');
      ordersLoadFailed = true;
      hasMoreOrders = false;
    }
  }
}
