import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/screens/device_form_screen.dart';
import 'package:praticos/screens/widgets/app_sheet.dart';
import 'package:provider/provider.dart';

Device known(String name, String brand, String category) => Device()
  ..id = name
  ..name = name
  ..manufacturer = brand
  ..category = category;

class _Harness {
  Object? result = 'unset';
  final saved = <Device>[];

  Future<void> open(
    WidgetTester tester, {
    Device? editing,
    List<Device> devices = const [],
  }) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<SegmentConfigProvider>(
        create: (_) => SegmentConfigProvider(),
        child: CupertinoApp(
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => CupertinoPageScaffold(
              child: Center(
                child: CupertinoButton(
                  child: const Text('open'),
                  onPressed: () async {
                    final form = DeviceFormScreen(
                      device: editing,
                      asSheet: editing == null,
                      loadDevices: () async => devices,
                      onSave: (d) async => saved.add(d),
                    );
                    result = editing == null
                        ? await AppSheet.show<Device>(context, (_) => form)
                        : await Navigator.of(context).push(
                            CupertinoPageRoute(builder: (_) => form),
                          );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // SegmentConfigService reads FirebaseFirestore.instance.
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  testWidgets('new vehicle opens as a sheet: Cancelar left, only model and '
      'plate visible', (tester) async {
    final h = _Harness();
    await h.open(tester);

    expect(find.text('Cancelar'), findsOneWidget);
    expect(find.text('Salvar'), findsOneWidget);
    expect(find.byType(EditableText), findsNWidgets(2));
    expect(find.text('+ Foto e mais dados'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(h.result, isNull);
    expect(h.saved, isEmpty);
  });

  testWidgets('empty plate blocks saving with a hint', (tester) async {
    final h = _Harness();
    await h.open(tester);

    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Preencha o campo'), findsOneWidget);
    expect(h.saved, isEmpty);
  });

  testWidgets('choosing a suggestion fills brand and category, then saves',
      (tester) async {
    final h = _Harness();
    await h.open(tester, devices: [
      known('Fiat Uno 2015', 'Fiat', 'Carro'),
      known('Gol 1.0', 'VW', 'Carro'),
    ]);

    await tester.enterText(find.byType(EditableText).first, 'uno');
    await tester.pumpAndSettle();
    expect(find.text('Fiat · Carro'), findsOneWidget);
    expect(find.text('Gol 1.0'), findsNothing);

    await tester.tap(find.text('Fiat Uno 2015'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(EditableText).at(1), 'abc1d23');
    await tester.tap(find.text('+ Foto e mais dados'));
    await tester.pumpAndSettle();
    expect(find.text('Fiat'), findsOneWidget);
    expect(find.text('Carro'), findsOneWidget);

    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(h.saved, hasLength(1));
    final device = h.saved.single;
    expect(device.name, 'Fiat Uno 2015');
    expect(device.manufacturer, 'Fiat');
    expect(device.category, 'Carro');
    expect(device.serial, 'ABC1D23');
    expect(h.result, same(device));
  });

  testWidgets('typed model with no match offers "Usar" and is kept',
      (tester) async {
    final h = _Harness();
    await h.open(tester);

    await tester.enterText(find.byType(EditableText).first, 'Fiat Uno 2016');
    await tester.pumpAndSettle();
    expect(find.text('Usar “Fiat Uno 2016”'), findsOneWidget);

    await tester.enterText(find.byType(EditableText).at(1), 'XYZ9K88');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(h.saved.single.name, 'Fiat Uno 2016');
    expect(h.saved.single.manufacturer, isNull);
  });

  testWidgets('editing is a pushed screen with data prefilled and more data '
      'already open', (tester) async {
    final h = _Harness();
    final device = Device()
      ..id = 'd1'
      ..name = 'Gol 1.0'
      ..serial = 'AAA1B22'
      ..manufacturer = 'VW';
    await h.open(tester, editing: device);

    expect(find.text('Cancelar'), findsNothing);
    expect(find.text('Gol 1.0'), findsOneWidget);
    expect(find.text('AAA1B22'), findsOneWidget);
    expect(find.text('VW'), findsOneWidget);
    expect(find.text('+ Foto e mais dados'), findsNothing);

    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(h.saved.single, same(device));
  });
}
