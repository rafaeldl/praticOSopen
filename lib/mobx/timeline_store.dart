import 'dart:async';

import 'package:mobx/mobx.dart';
import 'package:praticos/models/timeline_event.dart';
import 'package:praticos/repositories/timeline_repository.dart';
import 'package:praticos/global.dart';

part 'timeline_store.g.dart';

class TimelineStore = _TimelineStore with _$TimelineStore;

abstract class _TimelineStore with Store {
  final TimelineRepository _repository = TimelineRepository();

  StreamSubscription<List<TimelineEvent>>? _subscription;

  @observable
  ObservableList<TimelineEvent> events = ObservableList<TimelineEvent>();

  @observable
  bool isLoading = true;

  @observable
  bool isSending = false;

  @observable
  String? error;

  String? _companyId;
  String? _orderId;

  @computed
  int get unreadCount {
    final userId = Global.userAggr?.id;
    if (userId == null) return 0;
    return events.where((e) => !e.isReadBy(userId)).length;
  }

  /// Events grouped by date (for separators)
  @computed
  Map<String, List<TimelineEvent>> get eventsByDate {
    final grouped = <String, List<TimelineEvent>>{};

    for (final event in events) {
      final dateKey = _formatDateKey(event.createdAt);
      grouped.putIfAbsent(dateKey, () => []).add(event);
    }

    return grouped;
  }

  @action
  void init(String companyId, String orderId) {
    _companyId = companyId;
    _orderId = orderId;
    isLoading = true;

    // Cancel previous subscription if any
    _subscription?.cancel();

    // Listen to stream and update observable list
    _subscription = _repository.getTimeline(companyId, orderId).listen(
      (newEvents) {
        _updateEvents(newEvents);
      },
      onError: (e) {
        error = e.toString();
        isLoading = false;
      },
    );

    // Mark as read when opening
    _markAllAsRead();
  }

  @action
  void _updateEvents(List<TimelineEvent> newEvents) {
    events.clear();
    events.addAll(newEvents);
    isLoading = false;
  }

  @action
  Future<void> sendMessage(
    String text, {
    List<TimelineAttachment>? attachments,
    bool isPublic = false,
  }) async {
    if (_companyId == null || _orderId == null) return;
    if (text.trim().isEmpty && (attachments?.isEmpty ?? true)) return;

    isSending = true;
    error = null;

    try {
      await _repository.sendComment(
        _companyId!,
        _orderId!,
        text.trim(),
        attachments: attachments,
        isPublic: isPublic,
      );
    } catch (e) {
      error = e.toString();
    } finally {
      isSending = false;
    }
  }

  @action
  Future<void> _markAllAsRead() async {
    if (_companyId == null || _orderId == null) return;

    final userId = Global.userAggr?.id;
    if (userId == null) return;

    await _repository.markAllAsRead(_companyId!, _orderId!, userId);
  }

  @action
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    events.clear();
    _companyId = null;
    _orderId = null;
  }

  String _formatDateKey(DateTime? date) {
    if (date == null) return 'Desconhecido';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final eventDate = DateTime(date.year, date.month, date.day);

    if (eventDate == today) return 'Hoje';
    if (eventDate == yesterday) return 'Ontem';
    if (now.difference(date).inDays < 7) {
      const weekdays = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
      return weekdays[date.weekday - 1];
    }

    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
