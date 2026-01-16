import 'package:flutter/cupertino.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
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
import 'package:praticos/widgets/cached_image.dart';
import 'package:url_launcher/url_launcher.dart';

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
  void initState() {
    super.initState();
  }

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

  Future<void> _openWhatsApp() async {
    final phone = _order?.customer?.phone;
    if (phone != null && phone.isNotEmpty) {
      final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
      final uri = Uri.parse('https://wa.me/$cleanPhone');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  Future<void> _handleEventTap(TimelineEvent event) async {
    switch (event.type) {
      case 'payment_received':
      case 'discount_applied':
        Navigator.pushNamed(
          context,
          '/payment_management',
          arguments: {'orderStore': _orderStore},
        );
        break;

      case 'form_added':
      case 'form_updated':
      case 'form_completed':
        final formId = event.data?.formId;
        if (formId != null &&
            _order?.id != null &&
            _orderStore.companyId != null) {
          final orderForm = await _formsService.getOrderFormById(
            _orderStore.companyId!,
            _order!.id!,
            formId,
          );
          if (orderForm != null && mounted) {
            Navigator.push(
              context,
              CupertinoPageRoute(
                fullscreenDialog: true,
                builder: (_) => FormFillScreen(
                  orderId: _order!.id!,
                  companyId: _orderStore.companyId!,
                  orderForm: orderForm,
                ),
              ),
            );
          }
        }
        break;

      case 'service_added':
      case 'service_updated':
      case 'service_removed':
        Navigator.pushNamed(
          context,
          '/service_list',
          arguments: {'orderStore': _orderStore, 'returnRoute': '/timeline'},
        );
        break;

      case 'product_added':
      case 'product_updated':
      case 'product_removed':
        Navigator.pushNamed(
          context,
          '/product_list',
          arguments: {'orderStore': _orderStore, 'returnRoute': '/timeline'},
        );
        break;

      case 'photos_added':
        _navigateToOrder(anchor: 'photos');
        break;

      default:
        _navigateToOrder();
        break;
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
          CupertinoActionSheetAction(
            child: Text(context.l10n.addPhoto),
            onPressed: () {
              Navigator.pop(actionContext);
              _showPhotoOptions();
            },
          ),
          CupertinoActionSheetAction(
            child: Text(context.l10n.addService),
            onPressed: () {
              Navigator.pop(actionContext);
              _addService();
            },
          ),
          CupertinoActionSheetAction(
            child: Text(context.l10n.addProduct),
            onPressed: () {
              Navigator.pop(actionContext);
              _addProduct();
            },
          ),
          CupertinoActionSheetAction(
            child: Text(context.l10n.addChecklist),
            onPressed: () {
              Navigator.pop(actionContext);
              _addChecklist();
            },
          ),
          CupertinoActionSheetAction(
            child: Text(context.l10n.addPayment),
            onPressed: () {
              Navigator.pop(actionContext);
              _addPayment();
            },
          ),
          CupertinoActionSheetAction(
            child: Text(context.l10n.addDueDate),
            onPressed: () {
              Navigator.pop(actionContext);
              _addDueDate();
            },
          ),
          CupertinoActionSheetAction(
            child: Text(context.l10n.changeStatus),
            onPressed: () {
              Navigator.pop(actionContext);
              _changeStatus();
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
    if (_order?.id == null) {
      await _orderStore.repository.createItem(_orderStore.companyId!, _order!);
    }
    if (!mounted) return;
    Navigator.pushNamed(
      context,
      '/service_list',
      arguments: {'orderStore': _orderStore, 'returnRoute': '/timeline'},
    );
  }

  Future<void> _addProduct() async {
    if (_order?.id == null) {
      await _orderStore.repository.createItem(_orderStore.companyId!, _order!);
    }
    if (!mounted) return;
    Navigator.pushNamed(
      context,
      '/product_list',
      arguments: {'orderStore': _orderStore, 'returnRoute': '/timeline'},
    );
  }

  Future<void> _addChecklist() async {
    if (_order?.id == null) {
      await _orderStore.repository.createItem(_orderStore.companyId!, _order!);
    }
    if (!mounted) return;

    final template = await Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => FormSelectionScreen(companyId: _orderStore.companyId!),
      ),
    );

    if (template != null && mounted) {
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

      if (result?['completed'] != true && mounted) {
        final responsesCount = result?['responsesCount'] ?? 0;
        final totalItems = newForm.items.length;

        if (responsesCount > 0) {
          await _timelineRepository.logFormUpdated(
            _orderStore.companyId!,
            _order!.id!,
            newForm.getLocalizedTitle(context.l10n.localeName),
            newForm.id,
            responsesCount,
            totalItems,
          );
        } else {
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
    if (_order?.id == null) {
      await _orderStore.repository.createItem(_orderStore.companyId!, _order!);
    }
    if (!mounted) return;
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

  void _changeStatus() {
    final currentStatus = _order?.status;

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(context.l10n.changeStatus),
        actions: [
          if (currentStatus != 'quote')
            CupertinoActionSheetAction(
              child: Text(context.l10n.statusQuote),
              onPressed: () {
                Navigator.pop(ctx);
                _orderStore.setStatus('quote');
              },
            ),
          if (currentStatus != 'approved')
            CupertinoActionSheetAction(
              child: Text(context.l10n.statusApproved),
              onPressed: () {
                Navigator.pop(ctx);
                _orderStore.setStatus('approved');
              },
            ),
          if (currentStatus != 'progress')
            CupertinoActionSheetAction(
              child: Text(context.l10n.statusInProgress),
              onPressed: () {
                Navigator.pop(ctx);
                _orderStore.setStatus('progress');
              },
            ),
          if (currentStatus != 'done')
            CupertinoActionSheetAction(
              child: Text(context.l10n.statusCompleted),
              onPressed: () {
                Navigator.pop(ctx);
                _orderStore.setStatus('done');
              },
            ),
          if (currentStatus != 'canceled')
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              child: Text(context.l10n.statusCancelled),
              onPressed: () {
                Navigator.pop(ctx);
                _confirmCancelOrder();
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

  void _confirmCancelOrder() {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(context.l10n.cancelOrder),
        content: Text(context.l10n.cancelOrderConfirmation),
        actions: [
          CupertinoDialogAction(
            child: Text(context.l10n.no),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: Text(context.l10n.yes),
            onPressed: () {
              Navigator.pop(ctx);
              _orderStore.setStatus('canceled');
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: _buildNavigationBar(),
      child: SafeArea(
        child: Column(
          children: [
            // Timeline Events
            Expanded(
              child: Observer(
                builder: (_) {
                  if (_store.isLoading) {
                    return const Center(child: CupertinoActivityIndicator());
                  }

                  if (_store.error != null) {
                    return Center(
                      child: Text(
                        _store.error!,
                        style: TextStyle(color: CupertinoColors.systemRed),
                      ),
                    );
                  }

                  final events = _store.events;
                  if (events.isEmpty) {
                    return _buildEmptyState();
                  }

                  _scrollToBottom();
                  return _buildEventsList(events);
                },
              ),
            ),
            // Input
            MessageInput(
              onSend: (text, isPublic) async {
                await _store.sendMessage(text, isPublic: isPublic);
                _scrollToBottom();
              },
              isSending: _store.isSending,
              customerName: _order?.customer?.name,
              onAttachmentTap: _showAttachmentMenu,
              onCameraTap: () => _orderStore.addPhotoFromCamera(),
            ),
          ],
        ),
      ),
    );
  }

  /// Standard iOS Navigation Bar
  CupertinoNavigationBar _buildNavigationBar() {
    final hasPhone = _order?.customer?.phone?.isNotEmpty == true;

    return CupertinoNavigationBar(
      automaticallyImplyLeading: false,
      leading: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        onPressed: () => Navigator.of(context).pop(),
        child: const Icon(CupertinoIcons.back, size: 28),
      ),
      middle: Observer(
        builder: (_) {
          final currentStatus = _orderStore.status ?? _order?.status;
          final total = _orderStore.order?.total ?? _order?.total ?? 0;
          final paidAmount =
              _orderStore.order?.paidAmount ?? _order?.paidAmount ?? 0;
          final isPaid = total > 0 && paidAmount >= total;

          return GestureDetector(
            onTap: () => _navigateToOrder(),
            child: Row(
              children: [
                // Avatar
                if (_order?.coverPhotoUrl != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CachedImage(
                        imageUrl: _order!.coverPhotoUrl!,
                        width: 32,
                        height: 32,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                // Nome e dispositivo (expansível, trunca)
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _order?.customer?.name ?? context.l10n.timeline,
                        style: const TextStyle(fontSize: 17),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      Row(
                        children: [
                          // Status dot
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _getStatusColor(currentStatus),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Device e serial
                          if (_order?.device?.name != null ||
                              _order?.device?.serial != null)
                            Expanded(
                              child: Text(
                                [
                                  _order?.device?.name,
                                  _order?.device?.serial,
                                ]
                                    .where((e) => e != null && e.isNotEmpty)
                                    .join(' · '),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.normal,
                                  color: CupertinoColors.secondaryLabel
                                      .resolveFrom(context),
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Valor e data
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Total
                    Text(
                      _formatService.formatCurrency(total, decimalDigits: 0),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isPaid
                            ? CupertinoColors.systemGreen
                            : CupertinoColors.label.resolveFrom(context),
                      ),
                    ),
                    // Data de entrega
                    if (_orderStore.order?.dueDate != null ||
                        _order?.dueDate != null)
                      Builder(builder: (_) {
                        final dueDate =
                            _orderStore.order?.dueDate ?? _order!.dueDate!;
                        return Text(
                          '${dueDate.day.toString().padLeft(2, '0')}/${dueDate.month.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.normal,
                            color: CupertinoColors.secondaryLabel
                                .resolveFrom(context),
                          ),
                        );
                      }),
                  ],
                ),
              ],
            ),
          );
        },
      ),
      trailing: hasPhone
          ? CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _openWhatsApp,
              child: const FaIcon(FontAwesomeIcons.whatsapp, size: 22),
            )
          : null,
    );
  }

  // ============================================================
  // iOS TEXT STYLES (Dynamic Type)
  // ============================================================

  /// Subhead: 15pt regular - secondary content
  TextStyle _subheadStyle({Color? color}) => TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.normal,
        color: color ?? CupertinoColors.label.resolveFrom(context),
      );

  /// Caption 1: 12pt regular - smallest readable
  TextStyle _caption1Style({Color? color}) => TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: color ?? CupertinoColors.secondaryLabel.resolveFrom(context),
      );

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.chat_bubble_2,
            size: 48,
            color: CupertinoColors.systemGrey3.resolveFrom(context),
          ),
          const SizedBox(height: 12),
          Text(context.l10n.timelineEmpty, style: _subheadStyle()),
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
            _buildDateSeparator(dateKey),
            ...dateEvents.map((event) => EventCard(
                  event: event,
                  isFromMe: event.author?.id == Global.userAggr?.id,
                  onTap: event.isComment ? null : () => _handleEventTap(event),
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
          child: Text(dateKey, style: _caption1Style()),
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
        return CupertinoColors.secondaryLabel;
    }
  }
}
