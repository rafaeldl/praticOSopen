import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/utils/vcard.dart';

void main() {
  test('reads a vCard 3.0 from iOS, with an accent in the name', () {
    final cards = parseVCards(
      'BEGIN:VCARD\r\n'
      'VERSION:3.0\r\n'
      'N:Conceição;João;;;\r\n'
      'FN:João Conceição\r\n'
      'TEL;type=CELL;type=VOICE;type=pref:+55 48 98408-7801\r\n'
      'EMAIL;type=INTERNET:joao@example.com\r\n'
      'END:VCARD\r\n',
    );
    expect(cards, hasLength(1));
    expect(cards.first.name, 'João Conceição');
    expect(cards.first.phones, ['+55 48 98408-7801']);
    expect(cards.first.email, 'joao@example.com');
  });

  test('reads quoted-printable from Android (vCard 2.1)', () {
    final cards = parseVCards(
      'BEGIN:VCARD\n'
      'VERSION:2.1\n'
      'N;CHARSET=UTF-8;ENCODING=QUOTED-PRINTABLE:Concei=C3=A7=C3=A3o;Jo=C3=A3o;;;\n'
      'FN;CHARSET=UTF-8;ENCODING=QUOTED-PRINTABLE:Jo=C3=A3o Con=\n'
      'cei=C3=A7=C3=A3o\n'
      'TEL;CELL:48984087801\n'
      'END:VCARD\n',
    );
    expect(cards.single.name, 'João Conceição');
  });

  test('keeps every phone in order, without repeats', () {
    final cards = parseVCards(
      'BEGIN:VCARD\n'
      'FN:Bia\n'
      'item1.TEL;type=pref:(48) 98408-7801\n'
      'item1.X-ABLabel:Trabalho\n'
      'TEL;type=HOME:(48) 3222-3344\n'
      'TEL;type=CELL:48 98408 7801\n'
      'TEL;VALUE=uri:tel:+1-202-555-0123\n'
      'END:VCARD\n',
    );
    expect(cards.single.phones, [
      '(48) 98408-7801',
      '(48) 3222-3344',
      '+1-202-555-0123',
    ]);
  });

  test('name falls back to the parts and then to the company', () {
    expect(
      parseVCards('BEGIN:VCARD\nN:Silva;Maria;Clara;Dra.;\nEND:VCARD').single.name,
      'Dra. Maria Clara Silva',
    );
    expect(
      parseVCards('BEGIN:VCARD\nORG:Oficina\\, Ltda;Vendas\nTEL:48984087801\nEND:VCARD')
          .single
          .name,
      'Oficina, Ltda',
    );
  });

  test('a phone without a name is still a contact', () {
    final card = parseVCards('BEGIN:VCARD\nTEL:48984087801\nEND:VCARD').single;
    expect(card.name, isNull);
    expect(card.phones, ['48984087801']);
  });

  test('joins folded lines and ignores the photo', () {
    final cards = parseVCards(
      'BEGIN:VCARD\r\n'
      'FN:Maria\r\n'
      '  Clara\r\n'
      'PHOTO;ENCODING=b;TYPE=JPEG:/9j/4AAQ\r\n'
      ' SkZJRgABAQ==\r\n'
      'END:VCARD\r\n',
    );
    expect(cards.single.name, 'Maria Clara');
    expect(cards.single.phones, isEmpty);
  });

  test('a file with several contacts keeps the order', () {
    final cards = parseVCards(
      'BEGIN:VCARD\nFN:Primeiro\nEND:VCARD\n'
      'BEGIN:VCARD\nFN:Segundo\nEND:VCARD\n',
    );
    expect(cards.map((c) => c.name), ['Primeiro', 'Segundo']);
  });

  test('an invalid file gives no contact', () {
    expect(parseVCards(''), isEmpty);
    expect(parseVCards('não é um vcard'), isEmpty);
    expect(parseVCards('BEGIN:VCARD\nFN:Sem fim'), isEmpty);
    expect(parseVCards('BEGIN:VCARD\nVERSION:3.0\nEND:VCARD'), isEmpty);
    expect(parseVCards('FN:Fora\nEND:VCARD'), isEmpty);
  });
}
