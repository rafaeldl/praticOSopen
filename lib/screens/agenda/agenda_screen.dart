import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/mobx/agenda_store.dart';
import 'package:praticos/mobx/collaborator_store.dart';
import 'package:praticos/mobx/reminder_store.dart';
import 'package:praticos/models/membership.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/screens/menu_navigation/home_groups.dart';
import 'package:praticos/screens/widgets/glass_bar_button.dart';
import 'package:praticos/screens/widgets/list_states.dart';
import 'package:praticos/screens/widgets/picker_screen.dart';
import 'package:praticos/screens/widgets/pull_down_menu.dart';
import 'package:praticos/screens/widgets/status_dot.dart';
import 'package:praticos/screens/widgets/text_link.dart';
import 'package:praticos/services/authorization_service.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/services/segment_config_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';
import 'package:praticos/theme/status_style.dart';

/// Agenda tab: the week (or month) on top, the orders of the selected day
/// below, as a flat list like Início.
class AgendaScreen extends StatefulWidget {
  const AgendaScreen({
    super.key,
    this.store,
    this.collaborators,
    this.canFilterByTechnician,
    this.statusLabel,
    this.loadOnStart = true,
    this.now,
  });

  /// Defaults to the app's [AgendaStore] provider.
  final AgendaStore? store;

  /// Team members for the "De quem" filter. Defaults to
  /// [CollaboratorStore.instance] (loaded on open).
  final List<Membership>? collaborators;

  /// Defaults to admin, manager or supervisor.
  final bool? canFilterByTechnician;

  /// Status label (segment aware). Defaults to [SegmentConfigProvider].
  final String Function(String? status)? statusLabel;

  /// Loads the selected month from Firestore on open (off in tests).
  final bool loadOnStart;

  /// Clock for "today" and overdue orders (tests).
  final DateTime Function()? now;

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  late AgendaStore _agendaStore;
  bool _initialized = false;
  final FormatService _format = FormatService();

  DateTime get _now => widget.now?.call() ?? DateTime.now();

  bool get _canFilterByTechnician {
    if (widget.canFilterByTechnician != null) {
      return widget.canFilterByTechnician!;
    }
    final auth = AuthorizationService.instance;
    return auth.isAdmin || auth.isManager || auth.isSupervisor;
  }

  List<Membership> get _collaborators =>
      widget.collaborators ?? CollaboratorStore.instance.collaborators.toList();

  @override
  void initState() {
    super.initState();
    if (widget.collaborators == null && _canFilterByTechnician) {
      CollaboratorStore.instance.loadCollaborators();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _agendaStore =
        widget.store ?? Provider.of<AgendaStore>(context, listen: false);
    if (widget.loadOnStart) {
      _agendaStore.setReminderStore(
        Provider.of<ReminderStore>(context, listen: false),
      );
      _agendaStore.loadMonth(_agendaStore.selectedDate);
    }
  }

  String _statusLabel(BuildContext context, String? status) {
    if (widget.statusLabel != null) return widget.statusLabel!(status);
    return context.read<SegmentConfigProvider>().getStatus(status);
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild when the segment (status labels) changes.
    if (widget.statusLabel == null) context.watch<SegmentConfigProvider>();
    final bottom = MediaQuery.paddingOf(context).bottom + AppSpacing.xl;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background.resolveFrom(context),
      child: Observer(
        builder: (context) {
          final orders = _agendaStore.ordersForSelectedDate
              .whereType<Order>()
              .toList();
          return CustomScrollView(
            slivers: [
              _buildNavigationBar(context),
              SliverToBoxAdapter(child: _buildMonthRow(context)),
              SliverToBoxAdapter(
                child: _agendaStore.showMonth
                    ? _buildMonthCalendar(context)
                    : _buildWeekStrip(context),
              ),
              if (_agendaStore.selectedTechnicianId != null)
                SliverToBoxAdapter(child: _buildFilterLine(context)),
              SliverToBoxAdapter(child: _buildDayHeader(context, orders)),
              if (orders.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: bottom),
                    child: EmptyState(
                      icon: CupertinoIcons.calendar,
                      title: SegmentConfigService().useScheduling
                          ? context.l10n.noScheduledOrders
                          : context.l10n.noOrdersDueOnDate,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.only(bottom: bottom),
                  sliver: SliverList.list(
                    children: [
                      for (var i = 0; i < orders.length; i++) ...[
                        if (i > 0) const _RowDivider(),
                        _buildRow(context, orders[i]),
                      ],
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // ── Top bar ────────────────────────────────────────────────────────────

  Widget _buildNavigationBar(BuildContext context) {
    return AppNavBar(
      largeTitle: Text(context.l10n.agenda),
      trailing: GlassBarButton(
        identifier: 'agenda_menu_button',
        label: context.l10n.orderMoreActions,
        icon: CupertinoIcons.ellipsis,
        onPressed: () => _showMenu(context),
      ),
    );
  }

  Future<void> _showMenu(BuildContext context) async {
    final l10n = context.l10n;
    final store = _agendaStore;
    final isToday = isSameDay(store.selectedDate, _now);
    final choice = await showPullDownMenu(
      context,
      groups: [
        PullDownGroup([
          PullDownItem(
            value: 'calendar',
            label: store.showMonth ? l10n.agendaShowWeek : l10n.agendaShowMonth,
            icon: CupertinoIcons.calendar,
          ),
          if (!isToday)
            PullDownItem(
              value: 'today',
              label: l10n.today,
              icon: CupertinoIcons.calendar_today,
            ),
        ]),
        if (_canFilterByTechnician)
          PullDownGroup([
            PullDownItem(
              value: 'whose',
              label: l10n.agendaWhose(_technicianName(context) ?? l10n.allTeam),
              icon: CupertinoIcons.person_2,
              submenu: true,
            ),
          ]),
      ],
    );
    if (!context.mounted) return;
    switch (choice) {
      case 'calendar':
        store.toggleMonth();
      case 'today':
        store.selectDate(_now);
      case 'whose':
        await _pickTechnician(context);
    }
  }

  Future<void> _pickTechnician(BuildContext context) async {
    final l10n = context.l10n;
    final picked = await pickOne<String>(
      context,
      title: l10n.agendaWhoseTitle,
      previousTitle: l10n.agenda,
      selected: _agendaStore.selectedTechnicianId ?? '',
      options: [
        PickerItem(value: '', title: l10n.allTeam),
        for (final m in _collaborators)
          if (m.userId != null)
            PickerItem(value: m.userId!, title: m.user?.name ?? l10n.noName),
      ],
    );
    if (picked == null) return;
    _agendaStore.setTechnicianFilter(picked.isEmpty ? null : picked);
  }

  String? _technicianName(BuildContext context) {
    final id = _agendaStore.selectedTechnicianId;
    if (id == null) return null;
    final member = _collaborators.firstWhereOrNull((m) => m.userId == id);
    return member?.user?.name ?? context.l10n.noName;
  }

  // ── Calendar ───────────────────────────────────────────────────────────

  Widget _buildMonthRow(BuildContext context) {
    final l10n = context.l10n;
    final month = _agendaStore.showMonth;
    final accent = AppColors.accentText.resolveFrom(context);

    Widget chevron(IconData icon, String label, int delta) => Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(
          AppSizes.minTouchTarget,
          AppSizes.minTouchTarget,
        ),
        onPressed: () => month
            ? _agendaStore.moveMonth(delta)
            : _agendaStore.moveWeek(delta),
        child: Icon(icon, size: 22, color: accent),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Row(
        children: [
          chevron(
            CupertinoIcons.chevron_back,
            month ? l10n.agendaPreviousMonth : l10n.agendaPreviousWeek,
            -1,
          ),
          Expanded(
            child: Text(
              _format.formatMonthYearTitle(_agendaStore.selectedDate),
              textAlign: TextAlign.center,
              style: AppTypography.callout.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary.resolveFrom(context),
              ),
            ),
          ),
          chevron(
            CupertinoIcons.chevron_forward,
            month ? l10n.agendaNextMonth : l10n.agendaNextWeek,
            1,
          ),
        ],
      ),
    );
  }

  /// Week of the selected day, Sunday first (as the month grid).
  List<DateTime> _weekDays() {
    final d = _agendaStore.selectedDate;
    final start = DateTime(d.year, d.month, d.day - d.weekday % 7);
    return [
      for (var i = 0; i < 7; i++)
        DateTime(start.year, start.month, start.day + i),
    ];
  }

  Widget _buildWeekStrip(BuildContext context) {
    final markers = _agendaStore.eventMarkers;
    final selected = _agendaStore.selectedDate;
    final now = _now;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final day in _weekDays())
            Expanded(
              child: _DayButton(
                key: Key('agenda_day_${day.day}'),
                weekday: _format.formatWeekdayShort(day),
                day: day.day,
                selected: isSameDay(day, selected),
                today: isSameDay(day, now),
                hasOrders: (markers[_dayKey(day)] ?? 0) > 0,
                onTap: () => _agendaStore.selectDate(day),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMonthCalendar(BuildContext context) {
    final markers = _agendaStore.eventMarkers;
    final selected = _agendaStore.selectedDate;
    final scaler = MediaQuery.textScalerOf(context);
    final text = AppColors.text.resolveFrom(context);
    final secondary = AppColors.textSecondary.resolveFrom(context);
    final dayStyle = AppTypography.body.copyWith(
      color: text,
      fontFeatures: AppTypography.tabular,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: TableCalendar<void>(
        locale: Localizations.localeOf(context).toString(),
        firstDay: DateTime(2020, 1, 1),
        lastDay: DateTime(2035, 12, 31),
        focusedDay: selected,
        currentDay: _now,
        headerVisible: false,
        // Rows grow with the text size (no fixed height for text).
        rowHeight: scaler.scale(48),
        daysOfWeekHeight: scaler.scale(22),
        selectedDayPredicate: (day) => isSameDay(day, selected),
        onDaySelected: (day, _) => _agendaStore.selectDate(day),
        onPageChanged: (focused) {
          if (focused.year == selected.year &&
              focused.month == selected.month) {
            return;
          }
          _agendaStore.selectDate(
            AgendaStore.dayInMonth(focused, selected.day),
          );
        },
        calendarFormat: CalendarFormat.month,
        availableCalendarFormats: const {CalendarFormat.month: ''},
        startingDayOfWeek: StartingDayOfWeek.sunday,
        daysOfWeekStyle: DaysOfWeekStyle(
          // Same "dom" (no trailing dot) as the week strip.
          dowTextFormatter: (day, _) => _format.formatWeekdayShort(day),
          weekdayStyle: AppTypography.label.copyWith(color: secondary),
          weekendStyle: AppTypography.label.copyWith(color: secondary),
        ),
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          cellMargin: const EdgeInsets.all(4),
          defaultTextStyle: dayStyle,
          weekendTextStyle: dayStyle,
          todayDecoration: const BoxDecoration(shape: BoxShape.circle),
          todayTextStyle: dayStyle.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.accentText.resolveFrom(context),
          ),
          selectedDecoration: BoxDecoration(
            color: AppColors.accent.resolveFrom(context),
            shape: BoxShape.circle,
          ),
          selectedTextStyle: dayStyle.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.onAccent.resolveFrom(context),
          ),
        ),
        eventLoader: (day) =>
            (markers[_dayKey(day)] ?? 0) > 0 ? const [null] : const [],
        calendarBuilders: CalendarBuilders(
          markerBuilder: (context, day, events) {
            if (events.isEmpty) return null;
            return Positioned(
              bottom: 2,
              child: StatusDot(color: AppColors.textSecondary, size: 5),
            );
          },
        ),
      ),
    );
  }

  // ── Filter and day header ──────────────────────────────────────────────

  Widget _buildFilterLine(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageMargin,
        AppSpacing.sm,
        AppSpacing.pageMargin,
        0,
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.md,
        children: [
          Text(
            l10n.agendaOnlyOf(_technicianName(context) ?? ''),
            style: AppTypography.callout.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.text.resolveFrom(context),
            ),
          ),
          TextLink(
            label: l10n.agendaShowAll,
            onPressed: () => _agendaStore.setTechnicianFilter(null),
          ),
        ],
      ),
    );
  }

  Widget _buildDayHeader(BuildContext context, List<Order> orders) {
    final date = _format.formatWeekdayDayMonth(_agendaStore.selectedDate);
    final title = orders.isEmpty
        ? date
        : '$date · ${context.l10n.agendaDayCount(orders.length)}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageMargin,
        AppSpacing.lg,
        AppSpacing.pageMargin,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Flexible(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: AppTypography.callout.copyWith(
                  color: AppColors.textSecondary.resolveFrom(context),
                ),
              ),
            ),
          ),
          if (_agendaStore.isLoading) ...[
            const SizedBox(width: AppSpacing.sm),
            const CupertinoActivityIndicator(radius: 8),
          ],
        ],
      ),
    );
  }

  // ── Rows ───────────────────────────────────────────────────────────────

  Widget _buildRow(BuildContext context, Order order) {
    final l10n = context.l10n;
    final now = _now;
    final useScheduling = SegmentConfigService().useScheduling;
    final date = useScheduling ? order.scheduledDate : order.dueDate;
    final allDay =
        !useScheduling || date == null || (date.hour == 0 && date.minute == 0);

    final overdue = HomeRules.isOverdue(order, now);
    final String status;
    if (overdue) {
      final (unit, count) = HomeRules.overdueSpan(order, now);
      status = switch (unit) {
        OverdueUnit.days => l10n.orderLateDays(count),
        OverdueUnit.months => l10n.orderLateMonths(count),
        OverdueUnit.years => l10n.orderLateYears(count),
      };
    } else {
      status = _statusLabel(context, order.status);
    }
    final statusLine = [
      if (status.isNotEmpty) status,
      if (order.number != null) l10n.orderRowNumber('${order.number}'),
    ].join(' · ');

    final devices = order.effectiveDevices;
    final deviceName = devices.firstOrNull?.name ?? '';
    final assignee = order.assignedTo?.name ?? '';
    final detail = [
      if (deviceName.isNotEmpty)
        devices.length > 1 ? '$deviceName +${devices.length - 1}' : deviceName,
      if (assignee.isNotEmpty) l10n.agendaWithPerson(assignee),
    ].join(' · ');

    return Semantics(
      identifier: 'agenda_order_${order.id ?? order.number ?? ''}',
      button: true,
      child: _AgendaRow(
        customerName: order.customer?.name ?? '',
        time: allDay ? l10n.allDay : _format.formatTime(date),
        allDay: allDay,
        statusText: statusLine,
        statusColor: overdue
            ? OrderStatusStyle.overdueColor
            : OrderStatusStyle.dotColor(order.status),
        overdue: overdue,
        detailText: detail.isEmpty ? null : detail,
        onTap: () {
          Navigator.of(context, rootNavigator: true).pushNamed(
            '/order',
            arguments: {'order': order, 'previousTitle': l10n.agenda},
          );
        },
      ),
    );
  }
}

/// One day of the week strip: short weekday, day number and a dot when the
/// day has orders. The selected day sits on a soft accent pill.
class _DayButton extends StatelessWidget {
  const _DayButton({
    super.key,
    required this.weekday,
    required this.day,
    required this.selected,
    required this.today,
    required this.hasOrders,
    required this.onTap,
  });

  final String weekday;
  final int day;
  final bool selected;
  final bool today;
  final bool hasOrders;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final secondary = AppColors.textSecondary.resolveFrom(context);
    final numberColor = selected
        ? AppColors.onAccentSoft.resolveFrom(context)
        : today
        ? AppColors.accentText.resolveFrom(context)
        : AppColors.text.resolveFrom(context);
    final name = '$weekday $day';
    return Semantics(
      button: true,
      selected: selected,
      label: hasOrders ? context.l10n.agendaDayHasOrders(name) : name,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: selected ? AppColors.accentSoft.resolveFrom(context) : null,
            borderRadius: BorderRadius.circular(AppRadii.field),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                weekday,
                textAlign: TextAlign.center,
                style: AppTypography.label.copyWith(
                  color: selected ? numberColor : secondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$day',
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(
                  fontWeight: selected || today
                      ? FontWeight.w700
                      : FontWeight.w400,
                  color: numberColor,
                  fontFeatures: AppTypography.tabular,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              if (hasOrders)
                StatusDot(
                  key: const Key('agenda_day_marker'),
                  color: AppColors.textSecondary,
                  size: 5,
                )
              else
                const SizedBox(height: 5),
            ],
          ),
        ),
      ),
    );
  }
}

/// Order of the day: customer and time, status · number, device · person.
class _AgendaRow extends StatelessWidget {
  const _AgendaRow({
    required this.customerName,
    required this.time,
    required this.allDay,
    required this.statusText,
    required this.statusColor,
    required this.overdue,
    required this.onTap,
    this.detailText,
  });

  final String customerName;
  final String time;
  final bool allDay;
  final String statusText;
  final Color statusColor;
  final bool overdue;
  final String? detailText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = AppColors.text.resolveFrom(context);
    final secondary = AppColors.textSecondary.resolveFrom(context);
    final statusStyle = overdue
        ? AppTypography.callout.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.danger.resolveFrom(context),
          )
        : AppTypography.callout.copyWith(color: secondary);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.minTouchTarget),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pageMargin,
            vertical: AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      customerName,
                      style: AppTypography.bodyStrong.copyWith(color: text),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    time,
                    style: allDay
                        ? AppTypography.callout.copyWith(color: secondary)
                        : AppTypography.body.copyWith(
                            color: text,
                            fontFeatures: AppTypography.tabular,
                          ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Icon(
                    CupertinoIcons.chevron_forward,
                    size: 14,
                    color: AppColors.separator.resolveFrom(context),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  // Dot on the text baseline, as a leading glyph.
                  Text.rich(
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: StatusDot(color: statusColor),
                    ),
                    style: statusStyle,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      statusText,
                      style: statusStyle.copyWith(
                        fontFeatures: AppTypography.tabular,
                      ),
                    ),
                  ),
                ],
              ),
              if (detailText != null) ...[
                const SizedBox(height: 2),
                Text(
                  detailText!,
                  style: AppTypography.label.copyWith(color: secondary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.pageMargin),
      child: Container(
        height: 0.5,
        color: AppColors.separator.resolveFrom(context),
      ),
    );
  }
}

DateTime _dayKey(DateTime d) => DateTime(d.year, d.month, d.day);
