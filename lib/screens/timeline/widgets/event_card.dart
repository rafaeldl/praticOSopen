import 'package:flutter/cupertino.dart';
import 'package:praticos/models/timeline_event.dart';
import 'package:praticos/extensions/context_extensions.dart';

class EventCard extends StatelessWidget {
  final TimelineEvent event;
  final bool isFromMe;
  final VoidCallback? onTap;

  const EventCard({
    super.key,
    required this.event,
    required this.isFromMe,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Route to specific card type
    if (event.isComment) {
      return _buildCommentBubble(context);
    } else if (event.type == 'photos_added') {
      return _buildPhotoCard(context);
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
      child: GestureDetector(
        onTap: onTap,
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
      ),
    );
  }

  /// Photo card with image grid
  Widget _buildPhotoCard(BuildContext context) {
    final photos = event.data?.photoUrls ?? [];
    final authorName = isFromMe ? context.l10n.you : event.author?.name;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
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
                  '$authorName • ${_formatTime(event.createdAt)}',
                  style: TextStyle(
                    fontSize: 12,
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
          // Caption if exists
          if (event.data?.caption != null && event.data!.caption!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                event.data!.caption!,
                style: TextStyle(
                  fontSize: 14,
                  color: CupertinoColors.label.resolveFrom(context),
                ),
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
      child: Image.network(
        url,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: CupertinoColors.systemGrey5.resolveFrom(context),
            child: const Center(
              child: CupertinoActivityIndicator(),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: CupertinoColors.systemGrey5.resolveFrom(context),
            child: const Center(
              child: Icon(CupertinoIcons.photo, size: 32),
            ),
          );
        },
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
            Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: CupertinoColors.systemGrey5.resolveFrom(context),
                  child: const Center(
                    child: Icon(CupertinoIcons.photo, size: 32),
                  ),
                );
              },
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
      case 'form_added':
      case 'form_updated':
      case 'form_completed':
        return CupertinoColors.systemIndigo;
      case 'payment_received':
        return CupertinoColors.systemGreen;
      case 'payment_removed':
        return CupertinoColors.systemRed;
      case 'discount_applied':
        return CupertinoColors.systemOrange;
      case 'discount_removed':
        return CupertinoColors.systemRed;
      case 'payment_status_change':
        return event.data?.newStatus == 'paid'
            ? CupertinoColors.systemGreen
            : CupertinoColors.systemOrange;
      case 'assignment_change':
        return CupertinoColors.systemPink;
      case 'order_created':
        return CupertinoColors.activeBlue;
      case 'device_change':
        return CupertinoColors.systemTeal;
      case 'customer_change':
        return CupertinoColors.systemOrange;
      case 'due_date_change':
        return CupertinoColors.systemIndigo;
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
                child: Image.network(
                  widget.photos[index],
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CupertinoActivityIndicator(
                        color: CupertinoColors.white,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(
                        CupertinoIcons.photo,
                        size: 64,
                        color: CupertinoColors.systemGrey,
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
