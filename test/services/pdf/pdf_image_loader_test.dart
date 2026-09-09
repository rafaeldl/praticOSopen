import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:praticos/services/pdf/pdf_image_loader.dart';

/// PNG 1x1 valido
final _pngBytes = Uint8List.fromList(base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='));

/// Fake HTTP que registra as requisicoes e permite controlar a conclusao
class _FakeHttp {
  final List<String> requested = [];
  final List<String> failing;
  final Map<String, Completer<void>> gates = {};

  /// Numero maximo de requisicoes simultaneas observado
  int maxInFlight = 0;
  int _inFlight = 0;

  _FakeHttp({this.failing = const []});

  Future<http.Response> get(Uri url) async {
    requested.add(url.toString());
    _inFlight++;
    maxInFlight = _inFlight > maxInFlight ? _inFlight : maxInFlight;

    final gate = gates[url.toString()];
    if (gate != null) {
      await gate.future;
    } else {
      await Future<void>.delayed(Duration.zero);
    }

    _inFlight--;

    if (failing.contains(url.toString())) {
      return http.Response('not found', 404);
    }
    return http.Response.bytes(_pngBytes, 200);
  }
}

void main() {
  test('loadPhotos respeita o limite de fotos', () async {
    final fake = _FakeHttp();
    final loader = PdfImageLoader(httpGet: fake.get);

    final images = await loader.loadPhotos(
      List.generate(10, (i) => 'https://example.com/$i.png'),
      limit: 4,
    );

    expect(images.length, 4);
    expect(fake.requested.length, 4);
  });

  test('loadPhotos ignora URLs vazias', () async {
    final fake = _FakeHttp();
    final loader = PdfImageLoader(httpGet: fake.get);

    final images = await loader.loadPhotos(
      ['', 'https://example.com/a.png', '', 'https://example.com/b.png'],
      limit: 4,
    );

    // URLs vazias nao consomem o limite nem geram requisicao
    expect(images.length, 2);
    expect(fake.requested, [
      'https://example.com/a.png',
      'https://example.com/b.png',
    ]);
  });

  test('loadPhotos baixa em paralelo respeitando o limite de concorrencia',
      () async {
    final fake = _FakeHttp();
    final loader = PdfImageLoader(httpGet: fake.get);

    await loader.loadPhotos(
      List.generate(12, (i) => 'https://example.com/$i.png'),
      limit: 12,
    );

    expect(fake.maxInFlight, greaterThan(1));
    expect(fake.maxInFlight,
        lessThanOrEqualTo(PdfImageLoader.maxConcurrentDownloads));
  });

  test('loadPhotos descarta downloads que falharam', () async {
    final fake = _FakeHttp(failing: ['https://example.com/1.png']);
    final loader = PdfImageLoader(httpGet: fake.get);

    final images = await loader.loadPhotos(
      List.generate(3, (i) => 'https://example.com/$i.png'),
      limit: 3,
    );

    expect(images.length, 2);
  });

  test('loadPhotos usa o cache e nao rebaixa a mesma URL', () async {
    final fake = _FakeHttp();
    final loader = PdfImageLoader(httpGet: fake.get);

    await loader.loadPhotos(['https://example.com/a.png'], limit: 1);
    await loader.loadPhotos(['https://example.com/a.png'], limit: 1);

    expect(fake.requested.length, 1);
    expect(loader.cacheSize, 1);
  });

  test('downloads simultaneos da mesma URL compartilham a requisicao',
      () async {
    final fake = _FakeHttp();
    fake.gates['https://example.com/a.png'] = Completer<void>();
    final loader = PdfImageLoader(httpGet: fake.get);

    final first = loader.loadPhotos(['https://example.com/a.png'], limit: 1);
    final second = loader.loadPhotos(['https://example.com/a.png'], limit: 1);

    fake.gates['https://example.com/a.png']!.complete();
    final results = await Future.wait([first, second]);

    expect(results[0].length, 1);
    expect(results[1].length, 1);
    expect(fake.requested.length, 1);
  });
}
