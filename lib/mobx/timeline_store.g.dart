// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'timeline_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$TimelineStore on _TimelineStore, Store {
  Computed<List<TimelineEvent>>? _$eventsComputed;

  @override
  List<TimelineEvent> get events =>
      (_$eventsComputed ??= Computed<List<TimelineEvent>>(
        () => super.events,
        name: '_TimelineStore.events',
      )).value;
  Computed<int>? _$unreadCountComputed;

  @override
  int get unreadCount => (_$unreadCountComputed ??= Computed<int>(
    () => super.unreadCount,
    name: '_TimelineStore.unreadCount',
  )).value;
  Computed<Map<String, List<TimelineEvent>>>? _$eventsByDateComputed;

  @override
  Map<String, List<TimelineEvent>> get eventsByDate =>
      (_$eventsByDateComputed ??= Computed<Map<String, List<TimelineEvent>>>(
        () => super.eventsByDate,
        name: '_TimelineStore.eventsByDate',
      )).value;

  late final _$timelineStreamAtom = Atom(
    name: '_TimelineStore.timelineStream',
    context: context,
  );

  @override
  ObservableStream<List<TimelineEvent>>? get timelineStream {
    _$timelineStreamAtom.reportRead();
    return super.timelineStream;
  }

  @override
  set timelineStream(ObservableStream<List<TimelineEvent>>? value) {
    _$timelineStreamAtom.reportWrite(value, super.timelineStream, () {
      super.timelineStream = value;
    });
  }

  late final _$isSendingAtom = Atom(
    name: '_TimelineStore.isSending',
    context: context,
  );

  @override
  bool get isSending {
    _$isSendingAtom.reportRead();
    return super.isSending;
  }

  @override
  set isSending(bool value) {
    _$isSendingAtom.reportWrite(value, super.isSending, () {
      super.isSending = value;
    });
  }

  late final _$errorAtom = Atom(name: '_TimelineStore.error', context: context);

  @override
  String? get error {
    _$errorAtom.reportRead();
    return super.error;
  }

  @override
  set error(String? value) {
    _$errorAtom.reportWrite(value, super.error, () {
      super.error = value;
    });
  }

  late final _$sendMessageAsyncAction = AsyncAction(
    '_TimelineStore.sendMessage',
    context: context,
  );

  @override
  Future<void> sendMessage(
    String text, {
    List<TimelineAttachment>? attachments,
    bool isPublic = false,
  }) {
    return _$sendMessageAsyncAction.run(
      () =>
          super.sendMessage(text, attachments: attachments, isPublic: isPublic),
    );
  }

  late final _$_markAllAsReadAsyncAction = AsyncAction(
    '_TimelineStore._markAllAsRead',
    context: context,
  );

  @override
  Future<void> _markAllAsRead() {
    return _$_markAllAsReadAsyncAction.run(() => super._markAllAsRead());
  }

  late final _$_TimelineStoreActionController = ActionController(
    name: '_TimelineStore',
    context: context,
  );

  @override
  void init(String companyId, String orderId) {
    final _$actionInfo = _$_TimelineStoreActionController.startAction(
      name: '_TimelineStore.init',
    );
    try {
      return super.init(companyId, orderId);
    } finally {
      _$_TimelineStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void dispose() {
    final _$actionInfo = _$_TimelineStoreActionController.startAction(
      name: '_TimelineStore.dispose',
    );
    try {
      return super.dispose();
    } finally {
      _$_TimelineStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
timelineStream: ${timelineStream},
isSending: ${isSending},
error: ${error},
events: ${events},
unreadCount: ${unreadCount},
eventsByDate: ${eventsByDate}
    ''';
  }
}
