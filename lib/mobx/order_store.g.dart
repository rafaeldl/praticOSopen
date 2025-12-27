// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$OrderStore on _OrderStore, Store {
  Computed<String?>? _$customerNameComputed;

  @override
  String? get customerName => (_$customerNameComputed ??= Computed<String?>(
    () => super.customerName,
    name: '_OrderStore.customerName',
  )).value;
  Computed<String?>? _$deviceNameComputed;

  @override
  String? get deviceName => (_$deviceNameComputed ??= Computed<String?>(
    () => super.deviceName,
    name: '_OrderStore.deviceName',
  )).value;
  Computed<String?>? _$devicePhotoComputed;

  @override
  String? get devicePhoto => (_$devicePhotoComputed ??= Computed<String?>(
    () => super.devicePhoto,
    name: '_OrderStore.devicePhoto',
  )).value;
  Computed<String?>? _$customerInitialsComputed;

  @override
  String? get customerInitials =>
      (_$customerInitialsComputed ??= Computed<String?>(
        () => super.customerInitials,
        name: '_OrderStore.customerInitials',
      )).value;
  Computed<String>? _$formattedCreatedDateComputed;

  @override
  String get formattedCreatedDate =>
      (_$formattedCreatedDateComputed ??= Computed<String>(
        () => super.formattedCreatedDate,
        name: '_OrderStore.formattedCreatedDate',
      )).value;

  late final _$orderListAtom = Atom(
    name: '_OrderStore.orderList',
    context: context,
  );

  @override
  ObservableStream<List<Order?>>? get orderList {
    _$orderListAtom.reportRead();
    return super.orderList;
  }

  @override
  set orderList(ObservableStream<List<Order?>>? value) {
    _$orderListAtom.reportWrite(value, super.orderList, () {
      super.orderList = value;
    });
  }

  late final _$orderStreamAtom = Atom(
    name: '_OrderStore.orderStream',
    context: context,
  );

  @override
  ObservableStream<Order?>? get orderStream {
    _$orderStreamAtom.reportRead();
    return super.orderStream;
  }

  @override
  set orderStream(ObservableStream<Order?>? value) {
    _$orderStreamAtom.reportWrite(value, super.orderStream, () {
      super.orderStream = value;
    });
  }

  late final _$dueDateAtom = Atom(
    name: '_OrderStore.dueDate',
    context: context,
  );

  @override
  String? get dueDate {
    _$dueDateAtom.reportRead();
    return super.dueDate;
  }

  @override
  set dueDate(String? value) {
    _$dueDateAtom.reportWrite(value, super.dueDate, () {
      super.dueDate = value;
    });
  }

  late final _$statusAtom = Atom(name: '_OrderStore.status', context: context);

  @override
  String? get status {
    _$statusAtom.reportRead();
    return super.status;
  }

  @override
  set status(String? value) {
    _$statusAtom.reportWrite(value, super.status, () {
      super.status = value;
    });
  }

  late final _$createdAtAtom = Atom(
    name: '_OrderStore.createdAt',
    context: context,
  );

  @override
  DateTime? get createdAt {
    _$createdAtAtom.reportRead();
    return super.createdAt;
  }

  @override
  set createdAt(DateTime? value) {
    _$createdAtAtom.reportWrite(value, super.createdAt, () {
      super.createdAt = value;
    });
  }

  late final _$totalAtom = Atom(name: '_OrderStore.total', context: context);

  @override
  double? get total {
    _$totalAtom.reportRead();
    return super.total;
  }

  @override
  set total(double? value) {
    _$totalAtom.reportWrite(value, super.total, () {
      super.total = value;
    });
  }

  late final _$discountAtom = Atom(
    name: '_OrderStore.discount',
    context: context,
  );

  @override
  double? get discount {
    _$discountAtom.reportRead();
    return super.discount;
  }

  @override
  set discount(double? value) {
    _$discountAtom.reportWrite(value, super.discount, () {
      super.discount = value;
    });
  }

  late final _$paymentAtom = Atom(
    name: '_OrderStore.payment',
    context: context,
  );

  @override
  String? get payment {
    _$paymentAtom.reportRead();
    return super.payment;
  }

  @override
  set payment(String? value) {
    _$paymentAtom.reportWrite(value, super.payment, () {
      super.payment = value;
    });
  }

  late final _$customerAtom = Atom(
    name: '_OrderStore.customer',
    context: context,
  );

  @override
  CustomerAggr? get customer {
    _$customerAtom.reportRead();
    return super.customer;
  }

  @override
  set customer(CustomerAggr? value) {
    _$customerAtom.reportWrite(value, super.customer, () {
      super.customer = value;
    });
  }

  late final _$deviceAtom = Atom(name: '_OrderStore.device', context: context);

  @override
  DeviceAggr? get device {
    _$deviceAtom.reportRead();
    return super.device;
  }

  @override
  set device(DeviceAggr? value) {
    _$deviceAtom.reportWrite(value, super.device, () {
      super.device = value;
    });
  }

  late final _$customerFilterAtom = Atom(
    name: '_OrderStore.customerFilter',
    context: context,
  );

  @override
  Customer? get customerFilter {
    _$customerFilterAtom.reportRead();
    return super.customerFilter;
  }

  @override
  set customerFilter(Customer? value) {
    _$customerFilterAtom.reportWrite(value, super.customerFilter, () {
      super.customerFilter = value;
    });
  }

  late final _$servicesAtom = Atom(
    name: '_OrderStore.services',
    context: context,
  );

  @override
  ObservableList<OrderService>? get services {
    _$servicesAtom.reportRead();
    return super.services;
  }

  @override
  set services(ObservableList<OrderService>? value) {
    _$servicesAtom.reportWrite(value, super.services, () {
      super.services = value;
    });
  }

  late final _$productsAtom = Atom(
    name: '_OrderStore.products',
    context: context,
  );

  @override
  ObservableList<OrderProduct>? get products {
    _$productsAtom.reportRead();
    return super.products;
  }

  @override
  set products(ObservableList<OrderProduct>? value) {
    _$productsAtom.reportWrite(value, super.products, () {
      super.products = value;
    });
  }

  late final _$photosAtom = Atom(name: '_OrderStore.photos', context: context);

  @override
  ObservableList<OrderPhoto> get photos {
    _$photosAtom.reportRead();
    return super.photos;
  }

  @override
  set photos(ObservableList<OrderPhoto> value) {
    _$photosAtom.reportWrite(value, super.photos, () {
      super.photos = value;
    });
  }

  late final _$isUploadingPhotoAtom = Atom(
    name: '_OrderStore.isUploadingPhoto',
    context: context,
  );

  @override
  bool get isUploadingPhoto {
    _$isUploadingPhotoAtom.reportRead();
    return super.isUploadingPhoto;
  }

  @override
  set isUploadingPhoto(bool value) {
    _$isUploadingPhotoAtom.reportWrite(value, super.isUploadingPhoto, () {
      super.isUploadingPhoto = value;
    });
  }

  late final _$totalPaidAmountAtom = Atom(
    name: '_OrderStore.totalPaidAmount',
    context: context,
  );

  @override
  double get totalPaidAmount {
    _$totalPaidAmountAtom.reportRead();
    return super.totalPaidAmount;
  }

  @override
  set totalPaidAmount(double value) {
    _$totalPaidAmountAtom.reportWrite(value, super.totalPaidAmount, () {
      super.totalPaidAmount = value;
    });
  }

  late final _$totalUnpaidAmountAtom = Atom(
    name: '_OrderStore.totalUnpaidAmount',
    context: context,
  );

  @override
  double get totalUnpaidAmount {
    _$totalUnpaidAmountAtom.reportRead();
    return super.totalUnpaidAmount;
  }

  @override
  set totalUnpaidAmount(double value) {
    _$totalUnpaidAmountAtom.reportWrite(value, super.totalUnpaidAmount, () {
      super.totalUnpaidAmount = value;
    });
  }

  late final _$totalRevenueAtom = Atom(
    name: '_OrderStore.totalRevenue',
    context: context,
  );

  @override
  double get totalRevenue {
    _$totalRevenueAtom.reportRead();
    return super.totalRevenue;
  }

  @override
  set totalRevenue(double value) {
    _$totalRevenueAtom.reportWrite(value, super.totalRevenue, () {
      super.totalRevenue = value;
    });
  }

  late final _$totalOrdersCountAtom = Atom(
    name: '_OrderStore.totalOrdersCount',
    context: context,
  );

  @override
  int get totalOrdersCount {
    _$totalOrdersCountAtom.reportRead();
    return super.totalOrdersCount;
  }

  @override
  set totalOrdersCount(int value) {
    _$totalOrdersCountAtom.reportWrite(value, super.totalOrdersCount, () {
      super.totalOrdersCount = value;
    });
  }

  late final _$paidOrdersCountAtom = Atom(
    name: '_OrderStore.paidOrdersCount',
    context: context,
  );

  @override
  int get paidOrdersCount {
    _$paidOrdersCountAtom.reportRead();
    return super.paidOrdersCount;
  }

  @override
  set paidOrdersCount(int value) {
    _$paidOrdersCountAtom.reportWrite(value, super.paidOrdersCount, () {
      super.paidOrdersCount = value;
    });
  }

  late final _$recentOrdersAtom = Atom(
    name: '_OrderStore.recentOrders',
    context: context,
  );

  @override
  ObservableList<Order?> get recentOrders {
    _$recentOrdersAtom.reportRead();
    return super.recentOrders;
  }

  @override
  set recentOrders(ObservableList<Order?> value) {
    _$recentOrdersAtom.reportWrite(value, super.recentOrders, () {
      super.recentOrders = value;
    });
  }

  late final _$selectedDashboardPeriodAtom = Atom(
    name: '_OrderStore.selectedDashboardPeriod',
    context: context,
  );

  @override
  String get selectedDashboardPeriod {
    _$selectedDashboardPeriodAtom.reportRead();
    return super.selectedDashboardPeriod;
  }

  @override
  set selectedDashboardPeriod(String value) {
    _$selectedDashboardPeriodAtom.reportWrite(
      value,
      super.selectedDashboardPeriod,
      () {
        super.selectedDashboardPeriod = value;
      },
    );
  }

  late final _$periodOffsetAtom = Atom(
    name: '_OrderStore.periodOffset',
    context: context,
  );

  @override
  int get periodOffset {
    _$periodOffsetAtom.reportRead();
    return super.periodOffset;
  }

  @override
  set periodOffset(int value) {
    _$periodOffsetAtom.reportWrite(value, super.periodOffset, () {
      super.periodOffset = value;
    });
  }

  late final _$orderStatusCountsAtom = Atom(
    name: '_OrderStore.orderStatusCounts',
    context: context,
  );

  @override
  ObservableMap<String, int> get orderStatusCounts {
    _$orderStatusCountsAtom.reportRead();
    return super.orderStatusCounts;
  }

  @override
  set orderStatusCounts(ObservableMap<String, int> value) {
    _$orderStatusCountsAtom.reportWrite(value, super.orderStatusCounts, () {
      super.orderStatusCounts = value;
    });
  }

  late final _$paymentStatusCountsAtom = Atom(
    name: '_OrderStore.paymentStatusCounts',
    context: context,
  );

  @override
  ObservableMap<String, double> get paymentStatusCounts {
    _$paymentStatusCountsAtom.reportRead();
    return super.paymentStatusCounts;
  }

  @override
  set paymentStatusCounts(ObservableMap<String, double> value) {
    _$paymentStatusCountsAtom.reportWrite(value, super.paymentStatusCounts, () {
      super.paymentStatusCounts = value;
    });
  }

  late final _$paymentFilterAtom = Atom(
    name: '_OrderStore.paymentFilter',
    context: context,
  );

  @override
  String? get paymentFilter {
    _$paymentFilterAtom.reportRead();
    return super.paymentFilter;
  }

  @override
  set paymentFilter(String? value) {
    _$paymentFilterAtom.reportWrite(value, super.paymentFilter, () {
      super.paymentFilter = value;
    });
  }

  late final _$ordersAtom = Atom(name: '_OrderStore.orders', context: context);

  @override
  ObservableList<Order?> get orders {
    _$ordersAtom.reportRead();
    return super.orders;
  }

  @override
  set orders(ObservableList<Order?> value) {
    _$ordersAtom.reportWrite(value, super.orders, () {
      super.orders = value;
    });
  }

  late final _$isLoadingAtom = Atom(
    name: '_OrderStore.isLoading',
    context: context,
  );

  @override
  bool get isLoading {
    _$isLoadingAtom.reportRead();
    return super.isLoading;
  }

  @override
  set isLoading(bool value) {
    _$isLoadingAtom.reportWrite(value, super.isLoading, () {
      super.isLoading = value;
    });
  }

  late final _$hasMoreOrdersAtom = Atom(
    name: '_OrderStore.hasMoreOrders',
    context: context,
  );

  @override
  bool get hasMoreOrders {
    _$hasMoreOrdersAtom.reportRead();
    return super.hasMoreOrders;
  }

  @override
  set hasMoreOrders(bool value) {
    _$hasMoreOrdersAtom.reportWrite(value, super.hasMoreOrders, () {
      super.hasMoreOrders = value;
    });
  }

  late final _$customerOrderTotalsAtom = Atom(
    name: '_OrderStore.customerOrderTotals',
    context: context,
  );

  @override
  ObservableMap<String, double> get customerOrderTotals {
    _$customerOrderTotalsAtom.reportRead();
    return super.customerOrderTotals;
  }

  @override
  set customerOrderTotals(ObservableMap<String, double> value) {
    _$customerOrderTotalsAtom.reportWrite(value, super.customerOrderTotals, () {
      super.customerOrderTotals = value;
    });
  }

  late final _$customerUnpaidTotalsAtom = Atom(
    name: '_OrderStore.customerUnpaidTotals',
    context: context,
  );

  @override
  ObservableMap<String, double> get customerUnpaidTotals {
    _$customerUnpaidTotalsAtom.reportRead();
    return super.customerUnpaidTotals;
  }

  @override
  set customerUnpaidTotals(ObservableMap<String, double> value) {
    _$customerUnpaidTotalsAtom.reportWrite(
      value,
      super.customerUnpaidTotals,
      () {
        super.customerUnpaidTotals = value;
      },
    );
  }

  late final _$customerRankingAtom = Atom(
    name: '_OrderStore.customerRanking',
    context: context,
  );

  @override
  ObservableList<Map<String, dynamic>> get customerRanking {
    _$customerRankingAtom.reportRead();
    return super.customerRanking;
  }

  @override
  set customerRanking(ObservableList<Map<String, dynamic>> value) {
    _$customerRankingAtom.reportWrite(value, super.customerRanking, () {
      super.customerRanking = value;
    });
  }

  late final _$selectedCustomerInRankingAtom = Atom(
    name: '_OrderStore.selectedCustomerInRanking',
    context: context,
  );

  @override
  Map<String, dynamic>? get selectedCustomerInRanking {
    _$selectedCustomerInRankingAtom.reportRead();
    return super.selectedCustomerInRanking;
  }

  @override
  set selectedCustomerInRanking(Map<String, dynamic>? value) {
    _$selectedCustomerInRankingAtom.reportWrite(
      value,
      super.selectedCustomerInRanking,
      () {
        super.selectedCustomerInRanking = value;
      },
    );
  }

  late final _$rankingSortTypeAtom = Atom(
    name: '_OrderStore.rankingSortType',
    context: context,
  );

  @override
  String get rankingSortType {
    _$rankingSortTypeAtom.reportRead();
    return super.rankingSortType;
  }

  @override
  set rankingSortType(String value) {
    _$rankingSortTypeAtom.reportWrite(value, super.rankingSortType, () {
      super.rankingSortType = value;
    });
  }

  late final _$customStartDateAtom = Atom(
    name: '_OrderStore.customStartDate',
    context: context,
  );

  @override
  DateTime? get customStartDate {
    _$customStartDateAtom.reportRead();
    return super.customStartDate;
  }

  @override
  set customStartDate(DateTime? value) {
    _$customStartDateAtom.reportWrite(value, super.customStartDate, () {
      super.customStartDate = value;
    });
  }

  late final _$customEndDateAtom = Atom(
    name: '_OrderStore.customEndDate',
    context: context,
  );

  @override
  DateTime? get customEndDate {
    _$customEndDateAtom.reportRead();
    return super.customEndDate;
  }

  @override
  set customEndDate(DateTime? value) {
    _$customEndDateAtom.reportWrite(value, super.customEndDate, () {
      super.customEndDate = value;
    });
  }

  late final _$loadOrdersAsyncAction = AsyncAction(
    '_OrderStore.loadOrders',
    context: context,
  );

  @override
  Future loadOrders(String? status) {
    return _$loadOrdersAsyncAction.run(() => super.loadOrders(status));
  }

  late final _$addPhotoFromGalleryAsyncAction = AsyncAction(
    '_OrderStore.addPhotoFromGallery',
    context: context,
  );

  @override
  Future<bool> addPhotoFromGallery() {
    return _$addPhotoFromGalleryAsyncAction.run(
      () => super.addPhotoFromGallery(),
    );
  }

  late final _$addPhotoFromCameraAsyncAction = AsyncAction(
    '_OrderStore.addPhotoFromCamera',
    context: context,
  );

  @override
  Future<bool> addPhotoFromCamera() {
    return _$addPhotoFromCameraAsyncAction.run(
      () => super.addPhotoFromCamera(),
    );
  }

  late final _$deletePhotoAsyncAction = AsyncAction(
    '_OrderStore.deletePhoto',
    context: context,
  );

  @override
  Future<bool> deletePhoto(int index) {
    return _$deletePhotoAsyncAction.run(() => super.deletePhoto(index));
  }

  late final _$loadOrdersForDashboardCustomRangeAsyncAction = AsyncAction(
    '_OrderStore.loadOrdersForDashboardCustomRange',
    context: context,
  );

  @override
  Future<void> loadOrdersForDashboardCustomRange(DateTime start, DateTime end) {
    return _$loadOrdersForDashboardCustomRangeAsyncAction.run(
      () => super.loadOrdersForDashboardCustomRange(start, end),
    );
  }

  late final _$loadOrdersForDashboardAsyncAction = AsyncAction(
    '_OrderStore.loadOrdersForDashboard',
    context: context,
  );

  @override
  Future<void> loadOrdersForDashboard() {
    return _$loadOrdersForDashboardAsyncAction.run(
      () => super.loadOrdersForDashboard(),
    );
  }

  late final _$loadOrdersInfiniteAsyncAction = AsyncAction(
    '_OrderStore.loadOrdersInfinite',
    context: context,
  );

  @override
  Future<void> loadOrdersInfinite(String? status) {
    return _$loadOrdersInfiniteAsyncAction.run(
      () => super.loadOrdersInfinite(status),
    );
  }

  late final _$loadMoreOrdersInfiniteAsyncAction = AsyncAction(
    '_OrderStore.loadMoreOrdersInfinite',
    context: context,
  );

  @override
  Future<void> loadMoreOrdersInfinite(String? status) {
    return _$loadMoreOrdersInfiniteAsyncAction.run(
      () => super.loadMoreOrdersInfinite(status),
    );
  }

  late final _$_OrderStoreActionController = ActionController(
    name: '_OrderStore',
    context: context,
  );

  @override
  dynamic loadOrder({String? id}) {
    final _$actionInfo = _$_OrderStoreActionController.startAction(
      name: '_OrderStore.loadOrder',
    );
    try {
      return super.loadOrder(id: id);
    } finally {
      _$_OrderStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setOrder(Order? order) {
    final _$actionInfo = _$_OrderStoreActionController.startAction(
      name: '_OrderStore.setOrder',
    );
    try {
      return super.setOrder(order);
    } finally {
      _$_OrderStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  dynamic setCustomer(Customer? c) {
    final _$actionInfo = _$_OrderStoreActionController.startAction(
      name: '_OrderStore.setCustomer',
    );
    try {
      return super.setCustomer(c);
    } finally {
      _$_OrderStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  dynamic setDevice(Device? d) {
    final _$actionInfo = _$_OrderStoreActionController.startAction(
      name: '_OrderStore.setDevice',
    );
    try {
      return super.setDevice(d);
    } finally {
      _$_OrderStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  dynamic setStatus(String? status) {
    final _$actionInfo = _$_OrderStoreActionController.startAction(
      name: '_OrderStore.setStatus',
    );
    try {
      return super.setStatus(status);
    } finally {
      _$_OrderStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  dynamic updateOrder() {
    final _$actionInfo = _$_OrderStoreActionController.startAction(
      name: '_OrderStore.updateOrder',
    );
    try {
      return super.updateOrder();
    } finally {
      _$_OrderStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  Future<void> deleteOrder() {
    final _$actionInfo = _$_OrderStoreActionController.startAction(
      name: '_OrderStore.deleteOrder',
    );
    try {
      return super.deleteOrder();
    } finally {
      _$_OrderStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  dynamic addService(OrderService orderService) {
    final _$actionInfo = _$_OrderStoreActionController.startAction(
      name: '_OrderStore.addService',
    );
    try {
      return super.addService(orderService);
    } finally {
      _$_OrderStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  dynamic addProduct(OrderProduct orderProduct) {
    final _$actionInfo = _$_OrderStoreActionController.startAction(
      name: '_OrderStore.addProduct',
    );
    try {
      return super.addProduct(orderProduct);
    } finally {
      _$_OrderStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  dynamic deleteService(int index) {
    final _$actionInfo = _$_OrderStoreActionController.startAction(
      name: '_OrderStore.deleteService',
    );
    try {
      return super.deleteService(index);
    } finally {
      _$_OrderStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  dynamic deleteProduct(int index) {
    final _$actionInfo = _$_OrderStoreActionController.startAction(
      name: '_OrderStore.deleteProduct',
    );
    try {
      return super.deleteProduct(index);
    } finally {
      _$_OrderStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setPhotoCover(int index) {
    final _$actionInfo = _$_OrderStoreActionController.startAction(
      name: '_OrderStore.setPhotoCover',
    );
    try {
      return super.setPhotoCover(index);
    } finally {
      _$_OrderStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  dynamic setDiscount(double value) {
    final _$actionInfo = _$_OrderStoreActionController.startAction(
      name: '_OrderStore.setDiscount',
    );
    try {
      return super.setDiscount(value);
    } finally {
      _$_OrderStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  dynamic setCustomerFilter(Customer? customerFilter) {
    final _$actionInfo = _$_OrderStoreActionController.startAction(
      name: '_OrderStore.setCustomerFilter',
    );
    try {
      return super.setCustomerFilter(customerFilter);
    } finally {
      _$_OrderStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setDashboardPeriod(String period) {
    final _$actionInfo = _$_OrderStoreActionController.startAction(
      name: '_OrderStore.setDashboardPeriod',
    );
    try {
      return super.setDashboardPeriod(period);
    } finally {
      _$_OrderStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setCustomPeriod(String period, int offset) {
    final _$actionInfo = _$_OrderStoreActionController.startAction(
      name: '_OrderStore.setCustomPeriod',
    );
    try {
      return super.setCustomPeriod(period, offset);
    } finally {
      _$_OrderStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setCustomDateRange(DateTime start, DateTime end) {
    final _$actionInfo = _$_OrderStoreActionController.startAction(
      name: '_OrderStore.setCustomDateRange',
    );
    try {
      return super.setCustomDateRange(start, end);
    } finally {
      _$_OrderStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setPaymentFilter(String? filter) {
    final _$actionInfo = _$_OrderStoreActionController.startAction(
      name: '_OrderStore.setPaymentFilter',
    );
    try {
      return super.setPaymentFilter(filter);
    } finally {
      _$_OrderStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void sortCustomerRanking() {
    final _$actionInfo = _$_OrderStoreActionController.startAction(
      name: '_OrderStore.sortCustomerRanking',
    );
    try {
      return super.sortCustomerRanking();
    } finally {
      _$_OrderStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setRankingSortType(String sortType) {
    final _$actionInfo = _$_OrderStoreActionController.startAction(
      name: '_OrderStore.setRankingSortType',
    );
    try {
      return super.setRankingSortType(sortType);
    } finally {
      _$_OrderStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void selectCustomerInRanking(Map<String, dynamic>? customerData) {
    final _$actionInfo = _$_OrderStoreActionController.startAction(
      name: '_OrderStore.selectCustomerInRanking',
    );
    try {
      return super.selectCustomerInRanking(customerData);
    } finally {
      _$_OrderStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearCustomerRankingSelection() {
    final _$actionInfo = _$_OrderStoreActionController.startAction(
      name: '_OrderStore.clearCustomerRankingSelection',
    );
    try {
      return super.clearCustomerRankingSelection();
    } finally {
      _$_OrderStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
orderList: ${orderList},
orderStream: ${orderStream},
dueDate: ${dueDate},
status: ${status},
createdAt: ${createdAt},
total: ${total},
discount: ${discount},
payment: ${payment},
customer: ${customer},
device: ${device},
customerFilter: ${customerFilter},
services: ${services},
products: ${products},
photos: ${photos},
isUploadingPhoto: ${isUploadingPhoto},
totalPaidAmount: ${totalPaidAmount},
totalUnpaidAmount: ${totalUnpaidAmount},
totalRevenue: ${totalRevenue},
totalOrdersCount: ${totalOrdersCount},
paidOrdersCount: ${paidOrdersCount},
recentOrders: ${recentOrders},
selectedDashboardPeriod: ${selectedDashboardPeriod},
periodOffset: ${periodOffset},
orderStatusCounts: ${orderStatusCounts},
paymentStatusCounts: ${paymentStatusCounts},
paymentFilter: ${paymentFilter},
orders: ${orders},
isLoading: ${isLoading},
hasMoreOrders: ${hasMoreOrders},
customerOrderTotals: ${customerOrderTotals},
customerUnpaidTotals: ${customerUnpaidTotals},
customerRanking: ${customerRanking},
selectedCustomerInRanking: ${selectedCustomerInRanking},
rankingSortType: ${rankingSortType},
customStartDate: ${customStartDate},
customEndDate: ${customEndDate},
customerName: ${customerName},
deviceName: ${deviceName},
devicePhoto: ${devicePhoto},
customerInitials: ${customerInitials},
formattedCreatedDate: ${formattedCreatedDate}
    ''';
  }
}
