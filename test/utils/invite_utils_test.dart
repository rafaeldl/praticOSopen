import 'package:praticos/models/invite.dart';
import 'package:praticos/utils/invite_utils.dart';
import 'package:test/test.dart';

Invite _makeInvite({String? email, String? phone, String? token}) {
  return Invite()
    ..email = email
    ..phone = phone
    ..token = token ?? 'INV_TEST';
}

void main() {
  group('findExistingPendingInvite - match by email', () {
    test('finds invite with exact email', () {
      final invites = [_makeInvite(email: 'joao@example.com')];
      final result =
          findExistingPendingInvite(invites, email: 'joao@example.com');
      expect(result, isNotNull);
      expect(result!.email, equals('joao@example.com'));
    });

    test('matches email case-insensitively', () {
      final invites = [_makeInvite(email: 'Joao@Example.COM')];
      final result =
          findExistingPendingInvite(invites, email: 'joao@example.com');
      expect(result, isNotNull);
    });

    test('matches email with extra whitespace', () {
      final invites = [_makeInvite(email: 'joao@example.com')];
      final result =
          findExistingPendingInvite(invites, email: '  joao@example.com  ');
      expect(result, isNotNull);
    });
  });

  group('findExistingPendingInvite - match by phone', () {
    test('finds invite with exact phone', () {
      final invites = [_makeInvite(phone: '5511999999999')];
      final result =
          findExistingPendingInvite(invites, phone: '5511999999999');
      expect(result, isNotNull);
      expect(result!.phone, equals('5511999999999'));
    });

    test('matches phone with different formatting', () {
      final invites = [_makeInvite(phone: '+55 11 99999-9999')];
      final result =
          findExistingPendingInvite(invites, phone: '5511999999999');
      expect(result, isNotNull);
    });

    test('matches formatted search against raw stored phone', () {
      final invites = [_makeInvite(phone: '5511999999999')];
      final result =
          findExistingPendingInvite(invites, phone: '+55 (11) 99999-9999');
      expect(result, isNotNull);
    });
  });

  group('findExistingPendingInvite - no match', () {
    test('returns null when email does not match', () {
      final invites = [_makeInvite(email: 'joao@example.com')];
      final result =
          findExistingPendingInvite(invites, email: 'maria@example.com');
      expect(result, isNull);
    });

    test('returns null when phone does not match', () {
      final invites = [_makeInvite(phone: '5511999999999')];
      final result =
          findExistingPendingInvite(invites, phone: '5521888888888');
      expect(result, isNull);
    });

    test('returns null for empty list', () {
      final result =
          findExistingPendingInvite([], email: 'joao@example.com');
      expect(result, isNull);
    });

    test('returns null when email and phone are null', () {
      final invites = [_makeInvite(email: 'joao@example.com')];
      final result = findExistingPendingInvite(invites);
      expect(result, isNull);
    });

    test('returns null when email is empty string', () {
      final invites = [_makeInvite(email: 'joao@example.com')];
      final result = findExistingPendingInvite(invites, email: '');
      expect(result, isNull);
    });
  });

  group('findExistingPendingInvite - priority and multiple invites', () {
    test('email match has priority over phone match', () {
      final emailInvite =
          _makeInvite(email: 'joao@example.com', token: 'EMAIL_MATCH');
      final phoneInvite =
          _makeInvite(phone: '5511999999999', token: 'PHONE_MATCH');
      final invites = [emailInvite, phoneInvite];

      final result = findExistingPendingInvite(
        invites,
        email: 'joao@example.com',
        phone: '5511999999999',
      );

      expect(result, isNotNull);
      expect(result!.token, equals('EMAIL_MATCH'));
    });

    test('returns first matching invite when multiple match', () {
      final first = _makeInvite(email: 'joao@example.com', token: 'FIRST');
      final second = _makeInvite(email: 'joao@example.com', token: 'SECOND');
      final invites = [first, second];

      final result =
          findExistingPendingInvite(invites, email: 'joao@example.com');

      expect(result, isNotNull);
      expect(result!.token, equals('FIRST'));
    });

    test('falls back to phone match when email does not match', () {
      final invite = _makeInvite(
        email: 'other@example.com',
        phone: '5511999999999',
        token: 'PHONE_FALLBACK',
      );
      final invites = [invite];

      final result = findExistingPendingInvite(
        invites,
        email: 'joao@example.com',
        phone: '5511999999999',
      );

      expect(result, isNotNull);
      expect(result!.token, equals('PHONE_FALLBACK'));
    });
  });
}
