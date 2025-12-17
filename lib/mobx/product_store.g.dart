// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$ProductStore on _ProductStore, Store {
  late final _$productListAtom = Atom(
    name: '_ProductStore.productList',
    context: context,
  );

  @override
  ObservableStream<List<Product>>? get productList {
    _$productListAtom.reportRead();
    return super.productList;
  }

  @override
  set productList(ObservableStream<List<Product>>? value) {
    _$productListAtom.reportWrite(value, super.productList, () {
      super.productList = value;
    });
  }

  late final _$saveProductAsyncAction = AsyncAction(
    '_ProductStore.saveProduct',
    context: context,
  );

  @override
  Future saveProduct(Product product) {
    return _$saveProductAsyncAction.run(() => super.saveProduct(product));
  }

  late final _$deleteProductAsyncAction = AsyncAction(
    '_ProductStore.deleteProduct',
    context: context,
  );

  @override
  Future deleteProduct(Product product) {
    return _$deleteProductAsyncAction.run(() => super.deleteProduct(product));
  }

  late final _$_ProductStoreActionController = ActionController(
    name: '_ProductStore',
    context: context,
  );

  @override
  dynamic retrieveProducts() {
    final _$actionInfo = _$_ProductStoreActionController.startAction(
      name: '_ProductStore.retrieveProducts',
    );
    try {
      return super.retrieveProducts();
    } finally {
      _$_ProductStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
productList: ${productList}
    ''';
  }
}
