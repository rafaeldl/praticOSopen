import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/services/received_share.dart';

void main() {
  group('classifyReceived', () {
    test('images by mime type', () {
      expect(classifyReceived('/x/a', 'image/jpeg'), ReceivedKind.photo);
      expect(classifyReceived('/x/a', 'IMAGE/PNG'), ReceivedKind.photo);
    });

    test('pdf by mime type', () {
      expect(classifyReceived('/x/a', 'application/pdf'), ReceivedKind.pdf);
    });

    test('falls back to extension when mime is missing or generic', () {
      expect(classifyReceived('/x/a.JPG', null), ReceivedKind.photo);
      expect(classifyReceived('/x/a.heic', ''), ReceivedKind.photo);
      expect(classifyReceived('/x/a.pdf', null), ReceivedKind.pdf);
      expect(classifyReceived('/x/a.pdf', 'application/octet-stream'),
          ReceivedKind.pdf);
    });

    test('other files are unsupported', () {
      expect(classifyReceived('/x/a.docx', 'application/msword'),
          ReceivedKind.unsupported);
      expect(classifyReceived('/x/noext', null), ReceivedKind.unsupported);
    });
  });

  test('ReceivedBatch routes photos and pdfs and drops the rest', () {
    final batch = ReceivedBatch(const [
      ReceivedFile(path: '/c/1.jpg', mimeType: 'image/jpeg'),
      ReceivedFile(path: '/c/2.pdf', mimeType: 'application/pdf'),
      ReceivedFile(path: '/c/3.png'),
      ReceivedFile(path: '/c/4.zip', mimeType: 'application/zip'),
    ]);
    expect(batch.photos.map((f) => f.fileName), ['1.jpg', '3.png']);
    expect(batch.pdfs.map((f) => f.fileName), ['2.pdf']);
    expect(batch.isEmpty, isFalse);
    expect(ReceivedBatch(const []).isEmpty, isTrue);
  });
}
