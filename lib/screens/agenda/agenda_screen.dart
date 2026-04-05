import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Material, MaterialType;
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:praticos/mobx/agenda_store.dart';
import 'package:praticos/mobx/reminder_store.dart';
import 'package:praticos/mobx/collaborator_store.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/services/authorization_service.dart';
import 'package:praticos/services/segment_config_service.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/extensions/context_extensions.dart';

class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  late AgendaStore _agendaStore;
  final CollaboratorStore _collaboratorStore = CollaboratorStore.instance;
  final AuthorizationService _authService = AuthorizationService.instance;
  final FormatService _formatService = FormatService();

  @override
  void initState() {
    super.initState();
    _collaboratorStore.loadCollaborators();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _agendaStore = Provider.of<AgendaStore>(context);
    _agendaStore.setReminderStore(Provider.of<ReminderStore>(context, listen: false));
    _agendaStore.loadMonth(DateTime.now());
  }

  bool get _canFilterByTechnician {
    return _authService.isAdmin ||
        _authService.isManager ||
        _authService.isSupervisor;
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: Material(
        type: MaterialType.transparency,
        child: CustomScrollView(
          slivers: [
            _buildNavigationBar(context),
            SliverSafeArea(
              top: false,
              sliver: Observer(
                builder: (_) {
                  return SliverList(
                    delegate: SliverChildListDelegate([
                      _buildCalendar(context),
                      _buildDayHeader(context),
                      _buildDayOrdersList(context),
                      const SizedBox(height: 40),
                    ]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationBar(BuildContext context) {
    return CupertinoSliverNavigationBar(
      largeTitle: Text(context.l10n.agenda),
      trailing: _canFilterByTechnician
          ? CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _showTechnicianFilter(context),
              child: Observer(
                builder: (_) {
                  final hasFilter = _agendaStore.selectedTechnicianId != null;
                  return Icon(
                    hasFilter
                        ? CupertinoIcons.person_crop_circle_fill
                        : CupertinoIcons.person_crop_circle,
                    color: hasFilter
                        ? CupertinoColors.activeBlue
                        : null,
                  );
                },
              ),
            )
          : null,
    );
  }

  Widget _buildCalendar(BuildContext context) {
    return Observer(
      builder: (_) {
        final markers = _agendaStore.eventMarkers;
        final selectedDay = _agendaStore.selectedDate;
        final focusedDay = _agendaStore.focusedMonth.month == selectedDay.month &&
                _agendaStore.focusedMonth.year == selectedDay.year
            ? selectedDay
            : DateTime(_agendaStore.focusedMonth.year, _agendaStore.focusedMonth.month, 1);

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          decoration: BoxDecoration(
            color: CupertinoColors.systemBackground.resolveFrom(context),
            borderRadius: BorderRadius.circular(10),
          ),
          child: TableCalendar(
            locale: Localizations.localeOf(context).toString(),
            firstDay: DateTime(2020, 1, 1),
            lastDay: DateTime(2030, 12, 31),
            focusedDay: focusedDay,
            selectedDayPredicate: (day) => isSameDay(day, selectedDay),
            onDaySelected: (selected, focused) {
              _agendaStore.selectDate(selected);
            },
            onPageChanged: (focusedDay) {
              _agendaStore.loadMonth(focusedDay);
            },
            calendarFormat: CalendarFormat.month,
            startingDayOfWeek: StartingDayOfWeek.sunday,
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              leftChevronIcon: Icon(
                CupertinoIcons.chevron_left,
                size: 18,
                color: CupertinoColors.activeBlue.resolveFrom(context),
              ),
              rightChevronIcon: Icon(
                CupertinoIcons.chevron_right,
                size: 18,
                color: CupertinoColors.activeBlue.resolveFrom(context),
              ),
              titleTextStyle: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.label.resolveFrom(context),
              ),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
              weekendStyle: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              todayDecoration: BoxDecoration(
                color: CupertinoColors.systemGrey5.resolveFrom(context),
                shape: BoxShape.circle,
              ),
              todayTextStyle: TextStyle(
                fontWeight: FontWeight.w600,
                color: CupertinoColors.label.resolveFrom(context),
              ),
              selectedDecoration: const BoxDecoration(
                color: CupertinoColors.activeBlue,
                shape: BoxShape.circle,
              ),
              selectedTextStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                color: CupertinoColors.white,
              ),
              defaultTextStyle: TextStyle(
                color: CupertinoColors.label.resolveFrom(context),
              ),
              weekendTextStyle: TextStyle(
                color: CupertinoColors.label.resolveFrom(context),
              ),
              markersMaxCount: 4,
              markerSize: 6,
              markerMargin: const EdgeInsets.symmetric(horizontal: 0.5),
            ),
            eventLoader: (day) {
              final dayKey = DateTime(day.year, day.month, day.day);
              final count = markers[dayKey] ?? 0;
              return List.generate(count.clamp(0, 4), (_) => null);
            },
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                final dayKey = DateTime(date.year, date.month, date.day);
                final count = markers[dayKey] ?? 0;
                if (count == 0) return null;

                final dotCount = count.clamp(1, 4);

                return Positioned(
                  bottom: 1,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(dotCount, (_) => Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 0.5),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: CupertinoColors.activeBlue,
                      ),
                    )),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildDayHeader(BuildContext context) {
    return Observer(
      builder: (_) {
        final date = _agendaStore.selectedDate;
        final formattedDate = _formatService.formatDateLong(date);

        return Padding(
          padding: const EdgeInsets.fromLTRB(32, 24, 20, 8),
          child: Row(
            children: [
              Text(
                formattedDate,
                style: TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
              if (_agendaStore.isLoading) ...[
                const SizedBox(width: 8),
                const CupertinoActivityIndicator(radius: 8),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildDayOrdersList(BuildContext context) {
    final config = context.watch<SegmentConfigProvider>();

    return Observer(
      builder: (_) {
        final dayOrders = _agendaStore.ordersForSelectedDate;

        if (dayOrders.isEmpty) {
          return _buildEmptyState(context);
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: CupertinoColors.systemBackground.resolveFrom(context),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: dayOrders.asMap().entries.map((entry) {
              final index = entry.key;
              final order = entry.value;
              final isLast = index == dayOrders.length - 1;
              return _buildOrderRow(context, order!, isLast, config);
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildOrderRow(
    BuildContext context,
    Order order,
    bool isLast,
    SegmentConfigProvider config,
  ) {
    final useScheduling = SegmentConfigService().useScheduling;
    final relevantDate = useScheduling ? order.scheduledDate : order.dueDate;
    final isMidnight = !useScheduling || (relevantDate != null &&
        relevantDate.hour == 0 &&
        relevantDate.minute == 0);
    final timeStr = isMidnight
        ? context.l10n.allDay
        : _formatService.formatTime(relevantDate!);

    final customerName = order.customer?.name ?? '';
    final deviceName = order.device?.name ?? '';
    final orderNumber = order.number != null ? '#${order.number}' : '';
    final subtitle = [deviceName, config.getStatus(order.status)]
        .where((s) => s.isNotEmpty)
        .join(' \u00B7 ');

    return GestureDetector(
      onTap: () {
        Navigator.of(context, rootNavigator: true).pushNamed(
          '/order',
          arguments: {'order': order},
        );
      },
      child: Container(
        color: Colors.transparent,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Time column
                  SizedBox(
                    width: 56,
                    child: Text(
                      timeStr,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: isMidnight
                            ? CupertinoColors.secondaryLabel.resolveFrom(context)
                            : CupertinoColors.activeBlue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Status dot
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _getStatusColor(order.status),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Order info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${context.l10n.orderShort} $orderNumber${customerName.isNotEmpty ? ' - $customerName' : ''}',
                          style: TextStyle(
                            fontSize: 17,
                            color: CupertinoColors.label.resolveFrom(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: 13,
                                color: CupertinoColors.secondaryLabel
                                    .resolveFrom(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    CupertinoIcons.chevron_right,
                    size: 16,
                    color: CupertinoColors.systemGrey3.resolveFrom(context),
                  ),
                ],
              ),
            ),
            if (!isLast)
              Container(
                height: 0.5,
                margin: const EdgeInsets.only(left: 86),
                color: CupertinoColors.systemGrey5.resolveFrom(context),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
        child: Column(
          children: [
            Icon(
              CupertinoIcons.calendar_badge_minus,
              size: 48,
              color: CupertinoColors.systemGrey3.resolveFrom(context),
            ),
            const SizedBox(height: 12),
            Text(
              SegmentConfigService().useScheduling
                  ? context.l10n.noScheduledOrders
                  : context.l10n.noOrdersDueOnDate,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTechnicianFilter(BuildContext context) {
    final collaborators = _collaboratorStore.collaborators.toList();

    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(context.l10n.filterByTechnician),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _agendaStore.setTechnicianFilter(null);
            },
            child: Text(
              context.l10n.allTeam,
              style: TextStyle(
                fontWeight: _agendaStore.selectedTechnicianId == null
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
          ),
          ...collaborators.map((membership) {
            final name = membership.user?.name ?? context.l10n.noName;
            final userId = membership.userId;
            final isSelected = _agendaStore.selectedTechnicianId == userId;

            return CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                _agendaStore.setTechnicianFilter(userId);
              },
              child: Text(
                name,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            );
          }),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: Text(context.l10n.cancel),
          onPressed: () => Navigator.pop(ctx),
        ),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'quote':
        return CupertinoColors.systemOrange;
      case 'approved':
        return CupertinoColors.systemBlue;
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
