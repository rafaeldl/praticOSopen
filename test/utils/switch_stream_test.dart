import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/utils/switch_stream.dart';

void main() {
  test('switches to the inner stream of the latest value', () async {
    final source = StreamController<String>();
    final inners = <String, StreamController<int>>{
      'a': StreamController<int>(),
      'b': StreamController<int>(),
    };
    final got = <int>[];
    final sub = switchStream(source.stream, (String k) => inners[k]!.stream)
        .listen(got.add);

    source.add('a');
    await pumpEventQueue();
    inners['a']!.add(1);
    await pumpEventQueue();
    // The inner stream never ends (like Firestore snapshots): still switches.
    source.add('b');
    await pumpEventQueue();
    inners['a']!.add(99);
    inners['b']!.add(2);
    await pumpEventQueue();

    expect(got, [1, 2]);
    expect(inners['a']!.hasListener, isFalse);
    await sub.cancel();
    expect(inners['b']!.hasListener, isFalse);
  });

  test('.first answers even when the source never finishes cancelling', () async {
    // The role stream behind the order queries did this (a MobX
    // ObservableStream), and `.first` waits for the cancel: the Nova OS
    // customer picker stayed open on every tap.
    final source = StreamController<String>(
      onCancel: () => Completer<void>().future,
    );
    final inner = StreamController<int>();
    final first = switchStream(source.stream, (_) => inner.stream).first;
    source.add('a');
    await pumpEventQueue();
    inner.add(7);
    expect(
      await first.timeout(const Duration(seconds: 1), onTimeout: () => -1),
      7,
    );
    expect(inner.hasListener, isFalse);
  });
}
