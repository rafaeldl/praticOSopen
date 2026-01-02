// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'customer_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$CustomerStore on _CustomerStore, Store {
  late final _$customerListAtom = Atom(
    name: '_CustomerStore.customerList',
    context: context,
  );

  @override
  ObservableStream<List<Customer?>>? get customerList {
    _$customerListAtom.reportRead();
    return super.customerList;
  }

  @override
  set customerList(ObservableStream<List<Customer?>>? value) {
    _$customerListAtom.reportWrite(value, super.customerList, () {
      super.customerList = value;
    });
  }

  late final _$saveCustomerAsyncAction = AsyncAction(
    '_CustomerStore.saveCustomer',
    context: context,
  );

  @override
  Future saveCustomer(Customer customer) {
    return _$saveCustomerAsyncAction.run(() => super.saveCustomer(customer));
  }

  late final _$deleteCustomerAsyncAction = AsyncAction(
    '_CustomerStore.deleteCustomer',
    context: context,
  );

  @override
  Future deleteCustomer(Customer customer) {
    return _$deleteCustomerAsyncAction.run(
      () => super.deleteCustomer(customer),
    );
  }

  late final _$_CustomerStoreActionController = ActionController(
    name: '_CustomerStore',
    context: context,
  );

  @override
  dynamic retrieveCustomers() {
    final _$actionInfo = _$_CustomerStoreActionController.startAction(
      name: '_CustomerStore.retrieveCustomers',
    );
    try {
      return super.retrieveCustomers();
    } finally {
      _$_CustomerStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  Future<Customer?> retrieveCustomer(String? id) {
    final _$actionInfo = _$_CustomerStoreActionController.startAction(
      name: '_CustomerStore.retrieveCustomer',
    );
    try {
      return super.retrieveCustomer(id);
    } finally {
      _$_CustomerStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
customerList: ${customerList}
    ''';
  }
}
