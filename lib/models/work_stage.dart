import 'package:json_annotation/json_annotation.dart';
import 'package:praticos/models/order.dart';

part 'work_stage.g.dart';

/// A step inside "Em andamento" (Pintura, Polimento…), from
/// `company.workStages`. See docs/WORK_STAGES.md.
class WorkStage {
  const WorkStage(this.id, this.name);

  final String id;
  final String name;

  /// The company's stages in order. Entries without `id` or `name` are left
  /// out; anything else than a list means no stages.
  static List<WorkStage> listFrom(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final entry in raw)
        if (entry is Map &&
            entry['id'] is String &&
            (entry['id'] as String).isNotEmpty &&
            entry['name'] is String &&
            (entry['name'] as String).trim().isNotEmpty)
          WorkStage(entry['id'] as String, (entry['name'] as String).trim()),
    ];
  }

  /// Stage an order is in: only while in progress. One with no stage (started
  /// before stages, or by the API) or with a stage the company removed is in
  /// the first one, as on the web board.
  static WorkStage? of(Order order, List<WorkStage> stages) {
    if (order.status != 'progress' || stages.isEmpty) return null;
    final id = order.stage?.id;
    return stages.firstWhere((s) => s.id == id, orElse: () => stages.first);
  }

  /// The stage after the one the order is in; null on the last one.
  static WorkStage? next(Order order, List<WorkStage> stages) {
    final current = of(order, stages);
    if (current == null) return null;
    final index = stages.indexOf(current);
    return index + 1 < stages.length ? stages[index + 1] : null;
  }
}

/// Where an in-progress order is: its stage, its place in that column of the
/// web board and since when. Written only by the server
/// (`PUT /v1/app/orders/:id/stage`).
@JsonSerializable(includeIfNull: false)
class OrderStage {
  String? id;
  double? rank;
  DateTime? since;

  OrderStage();

  factory OrderStage.fromJson(Map<String, dynamic> json) =>
      _$OrderStageFromJson(json);
  Map<String, dynamic> toJson() => _$OrderStageToJson(this);
}
