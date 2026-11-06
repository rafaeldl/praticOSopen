import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/work_stage.dart';

void main() {
  const paint = WorkStage('paint', 'Pintura');
  const polish = WorkStage('polish', 'Polimento');
  const stages = [paint, polish];

  Order order(String status, [String? stageId]) => Order()
    ..status = status
    ..stage = stageId == null ? null : (OrderStage()..id = stageId);

  test('reads the company stages in order, skipping broken entries', () {
    final read = WorkStage.listFrom([
      {
        'id': 'paint',
        'name': ' Pintura ',
        'keywords': ['pint'],
      },
      {'id': 'x'},
      {'name': 'Sem id'},
      'junk',
      {'id': 'polish', 'name': 'Polimento'},
    ]);
    expect(read.map((s) => '${s.id}:${s.name}'), [
      'paint:Pintura',
      'polish:Polimento',
    ]);
    expect(WorkStage.listFrom(null), isEmpty);
    expect(WorkStage.listFrom({'id': 'paint'}), isEmpty);
  });

  test('the stage only counts in progress', () {
    expect(WorkStage.of(order('progress', 'polish'), stages), polish);
    expect(WorkStage.of(order('approved', 'polish'), stages), isNull);
    expect(WorkStage.of(order('done', 'polish'), stages), isNull);
    expect(WorkStage.of(order('progress', 'polish'), const []), isNull);
  });

  test('no stage, or one the company removed, is the first one', () {
    expect(WorkStage.of(order('progress'), stages), paint);
    expect(WorkStage.of(order('progress', 'gone'), stages), paint);
  });

  test('next stage, none after the last', () {
    expect(WorkStage.next(order('progress'), stages), polish);
    expect(WorkStage.next(order('progress', 'polish'), stages), isNull);
    expect(WorkStage.next(order('approved'), stages), isNull);
  });

  test('a full save never sends the stage', () {
    final json = order('progress', 'paint').toJson();
    expect(json.containsKey('stage'), isFalse);
    final read = Order.fromJson({
      'status': 'progress',
      'stage': {
        'id': 'paint',
        'rank': 1730900000000,
        'since': '2026-11-06T12:30:00.000Z',
      },
    });
    expect(read.stage?.id, 'paint');
    expect(read.stage?.rank, 1730900000000);
  });
}
