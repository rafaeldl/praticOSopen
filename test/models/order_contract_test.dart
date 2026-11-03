import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/utils/contract_generation.dart';

OrderContract monthly({
  required DateTime next,
  DateTime? end,
  DateTime? start,
}) => OrderContract()
  ..frequency = 'monthly'
  ..interval = 1
  ..active = true
  ..autoGenerate = true
  ..startDate = start ?? DateTime(2026, 1, 10)
  ..nextDueDate = next
  ..endDate = end;

void main() {
  group('isDueAt', () {
    test('due on and after the date, not before', () {
      final c = monthly(next: DateTime(2026, 11, 10));
      expect(c.isDueAt(DateTime(2026, 11, 9)), isFalse);
      expect(c.isDueAt(DateTime(2026, 11, 10)), isTrue);
      expect(c.isDueAt(DateTime(2026, 11, 20)), isTrue);
    });

    test('never after the contract ended', () {
      final c = monthly(
        next: DateTime(2026, 12, 10),
        end: DateTime(2026, 11, 30),
      );
      expect(c.isDueAt(DateTime(2026, 12, 15)), isFalse);
    });

    test('the last day of the contract still counts', () {
      final c = monthly(
        next: DateTime(2026, 11, 30, 9),
        end: DateTime(2026, 11, 30),
      );
      expect(c.isDueAt(DateTime(2026, 12, 2)), isTrue);
    });
  });

  group('advanceAfterGenerating', () {
    test('the next date keeps the schedule day, not the day the app ran', () {
      final c = monthly(next: DateTime(2026, 11, 10));
      // The app only ran on the 25th.
      c.advanceAfterGenerating(DateTime(2026, 11, 25));
      expect(c.lastGeneratedDate, DateTime(2026, 11, 25));
      expect(c.nextDueDate, DateTime(2026, 12, 10));
      expect(c.generatedCount, 1);
      expect(c.active, isTrue);
    });

    test('stops when the next date is past the end', () {
      final c = monthly(
        next: DateTime(2026, 11, 10),
        end: DateTime(2026, 12, 1),
      );
      c.advanceAfterGenerating(DateTime(2026, 11, 10));
      expect(c.nextDueDate, DateTime(2026, 12, 10));
      expect(c.active, isFalse);
    });
  });

  test('missed periods are skipped: one order, next date in the future', () {
    final c = monthly(next: DateTime(2026, 6, 10));
    c.advanceAfterGenerating(DateTime(2026, 11, 3));
    expect(c.nextDueDate, DateTime(2026, 11, 10));
    expect(c.isDueAt(DateTime(2026, 11, 3)), isFalse);
  });

  test('the generated order id is the same on every device', () {
    final due = DateTime(2026, 3, 5, 14, 30);
    expect(contractOrderId('t1', due), 'contract_t1_20260305');
    expect(
      contractOrderId('t1', DateTime(2026, 3, 5)),
      contractOrderId('t1', due),
    );
  });
}
