import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:praticos/models/timeline_event.dart';
import 'package:praticos/models/membership.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/services/segment_config_service.dart';

/// iOS Dynamic Type font sizes
class _FontSize {
  static const double body = 17; // Main text
  static const double subhead = 15; // Tertiary text
  static const double footnote = 13; // Meta info
  static const double caption1 = 12; // Small labels
  static const double caption2 = 11; // Timestamps
}

class EventCard extends StatelessWidget {
  final TimelineEvent event;
  final bool isFromMe;
  final VoidCallback? onTap;
  final List<Membership> collaborators;

  const EventCard({
    super.key,
    required this.event,
    required this.isFromMe,
    this.onTap,
    this.collaborators = const [],
  });

  @override
  Widget build(BuildContext context) {
    // Wrap in DefaultTextStyle to remove yellow underline
    return DefaultTextStyle(
      style: TextStyle(
        decoration: TextDecoration.none,
        color: CupertinoColors.label.resolveFrom(context),
      ),
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    // Route to specific card type
    if (event.isComment) {
      return _buildCommentBubble(context);
    } else if (event.type == 'photos_added') {
      return _buildPhotoCard(context);
    } else if (event.type == 'status_change') {
      // Status changes are rendered as separators (not balloons)
      return _buildStatusSeparator(context);
    } else {
      return _buildSystemEventCard(context);
    }
  }

  /// Status separator (centered text line, not a bubble)
  /// Similar to date separators, status changes are displayed as simple text lines
  Widget _buildStatusSeparator(BuildContext context) {
    final content = _getStatusContent(context);
    final textColor = CupertinoColors.secondaryLabel.resolveFrom(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Center(
          child: Text(
            '${content.icon} ${content.text} · ${_formatTime(event.createdAt)}',
            style: TextStyle(
              fontSize: _FontSize.caption1,
              color: textColor,
            ),
          ),
        ),
      ),
    );
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
      padding: const EdgeInsets.symmetric(vertical: 6),
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
                              fontSize: _FontSize.footnote,
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
                                  fontSize: _FontSize.caption2,
                                  color:
                                      CupertinoColors.white.withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  // Message text with highlighted mentions
                  _buildMessageText(
                    event.data?.text ?? '',
                    textColor,
                    isFromMe || isCustomer,
                  ),
                  // Timestamp and visibility indicator
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(event.createdAt),
                        style: TextStyle(
                          fontSize: _FontSize.caption2,
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
                          size: _FontSize.caption2,
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

  /// System event card (WhatsApp style - centered, compact, single line)
  Widget _buildSystemEventCard(BuildContext context) {
    final chatContent = _getChatEventContent(context);
    final textColor = CupertinoColors.secondaryLabel.resolveFrom(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Center(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.9,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey6.resolveFrom(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${chatContent.icon} ${chatContent.text}${chatContent.detail ?? ''} · ${_formatTime(event.createdAt)}',
              style: TextStyle(
                fontSize: _FontSize.caption1,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  /// Get compact chat event content (icon, text, detail, color)
  _ChatEventContent _getChatEventContent(BuildContext context) {
    switch (event.type) {
      case 'status_change':
        return _getStatusContent(context);
      case 'due_date_change':
        return _getDueDateContent(context);
      case 'payment_received':
        return _getPaymentContent(context);
      case 'payment_status_change':
        return _getPaymentStatusContent(context);
      case 'form_completed':
        return _ChatEventContent(
          icon: '✅',
          text: context.l10n.checklistCompletedChat,
        );
      default:
        // Fallback for any other event types
        return _ChatEventContent(
          icon: event.icon,
          text: _getEventTitle(context),
          detail: _getEventSubtitle(context) != null
              ? ': ${_getEventSubtitle(context)}'
              : null,
        );
    }
  }

  /// Get status change content with system colors (uses SegmentConfigService)
  _ChatEventContent _getStatusContent(BuildContext context) {
    final newStatus = event.data?.newStatus;
    final config = SegmentConfigService();
    final statusText = config.getStatus(newStatus);

    // Get icon based on status
    String icon;
    switch (newStatus) {
      case 'quote':
        icon = '🟠';
        break;
      case 'approved':
        icon = '🔵';
        break;
      case 'progress':
        icon = '🟣';
        break;
      case 'done':
        icon = '🟢';
        break;
      case 'canceled':
        icon = '🔴';
        break;
      default:
        icon = '⚪';
    }

    return _ChatEventContent(
      icon: icon,
      text: statusText,
    );
  }

  /// Get due date change content
  _ChatEventContent _getDueDateContent(BuildContext context) {
    final oldDate = event.data?.oldDate;
    final newDate = event.data?.newDate;

    if (newDate == null && oldDate != null) {
      // Delivery removed
      return _ChatEventContent(
        icon: '📅',
        text: context.l10n.deliveryRemoved,
      );
    }

    if (oldDate == null && newDate != null) {
      // Delivery defined
      return _ChatEventContent(
        icon: '📅',
        text: context.l10n.deliveryDefined,
        detail: ': ${_formatDate(newDate)}',
      );
    }

    // Delivery rescheduled
    return _ChatEventContent(
      icon: '📅',
      text: context.l10n.deliveryRescheduled,
      detail: ': ${_formatDate(oldDate)} → ${_formatDate(newDate)}',
    );
  }

  /// Get payment received content
  _ChatEventContent _getPaymentContent(BuildContext context) {
    final amount = event.data?.amount ?? 0;
    final orderTotal = event.data?.orderTotal ?? 0;
    final isPartial = orderTotal > 0 && amount < orderTotal;

    return _ChatEventContent(
      icon: '💳',
      text: context.l10n.paymentReceivedChat,
      detail: ': R\$ ${amount.toStringAsFixed(2)}${isPartial ? ' (${context.l10n.paymentPartial})' : ''}',
    );
  }

  /// Get payment status change content
  _ChatEventContent _getPaymentStatusContent(BuildContext context) {
    final newStatus = event.data?.newStatus;

    if (newStatus == 'paid') {
      return _ChatEventContent(
        icon: '✅',
        text: context.l10n.markedAsPaid,
      );
    }

    return _ChatEventContent(
      icon: '⚠️',
      text: context.l10n.markedAsUnpaid,
    );
  }

  /// Photo card with image grid (aligned by author)
  Widget _buildPhotoCard(BuildContext context) {
    final photos = event.data?.photoUrls ?? [];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment:
            isFromMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Author and time header
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isFromMe) ...[
                  _buildAvatar(context),
                  const SizedBox(width: 8),
                ],
                Text(
                  '📷 ${_formatTime(event.createdAt)}',
                  style: TextStyle(
                    fontSize: _FontSize.caption1,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ],
            ),
          ),
          // Photo grid
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _buildPhotoGrid(context, photos),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoGrid(BuildContext context, List<String> photos) {
    if (photos.isEmpty) {
      return const SizedBox.shrink();
    }

    if (photos.length == 1) {
      return _buildPhotoTile(context, photos[0], index: 0);
    }

    if (photos.length == 2) {
      return Row(
        children: [
          Expanded(child: _buildPhotoTile(context, photos[0], aspectRatio: 1, index: 0)),
          const SizedBox(width: 2),
          Expanded(child: _buildPhotoTile(context, photos[1], aspectRatio: 1, index: 1)),
        ],
      );
    }

    if (photos.length == 3) {
      return Row(
        children: [
          Expanded(
            flex: 2,
            child: _buildPhotoTile(context, photos[0], aspectRatio: 0.75, index: 0),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Column(
              children: [
                _buildPhotoTile(context, photos[1], aspectRatio: 1, index: 1),
                const SizedBox(height: 2),
                _buildPhotoTile(context, photos[2], aspectRatio: 1, index: 2),
              ],
            ),
          ),
        ],
      );
    }

    // 4+ photos: 2x2 grid with overflow indicator
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildPhotoTile(context, photos[0], aspectRatio: 1, index: 0)),
            const SizedBox(width: 2),
            Expanded(child: _buildPhotoTile(context, photos[1], aspectRatio: 1, index: 1)),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Expanded(child: _buildPhotoTile(context, photos[2], aspectRatio: 1, index: 2)),
            const SizedBox(width: 2),
            Expanded(
              child: photos.length > 4
                  ? _buildPhotoTileWithOverlay(
                      context, photos[3], photos.length - 4, 3)
                  : _buildPhotoTile(context, photos[3], aspectRatio: 1, index: 3),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPhotoTile(BuildContext context, String url,
      {double? aspectRatio, int? index}) {
    final widget = GestureDetector(
      onTap: () => _openPhotoViewer(context, url, index ?? 0),
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: CupertinoColors.systemGrey5.resolveFrom(context),
          child: const Center(
            child: CupertinoActivityIndicator(),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          color: CupertinoColors.systemGrey5.resolveFrom(context),
          child: const Center(
            child: Icon(CupertinoIcons.photo, size: 32),
          ),
        ),
      ),
    );

    if (aspectRatio != null) {
      return AspectRatio(
        aspectRatio: aspectRatio,
        child: widget,
      );
    }

    return widget;
  }

  void _openPhotoViewer(BuildContext context, String initialUrl, int initialIndex) {
    final photos = event.data?.photoUrls ?? [];

    Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(
        fullscreenDialog: true,
        builder: (context) => _FullscreenPhotoViewer(
          photos: photos,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  Widget _buildPhotoTileWithOverlay(
      BuildContext context, String url, int moreCount, int index) {
    return GestureDetector(
      onTap: () => _openPhotoViewer(context, url, index),
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              errorWidget: (context, url, error) => Container(
                color: CupertinoColors.systemGrey5.resolveFrom(context),
                child: const Center(
                  child: Icon(CupertinoIcons.photo, size: 32),
                ),
              ),
            ),
            Container(
              color: CupertinoColors.black.withValues(alpha: 0.5),
              child: Center(
                child: Text(
                  '+$moreCount',
                  style: const TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
            fontSize: _FontSize.caption1,
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
      case 'form_added':
        return context.l10n.checklistAdded;
      case 'form_updated':
        return context.l10n.checklistUpdated;
      case 'form_completed':
        return context.l10n.checklistCompleted;
      case 'payment_received':
        return context.l10n.paymentReceived;
      case 'payment_removed':
        return context.l10n.paymentRemoved;
      case 'discount_applied':
        return context.l10n.discountApplied;
      case 'discount_removed':
        return context.l10n.discountRemoved;
      case 'payment_status_change':
        return event.data?.newStatus == 'paid'
            ? context.l10n.markedAsPaid
            : context.l10n.markedAsUnpaid;
      case 'assignment_change':
        return context.l10n
            .assignedTo(event.data?.newAssignee?.name ?? '');
      case 'order_created':
        return context.l10n.osCreated;
      case 'device_change':
        return context.l10n.deviceChanged;
      case 'customer_change':
        return context.l10n.customerChanged;
      case 'due_date_change':
        return context.l10n.dueDateChanged;
      default:
        return context.l10n.newActivity;
    }
  }

  String? _getEventSubtitle(BuildContext context) {
    switch (event.type) {
      case 'status_change':
        return '${event.data?.oldStatus ?? ''} → ${event.data?.newStatus ?? ''}';
      case 'device_change':
        final oldName = event.data?.oldDeviceName ?? '?';
        final newName = event.data?.newDeviceName ?? '?';
        return '$oldName → $newName';
      case 'customer_change':
        final oldName = event.data?.oldCustomerName ?? '?';
        final newName = event.data?.newCustomerName ?? '?';
        return '$oldName → $newName';
      case 'due_date_change':
        final oldDate = _formatDate(event.data?.oldDate);
        final newDate = _formatDate(event.data?.newDate);
        return '$oldDate → $newDate';
      case 'service_added':
        final value = event.data?.serviceValue;
        return '${event.data?.serviceName}${value != null ? ' • R\$ ${value.toStringAsFixed(2)}' : ''}';
      case 'service_updated':
        final oldVal = event.data?.oldValue;
        final newVal = event.data?.newValue;
        if (oldVal != null && newVal != null) {
          return '${event.data?.serviceName} • R\$ ${oldVal.toStringAsFixed(2)} → R\$ ${newVal.toStringAsFixed(2)}';
        }
        return event.data?.serviceName;
      case 'service_removed':
        final sValue = event.data?.serviceValue;
        return '${event.data?.serviceName}${sValue != null ? ' • R\$ ${sValue.toStringAsFixed(2)}' : ''}';
      case 'product_added':
        return '${event.data?.productName} (${event.data?.quantity}x)';
      case 'product_updated':
        final oldQty = event.data?.oldQuantity;
        final newQty = event.data?.newQuantity;
        if (oldQty != null && newQty != null && oldQty != newQty) {
          return '${event.data?.productName} • ${oldQty}x → ${newQty}x';
        }
        final oldT = event.data?.oldTotal;
        final newT = event.data?.newTotal;
        if (oldT != null && newT != null) {
          return '${event.data?.productName} • R\$ ${oldT.toStringAsFixed(2)} → R\$ ${newT.toStringAsFixed(2)}';
        }
        return event.data?.productName;
      case 'product_removed':
        return '${event.data?.productName} (${event.data?.quantity}x)';
      case 'form_added':
        return event.data?.formName;
      case 'form_updated':
        final completed = event.data?.completedItems ?? 0;
        final total = event.data?.totalItems ?? 0;
        return '${event.data?.formName} • $completed/$total';
      case 'form_completed':
        return event.data?.formName;
      case 'payment_received':
        return 'R\$ ${event.data?.amount?.toStringAsFixed(2)} • ${event.data?.method}';
      case 'payment_removed':
        return 'R\$ ${event.data?.amount?.toStringAsFixed(2)}${event.data?.description != null ? ' • ${event.data!.description}' : ''}';
      case 'discount_applied':
        return 'R\$ ${event.data?.amount?.toStringAsFixed(2)}${event.data?.description != null ? ' • ${event.data!.description}' : ''}';
      case 'discount_removed':
        return 'R\$ ${event.data?.amount?.toStringAsFixed(2)}${event.data?.description != null ? ' • ${event.data!.description}' : ''}';
      case 'payment_status_change':
        final total = event.data?.orderTotal ?? 0;
        final paid = event.data?.totalPaid ?? 0;
        return 'R\$ ${paid.toStringAsFixed(2)} / R\$ ${total.toStringAsFixed(2)}';
      case 'order_created':
        return event.data?.customerName;
      default:
        return event.author?.name;
    }
  }

  /// Builds message text with highlighted @mentions
  Widget _buildMessageText(String text, Color textColor, bool isColoredBubble) {
    // Get mentioned names from IDs
    final mentionedNames = _getMentionedNames();

    if (mentionedNames.isEmpty) {
      // Fallback: highlight any @word pattern
      return _buildTextWithSimpleMentions(text, textColor, isColoredBubble);
    }

    // Build regex to match full names after @
    final namesPattern = mentionedNames
        .map((name) => RegExp.escape(name))
        .join('|');
    final mentionRegex = RegExp('@($namesPattern)', caseSensitive: false);
    final matches = mentionRegex.allMatches(text);

    if (matches.isEmpty) {
      return Text(
        text,
        style: TextStyle(
          fontSize: _FontSize.body,
          color: textColor,
        ),
      );
    }

    final spans = <TextSpan>[];
    int lastEnd = 0;

    for (final match in matches) {
      // Add text before mention
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }

      // Add highlighted mention
      spans.add(TextSpan(
        text: match.group(0),
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isColoredBubble
              ? CupertinoColors.white
              : CupertinoColors.activeBlue,
        ),
      ));

      lastEnd = match.end;
    }

    // Add remaining text
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return Text.rich(
      TextSpan(
        style: TextStyle(
          fontSize: _FontSize.body,
          color: textColor,
        ),
        children: spans,
      ),
    );
  }

  /// Gets the names of mentioned users from their IDs
  List<String> _getMentionedNames() {
    final mentionIds = event.mentions ?? [];
    if (mentionIds.isEmpty || collaborators.isEmpty) return [];

    final names = <String>[];
    for (final id in mentionIds) {
      final collab = collaborators.cast<Membership?>().firstWhere(
        (c) => c?.userId == id,
        orElse: () => null,
      );
      if (collab?.user?.name != null) {
        names.add(collab!.user!.name!);
      }
    }
    return names;
  }

  /// Fallback: highlight simple @word patterns
  Widget _buildTextWithSimpleMentions(String text, Color textColor, bool isColoredBubble) {
    final mentionRegex = RegExp(r'@(\S+)');
    final matches = mentionRegex.allMatches(text);

    if (matches.isEmpty) {
      return Text(
        text,
        style: TextStyle(
          fontSize: _FontSize.body,
          color: textColor,
        ),
      );
    }

    final spans = <TextSpan>[];
    int lastEnd = 0;

    for (final match in matches) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(0),
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isColoredBubble
              ? CupertinoColors.white
              : CupertinoColors.activeBlue,
        ),
      ));
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return Text.rich(
      TextSpan(
        style: TextStyle(
          fontSize: _FontSize.body,
          color: textColor,
        ),
        children: spans,
      ),
    );
  }

  String _formatTime(DateTime? date) {
    if (date == null) return '';
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '?';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
  }
}

/// Fullscreen photo viewer with swipe navigation
class _FullscreenPhotoViewer extends StatefulWidget {
  final List<String> photos;
  final int initialIndex;

  const _FullscreenPhotoViewer({
    required this.photos,
    required this.initialIndex,
  });

  @override
  State<_FullscreenPhotoViewer> createState() => _FullscreenPhotoViewerState();
}

/// Helper class for chat event content
class _ChatEventContent {
  final String icon;
  final String text;
  final String? detail;

  const _ChatEventContent({
    required this.icon,
    required this.text,
    this.detail,
  });
}

class _FullscreenPhotoViewerState extends State<_FullscreenPhotoViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.black.withValues(alpha: 0.8),
        border: null,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(
            CupertinoIcons.xmark,
            color: CupertinoColors.white,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        middle: widget.photos.length > 1
            ? Text(
                '${_currentIndex + 1} / ${widget.photos.length}',
                style: const TextStyle(color: CupertinoColors.white),
              )
            : null,
      ),
      child: SafeArea(
        child: PageView.builder(
          controller: _pageController,
          itemCount: widget.photos.length,
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          itemBuilder: (context, index) {
            return InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: widget.photos[index],
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const Center(
                    child: CupertinoActivityIndicator(
                      color: CupertinoColors.white,
                    ),
                  ),
                  errorWidget: (context, url, error) => const Center(
                    child: Icon(
                      CupertinoIcons.photo,
                      size: 64,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
