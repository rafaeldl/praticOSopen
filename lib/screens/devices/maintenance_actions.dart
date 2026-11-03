import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/screens/order/order_route.dart';
import 'package:praticos/screens/widgets/app_toast.dart';
import 'package:praticos/services/device_maintenance_service.dart';
import 'package:praticos/services/format_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// What the person chose on a maintenance of "Manutenções chegando".
enum MaintenanceAction { callCustomer, openOrder, viewDevice }

/// Sheet of a maintenance. "Chamar cliente" needs a customer and "Abrir OS"
/// who can create orders; "Ver aparelho" leads to changing or removing the
/// date, so nothing gets stuck on Início.
Future<MaintenanceAction?> askMaintenanceAction(
  BuildContext context,
  Device device, {
  required bool canCreateOrder,
  required String deviceLabel,
}) {
  final l10n = context.l10n;
  final format = FormatService()..setLocale(l10n.localeName);
  final customer = device.nextMaintenanceCustomer?.name?.trim() ?? '';
  var answered = false;
  return showCupertinoModalPopup<MaintenanceAction>(
    context: context,
    builder: (popupContext) {
      // A second tap while the sheet slides away would pop the screen below.
      void close(MaintenanceAction? action) {
        if (answered) return;
        answered = true;
        Navigator.pop(popupContext, action);
      }

      Widget option(MaintenanceAction action, String label) =>
          CupertinoActionSheetAction(
            onPressed: () => close(action),
            child: Text(label),
          );

      return CupertinoActionSheet(
        title: Text(device.name ?? ''),
        message: Text(
          [
            if (customer.isNotEmpty) customer,
            format.formatDate(device.nextMaintenance),
          ].join(' · '),
        ),
        actions: [
          if (device.nextMaintenanceCustomer?.id != null)
            option(
              MaintenanceAction.callCustomer,
              l10n.maintenanceCallCustomer,
            ),
          if (canCreateOrder)
            option(MaintenanceAction.openOrder, l10n.maintenanceOpenOrder),
          option(
            MaintenanceAction.viewDevice,
            l10n.maintenanceViewDevice(deviceLabel),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => close(null),
          child: Text(l10n.cancel),
        ),
      );
    },
  );
}

/// Opens WhatsApp with the message ready, for the person to review and send.
/// The app sends nothing on its own.
Future<void> callMaintenanceCustomer(
  BuildContext context,
  Device device, {
  DeviceMaintenanceService? service,
}) async {
  final l10n = context.l10n;
  final format = FormatService()..setLocale(l10n.localeName);
  final customer = device.nextMaintenanceCustomer;
  final phone = await (service ?? DeviceMaintenanceService()).customerPhone(
    customer?.id,
  );
  if (!context.mounted) return;
  final uri = whatsappMessageUri(
    phone,
    maintenanceWhatsappText(
      l10n,
      customer: customer?.name,
      device: device.name ?? '',
      date: format.formatMonthYear(device.nextMaintenance),
    ),
  );
  if (uri == null) {
    showAppToast(context, l10n.maintenanceNoPhone);
    return;
  }
  var opened = false;
  try {
    opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    // Same notice as a phone with no way to open the link.
  }
  if (!opened && context.mounted) {
    showAppToast(context, l10n.maintenanceWhatsappError);
  }
}

/// "Abrir OS": a Nova OS with the customer, the device and the services of the
/// last finished order. It only opens the form: nothing is saved until "✓".
Future<Object?> openMaintenanceOrder(
  BuildContext context,
  Device device, {
  DeviceMaintenanceService? service,
}) async {
  final order = await (service ?? DeviceMaintenanceService()).newOrderFor(
    device,
  );
  if (!context.mounted) return null;
  return openNewOrder(context, prefill: order);
}
