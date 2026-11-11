import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/services/receive_share_service.dart';
import 'package:praticos/services/received_share.dart';

void main() {
  group('newOrderIdAfter ("+" Nova OS in "Em qual OS?")', () {
    test('"X" (closed without saving): no order, nothing saved', () async {
      final created = Completer<String>();
      expect(await newOrderIdAfter(Future.value(null), created.future), isNull);
    });

    test('"✓": waits for the order written after the sheet closed', () async {
      final created = Completer<String>();
      final id = newOrderIdAfter(Future.value(true), created.future);
      created.complete('o42');
      expect(await id, 'o42');
    });

    test('created before the sheet finished closing still counts', () async {
      final created = Completer<String>()..complete('o7');
      expect(await newOrderIdAfter(Future.value(true), created.future), 'o7');
    });

    test('never created (offline): times out', () async {
      final created = Completer<String>();
      expect(
        newOrderIdAfter(
          Future.value(true),
          created.future,
          timeout: const Duration(milliseconds: 10),
        ),
        throwsA(isA<TimeoutException>()),
      );
    });
  });

  group('photosForNewOrder (#633)', () {
    const a = ReceivedFile(path: '/tmp/a.heic', mimeType: 'image/heic');
    const b = ReceivedFile(path: '/tmp/b.jpg', mimeType: 'image/jpeg');

    test('each photo becomes a JPEG for the Nova OS, in order', () async {
      final result = await photosForNewOrder(
        [a, b],
        compress: (path) async => Uint8List.fromList(path.codeUnits),
      );
      expect(result.photos.map((p) => String.fromCharCodes(p.bytes)), [
        '/tmp/a.heic',
        '/tmp/b.jpg',
      ]);
      expect(result.photos.every((p) => p.mimeType == 'image/jpeg'), isTrue);
      expect(result.left, isEmpty);
    });

    test('a photo that cannot be read is left to be saved as before', () async {
      final result = await photosForNewOrder(
        [a, b],
        compress: (path) async {
          if (path == a.path) throw Exception('bad file');
          return Uint8List.fromList([1]);
        },
      );
      expect(result.photos, hasLength(1));
      expect(result.left.map((f) => f.path), [a.path]);
    });

    test('null bytes also leave the file', () async {
      final result = await photosForNewOrder([a], compress: (_) async => null);
      expect(result.photos, isEmpty);
      expect(result.left, [a]);
    });
  });
}
