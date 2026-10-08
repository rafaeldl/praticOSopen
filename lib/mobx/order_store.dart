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
import 'package:praticos/utils/order_payment_math.dart';
import 'package:praticos/utils/payment_update_failure.dart';
import 'package:praticos/models/permission.dart';
import 'package:praticos/services/authorization_service.dart';
import 'package:praticos/services/forms_service.dart';
import 'package:praticos/repositories/v2/order_repository_v2.dart';
import 'package:praticos/repositories/tenant/tenant_order_repository.dart';
import 'package:praticos/services/photo_service.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:mobx/mobx.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;

import 'package:praticos/global.dart';
import 'package:praticos/services/notification_service.dart';
import 'package:praticos/mobx/reminder_store.dart';
part 'order_store.g.dart';

class OrderStore = _OrderStore with _$OrderStore;

abstract class _OrderStore with Store {
  final OrderRepositoryV2 repository = OrderRepositoryV2();
  final PhotoService photoService = PhotoService();
  final FormsService formsService = FormsService();
  final AuthorizationService _authService = AuthorizationService.instance;

  Order? order;

  @observable
  ObservableStream<List<Order?>>? orderList;

  @observable
  ObservableStream<Order?>? orderStream;

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
    return totalValue - paid;
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
    return _authService.filterOrdersByPermission(
      ordersList.whereType<Order>().toList(),
    ).cast<Order?>();
  }

  /// Verifica se o usuário pode visualizar valores financeiros.
  @computed
  bool get canViewPrices => _authService.canViewPrices;

  /// Verifica se o usuário pode criar novas OS.
  @computed
  bool get canCreateOrder => _authService.hasPermission(
    PermissionType.createOrder,
  );

  /// Verifica se o usuário pode visualizar o dashboard financeiro.
  @computed
  bool get canViewFinancialDashboard => _authService.canViewFinancialReports;

  @observable
  bool isLoading = false;

  @observable
  bool hasMoreOrders = true;

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
      if (orderStream == null ||
          orderStream!.data == null ||
          order == null) {
        return;
      }

      // Atualiza o número da OS a partir do stream
      order!.number = orderStream!.data.number;
    });
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
      formsStream = formsService.getOrderForms(companyId!, orderId).asObservable();
    }

    customer = order.customer;
    devices = order.effectiveDevices.asObservable();
    device = devices.isNotEmpty ? devices.first : null;
    services = order.services?.asObservable() ?? ObservableList<OrderService>();
    products = order.products?.asObservable() ?? ObservableList<OrderProduct>();
    photos = order.photos?.asObservable() ?? ObservableList<OrderPhoto>();
    documents = order.documents?.asObservable() ?? ObservableList<OrderDocument>();
    transactions = order.transactions?.asObservable() ?? ObservableList<PaymentTransaction>();
    paidAmount = order.paidAmount ?? 0.0;
    dueDate = order.dueDate != null
        ? FormatService().formatDateTime(order.dueDate!)
        : dateToString(order.dueDate);
    scheduledDate = order.scheduledDate != null
        ? FormatService().formatDateTime(order.scheduledDate!)
        : null;
    status = order.status;
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
    childOrders = tenantRepo.streamChildOrders(companyId!, order!.id!).asObservable();
  }

  @action
  setCustomer(Customer? c) {
    if (c == null) return;

    // Evita operações desnecessárias para o mesmo cliente
    if (customer?.id == c.id) return;

    order!.customer = c.toAggr();
    customer = order!.customer;

    // Auto-fill address from customer if OS has no address yet
    if ((address == null || address!.isEmpty) && c.address != null && c.address!.isNotEmpty) {
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
    order!.device =
        order!.devices?.isNotEmpty == true ? order!.devices!.first : null;
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

  @action
  void removeDeviceAndItems(String deviceId) {
    order!.devices?.removeWhere((d) => d.id == deviceId);
    devices.removeWhere((d) => d.id == deviceId);

    // Sync backward compat
    order!.device =
        order!.devices?.isNotEmpty == true ? order!.devices!.first : null;
    device = order!.device;
    order!.syncDeviceIds();

    // Remove items linked to this device
    order!.services?.removeWhere((s) => s.deviceId == deviceId);
    order!.products?.removeWhere((p) => p.deviceId == deviceId);
    services = order!.services?.asObservable() ?? ObservableList();
    products = order!.products?.asObservable() ?? ObservableList();

    updateTotal();
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
    _scheduleReminder(reminderStore);
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
    order!.contract!.nextDueDate = order!.contract!.computeNextDueDate()
        ?? order!.contract!.startDate;
    createItem();
  }

  @action
  void setContractInterval(int interval) {
    if (order?.contract == null) return;
    order!.contract!.interval = interval;
    order!.contract!.nextDueDate = order!.contract!.computeNextDueDate()
        ?? order!.contract!.startDate;
    createItem();
  }

  @action
  void setContractStartDate(DateTime date) {
    if (order?.contract == null) return;
    order!.contract!.startDate = date;
    order!.contract!.nextDueDate = order!.contract!.computeNextDueDate() ?? date;
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

    final newOrder = Order()
      ..company = Global.companyAggr
      ..status = 'quote'
      ..payment = 'unpaid'
      ..createdAt = DateTime.now()
      ..createdBy = template.createdBy
      ..updatedAt = DateTime.now()
      ..updatedBy = template.createdBy
      ..customer = template.customer
      ..devices = template.devices != null ? List.from(template.devices!) : null
      ..device = template.device
      ..services = template.services?.map((s) => OrderService()
        ..service = s.service
        ..description = s.description
        ..value = s.value
      ).toList()
      ..products = template.products?.map((p) => OrderProduct()
        ..product = p.product
        ..description = p.description
        ..value = p.value
        ..quantity = p.quantity
        ..total = p.total
      ).toList()
      ..assignedTo = template.assignedTo
      ..contract = (OrderContract()
        ..parentOrderId = template.id
        ..parentOrderNumber = template.number);

    newOrder.syncDeviceIds();

    // Calculate total from services + products
    double total = 0;
    for (final s in newOrder.services ?? <OrderService>[]) {
      total += s.value ?? 0;
    }
    for (final p in newOrder.products ?? <OrderProduct>[]) {
      total += p.total ?? (p.value ?? 0) * (p.quantity ?? 1);
    }
    newOrder.total = total;

    final tenantRepo = TenantOrderRepository();
    await tenantRepo.createItem(companyId!, newOrder);

    // Update template contract tracking
    template.contract!.lastGeneratedDate = DateTime.now();
    template.contract!.generatedCount =
        (template.contract!.generatedCount ?? 0) + 1;
    template.contract!.nextDueDate =
        template.contract!.computeNextDueDate();

    // Deactivate if expired
    if (template.contract!.isExpired) {
      template.contract!.active = false;
    }

    await tenantRepo.updateItem(companyId!, template);

    return newOrder;
  }

  /// Check and auto-generate orders for all due contracts (called on app startup)
  Future<int> checkAndGenerateDueOrders() async {
    if (companyId == null) {
      print('[Contracts] companyId is null, skipping');
      return 0;
    }

    try {
      final tenantRepo = TenantOrderRepository();
      final orders = await tenantRepo.streamContractOrders(companyId!).first;
      print('[Contracts] Found ${orders.length} contract orders');

      for (final o in orders.whereType<Order>()) {
        print('[Contracts] Order #${o.number}: isDue=${o.contract?.isDue}, autoGenerate=${o.contract?.autoGenerate}, nextDueDate=${o.contract?.nextDueDate}, active=${o.contract?.active}');
      }

      final dueOrders = orders
          .whereType<Order>()
          .where((o) =>
              o.contract?.isDue == true &&
              o.contract?.autoGenerate == true)
          .toList();

      print('[Contracts] ${dueOrders.length} due orders to generate');

      int generated = 0;
      for (final template in dueOrders) {
        await generateOrderFromContract(template);
        generated++;
      }
      print('[Contracts] Generated $generated orders');
      return generated;
    } catch (e, stack) {
      print('[Contracts] Error: $e');
      print('[Contracts] Stack: $stack');
      return 0;
    }
  }

  /// Schedule a local reminder for the current order
  void _scheduleReminder(ReminderStore? reminderStore) {
    final orderId = order?.id;
    final date = order?.scheduledDate;
    final minutes = reminderStore?.reminderMinutes ?? 0;
    if (orderId == null || date == null || minutes <= 0) return;

    final orderNumber = order?.number?.toString() ?? '';
    final customerName = order?.customer?.name ?? '';
    final companyId = Global.companyAggr?.id;

    NotificationService.instance.scheduleOrderReminder(
      orderId: orderId,
      title: 'Agendamento em breve',
      body: 'OS #$orderNumber - $customerName',
      scheduledDate: date,
      minutesBefore: minutes,
      companyId: companyId,
    );
  }

  @action
  setStatus(String? status) {
    if (status == null) return;
    final previousPayment = order!.payment;
    order!.status = status;
    this.status = status;
    updatePayment();
    createItem();
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
  }

  String dateToString(DateTime? date) {
    if (date == null) return 'Não definida';
    return FormatService().formatDate(date);
  }

  @computed
  String get formattedCreatedDate {
    if (createdAt == null && order?.createdAt == null) return 'Data criação';
    DateTime date = createdAt ?? order!.createdAt!;
    return dateToString(date);
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
      final remaining = photoLimitResult!.limit - photoLimitResult!.currentUsage;
      if (files.length > remaining) {
        // Atualizar resultado com mensagem especifica
        photoLimitResult = FeatureGateResult(
          isAllowed: false,
          currentUsage: photoLimitResult!.currentUsage,
          limit: photoLimitResult!.limit,
          featureType: photoLimitResult!.featureType,
          currentPlan: photoLimitResult!.currentPlan,
          message: 'Voce selecionou ${files.length} fotos, mas so pode adicionar mais $remaining este mes.',
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

  /// Remove uma foto pelo índice
  @action
  Future<bool> deletePhoto(int index) async {
    if (order == null || order!.photos == null || index >= order!.photos!.length) {
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
    if (order == null || order!.photos == null || index >= order!.photos!.length) {
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

    if (doc.storagePath != null) {
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
  Future<bool> attachReceiptToTransaction(int index, File file,
      String contentType, String fileName) async {
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
    if (doc.storagePath != null) {
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
      }).whenComplete(() {
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
      final notAcked =
          await waitForPendingPaymentWrite(_pendingPaymentFieldWrite);
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
      if (await waitForPendingPaymentWrite(_pendingPaymentFieldWrite) !=
          null) {
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
        fresh, _pendingTransactions.values.toList());
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
          order!.transactions ?? const <PaymentTransaction>[]);
      paidAmount = order!.paidAmount ?? 0.0;
      updateTotal();
      updatePayment();
    });
  }

  /// Adiciona um pagamento parcial. Funciona offline: grava com
  /// arrayUnion/increment e atualiza o estado local na hora. Retorna a
  /// transação criada, ou null se não foi possível registrar.
  @action
  Future<PaymentTransaction?> addPayment(double amount,
      {String? description}) async {
    lastPaymentFailure = null;
    if (order == null || companyId == null || amount <= 0) return null;

    final actor = Global.userAggr;
    final transaction = PaymentTransaction.payment(
      amount: amount,
      description: description,
      createdBy: actor,
    );
    transaction.id = _newTransactionId();

    final orderId = order!.id;
    if (orderId != null) {
      // Update map is computed from the state before the local change
      final update = OrderPaymentMath.addPaymentUpdate(
        current: order!,
        tx: transaction,
      );
      if (!_queuePaymentFieldUpdate(orderId, update, actor,
          transaction: transaction)) {
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
  Future<bool> addDiscountTransaction(double amount,
      {String? description}) async {
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
      if (!_queuePaymentFieldUpdate(orderId, update, actor,
          transaction: transaction)) {
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
    double temp = 0.0;
    order?.services?.forEach((s) {
      temp += s.value!;
    });

    order?.products?.forEach((p) {
      temp += p.total!;
    });

    if (order?.discount == null) order!.discount = 0.0;
    discount = order?.discount;
    temp -= order!.discount!;

    order?.total = temp;
    total = temp;
  }

  createItem() {
    if (order == null || companyId == null) return;
    order!.syncDeviceIds();

    if (order!.id == null) {
      // Para nova OS, verifica duplicação pelo número
      if (order!.number != null) {
        // Verifica se existe OS com o mesmo número
        repository.getOrderByNumber(companyId!, order!.number!).then((existingOrder) {
          if (existingOrder != null) {
            // Se encontrou, usa o ID da existente
            order!.id = existingOrder.id;
            repository.updateItem(companyId!, order);
            orderStream =
                repository.streamSingle(companyId!, order!.id).asObservable();
          } else {
            // Cria nova se não encontrou
            repository.createItem(companyId!, order).then((_) {
              if (order!.id != null) {
                orderStream =
                    repository.streamSingle(companyId!, order!.id).asObservable();
                _logOrderCreated();
              }
            });
          }
        });
      } else {
        // Cria nova OS sem número
        repository.createItem(companyId!, order).then((_) {
          if (order!.id != null) {
            orderStream =
                repository.streamSingle(companyId!, order!.id).asObservable();
            _logOrderCreated();
          }
        });
      }
    } else {
      // Atualiza OS existente
      repository.updateItem(companyId!, order).then((_) {
        if (orderStream == null ||
            orderStream!.value?.id != order!.id) {
          orderStream = repository.streamSingle(companyId!, order!.id).asObservable();
        }
      });
    }
  }

  void _logOrderCreated() {
    AnalyticsService.instance.logOrderCreated(
      orderId: order?.id,
      customerId: order?.customer?.id,
      deviceCount: order?.devices?.length ?? 0,
      itemCount: (order?.services?.length ?? 0) + (order?.products?.length ?? 0),
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
  Future<void> loadOrdersForDashboardCustomRange(DateTime start, DateTime end) async {
    if (companyId == null) return;
    try {
      final orders = await repository.getOrdersByDateRange(companyId!, start, end);

      // Filtrar ordens que não são orçamentos
      var filteredOrders =
          orders.where((order) => order?.status != 'quote').toList();

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
      paidOrdersCount =
          filteredOrders.where((order) => order?.payment == 'paid').length;

      // Calcular o faturamento total (soma de todos os valores)
      totalRevenue =
          filteredOrders.fold(0.0, (sum, order) => sum + (order?.total ?? 0.0));

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
          final orderUnpaid = order.payment != 'paid' ? (orderTotal - orderPaid) : 0.0;

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
          var customerName = filteredOrders
                  .firstWhere((order) => order?.customer?.id == customerId,
                      orElse: () => null)
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
    try {
      final orders = await repository.getOrdersByCustomPeriod(
          companyId!, selectedDashboardPeriod, periodOffset);

      // Filtrar ordens que não são orçamentos
      var filteredOrders =
          orders.where((order) => order?.status != 'quote').toList();

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
      paidOrdersCount =
          filteredOrders.where((order) => order?.payment == 'paid').length;

      // Calcular o faturamento total (soma de todos os valores)
      totalRevenue =
          filteredOrders.fold(0.0, (sum, order) => sum + (order?.total ?? 0.0));

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
          final orderUnpaid = order.payment != 'paid' ? (orderTotal - orderPaid) : 0.0;

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
          var customerName = filteredOrders
                  .firstWhere((order) => order?.customer?.id == customerId,
                      orElse: () => null)
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
    customerRanking
        .sort((a, b) => (b['total'] as double).compareTo(a['total'] as double));
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
    isLoading = true;
    _lastDocument = null;
    hasMoreOrders = true;
    orders.clear();

    await _fetchOrdersInfinite(status);

    isLoading = false;
  }

  @action
  Future<void> loadMoreOrdersInfinite(String? status) async {
    if (isLoading || !hasMoreOrders) return;

    isLoading = true;
    await _fetchOrdersInfinite(status);
    isLoading = false;
  }

  Future<void> _fetchOrdersInfinite(String? status) async {
    if (companyId == null) return;

    try {
      final snapshot = await repository.getOrdersWithPagination(
        companyId!,
        status: status,
        customerId: customerFilter?.id,
        limit: _limit,
        startAfterDocument: _lastDocument,
      );

      if (snapshot.docs.isEmpty) {
        hasMoreOrders = false;
        return;
      }

      _lastDocument = snapshot.docs.last;

      // Converter para objetos Order e adicionar à lista
      final newOrders = snapshot.docs
          .map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return Order.fromJson(data);
          })
          .toList();

      orders.addAll(newOrders);

      // Verificar se há mais resultados
      if (snapshot.docs.length < _limit) {
        hasMoreOrders = false;
      }
    } catch (e) {
      print('Erro ao buscar ordens: $e');
    }
  }
}
