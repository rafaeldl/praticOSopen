import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/global.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/permission.dart';
import 'package:praticos/screens/widgets/app_toast.dart';
import 'package:praticos/screens/widgets/picker_screen.dart';
import 'package:praticos/services/authorization_service.dart';
import 'package:praticos/services/device_maintenance_service.dart';
import 'package:praticos/services/format_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// "Não repetir" this many times in a row and the question stops: who does
/// no preventive maintenance should not answer it on every order. Setting a
/// date, here or on the device, starts the count over.
const kMaintenanceOfferLimit = 3;

/// The question waits this long after the order is done: the second tap of a
/// double tap on "Marcar como pronta" would land on one of the answers.
const kMaintenanceAskDelay = Duration(milliseconds: 800);

/// Each company has its own count.
String _declinedKey() =>
    'next_maintenance_declined_${Global.companyAggr?.id ?? ''}';

/// Starts the "Não repetir" count over: the person uses the date again.
Future<void> resetMaintenanceDeclines() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_declinedKey());
}

/// Answer to "Quando é a próxima manutenção?".
enum MaintenanceAnswer {
  threeMonths(3),
  sixMonths(6),
  oneYear(12),
  noRepeat(null);

  const MaintenanceAnswer(this.months);
  final int? months;
}

/// Whether finishing [order] should ask for the next maintenance. The answer
/// writes on the device, so it takes the permission of who edits devices. An
/// order of a contract never asks: the contract already sets the next one.
bool shouldOfferNextMaintenance({
  required Order order,
  required bool canManageDevices,
  required int declined,
}) {
  return order.id != null &&
      order.contract == null &&
      order.effectiveDevices.any((device) => device.id != null) &&
      canManageDevices &&
      declined < kMaintenanceOfferLimit;
}

/// Asks "Quando é a próxima manutenção?" on the screen of choosing, with the
/// month each answer leads to. Resolves with null when the person goes back.
Future<MaintenanceAnswer?> askNextMaintenance(
  BuildContext context, {
  required String subtitle,
  required DateTime now,
}) {
  final l10n = context.l10n;
  final format = FormatService()..setLocale(l10n.localeName);
  PickerItem<MaintenanceAnswer> option(
    MaintenanceAnswer answer,
    String label,
  ) => PickerItem<MaintenanceAnswer>(
    value: answer,
    title: label,
    trailing: format.formatMonthYear(addMonths(now, answer.months!)),
  );

  return pickOne<MaintenanceAnswer>(
    context,
    title: l10n.nextMaintenanceQuestion,
    subtitle: subtitle.isEmpty ? null : subtitle,
    options: [
      option(MaintenanceAnswer.threeMonths, l10n.nextMaintenanceThreeMonths),
      option(MaintenanceAnswer.sixMonths, l10n.nextMaintenanceSixMonths),
      option(MaintenanceAnswer.oneYear, l10n.nextMaintenanceOneYear),
      PickerItem<MaintenanceAnswer>(
        value: MaintenanceAnswer.noRepeat,
        title: l10n.nextMaintenanceNoRepeat,
      ),
    ],
  );
}

/// Under the question: the devices, and the date in place if there is one.
String maintenanceOfferMessage(
  BuildContext context,
  List<DeviceAggr> devices,
  List<Device?> current,
) {
  final l10n = context.l10n;
  final names = devices
      .map((device) => device.name?.trim() ?? '')
      .where((name) => name.isNotEmpty)
      .join(', ');
  final dates = current
      .map((device) => device?.nextMaintenance)
      .whereType<DateTime>()
      .toList();
  if (dates.isEmpty) return names;
  final format = FormatService()..setLocale(l10n.localeName);
  final now = l10n.nextMaintenanceCurrent(format.formatMonthYear(dates.first));
  return names.isEmpty ? now : '$names · $now';
}

/// Asks about the order just finished and saves the answer on its devices,
/// leaving out those under an active contract. Going back counts as "Não
/// repetir" for the count, as on the checklist offer, and changes no date.
/// "Não repetir" takes away only a date this order fulfilled (late or
/// "chegando"): a corrective visit does not erase the preventive set for
/// months from now.
Future<void> offerNextMaintenance(
  BuildContext context,
  Order? order, {
  DeviceMaintenanceService? service,
  bool? canManageDevices,
  DateTime Function() now = DateTime.now,
  Duration delay = kMaintenanceAskDelay,
}) async {
  final canManage =
      canManageDevices ??
      AuthorizationService.instance.hasPermission(PermissionType.manageDevices);
  if (order == null || !canManage) return;
  final prefs = await SharedPreferences.getInstance();
  final declined = prefs.getInt(_declinedKey()) ?? 0;
  if (!shouldOfferNextMaintenance(
    order: order,
    canManageDevices: canManage,
    declined: declined,
  )) {
    return;
  }
  final maintenance = service ?? DeviceMaintenanceService();
  final aggrs = order.effectiveDevices.where((d) => d.id != null).toList();
  final contracts = await Future.wait(
    aggrs.map((device) => maintenance.activeContract(device.id!)),
  );
  final free = [
    for (var i = 0; i < aggrs.length; i++)
      if (contracts[i] == null) aggrs[i],
  ];
  if (free.isEmpty) return;
  final devices = await Future.wait(
    free.map((device) => maintenance.device(device.id!)),
  );
  await Future<void>.delayed(delay);
  if (!context.mounted) return;

  final today = now();
  final answer = await askNextMaintenance(
    context,
    subtitle: maintenanceOfferMessage(context, free, devices),
    now: today,
  );
  if (answer == null) {
    await prefs.setInt(_declinedKey(), declined + 1);
    return;
  }
  if (!context.mounted) return;
  final toast = context.l10n.nextMaintenanceSaveError;
  void warn() {
    if (context.mounted) showAppToast(context, toast);
  }

  final months = answer.months;
  if (months != null) {
    await prefs.remove(_declinedKey());
    maintenance.save(
      free.map((device) => device.id!),
      date: addMonths(today, months),
      customer: order.customer,
      onFailed: warn,
    );
    return;
  }

  await prefs.setInt(_declinedKey(), declined + 1);
  final fulfilled = [
    for (var i = 0; i < free.length; i++)
      if (maintenanceIsNear(devices[i]?.nextMaintenanceDate, today))
        free[i].id!,
  ];
  if (fulfilled.isNotEmpty) {
    maintenance.save(fulfilled, date: null, onFailed: warn);
  }
}
