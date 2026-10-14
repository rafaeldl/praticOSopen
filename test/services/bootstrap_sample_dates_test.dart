import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/services/bootstrap_service.dart';

void main() {
  test('sample orders are due in the coming days, never late', () {
    final now = DateTime(2026, 10, 31, 18, 30);
    final dates = [
      for (var i = 0; i < 4; i++) BootstrapService.sampleOrderDueDate(i, now),
    ];

    expect(dates.every((d) => d.isAfter(now)), isTrue);
    expect(dates.first, DateTime(2026, 11, 1, 9));
    expect(dates.last, DateTime(2026, 11, 7, 9));
  });
  test(
    'open sample orders are scheduled (Agenda), the finished one is not',
    () {
      final now = DateTime(2026, 10, 31, 18, 30);

      expect(
        BootstrapService.sampleOrderScheduledDate(0, 'quote', now),
        DateTime(2026, 11, 1, 9),
      );
      expect(
        BootstrapService.sampleOrderScheduledDate(2, 'progress', now),
        BootstrapService.sampleOrderDueDate(2, now),
      );
      expect(BootstrapService.sampleOrderScheduledDate(3, 'done', now), isNull);
    },
  );
}
