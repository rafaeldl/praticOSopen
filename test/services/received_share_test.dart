import 'dart:convert';
import 'dart:io';

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

    test('contact cards by mime type or extension', () {
      expect(classifyReceived('/x/a', 'text/x-vcard'), ReceivedKind.contact);
      expect(classifyReceived('/x/a', 'TEXT/VCARD'), ReceivedKind.contact);
      expect(classifyReceived('/x/Ana.VCF', null), ReceivedKind.contact);
      expect(classifyReceived('/x/Ana.vcf', 'application/octet-stream'),
          ReceivedKind.contact);
      expect(classifyReceived('/x/a.txt', 'text/plain'),
          ReceivedKind.unsupported);
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

  group('contacts in a batch', () {
    const contact = ReceivedFile(path: '/c/Ana.vcf', mimeType: 'text/x-vcard');
    const photo = ReceivedFile(path: '/c/1.jpg', mimeType: 'image/jpeg');

    test('only contacts skip "Em qual OS?"', () {
      final batch = ReceivedBatch(const [contact]);
      expect(batch.isEmpty, isFalse);
      expect(batch.isOnlyContacts, isTrue);
      expect(batch.contacts.single.fileName, 'Ana.vcf');
    });

    test('with a photo the file goes to the order as always', () {
      final batch = ReceivedBatch(const [contact, photo]);
      expect(batch.isOnlyContacts, isFalse);
      expect(batch.photos, hasLength(1));
    });

    test('nothing to do is not a contact', () {
      expect(ReceivedBatch(const []).isOnlyContacts, isFalse);
    });
  });

  group('readContactCards', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('contact'));
    tearDown(() => dir.deleteSync(recursive: true));

    ReceivedFile file(String name, List<int> bytes) {
      final f = File('${dir.path}/$name')..writeAsBytesSync(bytes);
      return ReceivedFile(path: f.path);
    }

    test('reads every card, accents included', () async {
      final cards = await readContactCards([
        file('a.vcf', utf8.encode('''
BEGIN:VCARD
FN:João
TEL:48981234567
END:VCARD
BEGIN:VCARD
FN:Bia
END:VCARD
''')),
      ]);
      expect(cards.map((c) => c.name), ['João', 'Bia']);
    });

    test('a broken or missing file gives no contact', () async {
      final cards = await readContactCards([
        file('bad.vcf', [0xFF, 0xFE, 0x00]),
        const ReceivedFile(path: '/nao/existe.vcf'),
      ]);
      expect(cards, isEmpty);
    });
  });

  test('only copies made by the app can be deleted', () {
    expect(
      isAndroidCacheCopy(
          '/data/user/0/br.com.rafsoft.praticos/cache/Ana.vcf'),
      isTrue,
    );
    expect(isAndroidCacheCopy('/storage/emulated/0/Download/Ana.vcf'), isFalse);
  });
}
