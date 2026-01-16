import 'package:flutter/cupertino.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/mobx/timeline_store.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/timeline_event.dart';
import 'package:praticos/global.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/screens/timeline/widgets/event_card.dart';
import 'package:praticos/screens/timeline/widgets/message_input.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  final TimelineStore _store = TimelineStore();
  final ScrollController _scrollController = ScrollController();
  final FormatService _formatService = FormatService();
  Order? _order;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _formatService.setLocale(context.l10n.localeName);

    if (_order == null) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      _order = args?['order'] as Order?;

      if (_order?.id != null && Global.companyAggr?.id != null) {
        _store.init(Global.companyAggr!.id!, _order!.id!);
      }
    }
  }

  @override
  void dispose() {
    _store.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _navigateToOrder() {
    if (_order != null) {
      Navigator.of(context, rootNavigator: true)
          .pushNamed('/order', arguments: {'order': _order});
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _order?.customer?.name ?? context.l10n.timeline,
              style: const TextStyle(fontSize: 17),
            ),
            if (_order?.device?.name != null)
              Text(
                _order!.device!.name!,
                style: TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
          ],
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.info),
          onPressed: () {
            Navigator.of(context, rootNavigator: true)
                .pushNamed('/order', arguments: {'order': _order});
          },
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Order Status Header
            _buildOrderHeader(),
            // Timeline Events List
            Expanded(
              child: Observer(
                builder: (_) {
                  if (_store.isLoading) {
                    return const Center(
                      child: CupertinoActivityIndicator(),
                    );
                  }

                  if (_store.error != null) {
                    return Center(
                      child: Text(
                        _store.error!,
                        style: TextStyle(
                          color: CupertinoColors.systemRed,
                        ),
                      ),
                    );
                  }

                  final events = _store.events;

                  if (events.isEmpty) {
                    return _buildEmptyState();
                  }

                  // Scroll to bottom when new events arrive
                  _scrollToBottom();

                  return _buildEventsList(events);
                },
              ),
            ),
            // Message Input
            MessageInput(
              onSend: (text, isPublic) async {
                await _store.sendMessage(text, isPublic: isPublic);
                _scrollToBottom();
              },
              isSending: _store.isSending,
              customerName: _order?.customer?.name,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderHeader() {
    final statusColor = _getStatusColor(_order?.status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGroupedBackground.resolveFrom(context),
        border: Border(
          bottom: BorderSide(
            color: CupertinoColors.separator.resolveFrom(context),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              Order.statusMap[_order?.status] ?? _order?.status ?? '',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Order Number
          if (_order?.number != null)
            Text(
              '#${_order!.number}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.label.resolveFrom(context),
              ),
            ),
          const Spacer(),
          // Due Date
          if (_order?.dueDate != null)
            Text(
              _formatService.formatDate(_order!.dueDate!),
              style: TextStyle(
                fontSize: 12,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.chat_bubble_2,
            size: 64,
            color: CupertinoColors.systemGrey3.resolveFrom(context),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.timelineEmpty,
            style: TextStyle(
              fontSize: 16,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsList(List<TimelineEvent> events) {
    final eventsByDate = _store.eventsByDate;

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: eventsByDate.length,
      itemBuilder: (context, index) {
        final dateKey = eventsByDate.keys.elementAt(index);
        final dateEvents = eventsByDate[dateKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Date Separator
            _buildDateSeparator(dateKey),
            // Events for this date
            ...dateEvents.map((event) => EventCard(
                  event: event,
                  isFromMe: event.author?.id == Global.userAggr?.id,
                  onTap: event.isComment ? null : () => _navigateToOrder(),
                )),
          ],
        );
      },
    );
  }

  Widget _buildDateSeparator(String dateKey) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey5.resolveFrom(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            dateKey,
            style: TextStyle(
              fontSize: 12,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'quote':
        return CupertinoColors.systemOrange;
      case 'approved':
        return CupertinoColors.activeBlue;
      case 'progress':
        return CupertinoColors.systemPurple;
      case 'done':
        return CupertinoColors.systemGreen;
      case 'canceled':
        return CupertinoColors.systemRed;
      default:
        return CupertinoColors.systemGrey;
    }
  }
}
