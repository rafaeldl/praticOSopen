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
}
