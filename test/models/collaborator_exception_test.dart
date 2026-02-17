import 'package:praticos/models/collaborator_exception.dart';
import 'package:test/test.dart';

void main() {
  group('CollaboratorException construction', () {
    test('creates exception for each error code', () {
      for (final code in CollaboratorErrorCode.values) {
        final exception = CollaboratorException(code);
        expect(exception.code, equals(code));
      }
    });

    test('stores the provided error code', () {
      final exception =
          CollaboratorException(CollaboratorErrorCode.cannotRemoveOnlyAdmin);
      expect(exception.code, equals(CollaboratorErrorCode.cannotRemoveOnlyAdmin));
    });
  });

  group('CollaboratorException.toString()', () {
    test('formats as CollaboratorException: {code.name}', () {
      final exception =
          CollaboratorException(CollaboratorErrorCode.cannotRemoveOnlyAdmin);
      expect(
        exception.toString(),
        equals('CollaboratorException: cannotRemoveOnlyAdmin'),
      );
    });

    test('formats correctly for each error code', () {
      final expected = {
        CollaboratorErrorCode.cannotRemoveOnlyAdmin:
            'CollaboratorException: cannotRemoveOnlyAdmin',
        CollaboratorErrorCode.cannotChangeOnlyAdminRole:
            'CollaboratorException: cannotChangeOnlyAdminRole',
        CollaboratorErrorCode.cannotRemoveSelf:
            'CollaboratorException: cannotRemoveSelf',
        CollaboratorErrorCode.invalidInvite:
            'CollaboratorException: invalidInvite',
        CollaboratorErrorCode.userNotFound:
            'CollaboratorException: userNotFound',
      };

      for (final entry in expected.entries) {
        final exception = CollaboratorException(entry.key);
        expect(exception.toString(), equals(entry.value));
      }
    });
  });

  group('CollaboratorException type', () {
    test('implements Exception', () {
      final exception =
          CollaboratorException(CollaboratorErrorCode.cannotRemoveSelf);
      expect(exception, isA<Exception>());
    });

    test('can be caught as Exception', () {
      expect(
        () => throw CollaboratorException(CollaboratorErrorCode.invalidInvite),
        throwsA(isA<Exception>()),
      );
    });

    test('can be caught as CollaboratorException', () {
      expect(
        () => throw CollaboratorException(CollaboratorErrorCode.userNotFound),
        throwsA(isA<CollaboratorException>()),
      );
    });
  });

  group('CollaboratorErrorCode', () {
    test('has exactly 5 values', () {
      expect(CollaboratorErrorCode.values.length, equals(5));
    });

    test('all expected codes exist', () {
      expect(CollaboratorErrorCode.values, containsAll([
        CollaboratorErrorCode.cannotRemoveOnlyAdmin,
        CollaboratorErrorCode.cannotChangeOnlyAdminRole,
        CollaboratorErrorCode.cannotRemoveSelf,
        CollaboratorErrorCode.invalidInvite,
        CollaboratorErrorCode.userNotFound,
      ]));
    });
  });
}
