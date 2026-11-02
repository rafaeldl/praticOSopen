import 'dart:ui';

import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/services/format_service.dart';

/// Text of the local reminder before a scheduled order: the time on the
/// title, and who and what under it, so nobody has to open the app to know
/// which car or device it is. Stores have no `context`, so the strings come
/// from the locale [FormatService] is using.
class OrderReminderText {
  const OrderReminderText({required this.title, required this.body});

  final String title;
  final String body;

  factory OrderReminderText.of(Order order) {
    final format = FormatService();
    return OrderReminderText.format(
      order,
      lookupAppLocalizations(Locale(format.locale.split(RegExp('[-_]')).first)),
      format.formatTime(order.scheduledDate),
    );
  }

  /// "Agendamento às 14:00" / "OS 12 · Ana Souza · Onix 1.0 +1".
  factory OrderReminderText.format(
    Order order,
    AppLocalizations l10n,
    String time,
  ) {
    final devices = order.effectiveDevices;
    final device = devices.firstOrNull?.name ?? '';
    final number = order.number;
    return OrderReminderText(
      title: l10n.reminderNotificationTitle(time),
      body: [
        if (number != null) '${l10n.orderShort} $number',
        order.customer?.name ?? '',
        if (device.isNotEmpty)
          devices.length > 1 ? '$device +${devices.length - 1}' : device,
      ].where((part) => part.isNotEmpty).join(' · '),
    );
  }
}
