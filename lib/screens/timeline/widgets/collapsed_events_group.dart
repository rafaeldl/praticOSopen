import 'package:flutter/cupertino.dart';
import 'package:praticos/models/timeline_event.dart';
import 'package:praticos/extensions/context_extensions.dart';

/// A collapsible group of system events.
/// Shows a compact summary when collapsed, expands to show all events.
class CollapsedEventsGroup extends StatefulWidget {
  final List<TimelineEvent> events;
  final Widget Function(TimelineEvent event) eventBuilder;

  const CollapsedEventsGroup({
    super.key,
    required this.events,
    required this.eventBuilder,
  });

  @override
  State<CollapsedEventsGroup> createState() => _CollapsedEventsGroupState();
}

class _CollapsedEventsGroupState extends State<CollapsedEventsGroup> {
  bool _isExpanded = false;

  String _getTimeRange() {
    if (widget.events.isEmpty) return '';

    final first = widget.events.first.createdAt;
    final last = widget.events.last.createdAt;

    if (first == null || last == null) return '';

    return '${_formatTime(first)}\u2013${_formatTime(last)}';
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final count = widget.events.length;
    final timeRange = _getTimeRange();

    return DefaultTextStyle(
      style: TextStyle(
        decoration: TextDecoration.none,
        color: CupertinoColors.label.resolveFrom(context),
      ),
      child: Column(
        children: [
          // Collapsed header (always visible)
          GestureDetector(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey6.resolveFrom(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.info_circle,
                        size: 14,
                        color: CupertinoColors.secondaryLabel.resolveFrom(context),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${l10n.orderUpdates} ($count) · $timeRange',
                        style: TextStyle(
                          fontSize: 12,
                          color: CupertinoColors.secondaryLabel.resolveFrom(context),
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _isExpanded
                            ? CupertinoIcons.chevron_up
                            : CupertinoIcons.chevron_down,
                        size: 12,
                        color: CupertinoColors.tertiaryLabel.resolveFrom(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Expanded content
          if (_isExpanded)
            ...widget.events.map((event) => widget.eventBuilder(event)),
        ],
      ),
    );
  }
}

/// Model class representing a group of collapsed events
class CollapsedGroup {
  final List<TimelineEvent> events;

  const CollapsedGroup(this.events);

  DateTime? get startTime => events.isNotEmpty ? events.first.createdAt : null;
  DateTime? get endTime => events.isNotEmpty ? events.last.createdAt : null;
  int get count => events.length;
}
