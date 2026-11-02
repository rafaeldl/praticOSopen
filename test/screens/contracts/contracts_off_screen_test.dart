import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/screens/contracts/contracts_off_screen.dart';
import 'package:provider/provider.dart';

void main() {
  Future<SegmentConfigProvider> pump(
    WidgetTester tester, {
    required ContractsSwitchWriter writer,
    required VoidCallback onTurnedOn,
  }) async {
    // The provider reads a shared service: start every test with it off.
    final provider = SegmentConfigProvider()
      ..setCompanyConfig(
        fieldService: false,
        useScheduling: true,
        useDeviceManagement: false,
        useContracts: false,
        useFinancial: true,
      );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: CupertinoApp(
          locale: const Locale('pt'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: ContractsOffScreen(
            companyId: 'c1',
            writer: writer,
            onTurnedOn: onTurnedOn,
          ),
        ),
      ),
    );
    await tester.pump();
    return provider;
  }

  testWidgets('says what it is for and turns the switch on', (tester) async {
    final written = <String>[];
    var turnedOn = 0;
    final provider = await pump(
      tester,
      writer: (id) async => written.add(id),
      onTurnedOn: () => turnedOn++,
    );

    expect(
      find.text('Tem cliente fixo ou manutenção que se repete?'),
      findsOneWidget,
    );
    await tester.tap(find.text('Usar contratos'));
    await tester.pumpAndSettle();

    expect(written, ['c1']);
    expect(provider.useContracts, isTrue);
    expect(turnedOn, 1);
  });

  testWidgets('a failed write stays here and explains', (tester) async {
    var turnedOn = 0;
    final provider = await pump(
      tester,
      writer: (_) async => throw Exception('x'),
      onTurnedOn: () => turnedOn++,
    );

    await tester.tap(find.text('Usar contratos'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    expect(provider.useContracts, isFalse);
    expect(turnedOn, 0);
  });
}
