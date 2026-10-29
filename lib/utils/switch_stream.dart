import 'dart:async';

/// For every value of [source], listens to `inner(value)` and forwards its
/// events, dropping the previous inner stream. Unlike `asyncExpand`, it
/// doesn't wait for the inner stream to finish (Firestore snapshots never do).
Stream<T> switchStream<S, T>(Stream<S> source, Stream<T> Function(S) inner) {
  late StreamController<T> controller;
  StreamSubscription<S>? outerSub;
  StreamSubscription<T>? innerSub;
  var outerDone = false;

  controller = StreamController<T>(
    onListen: () {
      outerSub = source.listen(
        (value) {
          innerSub?.cancel();
          innerSub = inner(value).listen(
            controller.add,
            onError: controller.addError,
            onDone: () {
              innerSub = null;
              if (outerDone) controller.close();
            },
          );
        },
        onError: controller.addError,
        onDone: () {
          outerDone = true;
          if (innerSub == null) controller.close();
        },
      );
    },
    onPause: () {
      outerSub?.pause();
      innerSub?.pause();
    },
    onResume: () {
      outerSub?.resume();
      innerSub?.resume();
    },
    // Doesn't wait for the cancels: `.first` waits for the cancel to finish
    // before returning its value, and a source that never finishes cancelling
    // would hang it (the Nova OS customer picker did).
    onCancel: () {
      unawaited(innerSub?.cancel());
      unawaited(outerSub?.cancel());
    },
  );
  return controller.stream;
}
