import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/order.dart';

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
    test('the next date counts from the due date, not from today', () {
      final c = monthly(next: DateTime(2026, 11, 10));
      // The app only ran on the 25th.
      c.advanceAfterGenerating(DateTime(2026, 11, 25));
      expect(c.lastGeneratedDate, DateTime(2026, 11, 10));
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

  test('the generated order id is the same on every device', () {
    final due = DateTime(2026, 3, 5, 14, 30);
    expect(OrderContract.generatedOrderId('t1', due), 't1_20260305');
    expect(
      OrderContract.generatedOrderId('t1', DateTime(2026, 3, 5)),
      OrderContract.generatedOrderId('t1', due),
    );
  });
}
