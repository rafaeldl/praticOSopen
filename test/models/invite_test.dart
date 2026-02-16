import 'package:praticos/models/invite.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/models/user_role.dart';
import 'package:test/test.dart';

void main() {
  group('Invite JSON round-trip', () {
    test('basic fields survive round-trip', () {
      final invite = Invite()
        ..id = 'INV_ABC123'
        ..token = 'INV_ABC123'
        ..name = 'João Silva'
        ..email = 'joao@example.com'
        ..phone = '+5511999999999'
        ..acceptedByUserId = 'user123';

      final json = invite.toJson();
      final restored = Invite.fromJson(json);

      expect(restored.id, equals('INV_ABC123'));
      expect(restored.token, equals('INV_ABC123'));
      expect(restored.name, equals('João Silva'));
      expect(restored.email, equals('joao@example.com'));
      expect(restored.phone, equals('+5511999999999'));
      expect(restored.acceptedByUserId, equals('user123'));
    });

    test('enum fields survive round-trip', () {
      final invite = Invite()
        ..status = InviteStatus.accepted
        ..channel = InviteChannel.whatsapp
        ..role = RolesType.admin;

      final json = invite.toJson();
      final restored = Invite.fromJson(json);

      expect(restored.status, equals(InviteStatus.accepted));
      expect(restored.channel, equals(InviteChannel.whatsapp));
      expect(restored.role, equals(RolesType.admin));
    });

    test('date fields survive round-trip', () {
      final now = DateTime(2025, 6, 15, 10, 30);
      final expires = DateTime(2025, 6, 22, 10, 30);
      final accepted = DateTime(2025, 6, 16, 14, 0);

      final invite = Invite()
        ..createdAt = now
        ..expiresAt = expires
        ..acceptedAt = accepted;

      final json = invite.toJson();
      final restored = Invite.fromJson(json);

      expect(restored.createdAt, equals(now));
      expect(restored.expiresAt, equals(expires));
      expect(restored.acceptedAt, equals(accepted));
    });

    test('nested company object survives round-trip', () {
      final company = CompanyAggr()
        ..id = 'comp123'
        ..name = 'Empresa Test';

      final invite = Invite()..company = company;

      final json = invite.toJson();
      final restored = Invite.fromJson(json);

      expect(restored.company?.id, equals('comp123'));
      expect(restored.company?.name, equals('Empresa Test'));
    });

    test('nested invitedBy object survives round-trip', () {
      final user = UserAggr()
        ..id = 'user456'
        ..name = 'Admin User'
        ..email = 'admin@example.com';

      final invite = Invite()..invitedBy = user;

      final json = invite.toJson();
      final restored = Invite.fromJson(json);

      expect(restored.invitedBy?.id, equals('user456'));
      expect(restored.invitedBy?.name, equals('Admin User'));
      expect(restored.invitedBy?.email, equals('admin@example.com'));
    });

    test('full invite toJson/fromJson round-trip matches', () {
      final invite = Invite()
        ..id = 'INV_FULL'
        ..token = 'INV_FULL'
        ..name = 'Test'
        ..email = 'test@test.com'
        ..status = InviteStatus.pending
        ..channel = InviteChannel.app
        ..role = RolesType.technician
        ..createdAt = DateTime(2025, 1, 1)
        ..expiresAt = DateTime(2025, 1, 8);

      final restored = Invite.fromJson(invite.toJson());
      expect(restored.toJson(), equals(invite.toJson()));
    });
  });

  group('Invite.isExpired', () {
    test('returns false when expiresAt is null', () {
      final invite = Invite();
      expect(invite.isExpired, isFalse);
    });

    test('returns false when expiresAt is in the future', () {
      final invite = Invite()
        ..expiresAt = DateTime.now().add(const Duration(days: 7));
      expect(invite.isExpired, isFalse);
    });

    test('returns true when expiresAt is in the past', () {
      final invite = Invite()
        ..expiresAt = DateTime.now().subtract(const Duration(days: 1));
      expect(invite.isExpired, isTrue);
    });

    test('returns true when expiresAt is well in the past', () {
      final invite = Invite()
        ..expiresAt = DateTime(2020, 1, 1);
      expect(invite.isExpired, isTrue);
    });
  });

  group('Invite.canBeAccepted', () {
    test('returns true when pending and not expired', () {
      final invite = Invite()
        ..status = InviteStatus.pending
        ..expiresAt = DateTime.now().add(const Duration(days: 7));
      expect(invite.canBeAccepted, isTrue);
    });

    test('returns false when accepted', () {
      final invite = Invite()
        ..status = InviteStatus.accepted
        ..expiresAt = DateTime.now().add(const Duration(days: 7));
      expect(invite.canBeAccepted, isFalse);
    });

    test('returns false when pending but expired', () {
      final invite = Invite()
        ..status = InviteStatus.pending
        ..expiresAt = DateTime.now().subtract(const Duration(days: 1));
      expect(invite.canBeAccepted, isFalse);
    });

    test('returns false when cancelled', () {
      final invite = Invite()
        ..status = InviteStatus.cancelled
        ..expiresAt = DateTime.now().add(const Duration(days: 7));
      expect(invite.canBeAccepted, isFalse);
    });

    test('returns false when rejected', () {
      final invite = Invite()
        ..status = InviteStatus.rejected
        ..expiresAt = DateTime.now().add(const Duration(days: 7));
      expect(invite.canBeAccepted, isFalse);
    });

    test('returns true when pending and expiresAt is null', () {
      final invite = Invite()..status = InviteStatus.pending;
      expect(invite.canBeAccepted, isTrue);
    });
  });

  group('Invite.getWhatsAppLink', () {
    test('generates correct URL format', () {
      final invite = Invite()..token = 'INV_ABC123';
      final link = invite.getWhatsAppLink('+55 11 91234-5678');

      expect(link, startsWith('https://wa.me/'));
      expect(link, contains('5511912345678'));
      expect(link, contains('text=INV_ABC123'));
    });

    test('strips non-digit characters from bot number', () {
      final invite = Invite()..token = 'INV_TEST';
      final link = invite.getWhatsAppLink('+1 (555) 123-4567');

      expect(link, contains('wa.me/15551234567'));
    });

    test('encodes token in URL', () {
      final invite = Invite()..token = 'INV_ABC 123';
      final link = invite.getWhatsAppLink('5511999999999');

      expect(link, contains('text=INV_ABC%20123'));
    });

    test('handles null token gracefully', () {
      final invite = Invite();
      final link = invite.getWhatsAppLink('5511999999999');

      expect(link, equals('https://wa.me/5511999999999?text='));
    });
  });

  group('InviteStatus enum', () {
    test('all values exist', () {
      expect(InviteStatus.values, containsAll([
        InviteStatus.pending,
        InviteStatus.accepted,
        InviteStatus.rejected,
        InviteStatus.cancelled,
      ]));
    });

    test('round-trip through JSON', () {
      for (final status in InviteStatus.values) {
        final invite = Invite()..status = status;
        final restored = Invite.fromJson(invite.toJson());
        expect(restored.status, equals(status));
      }
    });

    test('unknown enum value falls back to pending', () {
      final json = {'status': 'unknown_value'};
      final invite = Invite.fromJson(json);
      expect(invite.status, equals(InviteStatus.pending));
    });
  });

  group('InviteChannel enum', () {
    test('all values exist', () {
      expect(InviteChannel.values, containsAll([
        InviteChannel.app,
        InviteChannel.whatsapp,
      ]));
    });

    test('round-trip through JSON', () {
      for (final channel in InviteChannel.values) {
        final invite = Invite()..channel = channel;
        final restored = Invite.fromJson(invite.toJson());
        expect(restored.channel, equals(channel));
      }
    });

    test('unknown enum value falls back to app', () {
      final json = {'channel': 'sms'};
      final invite = Invite.fromJson(json);
      expect(invite.channel, equals(InviteChannel.app));
    });
  });
}
