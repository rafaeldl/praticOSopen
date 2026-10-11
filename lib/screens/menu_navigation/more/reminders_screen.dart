import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/mobx/engagement_reminder_store.dart';
import 'package:praticos/mobx/locale_store.dart';
import 'package:praticos/mobx/reminder_store.dart';
import 'package:praticos/screens/menu_navigation/more/more_page.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/services/notification_service.dart';

/// "Lembretes" (replaces "Preferências"): reminder before the scheduled
/// time and the three engagement reminders. Language and appearance follow
/// the iPhone, so only Android keeps the "Idioma" row.
class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});

  String _beforeText(BuildContext context, int minutes) {
    final l10n = context.l10n;
    if (minutes == 0) return l10n.reminderDisabled;
    if (minutes == 60) return l10n.reminderHourBefore;
    if (minutes == 120) return l10n.reminderHoursBefore(2);
    return l10n.reminderMinutesBefore(minutes);
  }

  void _pickBefore(BuildContext context, ReminderStore store) {
    final l10n = context.l10n;
    final options = <(int, String)>[
      (0, l10n.reminderDisabled),
      (15, l10n.reminderMinutesBefore(15)),
      (30, l10n.reminderMinutesBefore(30)),
      (60, l10n.reminderHourBefore),
      (120, l10n.reminderHoursBefore(2)),
    ];
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text(l10n.scheduleReminder),
        actions: [
          for (final (minutes, label) in options)
            CupertinoActionSheetAction(
              isDefaultAction: store.reminderMinutes == minutes,
              onPressed: () {
                store.setReminderMinutes(minutes);
                Navigator.pop(sheetContext);
              },
              child: Text(label),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: Text(l10n.cancel),
        ),
      ),
    );
  }

  void _pickLanguage(BuildContext context, LocaleStore store) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text(sheetContext.l10n.selectLanguage),
        actions: [
          for (final locale in store.availableLocales)
            CupertinoActionSheetAction(
              onPressed: () {
                store.setLocale(locale['code']!);
                Navigator.pop(sheetContext);
              },
              child: Text('${locale['flag']} ${locale['name']}'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: Text(sheetContext.l10n.cancel),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final reminderStore = Provider.of<ReminderStore>(context);
    final engagement = Provider.of<EngagementReminderStore>(context);
    final showLanguage = defaultTargetPlatform == TargetPlatform.android;

    return MorePage(
      title: l10n.engagementReminders,
      children: [
        Observer(
          builder: (_) => MoreRows(rows: [
            AppListRow(
              key: const ValueKey('reminder_before'),
              title: l10n.scheduleReminder,
              trailing: _beforeText(context, reminderStore.reminderMinutes),
              onTap: () => _pickBefore(context, reminderStore),
            ),
            MoreSwitchRow(
              key: const ValueKey('reminder_daily'),
              title: l10n.dailyReminderTitle,
              subtitle: l10n.dailyReminderDescription,
              value: engagement.dailyEnabled,
              onChanged: (value) {
                engagement.setDailyEnabled(value);
                if (!value) NotificationService.instance.cancelDailyReminder();
              },
            ),
            MoreSwitchRow(
              key: const ValueKey('reminder_inactivity'),
              title: l10n.inactivityReminderTitle,
              subtitle: l10n.inactivityReminderDescription,
              value: engagement.inactivityEnabled,
              onChanged: (value) {
                engagement.setInactivityEnabled(value);
                if (!value) {
                  NotificationService.instance.cancelInactivityReminders();
                }
              },
            ),
            MoreSwitchRow(
              key: const ValueKey('reminder_pending_os'),
              title: l10n.pendingOsReminderTitle,
              subtitle: l10n.pendingOsReminderDescription,
              value: engagement.pendingOsEnabled,
              onChanged: (value) {
                engagement.setPendingOsEnabled(value);
                if (!value) {
                  NotificationService.instance.cancelPendingOsReminders();
                }
              },
            ),
          ]),
        ),
        if (showLanguage)
          Observer(
            builder: (_) {
              final localeStore =
                  Provider.of<LocaleStore>(context, listen: false);
              return MoreRows(rows: [
                AppListRow(
                  key: const ValueKey('reminder_language'),
                  title: l10n.language,
                  trailing: localeStore.currentLocaleDisplayName,
                  onTap: () => _pickLanguage(context, localeStore),
                ),
              ]);
            },
          )
        else if (defaultTargetPlatform == TargetPlatform.iOS)
          MoreFootnote(l10n.followsPhoneSettings),
      ],
    );
  }
}
