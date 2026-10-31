import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/screens/widgets/app_form_field.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/global.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/custom_field.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/permission.dart';
import 'package:praticos/models/product.dart';
import 'package:praticos/models/service.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/models/user_role.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/screens/catalog/catalog_source.dart';
import 'package:praticos/screens/customers/customer_list_screen.dart'
    show CustomerPick;
import 'package:praticos/screens/order/order_screen_services.dart';
import 'package:praticos/screens/order/assistant/speech_listener.dart';
import 'package:praticos/screens/order/new_order_form.dart';
import 'package:praticos/screens/device_list_screen.dart'
    show kRemoveDeviceResult;
import 'package:praticos/screens/order/order_screen_v2.dart';
import 'package:praticos/screens/widgets/device_picker_sheet.dart';
import 'package:praticos/services/segment_config_service.dart';
import 'package:praticos/screens/widgets/status_dot.dart';
import 'package:praticos/services/ai_order_assist_service.dart';
import 'package:praticos/services/analytics_service.dart';
import 'package:praticos/services/subscription_service.dart';
import 'package:praticos/services/assistant_registration.dart';
import 'package:praticos/services/authorization_service.dart';
import 'package:praticos/services/format_service.dart';
import 'package:provider/provider.dart';

/// Firebase core mock whose default app has a storage bucket (OrderStore
/// creates Firestore/Storage services in its fields).
class _FirebaseCoreMockWithBucket extends MockFirebaseApp {
  @override
  Future<List<CoreInitializeResponse>> initializeCore() async => [
    CoreInitializeResponse(
      name: defaultFirebaseAppName,
      options: CoreFirebaseOptions(
        apiKey: '123',
        projectId: '123',
        appId: '123',
        messagingSenderId: '123',
        storageBucket: 'test.appspot.com',
      ),
      pluginConstants: {},
    ),
  ];
}

class FakeSource implements CatalogSource {
  FakeSource({this.services = const [], this.products = const []});

  final List<CatalogItem> services;
  final List<CatalogItem> products;
  final List<(CatalogKind, CatalogItem)> saved = [];

  @override
  Stream<List<CatalogItem>> watch(CatalogKind kind) =>
      Stream.value(kind == CatalogKind.service ? services : products);

  @override
  Future<void> save(CatalogKind kind, CatalogItem item) async {
    item.id ??= 'new-${saved.length}';
    saved.add((kind, item));
  }

  @override
  Future<void> delete(CatalogKind kind, CatalogItem item) async {}

  @override
  Future<String?> uploadPhoto(
    CatalogKind kind,
    CatalogItem item,
    PhotoOrigin from,
  ) async => null;
}

class FakeActions extends OrderScreenActions {
  final List<String> calls = [];

  @override
  Future<void> openPayments(BuildContext context, OrderStore store) async =>
      calls.add('payments');

  @override
  Future<void> shareWithCustomer(BuildContext context, Order order) async =>
      calls.add('send');
}

/// Registration without Firebase: ids in order, writes kept in lists.
class FakeRegistration extends AssistantRegistration {
  FakeRegistration() : super(newId: _next);
  static int _n = 0;
  static String _next() => 'new${++_n}';
  final List<Customer> customers = [];
  final List<Device> devices = [];

  @override
  Future<void> saveCustomer(Customer customer) async => customers.add(customer);

  @override
  Future<void> saveDevice(Device device) async => devices.add(device);
}

class FakeAssistant implements AiOrderAssistClient {
  FakeAssistant(this.draft, {this.error, this.enabled = true});

  /// What the next call returns (a test can swap it between calls).
  AiOrderDraft draft;
  final AiOrderAssistException? error;
  final bool enabled;
  int statusCalls = 0;

  @override
  Future<bool> isEnabled() async {
    statusCalls++;
    return enabled;
  }

  final List<String?> texts = [];
  final List<int> photoCounts = [];
  final List<AiOrderSnapshot?> orders = [];

  @override
  Future<AiOrderDraft> assist({
    String? text,
    List<AiPhoto> photos = const [],
    String? locale,
    AiOrderSnapshot? order,
  }) async {
    texts.add(text);
    photoCounts.add(photos.length);
    orders.add(order);
    if (error != null) throw error!;
    return draft;
  }
}

/// Labels of the open "…" pull-down menu, top to bottom.
List<String> _menuLabels(WidgetTester tester) => [
  for (final row in tester.widgetList(
    find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('pull_down_'),
    ),
  ))
    (tester.widget<Text>(
          find
              .descendant(of: find.byWidget(row), matching: find.byType(Text))
              .first,
        )).data ??
        '',
];

String _money(double v) => (FormatService()..setLocale('pt')).formatCurrency(v);

CatalogItem _item(String id, String name, [double? value]) =>
    CatalogItem(id: id, name: name, value: value, origin: Object());

OrderPermissions _permissions({
  bool prices = true,
  bool receive = true,
  bool Function(Order? order)? receiveOn,
}) => OrderPermissions(
  canViewPrices: () => prices,
  canReceivePayments: receiveOn ?? (_) => receive,
  canGiveDiscount: () => receive,
  availableStatuses: (_) => const ['approved', 'progress', 'canceled'],
  canChangeStatus: (_, _) => true,
  canDelete: (_) => true,
);

const _allCatalog = CatalogPermissions(_all);
bool _all(PermissionType p) => true;

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  Map<String, dynamic>? args,
  bool hosted = false,
}) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<SegmentConfigProvider>(
      create: (_) =>
          SegmentConfigProvider()
            ..injectL10n(lookupAppLocalizations(const Locale('pt'))),
      child: CupertinoApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        onGenerateRoute: (settings) {
          if (settings.name == '/' && hosted) {
            // A page under the sheet, so "X" and "✓" can close it.
            return CupertinoPageRoute(
              settings: settings,
              builder: (context) => CupertinoPageScaffold(
                child: Center(
                  child: CupertinoButton(
                    onPressed: () => Navigator.push(
                      context,
                      CupertinoPageRoute(builder: (_) => screen),
                    ),
                    child: const Text('abrir'),
                  ),
                ),
              ),
            );
          }
          if (settings.name == '/') {
            return CupertinoPageRoute(
              settings: RouteSettings(name: '/', arguments: args),
              builder: (_) => screen,
            );
          }
          if (settings.name == '/customer_list') {
            // Fake "Quem é o cliente?": a plate hit returns customer + vehicle.
            return CupertinoPageRoute(
              settings: settings,
              builder: (context) => CupertinoPageScaffold(
                child: Center(
                  child: CupertinoButton(
                    onPressed: () => Navigator.pop(
                      context,
                      CustomerPick(
                        Customer()
                          ..id = 'c1'
                          ..name = 'Ana Souza',
                        Device()
                          ..id = 'd1'
                          ..name = 'Gol 2018'
                          ..serial = 'ABC1D23',
                      ),
                    ),
                    child: const Text('pick ABC1D23'),
                  ),
                ),
              ),
            );
          }
          if (settings.name == '/device_list' &&
              (settings.arguments as Map?)?['current'] != null) {
            // Fake "Qual veículo?": only its "Tirar … da OS" row.
            return CupertinoPageRoute(
              settings: settings,
              builder: (context) => CupertinoPageScaffold(
                child: Center(
                  child: CupertinoButton(
                    onPressed: () =>
                        Navigator.pop(context, kRemoveDeviceResult),
                    child: const Text('remove device'),
                  ),
                ),
              ),
            );
          }
          return CupertinoPageRoute(
            settings: settings,
            builder: (_) => const Text('pushed'),
          );
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (hosted) {
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }
}

class FakeSpeech implements SpeechListener {
  FakeSpeech(this.words, {this.allowed = true, this.hold = false});

  final String words;
  final bool allowed;

  /// Keeps listening until stopped (otherwise it ends right away).
  final bool hold;
  int stops = 0;

  @override
  Future<bool> start({
    required String localeId,
    required void Function(String words) onWords,
    required void Function() onDone,
  }) async {
    if (!allowed) return false;
    onWords(words);
    if (!hold) onDone();
    return true;
  }

  @override
  Future<void> stop() async => stops++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestFirebaseCoreHostApi.setUp(_FirebaseCoreMockWithBucket());
    await Firebase.initializeApp();
  });

  // No company: OrderStore.createItem never reaches Firestore in tests.
  setUp(() => Global.companyAggr = null);

  final source = FakeSource(
    services: [_item('s1', 'Troca de óleo', 120), _item('s2', 'Alinhamento')],
    products: [_item('p1', 'Filtro de óleo', 35.5)],
  );

  OrderScreenV2 screen(
    OrderStore store, {
    FakeSource? catalog,
    CatalogPermissions catalogPermissions = _allCatalog,
    OrderScreenActions? actions,
    bool prices = true,
    bool receive = true,
    bool Function(Order? order)? receiveOn,
  }) => OrderScreenV2(
    showAssistant: false,
    store: store,
    permissions: _permissions(
      prices: prices,
      receive: receive,
      receiveOn: receiveOn,
    ),
    actions: actions ?? FakeActions(),
    catalogSource: catalog ?? source,
    catalogPermissions: catalogPermissions,
    mostUsed: () async => const [],
  );

  group('new order (sheet)', () {
    Finder save() => find.byKey(const ValueKey('new_order_save'));
    CupertinoButton saveButton(WidgetTester tester) =>
        tester.widget<CupertinoButton>(save());

    testWidgets('opens blank: X, gray ✓, cards in order, nothing saved', (
      tester,
    ) async {
      final store = OrderStore();
      await _pump(tester, screen(store), hosted: true);

      expect(find.text('Nova OS'), findsOneWidget);
      expect(find.byKey(const ValueKey('new_order_close')), findsOneWidget);
      expect(saveButton(tester).onPressed, isNull);
      expect(find.text('Escolha o cliente para salvar.'), findsOneWidget);

      // Order of importance: customer, items, request, delivery, more.
      double y(Finder f) => tester.getTopLeft(f).dy;
      final customer = y(find.byKey(const ValueKey('new_order_pick_customer')));
      final items = y(find.byKey(const ValueKey('new_order_add_item')));
      final request = y(find.byKey(const ValueKey('new_order_request')));
      final due = y(find.byKey(const ValueKey('new_order_due')));
      final more = y(find.byKey(const ValueKey('new_order_more')));
      expect(customer < items && items < request, isTrue);
      expect(request < due && due < more, isTrue);

      expect(find.text('Sem data'), findsOneWidget);
      expect(find.text('Mais opções'), findsOneWidget);
      // No big blue button at the bottom any more.
      expect(find.text('Salvar OS'), findsNothing);
      expect(store.deferSave, isTrue);
      expect(store.order!.id, isNull);
      expect(store.status, 'quote');
    });

    testWidgets('picking the customer lights the ✓; ✓ saves and closes', (
      tester,
    ) async {
      final store = OrderStore();
      await _pump(tester, screen(store), hosted: true);

      await tester.tap(find.byKey(const ValueKey('new_order_pick_customer')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('pick ABC1D23'));
      await tester.pumpAndSettle();

      expect(find.text('Ana Souza'), findsOneWidget);
      expect(find.text('Gol 2018'), findsOneWidget);
      expect(store.devices.single.id, 'd1');
      expect(find.text('Escolha o cliente para salvar.'), findsNothing);
      expect(saveButton(tester).onPressed, isNotNull);

      await tester.tap(save());
      await tester.pumpAndSettle();
      expect(store.deferSave, isFalse);
      // Back on the page under the sheet.
      expect(find.text('abrir'), findsOneWidget);
    });

    testWidgets('X closes at once when nothing was filled', (tester) async {
      await _pump(tester, screen(OrderStore()), hosted: true);
      await tester.tap(find.byKey(const ValueKey('new_order_close')));
      await tester.pumpAndSettle();
      expect(find.text('abrir'), findsOneWidget);
    });

    testWidgets('X asks before throwing away what was filled', (tester) async {
      await _pump(tester, screen(OrderStore()), hosted: true);
      await tester.enterText(
        find.byKey(const ValueKey('new_order_request')),
        'Barulho ao frear',
      );
      await tester.tap(find.byKey(const ValueKey('new_order_close')));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(find.text('abrir'), findsNothing);
    });

    testWidgets('from Contratos: starts with "Repetir" on, in sight', (
      tester,
    ) async {
      final store = OrderStore();
      await _pump(tester, screen(store), args: {'repeat': true});

      expect(store.hasContract, isTrue);
      expect(store.order?.contract?.frequency, 'monthly');
      final repeat = find.byKey(const ValueKey('new_order_more_repeat'));
      await tester.ensureVisible(repeat);
      expect(repeat, findsOneWidget);
      expect(
        find.descendant(of: repeat, matching: find.text('Todo mês')),
        findsOneWidget,
      );
    });

    testWidgets('a plain new order has no "Repetir" row', (tester) async {
      final store = OrderStore();
      await _pump(tester, screen(store), hosted: true);
      expect(store.hasContract, isFalse);
      expect(find.byKey(const ValueKey('new_order_more_repeat')), findsNothing);
    });

    testWidgets('"Mais opções" changes the status and shows it under it', (
      tester,
    ) async {
      final store = OrderStore();
      await _pump(tester, screen(store), hosted: true);

      // Closed, the fields stay hidden.
      expect(find.byKey(const ValueKey('new_order_more_status')), findsNothing);

      // Opens inside the same card, no other sheet. Scroll it out from
      // under the assistant bar first.
      await tester.drag(find.byType(ListView).first, const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('new_order_more')));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoActionSheet), findsNothing);
      expect(
        find.byKey(const ValueKey('new_order_more_responsible')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('new_order_more_address')),
        findsOneWidget,
      );

      await tester.ensureVisible(
        find.byKey(const ValueKey('new_order_more_status')),
      );
      // The value hugs the right edge (next to the chevron), not mid-row.
      final row = tester.getRect(
        find.byKey(const ValueKey('new_order_more_status')),
      );
      final value = tester.getRect(
        find.descendant(
          of: find.byKey(const ValueKey('new_order_more_status')),
          matching: find.text('Orçamento'),
        ),
      );
      expect(row.right - value.right, lessThan(60));
      // Clear of the Foto bar at the bottom.
      await tester.drag(find.byType(ListView).first, const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('new_order_more_status')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aprovado').last);
      await tester.pumpAndSettle();
      expect(store.status, 'approved');

      // Closed again, the summary shows what was chosen.
      await tester.ensureVisible(find.byKey(const ValueKey('new_order_more')));
      await tester.tap(find.byKey(const ValueKey('new_order_more')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('new_order_more_status')), findsNothing);
      expect(find.text('Aprovado'), findsOneWidget);
    });
  });

  group('assistant (aiOrderAssist)', () {
    // 1x1 transparent PNG.
    final png = Uint8List.fromList(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
      ),
    );

    const draft = AiOrderDraft(
      customer: AiCustomerHit(id: 'c9', name: 'Revenda Sul'),
      deviceGuessName: 'Classic',
      deviceGuessSerial: 'NXS8620',
      items: [
        AiDraftItem(
          kind: 'service',
          name: 'Troca de óleo',
          value: 120,
          catalogId: 's1',
        ),
        AiDraftItem(kind: 'service', name: 'Polimento'),
        AiDraftItem(
          kind: 'product',
          name: 'Filtro de óleo',
          value: 35.5,
          quantity: 2,
          catalogId: 'p1',
        ),
      ],
      used: 1,
      limit: 10,
    );

    OrderScreenV2 assistantScreen(
      OrderStore store,
      FakeAssistant assistant, {
      Future<AiPhoto?> Function()? capture,
      SpeechListener? speech,
      AssistantRegistration? registration,
    }) => OrderScreenV2(
      store: store,
      permissions: _permissions(),
      actions: FakeActions(),
      catalogSource: source,
      catalogPermissions: _allCatalog,
      mostUsed: () async => const [],
      showAssistant: true,
      assistant: assistant,
      capturePhoto: capture ?? () async => AiPhoto(png),
      speechListener: speech ?? FakeSpeech('Revenda Sul, troca de óleo'),
      registration: registration ?? FakeRegistration(),
    );

    FormRow rowOf(WidgetTester tester, String text) => tester.widget<FormRow>(
      find.byWidgetPredicate((w) => w is FormRow && w.title == text),
    );

    const filledNote = 'Preenchi o que está marcado. Confira e salve.';

    testWidgets('server says off: Foto stays, Falar is hidden', (tester) async {
      final assistant = FakeAssistant(const AiOrderDraft(), enabled: false);
      await _pump(
        tester,
        OrderScreenV2(
          store: OrderStore(),
          permissions: _permissions(),
          actions: FakeActions(),
          assistant: assistant,
        ),
      );
      expect(assistant.statusCalls, 1);
      expect(find.byKey(const ValueKey('assistant_photo')), findsOneWidget);
      expect(find.byKey(const ValueKey('assistant_talk')), findsNothing);
    });

    testWidgets('server says on: Falar shows without a new app build', (
      tester,
    ) async {
      final assistant = FakeAssistant(const AiOrderDraft());
      await _pump(
        tester,
        OrderScreenV2(
          store: OrderStore(),
          permissions: _permissions(),
          actions: FakeActions(),
          assistant: assistant,
        ),
      );
      expect(assistant.statusCalls, 1);
      expect(find.byKey(const ValueKey('assistant_talk')), findsOneWidget);
    });

    testWidgets('without the flag Foto attaches photos in a "Fotos" card', (
      tester,
    ) async {
      await _pump(
        tester,
        OrderScreenV2(
          showAssistant: false,
          store: OrderStore(),
          permissions: _permissions(),
          actions: FakeActions(),
          capturePhoto: () async => AiPhoto(png),
          pickGalleryPhotos: () async => [AiPhoto(png), AiPhoto(png)],
        ),
      );
      expect(find.byKey(const ValueKey('new_order_photos')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('assistant_photo')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tirar Foto'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('new_order_photos')), findsOneWidget);
      expect(find.byKey(const ValueKey('new_order_photo_0')), findsOneWidget);
      // No assistant sheet without the flag.
      expect(find.text('Pronto'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('new_order_photo_add')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Escolher da Galeria'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('new_order_photo_2')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('new_order_photo_0')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remover Foto'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('new_order_photo_2')), findsNothing);
      expect(find.byKey(const ValueKey('new_order_photo_1')), findsOneWidget);
    });

    testWidgets('with the flag: Foto and Falar sit in the bottom bar', (
      tester,
    ) async {
      await _pump(tester, assistantScreen(OrderStore(), FakeAssistant(draft)));
      expect(find.byType(AssistantBar), findsOneWidget);
      expect(find.byKey(const ValueKey('assistant_photo')), findsOneWidget);
      expect(find.byKey(const ValueKey('assistant_talk')), findsOneWidget);
    });

    testWidgets('Falar listens in the bar, fills the order and marks it', (
      tester,
    ) async {
      final store = OrderStore();
      final assistant = FakeAssistant(draft);
      await _pump(tester, assistantScreen(store, assistant));

      // Ends by itself (a pause): fills with what was heard.
      await tester.tap(find.byKey(const ValueKey('assistant_talk')));
      await tester.pumpAndSettle();

      expect(assistant.texts, ['Revenda Sul, troca de óleo']);
      expect(assistant.photoCounts, [0]);
      expect(store.deferSave, isTrue);
      expect(store.order!.id, isNull);
      // No other screen opened; the note says what happened.
      expect(find.byType(CupertinoActionSheet), findsNothing);
      expect(find.text(filledNote), findsOneWidget);
      expect(find.text('Desfazer'), findsOneWidget);

      expect(rowOf(tester, 'Revenda Sul').marked, isTrue);
      expect(rowOf(tester, 'Troca de óleo').marked, isTrue);
      expect(rowOf(tester, 'Polimento').marked, isTrue);
      expect(rowOf(tester, 'Filtro de óleo').marked, isTrue);
      expect(store.services!.map((s) => s.service?.id), ['s1', null]);
      expect(store.services![1].value, isNull);
      expect(store.products!.single.quantity, 2);
      expect(find.text('sem valor'), findsOneWidget);
    });

    testWidgets('while listening the bar shows what was heard; stop fills', (
      tester,
    ) async {
      final speech = FakeSpeech('Revenda Sul, troca de óleo', hold: true);
      final assistant = FakeAssistant(draft);
      await _pump(
        tester,
        assistantScreen(OrderStore(), assistant, speech: speech),
      );

      await tester.tap(find.byKey(const ValueKey('assistant_talk')));
      // The wave keeps moving: no pumpAndSettle while listening.
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Ouvindo…'), findsOneWidget);
      expect(find.text('“Revenda Sul, troca de óleo”'), findsOneWidget);
      expect(find.byKey(const ValueKey('assistant_photo')), findsNothing);
      expect(assistant.texts, isEmpty);

      await tester.tap(find.byKey(const ValueKey('assistant_stop')));
      await tester.pumpAndSettle();
      expect(speech.stops, 1);
      expect(assistant.texts, ['Revenda Sul, troca de óleo']);
      expect(find.text('Ouvindo…'), findsNothing);
      expect(find.byKey(const ValueKey('assistant_talk')), findsOneWidget);
    });

    testWidgets('"X" while listening sends nothing', (tester) async {
      final speech = FakeSpeech('Revenda Sul', hold: true);
      final assistant = FakeAssistant(draft);
      await _pump(
        tester,
        assistantScreen(OrderStore(), assistant, speech: speech),
      );

      await tester.tap(find.byKey(const ValueKey('assistant_talk')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const ValueKey('assistant_cancel')));
      await tester.pumpAndSettle();
      expect(speech.stops, 1);
      expect(assistant.texts, isEmpty);
      expect(find.text('Ouvindo…'), findsNothing);
      expect(find.byKey(const ValueKey('assistant_talk')), findsOneWidget);
    });

    testWidgets('"Desfazer" takes out what the assistant put', (tester) async {
      final store = OrderStore();
      await _pump(tester, assistantScreen(store, FakeAssistant(draft)));

      await tester.tap(find.byKey(const ValueKey('assistant_talk')));
      await tester.pumpAndSettle();
      expect(store.services, hasLength(2));

      await tester.tap(find.text('Desfazer'));
      await tester.pumpAndSettle();
      expect(store.customer, isNull);
      expect(store.services, isEmpty);
      expect(store.products, isEmpty);
      expect(find.text(filledNote), findsNothing);
      expect(
        find.byKey(const ValueKey('new_order_pick_customer')),
        findsOneWidget,
      );
    });

    testWidgets('sends the order; changes and takes out the lines named', (
      tester,
    ) async {
      final store = OrderStore();
      final assistant = FakeAssistant(draft);
      await _pump(tester, assistantScreen(store, assistant));
      await tester.tap(find.byKey(const ValueKey('assistant_talk')));
      await tester.pumpAndSettle();
      expect(assistant.orders.single!.isEmpty, isTrue);

      // "troca de óleo 150, tira o polimento e são 3 filtros".
      assistant.draft = const AiOrderDraft(
        changes: [
          AiDraftChange(
            remove: false,
            name: 'Troca de óleo',
            line: AiLineRef(kind: 'service', index: 0),
            value: 150,
          ),
          AiDraftChange(
            remove: true,
            name: 'Polimento',
            line: AiLineRef(kind: 'service', index: 1),
          ),
          AiDraftChange(
            remove: false,
            name: 'Filtro de óleo',
            line: AiLineRef(kind: 'product', index: 0),
            quantity: 3,
          ),
        ],
      );
      await tester.tap(find.byKey(const ValueKey('assistant_talk')));
      await tester.pumpAndSettle();

      final sent = assistant.orders.last!;
      expect(sent.services.map((l) => l.name), ['Troca de óleo', 'Polimento']);
      expect(sent.services.first.value, 120);
      expect(sent.products.single.quantity, 2);

      expect(store.services, hasLength(1));
      expect(store.services!.single.value, 150);
      expect(store.products!.single.quantity, 3);
      expect(store.products!.single.total, closeTo(106.5, 0.001));
      expect(store.order!.total, closeTo(256.5, 0.001));
      expect(rowOf(tester, 'Troca de óleo').marked, isTrue);
      expect(find.text('Mudei a OS como você pediu. Confira.'), findsOneWidget);

      // "Desfazer" puts the value, the quantity and the line back.
      await tester.tap(find.text('Desfazer'));
      await tester.pumpAndSettle();
      expect(store.services!.map((s) => s.service?.name), [
        'Troca de óleo',
        'Polimento',
      ]);
      expect(store.services!.first.value, 120);
      expect(store.products!.single.quantity, 2);
      expect(store.order!.total, closeTo(191, 0.001));
    });

    testWidgets(
      '"pintura do para-choque": the description goes with the line',
      (tester) async {
        final store = OrderStore();
        final assistant = FakeAssistant(
          const AiOrderDraft(
            items: [
              AiDraftItem(
                kind: 'service',
                name: 'Pintura',
                description: 'Para-choque dianteiro',
                value: 300,
                catalogId: 's9',
              ),
            ],
          ),
        );
        await _pump(tester, assistantScreen(store, assistant));
        await tester.tap(find.byKey(const ValueKey('assistant_talk')));
        await tester.pumpAndSettle();

        expect(store.services!.single.service?.name, 'Pintura');
        expect(store.services!.single.description, 'Para-choque dianteiro');
        expect(find.textContaining('Para-choque dianteiro'), findsOneWidget);

        // "a pintura é na porta": the line goes out with its description and
        // only the description changes; "Desfazer" puts it back.
        assistant.draft = const AiOrderDraft(
          changes: [
            AiDraftChange(
              remove: false,
              name: 'Pintura',
              line: AiLineRef(kind: 'service', index: 0),
              description: 'Porta traseira',
            ),
          ],
        );
        await tester.tap(find.byKey(const ValueKey('assistant_talk')));
        await tester.pumpAndSettle();
        final sent = assistant.orders.last!.services.single;
        expect(sent.name, 'Pintura');
        expect(sent.description, 'Para-choque dianteiro');
        expect(sent.toJson()['description'], 'Para-choque dianteiro');
        expect(store.services!.single.description, 'Porta traseira');
        expect(store.services!.single.value, 300);

        await tester.tap(find.text('Desfazer'));
        await tester.pumpAndSettle();
        expect(store.services!.single.description, 'Para-choque dianteiro');
      },
    );

    testWidgets('two lines with the same name: asks which one', (tester) async {
      final store = OrderStore();
      final assistant = FakeAssistant(
        const AiOrderDraft(
          items: [
            AiDraftItem(kind: 'service', name: 'Pintura', value: 33),
            AiDraftItem(kind: 'service', name: 'Pintura', value: 400),
          ],
        ),
      );
      await _pump(tester, assistantScreen(store, assistant));
      await tester.tap(find.byKey(const ValueKey('assistant_talk')));
      await tester.pumpAndSettle();

      assistant.draft = const AiOrderDraft(
        changes: [
          AiDraftChange(
            remove: false,
            name: 'Pintura',
            candidates: [
              AiLineRef(kind: 'service', index: 0),
              AiLineRef(kind: 'service', index: 1),
            ],
            value: 300,
          ),
        ],
      );
      await tester.tap(find.byKey(const ValueKey('assistant_talk')));
      await tester.pumpAndSettle();

      expect(find.text('Qual Pintura?'), findsWidgets);
      await tester.tap(find.textContaining('400').last);
      await tester.pumpAndSettle();
      expect(store.services!.map((s) => s.value), [33, 300]);
    });

    testWidgets('customer not found: "novo" in the order, saved on ✓', (
      tester,
    ) async {
      final store = OrderStore();
      final registration = FakeRegistration();
      await _pump(
        tester,
        assistantScreen(
          store,
          FakeAssistant(
            const AiOrderDraft(
              customerGuess: 'Juliana',
              customerGuessPhone: '48222222222',
            ),
          ),
          registration: registration,
        ),
        hosted: true,
      );
      await tester.tap(find.byKey(const ValueKey('assistant_talk')));
      await tester.pumpAndSettle();

      expect(store.customer!.name, 'Juliana');
      expect(rowOf(tester, 'Juliana').subtitle, contains('novo'));
      expect(rowOf(tester, 'Juliana').marked, isTrue);
      // Nothing is registered before "✓".
      expect(registration.customers, isEmpty);

      await tester.tap(find.byKey(const ValueKey('new_order_save')));
      await tester.pumpAndSettle();
      expect(registration.customers.single.name, 'Juliana');
      expect(registration.customers.single.phone, '48222222222');
      expect(registration.customers.single.id, store.customer!.id);
    });

    testWidgets('"Desfazer" before ✓: the new customer is not registered', (
      tester,
    ) async {
      final store = OrderStore();
      final registration = FakeRegistration();
      await _pump(
        tester,
        assistantScreen(
          store,
          FakeAssistant(const AiOrderDraft(customerGuess: 'Juliana')),
          registration: registration,
        ),
      );
      await tester.tap(find.byKey(const ValueKey('assistant_talk')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Desfazer'));
      await tester.pumpAndSettle();
      expect(store.customer, isNull);
      expect(registration.customers, isEmpty);
    });

    testWidgets('close names ("Juliene"): asks which, or registers new', (
      tester,
    ) async {
      final store = OrderStore();
      final registration = FakeRegistration();
      await _pump(
        tester,
        assistantScreen(
          store,
          FakeAssistant(
            const AiOrderDraft(
              customerGuess: 'Juliene',
              customerOptions: [
                AiCustomerHit(id: 'c1', name: 'Juliana Souza'),
                AiCustomerHit(id: 'c2', name: 'Juliana Lima'),
              ],
            ),
          ),
          registration: registration,
        ),
      );
      await tester.tap(find.byKey(const ValueKey('assistant_talk')));
      await tester.pumpAndSettle();
      expect(store.customer, isNull);

      await tester.tap(find.textContaining('Juliene').first);
      await tester.pumpAndSettle();
      expect(find.text('Qual Juliene?'), findsWidgets);
      expect(find.text('Cadastrar Juliene como cliente novo'), findsOneWidget);

      await tester.tap(find.text('Juliana Lima'));
      await tester.pumpAndSettle();
      expect(store.customer!.id, 'c2');
      expect(registration.customers, isEmpty);
    });

    testWidgets('plate not registered: new vehicle saved on ✓', (tester) async {
      final store = OrderStore();
      final registration = FakeRegistration();
      await _pump(
        tester,
        assistantScreen(
          store,
          FakeAssistant(
            const AiOrderDraft(
              customer: AiCustomerHit(id: 'c9', name: 'Revenda Sul'),
              deviceGuessName: 'Corsa',
              deviceGuessSerial: 'MMM0099',
              deviceGuessManufacturer: 'Chevrolet',
            ),
          ),
          registration: registration,
        ),
        hosted: true,
      );
      await tester.tap(find.byKey(const ValueKey('assistant_talk')));
      await tester.pumpAndSettle();

      expect(store.devices.single.serial, 'MMM0099');
      expect(rowOf(tester, 'Corsa').subtitle, 'MMM0099 · novo');
      expect(registration.devices, isEmpty);

      await tester.tap(find.byKey(const ValueKey('new_order_save')));
      await tester.pumpAndSettle();
      expect(registration.devices.single.manufacturer, 'Chevrolet');
    });

    testWidgets('a model with nothing close: new vehicle saved on ✓', (
      tester,
    ) async {
      final store = OrderStore();
      final registration = FakeRegistration();
      await _pump(
        tester,
        assistantScreen(
          store,
          FakeAssistant(
            const AiOrderDraft(
              customer: AiCustomerHit(id: 'c9', name: 'Revenda Sul'),
              deviceGuessName: 'Super Classic',
            ),
          ),
          registration: registration,
        ),
        hosted: true,
      );
      await tester.tap(find.byKey(const ValueKey('assistant_talk')));
      await tester.pumpAndSettle();

      expect(store.devices.single.name, 'Super Classic');
      expect(store.devices.single.serial, isNull);
      expect(rowOf(tester, 'Super Classic').subtitle, 'novo');
      expect(registration.devices, isEmpty);

      await tester.tap(find.byKey(const ValueKey('new_order_save')));
      await tester.pumpAndSettle();
      expect(registration.devices.single.name, 'Super Classic');
    });

    testWidgets('a model close to registered ones asks, and can register', (
      tester,
    ) async {
      final store = OrderStore();
      final registration = FakeRegistration();
      await _pump(
        tester,
        assistantScreen(
          store,
          FakeAssistant(
            const AiOrderDraft(
              customer: AiCustomerHit(id: 'c9', name: 'Revenda Sul'),
              deviceGuessName: 'Super Classic',
              deviceOptions: [
                AiDeviceHit(
                  id: 'd1',
                  name: 'Chevrolet Classic 1.0',
                  serial: 'NXS8620',
                ),
              ],
            ),
          ),
          registration: registration,
        ),
        hosted: true,
      );
      await tester.tap(find.byKey(const ValueKey('assistant_talk')));
      await tester.pumpAndSettle();
      expect(store.devices, isEmpty);

      await tester.tap(find.textContaining('Super Classic').first);
      await tester.pumpAndSettle();
      expect(find.text('Chevrolet Classic 1.0'), findsOneWidget);
      await tester.tap(find.text('Cadastrar Super Classic'));
      await tester.pumpAndSettle();

      expect(store.devices.single.name, 'Super Classic');
      await tester.tap(find.byKey(const ValueKey('new_order_save')));
      await tester.pumpAndSettle();
      expect(registration.devices.single.name, 'Super Classic');
    });

    testWidgets('notes fill "O que o cliente pediu"; "Desfazer" clears', (
      tester,
    ) async {
      final store = OrderStore();
      await _pump(
        tester,
        assistantScreen(
          store,
          FakeAssistant(const AiOrderDraft(notes: 'Barulho ao frear')),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('assistant_talk')));
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('new_order_request'));
      expect(
        tester.widget<CupertinoTextField>(field).controller!.text,
        'Barulho ao frear',
      );
      expect(
        find.byKey(const ValueKey('new_order_request_marked')),
        findsOneWidget,
      );

      await tester.tap(find.text('Desfazer'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<CupertinoTextField>(field).controller!.text,
        isEmpty,
      );
      expect(
        find.byKey(const ValueKey('new_order_request_marked')),
        findsNothing,
      );
    });

    testWidgets('the deadline fills "Fica pronto"; "Desfazer" clears it', (
      tester,
    ) async {
      final store = OrderStore();
      await _pump(
        tester,
        assistantScreen(
          store,
          FakeAssistant(AiOrderDraft(dueDate: DateTime(2026, 10, 16, 18))),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('assistant_talk')));
      await tester.pumpAndSettle();
      expect(store.order!.dueDate, DateTime(2026, 10, 16, 18));
      final due = find.byKey(const ValueKey('new_order_due'));
      expect(
        find.descendant(
          of: due,
          matching: find.byIcon(CupertinoIcons.sparkles),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Desfazer'));
      await tester.pumpAndSettle();
      expect(store.order!.dueDate, isNull);
      expect(
        find.descendant(
          of: due,
          matching: find.byIcon(CupertinoIcons.sparkles),
        ),
        findsNothing,
      );
    });

    testWidgets('the last card scrolls above the note and the bar', (
      tester,
    ) async {
      await _pump(
        tester,
        assistantScreen(
          OrderStore(),
          FakeAssistant(const AiOrderDraft(notes: 'Barulho ao frear')),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('assistant_talk')));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView).first, const Offset(0, -2000));
      await tester.pumpAndSettle();
      final last = tester.getRect(find.byKey(const ValueKey('new_order_more')));
      final note = tester.getRect(find.text('Desfazer'));
      expect(last.bottom, lessThan(note.top));
    });

    testWidgets('no microphone: the bar turns into a text field', (
      tester,
    ) async {
      final assistant = FakeAssistant(draft);
      await _pump(
        tester,
        assistantScreen(
          OrderStore(),
          assistant,
          speech: FakeSpeech('', allowed: false),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('assistant_talk')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'O microfone não está liberado. Libere em Ajustes ou digite o serviço.',
        ),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('assistant_text_field')),
        'polimento',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('assistant_send')));
      await tester.pumpAndSettle();
      expect(assistant.texts, ['polimento']);
    });

    testWidgets('Foto: the photo goes to "Fotos" and the assistant reads it', (
      tester,
    ) async {
      var cameraOpened = 0;
      final assistant = FakeAssistant(draft);
      await _pump(
        tester,
        assistantScreen(
          OrderStore(),
          assistant,
          capture: () async {
            cameraOpened++;
            return AiPhoto(png);
          },
        ),
      );
      expect(cameraOpened, 0);

      await tester.tap(find.byKey(const ValueKey('assistant_photo')));
      await tester.pumpAndSettle();
      expect(cameraOpened, 0);
      await tester.tap(find.text('Tirar Foto'));
      await tester.pumpAndSettle();
      expect(cameraOpened, 1);

      // No screen in between: read right away.
      expect(assistant.photoCounts, [1]);
      expect(rowOf(tester, 'Polimento').marked, isTrue);
      expect(find.text(filledNote), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('new_order_photo_0')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const ValueKey('new_order_photo_0')), findsOneWidget);
    });

    testWidgets('quota exceeded: a note, not an alert, and manual flow stays', (
      tester,
    ) async {
      final store = OrderStore();
      final assistant = FakeAssistant(
        draft,
        error: const AiOrderAssistException(
          AiAssistError.quotaExceeded,
          used: 10,
          limit: 10,
        ),
      );
      await _pump(tester, assistantScreen(store, assistant));

      await tester.tap(find.byKey(const ValueKey('assistant_talk')));
      await tester.pumpAndSettle();

      const message =
          'Você já usou os 10 pedidos do assistente deste mês. '
          'Dá para continuar preenchendo à mão.';
      expect(find.text(message), findsOneWidget);
      expect(find.byType(CupertinoAlertDialog), findsNothing);
      expect(store.services, isEmpty);
      expect(
        find.byKey(const ValueKey('new_order_pick_customer')),
        findsOneWidget,
      );

      await tester.tap(find.text('Fechar'));
      await tester.pumpAndSettle();
      expect(find.text(message), findsNothing);
    });

    testWidgets('quota exceeded with paid plans: the note opens the plans', (
      tester,
    ) async {
      SubscriptionService.debugPaidPlansEnabledOverride = true;
      addTearDown(() => SubscriptionService.debugPaidPlansEnabledOverride = null);
      final events = <String, Map<String, Object>>{};
      AnalyticsService.debugAiEventSink = (name, parameters) =>
          events[name] = parameters;
      addTearDown(() => AnalyticsService.debugAiEventSink = null);
      final assistant = FakeAssistant(
        draft,
        error: const AiOrderAssistException(
          AiAssistError.quotaExceeded,
          used: 10,
          limit: 10,
        ),
      );
      await _pump(tester, assistantScreen(OrderStore(), assistant));

      await tester.tap(find.byKey(const ValueKey('assistant_talk')));
      await tester.pumpAndSettle();

      expect(find.text('Ver planos'), findsOneWidget);
      expect(find.text('Fechar'), findsNothing);
      expect(events['ai_assist_requested'], {'input': 'text'});
      expect(events['ai_assist_result'], {'result': 'quota'});
      expect(events['upgrade_modal_shown'], {'trigger': 'ai_limit_100'});
    });

    testWidgets('from 80% of the month the note says what is left', (
      tester,
    ) async {
      final nearLimit = FakeAssistant(
        AiOrderDraft(items: draft.items, used: 8, limit: 10),
      );
      await _pump(tester, assistantScreen(OrderStore(), nearLimit));

      await tester.tap(find.byKey(const ValueKey('assistant_talk')));
      await tester.pumpAndSettle();

      expect(
        find.text('$filledNote Restam 2 usos do assistente este mês.'),
        findsOneWidget,
      );
    });

    testWidgets('below 80% the note says nothing about the limit', (
      tester,
    ) async {
      await _pump(tester, assistantScreen(OrderStore(), FakeAssistant(draft)));

      await tester.tap(find.byKey(const ValueKey('assistant_talk')));
      await tester.pumpAndSettle();

      expect(find.text(filledNote), findsOneWidget);
    });

    testWidgets('filled draft and undo reach the adoption funnel', (
      tester,
    ) async {
      final names = <String>[];
      final results = <Object?>[];
      AnalyticsService.debugAiEventSink = (name, parameters) {
        names.add(name);
        results.add(parameters['result']);
      };
      addTearDown(() => AnalyticsService.debugAiEventSink = null);
      await _pump(tester, assistantScreen(OrderStore(), FakeAssistant(draft)));

      await tester.tap(find.byKey(const ValueKey('assistant_talk')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Desfazer'));
      await tester.pumpAndSettle();

      expect(names, [
        'ai_assist_requested',
        'ai_assist_result',
        'ai_assist_undone',
      ]);
      expect(results[1], 'filled');
    });

    testWidgets('opened from the first-use sheet it starts listening', (
      tester,
    ) async {
      final speech = FakeSpeech('Revenda Sul, troca de óleo');
      final assistant = FakeAssistant(draft);
      await _pump(
        tester,
        assistantScreen(OrderStore(), assistant, speech: speech),
        args: const {'startTalking': true},
      );
      await tester.pumpAndSettle();

      expect(assistant.texts, ['Revenda Sul, troca de óleo']);
    });
  });

  group('"O que vai na OS?"', () {
    testWidgets('one search over services and products; tapping adds', (
      tester,
    ) async {
      final store = OrderStore();
      await _pump(tester, screen(store));

      await tester.tap(find.byKey(const ValueKey('new_order_add_item')));
      await tester.pumpAndSettle();
      expect(find.text('Troca de óleo'), findsOneWidget);
      expect(find.text('Filtro de óleo'), findsOneWidget);
      expect(find.text('serviço'), findsNWidgets(2));
      expect(find.text('produto'), findsOneWidget);

      await tester.enterText(find.byType(CupertinoSearchTextField), 'oleo');
      await tester.pumpAndSettle();
      expect(find.text('Alinhamento'), findsNothing);
      await tester.tap(find.text('Filtro de óleo'));
      await tester.pumpAndSettle();

      expect(store.products!.single.product!.name, 'Filtro de óleo');
      expect(store.products!.single.quantity, 1);
      expect(find.text('Filtro de óleo'), findsOneWidget);
      expect(find.text(_money(35.5)), findsNWidgets(2)); // row + total
    });

    testWidgets('"Cadastrar “X”" creates without price and adds', (
      tester,
    ) async {
      final catalog = FakeSource(services: [_item('s1', 'Troca de óleo', 120)]);
      final store = OrderStore();
      await _pump(tester, screen(store, catalog: catalog));

      await tester.tap(find.byKey(const ValueKey('new_order_add_item')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(CupertinoSearchTextField),
        'Troca de embreagem',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cadastrar “Troca de embreagem”'));
      await tester.pumpAndSettle();

      expect(catalog.saved.single.$1, CatalogKind.service);
      expect(catalog.saved.single.$2.name, 'Troca de embreagem');
      expect(catalog.saved.single.$2.value, isNull);
      expect(store.services!.single.value, isNull);
      expect(find.text('Troca de embreagem'), findsOneWidget);
      expect(find.text('sem valor'), findsOneWidget);
      expect(find.text('1 item sem valor, fora do total'), findsOneWidget);
    });

    testWidgets('no create row without manageServices/manageProducts', (
      tester,
    ) async {
      await _pump(
        tester,
        screen(
          OrderStore(),
          catalogPermissions: CatalogPermissions(
            {PermissionType.viewServices, PermissionType.viewProducts}.contains,
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('new_order_add_item')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(CupertinoSearchTextField), 'Nova');
      await tester.pumpAndSettle();
      expect(find.textContaining('Cadastrar “Nova”'), findsNothing);
    });

    testWidgets('"Mais usados" comes first, from the last orders', (
      tester,
    ) async {
      await _pump(
        tester,
        OrderScreenV2(
          showAssistant: false,
          store: OrderStore(),
          permissions: _permissions(),
          actions: FakeActions(),
          catalogSource: source,
          catalogPermissions: _allCatalog,
          mostUsed: () async => const ['product:p1'],
        ),
      );
      await tester.tap(find.byKey(const ValueKey('new_order_add_item')));
      await tester.pumpAndSettle();
      expect(find.text('Mais usados'), findsOneWidget);
      expect(find.text('Filtro de óleo'), findsNWidgets(2));
      final top = tester.getTopLeft(find.text('Filtro de óleo').first);
      expect(top.dy, lessThan(tester.getTopLeft(find.text('Alinhamento')).dy));
    });

    testWidgets('an item without price gets one in its sheet', (tester) async {
      final store = OrderStore();
      await _pump(tester, screen(store));
      await tester.tap(find.byKey(const ValueKey('new_order_add_item')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alinhamento'));
      await tester.pumpAndSettle();
      expect(find.text('sem valor'), findsOneWidget);

      await tester.tap(find.text('Alinhamento'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(CupertinoTextField).last, '8000');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(store.services!.single.value, 80);
      expect(find.text('sem valor'), findsNothing);
      expect(store.total, 80);
    });

    testWidgets('"Tirar da OS" removes the item', (tester) async {
      final store = OrderStore();
      await _pump(tester, screen(store));
      await tester.tap(find.byKey(const ValueKey('new_order_add_item')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Troca de óleo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Troca de óleo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tirar da OS'));
      await tester.pumpAndSettle();
      expect(store.services, isEmpty);
      expect(find.text('Troca de óleo'), findsNothing);
    });

    testWidgets('the item sheet writes the description of the line', (
      tester,
    ) async {
      final store = OrderStore();
      await _pump(tester, screen(store));
      await tester.tap(find.byKey(const ValueKey('new_order_add_item')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alinhamento'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Alinhamento'));
      await tester.pumpAndSettle();
      expect(find.text('Descrição'), findsOneWidget);
      final description = find.descendant(
        of: find.widgetWithText(AppFormField, 'Descrição'),
        matching: find.byType(CupertinoTextField),
      );
      await tester.enterText(description, 'Eixo dianteiro');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(store.services!.single.description, 'Eixo dianteiro');
      expect(find.textContaining('Eixo dianteiro'), findsOneWidget);

      // Opens again with what was written; blank takes it out.
      await tester.tap(find.text('Alinhamento'));
      await tester.pumpAndSettle();
      expect(find.text('Eixo dianteiro'), findsWidgets);
      await tester.enterText(description, '');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      expect(store.services!.single.description, isNull);
    });

    testWidgets('exact name match hides the create row', (tester) async {
      await _pump(tester, screen(OrderStore()));
      await tester.tap(find.byKey(const ValueKey('new_order_add_item')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(CupertinoSearchTextField),
        'alinhamento',
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Cadastrar “'), findsNothing);
      expect(find.text('Alinhamento'), findsOneWidget);
    });
  });

  group('existing order', () {
    Order order() => Order()
      ..id = 'o1'
      ..number = 186
      ..status = 'quote'
      ..customer = (CustomerAggr()
        ..id = 'c1'
        ..name = 'Ana Souza')
      ..services = [
        OrderService()
          ..service = (ServiceAggr()..name = 'Polimento')
          ..value = 450,
        OrderService()..service = (ServiceAggr()..name = 'Porta traseira'),
      ]
      ..products = [
        OrderProduct()
          ..product = (ProductAggr()..name = 'Cera')
          ..value = 25
          ..quantity = 2
          ..total = 50,
        OrderProduct()
          ..product = (ProductAggr()..name = 'Lixa')
          ..quantity = 1,
      ]
      ..discount = 0
      ..paidAmount = 0
      ..transactions = [];

    testWidgets('a rated order shows the stars, "4 de 5" and the comment', (
      tester,
    ) async {
      await _pump(
        tester,
        screen(OrderStore()),
        args: {
          'order': order()
            ..status = 'done'
            ..rating = (OrderRating()
              ..score = 4
              ..comment = 'Atendimento rápido'),
        },
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('order_rating')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Avaliação'), findsOneWidget);
      expect(find.text('4 de 5'), findsOneWidget);
      expect(find.text('Atendimento rápido'), findsOneWidget);
    });

    testWidgets('an order without rating has no "Avaliação"', (tester) async {
      await _pump(tester, screen(OrderStore()), args: {'order': order()});
      expect(find.byKey(const ValueKey('order_rating')), findsNothing);
    });

    testWidgets('items without price show "sem valor" and are not summed', (
      tester,
    ) async {
      final store = OrderStore();
      await _pump(tester, screen(store), args: {'order': order()});

      expect(find.text('sem valor'), findsNWidgets(2));
      expect(find.text('2 itens sem valor, fora do total'), findsOneWidget);
      expect(find.text(_money(500)), findsOneWidget); // 450 + 2 × 25
      expect(store.total, 500);
    });

    testWidgets('without viewPrices no price, total or "sem valor"', (
      tester,
    ) async {
      await _pump(
        tester,
        screen(OrderStore(), prices: false),
        args: {'order': order()},
      );
      expect(find.text('sem valor'), findsNothing);
      expect(find.text('Total'), findsNothing);
      expect(find.text('Polimento'), findsOneWidget);
    });

    testWidgets('without values and billing a done order has no "Receber" nor '
        '"Falta receber"', (tester) async {
      final actions = FakeActions();
      await _pump(
        tester,
        screen(OrderStore(), actions: actions, prices: false),
        args: {'order': order()..status = 'done'},
      );
      expect(find.textContaining('Receber'), findsNothing);
      expect(find.textContaining('Falta receber'), findsNothing);
      expect(find.text(_money(500)), findsNothing);
    });

    testWidgets('next step by status is the only blue button', (tester) async {
      Future<void> check(String status, String? label) async {
        await tester.pumpWidget(const SizedBox());
        await _pump(
          tester,
          screen(OrderStore()),
          args: {'order': order()..status = status},
        );
        final buttons = find.byKey(const ValueKey('order_primary_button'));
        if (label == null) {
          expect(buttons, findsNothing, reason: status);
        } else {
          expect(buttons, findsOneWidget, reason: status);
          expect(
            find.descendant(of: buttons, matching: find.text(label)),
            findsOneWidget,
            reason: status,
          );
        }
      }

      await check('quote', 'Aprovar orçamento');
      await check('approved', 'Começar serviço');
      await check('progress', 'Marcar como pronta');
      await check('done', 'Receber ${_money(500)}');
      await check('canceled', null);
      expect(find.textContaining('Salvar'), findsNothing);
    });

    testWidgets('done and paid: no blue button', (tester) async {
      await _pump(
        tester,
        screen(OrderStore()),
        args: {
          'order': order()
            ..status = 'done'
            ..paidAmount = 500,
        },
      );
      expect(find.byKey(const ValueKey('order_primary_button')), findsNothing);
    });

    testWidgets('small "OS N" title, customer in the header, status as dot '
        'and text', (tester) async {
      await _pump(tester, screen(OrderStore()), args: {'order': order()});

      expect(
        find.descendant(
          of: find.byType(CupertinoNavigationBar),
          matching: find.text('OS 186'),
        ),
        findsOneWidget,
      );
      expect(find.byType(CupertinoSliverNavigationBar), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('order_header_customer')),
          matching: find.text('Ana Souza'),
          matchRoot: true,
        ),
        findsOneWidget,
      );
      final status = find.byKey(const ValueKey('order_header_status'));
      expect(
        find.descendant(of: status, matching: find.byType(StatusDot)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: status, matching: find.text('Orçamento')),
        findsOneWidget,
      );
      // Share and "…" in the top bar.
      expect(find.byIcon(CupertinoIcons.share), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.ellipsis), findsOneWidget);
      // Total closes the list of items.
      expect(
        tester.getTopLeft(find.text('Total')).dy,
        greaterThan(tester.getTopLeft(find.text('Lixa')).dy),
      );
    });

    testWidgets('tapping the customer opens "Qual cliente?" directly', (
      tester,
    ) async {
      await _pump(tester, screen(OrderStore()), args: {'order': order()});
      await tester.tap(find.byKey(const ValueKey('order_header_customer')));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoActionSheet), findsNothing);
      expect(find.text('pick ABC1D23'), findsOneWidget);
    });

    testWidgets('items: services and parts, "peça" only under products', (
      tester,
    ) async {
      await _pump(tester, screen(OrderStore()), args: {'order': order()});
      expect(find.text('Serviços e peças'), findsOneWidget);
      expect(find.textContaining(RegExp('^peça')), findsNWidgets(2));
      expect(find.byKey(const ValueKey('order_add_item')), findsOneWidget);
    });

    testWidgets('empty sections do not show', (tester) async {
      await _pump(tester, screen(OrderStore()), args: {'order': order()});
      expect(find.text('O que o cliente pediu'), findsNothing);
      expect(find.text('Fotos'), findsNothing);
      expect(find.text('Comentários'), findsNothing);
      expect(find.text('Checklists'), findsNothing);
      expect(find.text('Detalhes'), findsNothing);
      // The old "what goes in the OS" row is gone from the screen.
      expect(find.text('O que vai na OS?'), findsNothing);
      // No due date: no phrase.
      expect(find.byKey(const ValueKey('order_header_phrase')), findsNothing);
    });

    testWidgets('"Falta receber" only with values and billing', (tester) async {
      await _pump(
        tester,
        screen(OrderStore()),
        args: {'order': order()..status = 'approved'},
      );
      expect(find.byKey(const ValueKey('order_remaining')), findsOneWidget);
      expect(find.text('Falta receber'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await _pump(
        tester,
        screen(OrderStore(), prices: false),
        args: {'order': order()..status = 'approved'},
      );
      expect(find.byKey(const ValueKey('order_remaining')), findsNothing);
      expect(find.textContaining('Falta receber'), findsNothing);
    });

    testWidgets('done with balance: phrase and "Receber" open payments', (
      tester,
    ) async {
      final actions = FakeActions();
      await _pump(
        tester,
        screen(OrderStore(), actions: actions),
        args: {'order': order()..status = 'done'},
      );
      expect(find.text('Falta receber ${_money(500)}'), findsOneWidget);
      await tester.tap(find.text('Receber ${_money(500)}'));
      await tester.pumpAndSettle();
      expect(actions.calls, ['payments']);
    });

    testWidgets('consultant on someone else\'s order sees what is left '
        'but has no "Receber"', (tester) async {
      final actions = FakeActions();
      await _pump(
        tester,
        screen(OrderStore(), actions: actions, receive: false),
        args: {'order': order()..status = 'done'},
      );
      // Values still show.
      expect(find.text('Falta receber ${_money(500)}'), findsOneWidget);
      expect(find.text('Falta receber'), findsOneWidget);
      // No blue "Receber" button: done with balance has no next step.
      expect(find.byKey(const ValueKey('order_primary_button')), findsNothing);
      expect(find.text('Receber ${_money(500)}'), findsNothing);
      // Neither the phrase nor the remaining row open the payments.
      await tester.tap(find.text('Falta receber ${_money(500)}'));
      await tester.ensureVisible(find.text('Falta receber'));
      await tester.tap(find.text('Falta receber'));
      await tester.pumpAndSettle();
      expect(actions.calls, isEmpty);
      expect(find.byKey(const ValueKey('order_remaining')), findsNothing);
    });

    // The real rule ([AuthorizationService.canReceiveOnOrderFor]) for a
    // consultant whose uid is 'me'.
    bool consultantReceives(Order? o) =>
        AuthorizationService.canReceiveOnOrderFor(
          role: RolesType.consultant,
          userId: 'me',
          order: o,
        );

    testWidgets('consultant gets "Receber" on an order they created', (
      tester,
    ) async {
      final actions = FakeActions();
      await _pump(
        tester,
        screen(OrderStore(), actions: actions, receiveOn: consultantReceives),
        args: {
          'order': order()
            ..status = 'done'
            ..createdBy = (UserAggr()..id = 'me'),
        },
      );
      expect(find.text('Receber ${_money(500)}'), findsOneWidget);
      await tester.tap(find.text('Receber ${_money(500)}'));
      await tester.pumpAndSettle();
      expect(actions.calls, ['payments']);
    });

    testWidgets('consultant gets no "Receber" on an order of someone else', (
      tester,
    ) async {
      await _pump(
        tester,
        screen(OrderStore(), receiveOn: consultantReceives),
        args: {
          'order': order()
            ..status = 'done'
            ..createdBy = (UserAggr()..id = 'other'),
        },
      );
      expect(find.text('Falta receber ${_money(500)}'), findsOneWidget);
      expect(find.text('Receber ${_money(500)}'), findsNothing);
    });

    testWidgets('supervisor never gets "Receber", even on their own order', (
      tester,
    ) async {
      await _pump(
        tester,
        screen(
          OrderStore(),
          prices: false,
          receiveOn: (o) => AuthorizationService.canReceiveOnOrderFor(
            role: RolesType.supervisor,
            userId: 'me',
            order: o,
          ),
        ),
        args: {
          'order': order()
            ..status = 'done'
            ..createdBy = (UserAggr()..id = 'me'),
        },
      );
      expect(find.textContaining('Receber'), findsNothing);
      expect(find.byKey(const ValueKey('order_primary_button')), findsNothing);
    });

    testWidgets('consultant still gets the status next steps', (tester) async {
      await _pump(
        tester,
        screen(OrderStore(), receive: false),
        args: {'order': order()..status = 'progress'},
      );
      final buttons = find.byKey(const ValueKey('order_primary_button'));
      expect(buttons, findsOneWidget);
      expect(
        find.descendant(of: buttons, matching: find.text('Marcar como pronta')),
        findsOneWidget,
      );
    });

    testWidgets('manager (financial access) gets "Receber" and the remaining '
        'row opens payments', (tester) async {
      final actions = FakeActions();
      await _pump(
        tester,
        screen(OrderStore(), actions: actions),
        args: {'order': order()..status = 'done'},
      );
      expect(find.text('Receber ${_money(500)}'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('order_remaining')));
      await tester.tap(find.byKey(const ValueKey('order_remaining')));
      await tester.pumpAndSettle();
      expect(actions.calls, ['payments']);
    });

    testWidgets('"+ Adicionar serviço ou peça" opens the item picker', (
      tester,
    ) async {
      await _pump(tester, screen(OrderStore()), args: {'order': order()});
      await tester.ensureVisible(find.byKey(const ValueKey('order_add_item')));
      await tester.tap(find.byKey(const ValueKey('order_add_item')));
      await tester.pumpAndSettle();
      expect(find.text('Troca de óleo'), findsOneWidget);
    });

    testWidgets('"…": status, "Adicionar à OS", PDF · link, cancel / delete', (
      tester,
    ) async {
      await _pump(tester, screen(OrderStore()), args: {'order': order()});
      await tester.tap(find.byIcon(CupertinoIcons.ellipsis));
      await tester.pumpAndSettle();

      final labels = _menuLabels(tester);
      expect(labels.first, 'Mudar a situação');
      expect(find.text('Adicionar à OS'), findsOneWidget); // group title
      expect(labels, containsAll(['Ver PDF', 'Cancelar OS', 'Apagar OS']));
      expect(labels.sublist(labels.length - 2), ['Cancelar OS', 'Apagar OS']);
      // Unsaved company: no comment / link.
      expect(labels, isNot(contains('Comentário')));
    });

    testWidgets('"Mudar a situação" lists the current one with a ✓', (
      tester,
    ) async {
      await _pump(tester, screen(OrderStore()), args: {'order': order()});
      await tester.tap(find.byIcon(CupertinoIcons.ellipsis));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mudar a situação'));
      await tester.pumpAndSettle();

      expect(find.text('Qual a situação?'), findsOneWidget);
      final current = find.ancestor(
        of: find.text('Orçamento'),
        matching: find.byType(AppListRow),
      );
      expect(current, findsOneWidget);
      expect(tester.widget<AppListRow>(current).selected, isTrue);
    });
  });

  group('segment custom fields', () {
    const brand = CustomField(
      key: 'service_order.brand',
      type: 'text',
      labels: {'pt-BR': 'Marca do lacre'},
      section: 'Lacre',
      sectionI18n: {'pt-BR': 'Lacre'},
    );
    const builtIn = CustomField(
      key: 'service_order.status',
      type: 'text',
      labels: {'pt-BR': 'Status custom'},
    );

    setUp(
      () => SegmentConfigService().debugSetCustomFields(const [brand, builtIn]),
    );
    tearDown(() => SegmentConfigService().debugSetCustomFields(const []));

    Order saved() => Order()
      ..id = 'o1'
      ..number = 7
      ..status = 'quote'
      ..customer = (CustomerAggr()
        ..id = 'c1'
        ..name = 'Ana Souza')
      ..customData = {'brand': 'ABC-123'}
      ..services = []
      ..products = []
      ..discount = 0
      ..paidAmount = 0
      ..transactions = [];

    testWidgets('new order: "O que o cliente pediu" is the segment\'s '
        '"Observação" (one field, not two)', (tester) async {
      const observation = CustomField(
        key: 'service_order.observation',
        type: 'textarea',
        labels: {'pt-BR': 'Observação'},
        section: 'Detalhes',
        sectionI18n: {'pt-BR': 'Detalhes'},
      );
      SegmentConfigService().debugSetCustomFields(const [observation]);
      final store = OrderStore();
      await _pump(tester, screen(store), hosted: true);
      expect(find.text('Detalhes'), findsNothing);
      expect(find.text('Observação'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('new_order_pick_customer')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('pick ABC1D23'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('new_order_request')),
        'Barulho ao frear',
      );
      await tester.tap(find.byKey(const ValueKey('new_order_save')));
      await tester.pumpAndSettle();
      expect(store.order!.customData, {'observation': 'Barulho ao frear'});
    });

    testWidgets('shows the segment fields with the saved value; built-ins '
        'are not duplicated', (tester) async {
      await _pump(tester, screen(OrderStore()), args: {'order': saved()});
      expect(find.text('Marca do lacre'), findsOneWidget);
      expect(find.text('ABC-123'), findsOneWidget);
      expect(find.text('Status custom'), findsNothing);
    });

    testWidgets('editing saves into order.customData; clearing removes it', (
      tester,
    ) async {
      final store = OrderStore();
      await _pump(tester, screen(store), args: {'order': saved()});

      await tester.enterText(find.byType(EditableText).first, 'XYZ-9');
      await tester.pump();
      expect(store.order!.customData, {'brand': 'XYZ-9'});

      await tester.enterText(find.byType(EditableText).first, '');
      await tester.pump();
      expect(store.order!.customData, isNull);
    });

    testWidgets('no fields configured, no section', (tester) async {
      SegmentConfigService().debugSetCustomFields(const []);
      await _pump(tester, screen(OrderStore()), args: {'order': saved()});
      expect(find.text('Marca do lacre'), findsNothing);
      expect(find.byType(EditableText), findsNothing);
    });
  });

  group('two or more vehicles', () {
    Order twoCars() => Order()
      ..id = 'o2'
      ..number = 9
      ..status = 'quote'
      ..customer = (CustomerAggr()
        ..id = 'c1'
        ..name = 'Ana Souza')
      ..devices = [
        DeviceAggr()
          ..id = 'd1'
          ..name = 'Gol'
          ..serial = 'AAA1A11',
        DeviceAggr()
          ..id = 'd2'
          ..name = 'Uno',
      ]
      ..services = [
        OrderService()
          ..service = (ServiceAggr()..name = 'Polimento')
          ..value = 100
          ..deviceId = 'd1',
        OrderService()
          ..service = (ServiceAggr()..name = 'Revisão')
          ..value = 300
          ..deviceId = 'd2',
        OrderService()
          ..service = (ServiceAggr()..name = 'Taxa de busca')
          ..value = 20,
      ]
      ..products = [
        OrderProduct()
          ..product = (ProductAggr()..name = 'Cera')
          ..value = 25
          ..quantity = 2
          ..total = 50
          ..deviceId = 'd1',
      ]
      ..discount = 0
      ..paidAmount = 0
      ..transactions = [];

    testWidgets('tapping a vehicle opens the picker directly', (tester) async {
      await _pump(tester, screen(OrderStore()), args: {'order': twoCars()});
      await tester.tap(find.byKey(const ValueKey('order_header_device_d2')));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoActionSheet), findsNothing);
      expect(find.text('remove device'), findsOneWidget);
    });

    testWidgets('"Tirar … da OS" lives in the vehicle picker, not in "…"', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = OrderStore();
      await _pump(tester, screen(store), args: {'order': twoCars()});
      await tester.tap(find.byIcon(CupertinoIcons.ellipsis));
      await tester.pumpAndSettle();
      expect(find.textContaining('da OS'), findsNothing);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('order_header_device_d2')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('remove device'));
      await tester.pumpAndSettle();
      expect(store.devices.map((d) => d.id), ['d1']);
    });

    testWidgets('items are grouped per vehicle with a subtotal each', (
      tester,
    ) async {
      await _pump(tester, screen(OrderStore()), args: {'order': twoCars()});

      expect(find.text('Gol - AAA1A11'), findsWidgets);
      expect(find.text('Geral'), findsOneWidget);
      expect(find.text('Subtotal'), findsNWidgets(3));
      expect(find.text(_money(150)), findsOneWidget); // Gol: 100 + 2 × 25
      expect(find.text(_money(300)), findsNWidgets(2)); // Uno + its row
      expect(find.text(_money(20)), findsNWidgets(2)); // Geral + its row
      expect(find.text(_money(470)), findsOneWidget); // Total
      // Order of the blocks: Gol, Uno, Geral.
      final gol = tester.getTopLeft(find.text('Polimento')).dy;
      final uno = tester.getTopLeft(find.text('Revisão')).dy;
      final general = tester.getTopLeft(find.text('Taxa de busca')).dy;
      expect(gol, lessThan(uno));
      expect(uno, lessThan(general));
    });

    testWidgets('without viewPrices no subtotals', (tester) async {
      await _pump(
        tester,
        screen(OrderStore(), prices: false),
        args: {'order': twoCars()},
      );
      expect(find.text('Subtotal'), findsNothing);
      expect(find.text('Revisão'), findsOneWidget);
    });

    testWidgets('one vehicle keeps the flat list', (tester) async {
      final order = twoCars()..devices = [twoCars().devices!.first];
      await _pump(tester, screen(OrderStore()), args: {'order': order});
      expect(find.text('Subtotal'), findsNothing);
      expect(find.text('Geral'), findsNothing);
    });

    testWidgets('adding an item asks which vehicle and files it there', (
      tester,
    ) async {
      final store = OrderStore();
      await _pump(
        tester,
        OrderScreenV2(
          showAssistant: false,
          store: store,
          permissions: _permissions(),
          actions: FakeActions(),
          catalogSource: source,
          catalogPermissions: _allCatalog,
          mostUsed: () async => const [],
          devicePicker: (_, devices) async =>
              DevicePickerResult(DevicePickerAction.specific, devices.last),
        ),
        args: {'order': twoCars()},
      );

      await tester.ensureVisible(find.byKey(const ValueKey('order_add_item')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('order_add_item')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alinhamento'));
      await tester.pumpAndSettle();

      final added = store.services!.last;
      expect(added.service!.name, 'Alinhamento');
      expect(added.deviceId, 'd2');
      expect(store.pendingDeviceId, isNull);
    });

    testWidgets('cancelling the vehicle question adds nothing', (tester) async {
      final store = OrderStore();
      await _pump(
        tester,
        OrderScreenV2(
          showAssistant: false,
          store: store,
          permissions: _permissions(),
          actions: FakeActions(),
          catalogSource: source,
          catalogPermissions: _allCatalog,
          mostUsed: () async => const [],
          devicePicker: (_, _) async => null,
        ),
        args: {'order': twoCars()},
      );
      await tester.ensureVisible(find.byKey(const ValueKey('order_add_item')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('order_add_item')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alinhamento'));
      await tester.pumpAndSettle();
      expect(store.services, hasLength(3));
    });

    test('applyDevicePick maps each answer to the store', () {
      final store = OrderStore();
      applyDevicePick(store, DevicePickerResult.multi(['d1', 'd2']));
      expect(store.pendingDeviceIds, ['d1', 'd2']);
      applyDevicePick(store, DevicePickerResult(DevicePickerAction.all));
      expect(store.pendingDuplicateAll, isTrue);
      expect(store.pendingDeviceIds, isNull);
      applyDevicePick(store, DevicePickerResult(DevicePickerAction.general));
      expect(store.pendingDuplicateAll, isFalse);
      expect(store.pendingDeviceId, isNull);
    });
  });
}
