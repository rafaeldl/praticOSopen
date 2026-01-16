import 'package:flutter/cupertino.dart';
import 'package:praticos/models/timeline_event.dart';
import 'package:praticos/extensions/context_extensions.dart';

class EventCard extends StatelessWidget {
  final TimelineEvent event;
  final bool isFromMe;

  const EventCard({
    super.key,
    required this.event,
    required this.isFromMe,
  });

  @override
  Widget build(BuildContext context) {
    // Route to specific card type
    if (event.isComment) {
      return _buildCommentBubble(context);
    } else {
      return _buildSystemEventCard(context);
    }
  }

  /// Chat bubble for comments (WhatsApp style)
  Widget _buildCommentBubble(BuildContext context) {
    final isCustomer = event.isFromCustomer;
    final isPublic = event.isPublic;

    // Bubble colors
    final bubbleColor = isFromMe
        ? CupertinoColors.activeBlue
        : isCustomer
            ? CupertinoColors.systemGreen
            : CupertinoColors.systemGrey5.resolveFrom(context);

    final textColor = isFromMe || isCustomer
        ? CupertinoColors.white
        : CupertinoColors.label.resolveFrom(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isFromMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar for others
          if (!isFromMe) ...[
            _buildAvatar(context),
            const SizedBox(width: 8),
          ],
          // Bubble
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isFromMe ? 16 : 4),
                  bottomRight: Radius.circular(isFromMe ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Author name (for others)
                  if (!isFromMe && event.author?.name != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            event.author!.name!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isCustomer
                                  ? CupertinoColors.white.withValues(alpha: 0.9)
                                  : CupertinoColors.activeBlue,
                            ),
                          ),
                          if (isCustomer)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Text(
                                '(${context.l10n.customerLabel})',
                                style: TextStyle(
                                  fontSize: 10,
                                  color:
                                      CupertinoColors.white.withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  // Message text
                  Text(
                    event.data?.text ?? '',
                    style: TextStyle(
                      fontSize: 15,
                      color: textColor,
                    ),
                  ),
                  // Timestamp and visibility indicator
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(event.createdAt),
                        style: TextStyle(
                          fontSize: 10,
                          color: (isFromMe || isCustomer)
                              ? CupertinoColors.white.withValues(alpha: 0.7)
                              : CupertinoColors.secondaryLabel
                                  .resolveFrom(context),
                        ),
                      ),
                      // Visibility indicator
                      if (isPublic) ...[
                        const SizedBox(width: 4),
                        Icon(
                          CupertinoIcons.globe,
                          size: 10,
                          color: (isFromMe || isCustomer)
                              ? CupertinoColors.white.withValues(alpha: 0.7)
                              : CupertinoColors.secondaryLabel
                                  .resolveFrom(context),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Space for my messages
          if (isFromMe) const SizedBox(width: 8),
        ],
      ),
    );
  }

  /// System event card (status change, payment, etc.)
  Widget _buildSystemEventCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey6.resolveFrom(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: CupertinoColors.separator.resolveFrom(context),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            // Event Icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _getEventColor(event.type).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  event.icon,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Event Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getEventTitle(context),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
                  if (_getEventSubtitle(context) != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        _getEventSubtitle(context)!,
                        style: TextStyle(
                          fontSize: 12,
                          color: CupertinoColors.secondaryLabel
                              .resolveFrom(context),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Timestamp
            Text(
              _formatTime(event.createdAt),
              style: TextStyle(
                fontSize: 11,
                color: CupertinoColors.tertiaryLabel.resolveFrom(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    final name = event.author?.name;
    final initial = (name != null && name.isNotEmpty) ? name[0].toUpperCase() : '?';
    final isCustomer = event.isFromCustomer;

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: isCustomer
            ? CupertinoColors.systemGreen
            : CupertinoColors.systemGrey4.resolveFrom(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isCustomer
                ? CupertinoColors.white
                : CupertinoColors.label.resolveFrom(context),
          ),
        ),
      ),
    );
  }

  String _getEventTitle(BuildContext context) {
    switch (event.type) {
      case 'status_change':
        return context.l10n.statusChanged;
      case 'photos_added':
        final count = event.data?.photoUrls?.length ?? 1;
        return context.l10n.photosAdded(count);
      case 'service_added':
        return context.l10n.serviceAdded;
      case 'service_updated':
        return context.l10n.serviceUpdated;
      case 'service_removed':
        return context.l10n.serviceRemoved;
      case 'product_added':
        return context.l10n.productAdded;
      case 'product_updated':
        return context.l10n.productUpdated;
      case 'product_removed':
        return context.l10n.productRemoved;
      case 'form_completed':
        return context.l10n.checklistCompleted;
      case 'payment_received':
        return context.l10n.paymentReceived;
      case 'assignment_change':
        return context.l10n
            .assignedTo(event.data?.newAssignee?.name ?? '');
      case 'order_created':
        return context.l10n.osCreated;
      default:
        return context.l10n.newActivity;
    }
  }

  String? _getEventSubtitle(BuildContext context) {
    switch (event.type) {
      case 'status_change':
        return '${event.data?.oldStatus ?? ''} → ${event.data?.newStatus ?? ''}';
      case 'service_added':
        final value = event.data?.serviceValue;
        return '${event.data?.serviceName}${value != null ? ' • R\$ ${value.toStringAsFixed(2)}' : ''}';
      case 'product_added':
        return '${event.data?.productName} (${event.data?.quantity}x)';
      case 'form_completed':
        return event.data?.formName;
      case 'payment_received':
        return 'R\$ ${event.data?.amount?.toStringAsFixed(2)} • ${event.data?.method}';
      case 'order_created':
        return event.data?.customerName;
      default:
        return event.author?.name;
    }
  }

  Color _getEventColor(String? type) {
    switch (type) {
      case 'status_change':
        return CupertinoColors.activeBlue;
      case 'photos_added':
        return CupertinoColors.systemPurple;
      case 'service_added':
      case 'service_updated':
      case 'service_removed':
        return CupertinoColors.systemOrange;
      case 'product_added':
      case 'product_updated':
      case 'product_removed':
        return CupertinoColors.systemTeal;
      case 'form_completed':
        return CupertinoColors.systemIndigo;
      case 'payment_received':
        return CupertinoColors.systemGreen;
      case 'assignment_change':
        return CupertinoColors.systemPink;
      case 'order_created':
        return CupertinoColors.activeBlue;
      default:
        return CupertinoColors.systemGrey;
    }
  }

  String _formatTime(DateTime? date) {
    if (date == null) return '';
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
