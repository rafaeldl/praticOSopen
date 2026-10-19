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
import 'package:praticos/screens/widgets/picker_screen.dart';
import 'package:praticos/services/notification_service.dart';

/// "Lembretes" (replaces "Preferências"): reminder before the scheduled
/// time and the three engagement reminders. Language and appearance follow
/// the iPhone, so only Android keeps the "Idioma" row.
class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});

  String _beforeText(BuildContext context, int minutes) {
    final l10n = context.l10n;
    if (minutes == 0) return l10n.reminderDisabled;
    if (minutes % 60 == 0) return l10n.reminderHoursValue(minutes ~/ 60);
    return l10n.reminderMinutesValue(minutes);
  }

  Future<void> _pickBefore(BuildContext context, ReminderStore store) async {
    final l10n = context.l10n;
    final minutes = await pickOne<int>(
      context,
      title: l10n.scheduleReminder,
      selected: store.reminderMinutes,
      options: [
        PickerItem(value: 0, title: l10n.reminderDisabled),
        PickerItem(value: 15, title: l10n.reminderMinutesBefore(15)),
        PickerItem(value: 30, title: l10n.reminderMinutesBefore(30)),
        PickerItem(value: 60, title: l10n.reminderHourBefore),
        PickerItem(value: 120, title: l10n.reminderHoursBefore(2)),
      ],
    );
    if (minutes != null) store.setReminderMinutes(minutes);
  }

  Future<void> _pickLanguage(BuildContext context, LocaleStore store) async {
    final code = await pickOne<String>(
      context,
      title: context.l10n.selectLanguage,
      selected: store.currentLocaleCode,
      options: [
        for (final locale in store.availableLocales)
          PickerItem(
            value: locale['code']!,
            title: '${locale['flag']} ${locale['name']}',
          ),
      ],
    );
    if (code != null) store.setLocale(code);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final reminderStore = Provider.of<ReminderStore>(context);
    final engagement = Provider.of<EngagementReminderStore>(context);
    final showLanguage = defaultTargetPlatform == TargetPlatform.android;

    return MorePage(
      title: l10n.engagementReminders,
      subtitle: l10n.remindersSubtitle,
      children: [
        Observer(
          builder: (_) => MoreRows(rows: [
            AppListRow(
              key: const ValueKey('reminder_before'),
              title: l10n.reminderBeforeTitle,
              trailing: _beforeText(context, reminderStore.reminderMinutes),
              onTap: () => _pickBefore(context, reminderStore),
            ),
            MoreSwitchRow(
              key: const ValueKey('reminder_daily'),
              title: l10n.reminderDailyTitle,
              subtitle: l10n.reminderDailySubtitle,
              value: engagement.dailyEnabled,
              onChanged: (value) {
                engagement.setDailyEnabled(value);
                if (!value) NotificationService.instance.cancelDailyReminder();
              },
            ),
            MoreSwitchRow(
              key: const ValueKey('reminder_inactivity'),
              title: l10n.reminderInactivityTitle,
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
              title: l10n.reminderPendingTitle,
              subtitle: l10n.reminderPendingSubtitle,
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
