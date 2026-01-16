import 'package:flutter/cupertino.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/mobx/timeline_store.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/timeline_event.dart';
import 'package:praticos/global.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/services/forms_service.dart';
import 'package:praticos/repositories/timeline_repository.dart';
import 'package:praticos/screens/timeline/widgets/event_card.dart';
import 'package:praticos/screens/timeline/widgets/message_input.dart';
import 'package:praticos/screens/forms/form_selection_screen.dart';
import 'package:praticos/screens/forms/form_fill_screen.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  final TimelineStore _store = TimelineStore();
  final ScrollController _scrollController = ScrollController();
  final FormatService _formatService = FormatService();
  final OrderStore _orderStore = OrderStore();
  final FormsService _formsService = FormsService();
  final TimelineRepository _timelineRepository = TimelineRepository();
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

      // Initialize OrderStore for attachment actions
      if (_order != null) {
        _orderStore.setOrder(_order!);
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

  void _navigateToOrder({String? anchor}) {
    if (_order != null) {
      Navigator.of(context, rootNavigator: true)
          .pushNamed('/order', arguments: {
        'order': _order,
        if (anchor != null) 'anchor': anchor,
      });
    }
  }

  String? _getAnchorForEvent(String? eventType) {
    switch (eventType) {
      case 'service_added':
      case 'service_updated':
      case 'service_removed':
        return 'services';
      case 'product_added':
      case 'product_updated':
      case 'product_removed':
        return 'products';
      case 'photos_added':
        return 'photos';
      case 'payment_received':
        return 'summary';
      case 'form_added':
      case 'form_updated':
      case 'form_completed':
        return 'forms';
      case 'status_change':
        return 'summary';
      default:
        return null;
    }
  }

  // ============================================================
  // ATTACHMENT MENU
  // ============================================================

  void _showAttachmentMenu() {
    showCupertinoModalPopup(
      context: context,
      builder: (actionContext) => CupertinoActionSheet(
        actions: [
          // Photos
          CupertinoActionSheetAction(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.camera,
                    color: CupertinoColors.activeBlue),
                const SizedBox(width: 8),
                Text(context.l10n.addPhoto),
              ],
            ),
            onPressed: () {
              Navigator.pop(actionContext);
              _showPhotoOptions();
            },
          ),

          // Services
          CupertinoActionSheetAction(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.wrench,
                    color: CupertinoColors.systemOrange),
                const SizedBox(width: 8),
                Text(context.l10n.addService),
              ],
            ),
            onPressed: () {
              Navigator.pop(actionContext);
              _addService();
            },
          ),

          // Products
          CupertinoActionSheetAction(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.cube_box,
                    color: CupertinoColors.systemPurple),
                const SizedBox(width: 8),
                Text(context.l10n.addProduct),
              ],
            ),
            onPressed: () {
              Navigator.pop(actionContext);
              _addProduct();
            },
          ),

          // Checklists
          CupertinoActionSheetAction(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.doc_checkmark,
                    color: CupertinoColors.systemGreen),
                const SizedBox(width: 8),
                Text(context.l10n.addChecklist),
              ],
            ),
            onPressed: () {
              Navigator.pop(actionContext);
              _addChecklist();
            },
          ),

          // Payments
          CupertinoActionSheetAction(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.creditcard,
                    color: CupertinoColors.systemTeal),
                const SizedBox(width: 8),
                Text(context.l10n.addPayment),
              ],
            ),
            onPressed: () {
              Navigator.pop(actionContext);
              _addPayment();
            },
          ),

          // Due Date
          CupertinoActionSheetAction(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.calendar,
                    color: CupertinoColors.systemIndigo),
                const SizedBox(width: 8),
                Text(context.l10n.addDueDate),
              ],
            ),
            onPressed: () {
              Navigator.pop(actionContext);
              _addDueDate();
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: Text(context.l10n.cancel),
          onPressed: () => Navigator.pop(actionContext),
        ),
      ),
    );
  }

  // ============================================================
  // ATTACHMENT HANDLERS
  // ============================================================

  void _showPhotoOptions() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            child: Text(context.l10n.takePhoto),
            onPressed: () async {
              Navigator.pop(ctx);
              await _orderStore.addPhotoFromCamera();
            },
          ),
          CupertinoActionSheetAction(
            child: Text(context.l10n.chooseFromGallery),
            onPressed: () async {
              Navigator.pop(ctx);
              await _orderStore.addPhotoFromGallery();
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: Text(context.l10n.cancel),
          onPressed: () => Navigator.pop(ctx),
        ),
      ),
    );
  }

  Future<void> _addService() async {
    // Ensure order is saved
    if (_order?.id == null) {
      await _orderStore.repository.createItem(_orderStore.companyId!, _order!);
    }

    if (!mounted) return;

    // Navigate to service list in selection mode
    Navigator.pushNamed(
      context,
      '/service_list',
      arguments: {'orderStore': _orderStore, 'returnRoute': '/timeline'},
    );
  }

  Future<void> _addProduct() async {
    // Ensure order is saved
    if (_order?.id == null) {
      await _orderStore.repository.createItem(_orderStore.companyId!, _order!);
    }

    if (!mounted) return;

    // Navigate to product list in selection mode
    Navigator.pushNamed(
      context,
      '/product_list',
      arguments: {'orderStore': _orderStore, 'returnRoute': '/timeline'},
    );
  }

  Future<void> _addChecklist() async {
    // Ensure order is saved
    if (_order?.id == null) {
      await _orderStore.repository.createItem(_orderStore.companyId!, _order!);
    }

    if (!mounted) return;

    // Open form template selector
    final template = await Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => FormSelectionScreen(companyId: _orderStore.companyId!),
      ),
    );

    if (template != null && mounted) {
      // Create form instance and open for filling
      final newForm = await _formsService.addFormToOrder(
        _orderStore.companyId!,
        _order!.id!,
        template,
      );

      if (!mounted) return;

      final result = await Navigator.push<Map<String, dynamic>>(
        context,
        CupertinoPageRoute(
          fullscreenDialog: true,
          builder: (_) => FormFillScreen(
            orderId: _order!.id!,
            companyId: _orderStore.companyId!,
            orderForm: newForm,
          ),
        ),
      );

      // If form was not completed, log appropriately
      // (If completed, form_fill_screen already logs "form_completed")
      if (result?['completed'] != true && mounted) {
        final responsesCount = result?['responsesCount'] ?? 0;
        final totalItems = newForm.items.length;

        if (responsesCount > 0) {
          // Has responses - log as "updated" with progress
          await _timelineRepository.logFormUpdated(
            _orderStore.companyId!,
            _order!.id!,
            newForm.getLocalizedTitle(context.l10n.localeName),
            newForm.id,
            responsesCount,
            totalItems,
          );
        } else {
          // No responses - log as "added"
          await _timelineRepository.logFormAdded(
            _orderStore.companyId!,
            _order!.id!,
            newForm.getLocalizedTitle(context.l10n.localeName),
            newForm.id,
            totalItems,
          );
        }
      }
    }
  }

  Future<void> _addPayment() async {
    // Ensure order is saved
    if (_order?.id == null) {
      await _orderStore.repository.createItem(_orderStore.companyId!, _order!);
    }

    if (!mounted) return;

    // Navigate to payment management screen
    Navigator.pushNamed(
      context,
      '/payment_management',
      arguments: {'orderStore': _orderStore},
    );
  }

  void _addDueDate() {
    final originalDate = _order?.dueDate;
    DateTime selectedDate = _order?.dueDate ?? DateTime.now();

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => Container(
        height: 300,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(
          children: [
            // Header with done button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: CupertinoColors.separator.resolveFrom(context),
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: Text(context.l10n.cancel),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                  Text(
                    context.l10n.dueDate,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: Text(
                      context.l10n.done,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      // Only log if date actually changed
                      final shouldLog = originalDate == null ||
                          selectedDate.day != originalDate.day ||
                          selectedDate.month != originalDate.month ||
                          selectedDate.year != originalDate.year;
                      _orderStore.setDueDate(
                        selectedDate,
                        logToTimeline: shouldLog,
                        originalDate: originalDate,
                      );
                    },
                  ),
                ],
              ),
            ),
            // Date picker
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: selectedDate,
                minimumDate: DateTime.now().subtract(const Duration(days: 365)),
                maximumDate: DateTime.now().add(const Duration(days: 365 * 2)),
                onDateTimeChanged: (DateTime date) {
                  selectedDate = date;
                },
              ),
            ),
          ],
        ),
      ),
    );
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
              onAttachmentTap: _showAttachmentMenu,
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
                  onTap: event.isComment
                      ? null
                      : () => _navigateToOrder(anchor: _getAnchorForEvent(event.type)),
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

