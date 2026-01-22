import 'dart:async';

import 'package:mobx/mobx.dart';
import 'package:praticos/models/timeline_event.dart';
import 'package:praticos/repositories/timeline_repository.dart';
import 'package:praticos/global.dart';
import 'package:praticos/screens/timeline/widgets/collapsed_events_group.dart';

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

  /// Event types that appear in the chat (relevant for conversation)
  static const _chatEventTypes = {
    'comment',
    'status_change',
    'due_date_change',
    'payment_received',
    // payment_status_change moved to audit-only (redundant with payment_received)
    'form_completed',
    'photos_added',
  };

  /// Event types that go to audit only (not shown in chat)
  // ignore: unused_field
  static const _auditOnlyEventTypes = {
    'order_created',
    'service_added',
    'service_updated',
    'service_removed',
    'product_added',
    'product_updated',
    'product_removed',
    'device_change',
    'customer_change',
    'form_added',
    'form_updated',
    'assignment_change',
    'discount_applied',
    'discount_removed',
    'payment_removed',
    'payment_status_change', // Redundant with payment_received
  };

  /// Filtered events for chat display (only relevant events)
  @computed
  List<TimelineEvent> get chatEvents {
    final filtered = events.where((e) {
      // Always show comments
      if (e.isComment) return true;
      // Show only chat-relevant event types
      if (!_chatEventTypes.contains(e.type)) return false;
      return true;
    }).toList();

    // Apply debounce and dedup rules
    return _applyDebounceAndDedup(filtered);
  }

  /// Apply debounce (≤300s for status) and dedup (no-op) rules
  List<TimelineEvent> _applyDebounceAndDedup(List<TimelineEvent> events) {
    if (events.isEmpty) return events;

    final result = <TimelineEvent>[];
    TimelineEvent? lastStatusEvent;

    for (var i = 0; i < events.length; i++) {
      final event = events[i];

      // Debounce status changes within 5 minutes (300 seconds)
      // This consolidates rapid status toggles (e.g., Done -> In Progress -> Done)
      if (event.type == 'status_change') {
        // Look ahead for more status changes within 300s
        if (i + 1 < events.length) {
          final nextEvent = events[i + 1];
          if (nextEvent.type == 'status_change' &&
              nextEvent.createdAt != null &&
              event.createdAt != null) {
            final diff =
                nextEvent.createdAt!.difference(event.createdAt!).inSeconds.abs();
            if (diff <= 300) {
              // Skip this one, use the next one (keep only the final status)
              continue;
            }
          }
        }

        // Dedup: skip if same status as last
        if (lastStatusEvent != null &&
            event.data?.newStatus == lastStatusEvent.data?.newStatus) {
          continue;
        }
        lastStatusEvent = event;
      }

      // Dedup due_date_change: skip no-op (same date)
      if (event.type == 'due_date_change') {
        final oldDate = event.data?.oldDate;
        final newDate = event.data?.newDate;
        if (oldDate != null && newDate != null) {
          if (oldDate.year == newDate.year &&
              oldDate.month == newDate.month &&
              oldDate.day == newDate.day) {
            continue; // Skip no-op
          }
        }
      }

      result.add(event);
    }

    return result;
  }

  /// Events grouped by date (for separators) - uses chatEvents
  @computed
  Map<String, List<TimelineEvent>> get eventsByDate {
    final grouped = <String, List<TimelineEvent>>{};

    for (final event in chatEvents) {
      final dateKey = _formatDateKey(event.createdAt);
      grouped.putIfAbsent(dateKey, () => []).add(event);
    }

    return grouped;
  }

  /// System event types that can be grouped (non-interactive events)
  static const _groupableEventTypes = {
    'status_change',
    'due_date_change',
    'form_completed',
  };

  /// Chat events with old system events grouped into collapsible blocks.
  /// Groups consecutive system events that are within 30 minutes of each other
  /// and older than 30 minutes from now.
  @computed
  Map<String, List<dynamic>> get chatEventsGrouped {
    final now = DateTime.now();
    final threshold = const Duration(minutes: 30);
    final result = <String, List<dynamic>>{};

    for (final entry in eventsByDate.entries) {
      final dateKey = entry.key;
      final dayEvents = entry.value;
      final groupedDay = <dynamic>[];

      List<TimelineEvent>? currentGroup;

      for (final event in dayEvents) {
        // Comments, photos, and payments are never grouped
        if (event.isComment ||
            event.type == 'photos_added' ||
            event.type == 'payment_received') {
          // Flush any pending group
          if (currentGroup != null && currentGroup.isNotEmpty) {
            if (currentGroup.length >= 2) {
              groupedDay.add(CollapsedGroup(currentGroup));
            } else {
              groupedDay.addAll(currentGroup);
            }
            currentGroup = null;
          }
          groupedDay.add(event);
          continue;
        }

        // Only group old system events (> 30 min ago)
        final isOldEvent = event.createdAt != null &&
            now.difference(event.createdAt!) > threshold;

        // Only group specific event types
        final isGroupable = _groupableEventTypes.contains(event.type);

        if (isOldEvent && isGroupable) {
          // Check if this event can join the current group (within 30 min of last)
          if (currentGroup != null && currentGroup.isNotEmpty) {
            final lastInGroup = currentGroup.last;
            final timeDiff = event.createdAt!
                .difference(lastInGroup.createdAt!)
                .inMinutes
                .abs();

            if (timeDiff <= 30) {
              currentGroup.add(event);
              continue;
            } else {
              // Flush current group, start new one
              if (currentGroup.length >= 2) {
                groupedDay.add(CollapsedGroup(currentGroup));
              } else {
                groupedDay.addAll(currentGroup);
              }
              currentGroup = [event];
              continue;
            }
          } else {
            // Start new group
            currentGroup = [event];
            continue;
          }
        }

        // Non-groupable event: flush any pending group
        if (currentGroup != null && currentGroup.isNotEmpty) {
          if (currentGroup.length >= 2) {
            groupedDay.add(CollapsedGroup(currentGroup));
          } else {
            groupedDay.addAll(currentGroup);
          }
          currentGroup = null;
        }
        groupedDay.add(event);
      }

      // Flush remaining group
      if (currentGroup != null && currentGroup.isNotEmpty) {
        if (currentGroup.length >= 2) {
          groupedDay.add(CollapsedGroup(currentGroup));
        } else {
          groupedDay.addAll(currentGroup);
        }
      }

      result[dateKey] = groupedDay;
    }

    return result;
  }

  /// All events (for audit screen) - grouped by date
  @computed
  Map<String, List<TimelineEvent>> get allEventsByDate {
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
    List<String>? mentions,
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
        mentions: mentions,
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
