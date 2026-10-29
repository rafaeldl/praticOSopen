import 'dart:async';

import 'package:mobx/mobx.dart';

/// Stream of [read] now and whenever the observables it reads change (a MobX
/// reaction). Use it instead of listening to an `ObservableStream` directly:
/// that one is single-subscription, so a second listener throws, and
/// cancelling closes it for every observer (and the cancel may never finish,
/// which hangs `.first`). Cancelling this one just disposes the reaction.
Stream<T> observeAsStream<T>(T Function() read) {
  late StreamController<T> controller;
  ReactionDisposer? dispose;
  controller = StreamController<T>(
    onListen: () {
      dispose = reaction<T>(
        (_) => read(),
        controller.add,
        fireImmediately: true,
      );
    },
    onCancel: () {
      dispose?.call();
      dispose = null;
    },
  );
  return controller.stream;
}
