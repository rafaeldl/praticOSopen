import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/status_style.dart';

void main() {
  group('OrderStatusStyle.dotColor', () {
    test('maps each status to its design-system role', () {
      expect(OrderStatusStyle.dotColor('approved'), AppColors.accentText);
      expect(OrderStatusStyle.dotColor('progress'), AppColors.warning);
      expect(OrderStatusStyle.dotColor('done'), AppColors.success);
      expect(OrderStatusStyle.dotColor('quote'), AppColors.textSecondary);
    });

    test('canceled is grey, never red', () {
      expect(OrderStatusStyle.dotColor('canceled'), AppColors.textSecondary);
      expect(OrderStatusStyle.dotColor('canceled'), isNot(AppColors.danger));
    });

    test('unknown or null status falls back to grey', () {
      expect(OrderStatusStyle.dotColor(null), AppColors.textSecondary);
      expect(OrderStatusStyle.dotColor('xyz'), AppColors.textSecondary);
    });

    test('overdue uses danger', () {
      expect(OrderStatusStyle.overdueColor, AppColors.danger);
    });
  });

  group('DeviceStatusStyle.dotColor', () {
    test('maps device statuses', () {
      expect(DeviceStatusStyle.dotColor('active'), AppColors.success);
      expect(DeviceStatusStyle.dotColor('maintenance'), AppColors.warning);
      expect(DeviceStatusStyle.dotColor('inactive'), AppColors.textSecondary);
      expect(
          DeviceStatusStyle.dotColor('decommissioned'), AppColors.textSecondary);
      expect(DeviceStatusStyle.dotColor(null), AppColors.success);
    });
  });

  group('text styles and labels', () {
    testWidgets('status text is secondary, overdue is bold danger',
        (tester) async {
      late AppLocalizations l10n;
      late TextStyle normal;
      late TextStyle overdue;
      await tester.pumpWidget(CupertinoApp(
        locale: const Locale('pt'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: (context) {
          l10n = AppLocalizations.of(context);
          normal = OrderStatusStyle.textStyle(context);
          overdue = OrderStatusStyle.overdueTextStyle(context);
          return const SizedBox();
        }),
      ));
      expect(normal.color!.toARGB32(), AppColors.textSecondary.color.toARGB32());
      expect(overdue.color!.toARGB32(), AppColors.danger.color.toARGB32());
      expect(overdue.fontWeight, FontWeight.w700);
      expect(OrderStatusStyle.label(l10n, 'canceled'), l10n.statusCancelled);
      expect(OrderStatusStyle.label(l10n, 'done'), l10n.statusCompleted);
      expect(DeviceStatusStyle.label(l10n, 'maintenance'),
          l10n.deviceStatusMaintenance);
      expect(l10n.orderOverdue, 'Atrasada');
    });
  });
}
