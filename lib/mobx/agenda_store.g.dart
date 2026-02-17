// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agenda_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$AgendaStore on _AgendaStore, Store {
  Computed<List<Order?>>? _$ordersForSelectedDateComputed;

  @override
  List<Order?> get ordersForSelectedDate =>
      (_$ordersForSelectedDateComputed ??= Computed<List<Order?>>(
        () => super.ordersForSelectedDate,
        name: '_AgendaStore.ordersForSelectedDate',
      )).value;
  Computed<Map<DateTime, int>>? _$eventMarkersComputed;

  @override
  Map<DateTime, int> get eventMarkers =>
      (_$eventMarkersComputed ??= Computed<Map<DateTime, int>>(
        () => super.eventMarkers,
        name: '_AgendaStore.eventMarkers',
      )).value;
  Computed<List<Order?>>? _$filteredOrdersComputed;

  @override
  List<Order?> get filteredOrders =>
      (_$filteredOrdersComputed ??= Computed<List<Order?>>(
        () => super.filteredOrders,
        name: '_AgendaStore.filteredOrders',
      )).value;

  late final _$selectedDateAtom = Atom(
    name: '_AgendaStore.selectedDate',
    context: context,
  );

  @override
  DateTime get selectedDate {
    _$selectedDateAtom.reportRead();
    return super.selectedDate;
  }

  @override
  set selectedDate(DateTime value) {
    _$selectedDateAtom.reportWrite(value, super.selectedDate, () {
      super.selectedDate = value;
    });
  }

  late final _$focusedMonthAtom = Atom(
    name: '_AgendaStore.focusedMonth',
    context: context,
  );

  @override
  DateTime get focusedMonth {
    _$focusedMonthAtom.reportRead();
    return super.focusedMonth;
  }

  @override
  set focusedMonth(DateTime value) {
    _$focusedMonthAtom.reportWrite(value, super.focusedMonth, () {
      super.focusedMonth = value;
    });
  }

  late final _$ordersAtom = Atom(name: '_AgendaStore.orders', context: context);

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

  late final _$selectedTechnicianIdAtom = Atom(
    name: '_AgendaStore.selectedTechnicianId',
    context: context,
  );

  @override
  String? get selectedTechnicianId {
    _$selectedTechnicianIdAtom.reportRead();
    return super.selectedTechnicianId;
  }

  @override
  set selectedTechnicianId(String? value) {
    _$selectedTechnicianIdAtom.reportWrite(
      value,
      super.selectedTechnicianId,
      () {
        super.selectedTechnicianId = value;
      },
    );
  }

  late final _$isLoadingAtom = Atom(
    name: '_AgendaStore.isLoading',
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

  late final _$_AgendaStoreActionController = ActionController(
    name: '_AgendaStore',
    context: context,
  );

  @override
  void loadMonth(DateTime month) {
    final _$actionInfo = _$_AgendaStoreActionController.startAction(
      name: '_AgendaStore.loadMonth',
    );
    try {
      return super.loadMonth(month);
    } finally {
      _$_AgendaStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void selectDate(DateTime date) {
    final _$actionInfo = _$_AgendaStoreActionController.startAction(
      name: '_AgendaStore.selectDate',
    );
    try {
      return super.selectDate(date);
    } finally {
      _$_AgendaStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setTechnicianFilter(String? userId) {
    final _$actionInfo = _$_AgendaStoreActionController.startAction(
      name: '_AgendaStore.setTechnicianFilter',
    );
    try {
      return super.setTechnicianFilter(userId);
    } finally {
      _$_AgendaStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
selectedDate: ${selectedDate},
focusedMonth: ${focusedMonth},
orders: ${orders},
selectedTechnicianId: ${selectedTechnicianId},
isLoading: ${isLoading},
ordersForSelectedDate: ${ordersForSelectedDate},
eventMarkers: ${eventMarkers},
filteredOrders: ${filteredOrders}
    ''';
  }
}
