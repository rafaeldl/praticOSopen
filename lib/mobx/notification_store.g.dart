// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$NotificationStore on _NotificationStore, Store {
  late final _$notificationsAtom = Atom(
    name: '_NotificationStore.notifications',
    context: context,
  );

  @override
  ObservableStream<List<AppNotification>>? get notifications {
    _$notificationsAtom.reportRead();
    return super.notifications;
  }

  @override
  set notifications(ObservableStream<List<AppNotification>>? value) {
    _$notificationsAtom.reportWrite(value, super.notifications, () {
      super.notifications = value;
    });
  }

  late final _$unreadCountAtom = Atom(
    name: '_NotificationStore.unreadCount',
    context: context,
  );

  @override
  ObservableStream<int>? get unreadCount {
    _$unreadCountAtom.reportRead();
    return super.unreadCount;
  }

  @override
  set unreadCount(ObservableStream<int>? value) {
    _$unreadCountAtom.reportWrite(value, super.unreadCount, () {
      super.unreadCount = value;
    });
  }

  late final _$isLoadingAtom = Atom(
    name: '_NotificationStore.isLoading',
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

  late final _$hasPermissionAtom = Atom(
    name: '_NotificationStore.hasPermission',
    context: context,
  );

  @override
  bool get hasPermission {
    _$hasPermissionAtom.reportRead();
    return super.hasPermission;
  }

  @override
  set hasPermission(bool value) {
    _$hasPermissionAtom.reportWrite(value, super.hasPermission, () {
      super.hasPermission = value;
    });
  }

  late final _$isInitializedAtom = Atom(
    name: '_NotificationStore.isInitialized',
    context: context,
  );

  @override
  bool get isInitialized {
    _$isInitializedAtom.reportRead();
    return super.isInitialized;
  }

  @override
  set isInitialized(bool value) {
    _$isInitializedAtom.reportWrite(value, super.isInitialized, () {
      super.isInitialized = value;
    });
  }

  late final _$initializeAsyncAction = AsyncAction(
    '_NotificationStore.initialize',
    context: context,
  );

  @override
  Future<void> initialize() {
    return _$initializeAsyncAction.run(() => super.initialize());
  }

  late final _$markAsReadAsyncAction = AsyncAction(
    '_NotificationStore.markAsRead',
    context: context,
  );

  @override
  Future<void> markAsRead(String notificationId) {
    return _$markAsReadAsyncAction.run(() => super.markAsRead(notificationId));
  }

  late final _$markAllAsReadAsyncAction = AsyncAction(
    '_NotificationStore.markAllAsRead',
    context: context,
  );

  @override
  Future<void> markAllAsRead() {
    return _$markAllAsReadAsyncAction.run(() => super.markAllAsRead());
  }

  late final _$disposeAsyncAction = AsyncAction(
    '_NotificationStore.dispose',
    context: context,
  );

  @override
  Future<void> dispose() {
    return _$disposeAsyncAction.run(() => super.dispose());
  }

  late final _$requestPermissionAgainAsyncAction = AsyncAction(
    '_NotificationStore.requestPermissionAgain',
    context: context,
  );

  @override
  Future<bool> requestPermissionAgain() {
    return _$requestPermissionAgainAsyncAction.run(
      () => super.requestPermissionAgain(),
    );
  }

  late final _$_NotificationStoreActionController = ActionController(
    name: '_NotificationStore',
    context: context,
  );

  @override
  void loadNotifications() {
    final _$actionInfo = _$_NotificationStoreActionController.startAction(
      name: '_NotificationStore.loadNotifications',
    );
    try {
      return super.loadNotifications();
    } finally {
      _$_NotificationStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void reload() {
    final _$actionInfo = _$_NotificationStoreActionController.startAction(
      name: '_NotificationStore.reload',
    );
    try {
      return super.reload();
    } finally {
      _$_NotificationStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
notifications: ${notifications},
unreadCount: ${unreadCount},
isLoading: ${isLoading},
hasPermission: ${hasPermission},
isInitialized: ${isInitialized}
    ''';
  }
}
