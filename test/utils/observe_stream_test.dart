import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart';
import 'package:praticos/utils/observe_stream.dart';

void main() {
  test('emits the value now and on each change', () async {
    final role = Observable<String?>(null);
    final got = <String?>[];
    final sub = observeAsStream(() => role.value).listen(got.add);
    await pumpEventQueue();
    runInAction(() => role.value = 'admin');
    runInAction(() => role.value = 'technician');
    await pumpEventQueue();
    expect(got, [null, 'admin', 'technician']);
    await sub.cancel();
  });

  test('.first answers and cancelling finishes', () async {
    final role = Observable('admin');
    final first = await observeAsStream(
      () => role.value,
    ).first.timeout(const Duration(seconds: 1), onTimeout: () => 'timeout');
    expect(first, 'admin');
  });

  test('reads an ObservableStream without consuming it', () async {
    // Listening to an ObservableStream directly takes its only subscription
    // (a second listener throws) and cancelling closes it for everyone.
    final source = StreamController<int>();
    final users = source.stream.asObservable();
    source.add(1);

    for (var i = 0; i < 2; i++) {
      final value = await observeAsStream(
        () => users.value,
      ).firstWhere((v) => v != null).timeout(const Duration(seconds: 1));
      expect(value, 1);
    }

    final again = <int?>[];
    final sub = observeAsStream(() => users.value).listen(again.add);
    source.add(2);
    await pumpEventQueue();
    expect(again.last, 2);
    await sub.cancel();
  });
}
