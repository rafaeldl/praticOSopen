import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart';
import 'package:praticos/global.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/models/form_definition.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/order_comment.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/models/order_document.dart';
import 'package:praticos/models/order_form.dart' as of_model;
import 'package:praticos/models/order_photo.dart';
import 'package:praticos/models/service.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/screens/order/order_screen_services.dart';
import 'package:praticos/screens/order/order_screen_v2.dart';
import 'package:praticos/screens/widgets/status_dot.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/theme/status_style.dart';
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

/// Records what the screen asked for instead of leaving it.
class FakeActions extends OrderScreenActions {
  final List<String> calls = [];

  @override
  Future<void> openPayments(BuildContext context, OrderStore store) async =>
      calls.add('payments');

  @override
  Future<void> shareWithCustomer(BuildContext context, Order order) async =>
      calls.add('send');

  @override
  Future<void> addMedia(BuildContext context, OrderStore store) async =>
      calls.add('media');

  @override
  Future<List<UserAggr>> teamMembers() async => [
    UserAggr()
      ..id = 'u1'
      ..name = 'Rafa Técnico',
  ];

  @override
  Future<void> viewPhoto(
    BuildContext context,
    OrderStore store,
    int index,
    SegmentConfigProvider config,
  ) async => calls.add('photo:$index');

  @override
  Widget photoThumb(String url, double size, BorderRadius radius) =>
      SizedBox(width: size, height: size, child: Text('thumb $url'));

  @override
  Future<void> openDocument(BuildContext context, OrderDocument doc) async =>
      calls.add('doc:${doc.fileName}');

  @override
  Future<void> addChecklist(BuildContext context, OrderStore store) async =>
      calls.add('addChecklist');

  @override
  Future<void> openChecklist(
    BuildContext context,
    OrderStore store,
    of_model.OrderForm form,
  ) async => calls.add('checklist:${form.id}');

  @override
  Future<void> deleteChecklist(
    OrderStore store,
    of_model.OrderForm form,
  ) async => calls.add('deleteChecklist:${form.id}');

  List<OrderComment> commentList = const [];

  @override
  Stream<List<OrderComment>> watchComments(Order order) =>
      Stream.value(commentList);

  @override
  Future<void> openComments(
    BuildContext context,
    Order order, {
    String? highlightCommentId,
  }) async => calls.add('comments:${order.id}:${highlightCommentId ?? ''}');

  @override
  Future<void> notifyCustomer(
    BuildContext context,
    Order order,
    String status,
  ) async => calls.add('notify:$status');

  @override
  Future<void> openInMaps(OrderStore store) async => calls.add('maps');

  @override
  Future<double?> askDiscount(
    BuildContext context, {
    required double currentTotal,
    required double maxDiscount,
  }) async {
    calls.add('discount:$currentTotal/$maxDiscount');
    return null;
  }

  @override
  Future<void> editContract(BuildContext context, OrderStore store) async =>
      calls.add('editContract');

  @override
  Future<void> openOrder(BuildContext context, Order order) async =>
      calls.add('order:${order.id}');
}

String _money(double v) => (FormatService()..setLocale('pt')).formatCurrency(v);

OrderPermissions _permissions({bool edit = true, bool prices = true}) =>
    OrderPermissions(
      canViewPrices: () => prices,
      availableStatuses: (_) => const ['approved', 'progress', 'done'],
      canChangeStatus: (_, _) => true,
      canDelete: (_) => true,
      canEditMainFields: (_) => edit,
      canManageForms: (_) => edit,
      canAttachMedia: () => edit,
    );

Future<SegmentConfigProvider> _pump(
  WidgetTester tester,
  Widget screen, {
  Map<String, dynamic>? args,
  bool fieldService = true,
  bool useScheduling = true,
  bool useContracts = true,
}) async {
  final config = SegmentConfigProvider()
    ..injectL10n(lookupAppLocalizations(const Locale('pt')))
    ..setCompanyConfig(
      fieldService: fieldService,
      useScheduling: useScheduling,
      useDeviceManagement: false,
      useContracts: useContracts,
    );
  // A tall phone, so every block of the order fits without scrolling.
  tester.view.physicalSize = const Size(1170, 6000);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider<SegmentConfigProvider>.value(
      value: config,
      child: CupertinoApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        onGenerateRoute: (settings) => CupertinoPageRoute(
          settings: RouteSettings(name: '/', arguments: args),
          builder: (_) => screen,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return config;
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

/// Opens the "…" menu (its "Adicionar à OS" group holds the extras).
Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(find.byIcon(CupertinoIcons.ellipsis));
  await tester.pumpAndSettle();
}

Order _order({String status = 'quote', String? phone}) => Order()
  ..id = 'o1'
  ..number = 186
  ..status = status
  ..company = (CompanyAggr()..id = 'co1')
  ..customer = (CustomerAggr()
    ..id = 'c1'
    ..name = 'Ana Souza'
    ..phone = phone)
  ..services = [
    OrderService()
      ..service = (ServiceAggr()..name = 'Polimento')
      ..value = 500,
  ]
  ..products = []
  ..discount = 0
  ..paidAmount = 0
  ..transactions = [];

of_model.OrderForm _form(String id, {int items = 3, int answered = 1}) =>
    of_model.OrderForm(
      id: id,
      formDefinitionId: 'def-$id',
      title: 'Entrada do veículo',
      status: answered >= items
          ? of_model.FormStatus.completed
          : of_model.FormStatus.inProgress,
      items: [
        for (var i = 0; i < items; i++)
          FormItemDefinition(
            id: 'q$i',
            label: 'Pergunta $i',
            type: FormItemType.text,
          ),
      ],
      responses: [
        for (var i = 0; i < answered; i++)
          of_model.FormResponse(itemId: 'q$i', value: 'ok'),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestFirebaseCoreHostApi.setUp(_FirebaseCoreMockWithBucket());
    await Firebase.initializeApp();
  });

  // No company: OrderStore.createItem never reaches Firestore in tests.
  setUp(() => Global.companyAggr = null);

  OrderScreenV2 screen(
    OrderStore store, {
    FakeActions? actions,
    bool edit = true,
    bool prices = true,
  }) => OrderScreenV2(
    store: store,
    permissions: _permissions(edit: edit, prices: prices),
    actions: actions ?? FakeActions(),
    mostUsed: () async => const [],
  );

  group('"…" > "Adicionar à OS"', () {
    testWidgets('lists only what the order does not have yet', (tester) async {
      await _pump(tester, screen(OrderStore()), args: {'order': _order()});
      await _openMenu(tester);

      expect(_menuLabels(tester), [
        'Mudar a situação',
        'Comentário',
        'Checklist',
        'Responsável',
        'Local do atendimento',
        'Documento',
        'Repetir todo mês (contrato)',
        'Data de entrega',
        'Agendar dia e hora',
        'Outro equipamento',
        'Ver PDF',
        'Copiar link',
        'Cancelar OS',
        'Apagar OS',
      ]);
      expect(find.text('Adicionar à OS'), findsOneWidget); // group title
      // Discount only after approval; no escape to the legacy screen.
      expect(find.text('Desconto'), findsNothing);
      expect(find.text('Outros campos'), findsNothing);
    });

    testWidgets('without field service, scheduling or contracts they hide', (
      tester,
    ) async {
      await _pump(
        tester,
        screen(OrderStore()),
        args: {'order': _order()},
        fieldService: false,
        useScheduling: false,
        useContracts: false,
      );
      await _openMenu(tester);

      final labels = _menuLabels(tester);
      expect(labels, isNot(contains('Local do atendimento')));
      expect(labels, isNot(contains('Agendar dia e hora')));
      expect(labels, isNot(contains('Repetir todo mês (contrato)')));
    });

    testWidgets('without permission only comment is left', (tester) async {
      await _pump(
        tester,
        screen(OrderStore(), edit: false),
        args: {'order': _order()},
      );
      await _openMenu(tester);
      final labels = _menuLabels(tester);
      expect(labels, contains('Comentário'));
      for (final hidden in [
        'Checklist',
        'Responsável',
        'Local do atendimento',
        'Documento',
        'Repetir todo mês (contrato)',
      ]) {
        expect(labels, isNot(contains(hidden)));
      }
    });

    testWidgets('no "Outros campos" escape even with 2 vehicles', (
      tester,
    ) async {
      final order = _order()
        ..devices = [
          DeviceAggr()
            ..id = 'd1'
            ..name = 'Gol',
          DeviceAggr()
            ..id = 'd2'
            ..name = 'Uno',
        ];
      await _pump(tester, screen(OrderStore()), args: {'order': order});
      await _openMenu(tester);
      expect(find.text('Outros campos'), findsNothing);
    });
  });

  group('checklists', () {
    testWidgets('"Checklist" adds one', (tester) async {
      final actions = FakeActions();
      await _pump(
        tester,
        screen(OrderStore(), actions: actions),
        args: {'order': _order()},
      );
      await _openMenu(tester);
      await tester.tap(find.text('Checklist'));
      await tester.pumpAndSettle();
      expect(actions.calls, ['addChecklist']);
    });

    testWidgets('show in "Checklists" with how many were answered; tap opens', (
      tester,
    ) async {
      final actions = FakeActions();
      final store = OrderStore()
        ..formsStream = ObservableStream(
          Stream.value([_form('f1'), _form('f2', items: 2, answered: 2)]),
        );
      await _pump(
        tester,
        screen(store, actions: actions),
        args: {'order': _order()},
      );

      expect(find.text('Checklists'), findsOneWidget);
      expect(find.text('1 de 3 respondidas'), findsOneWidget);
      expect(find.text('2 de 2 respondidas'), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text('Entrada do veículo'),
          matching: find.byType(Dismissible),
        ),
        findsNWidgets(2),
      );

      await tester.tap(find.text('1 de 3 respondidas'));
      await tester.pumpAndSettle();
      expect(actions.calls, ['checklist:f1']);
    });

    testWidgets('swipe asks before removing', (tester) async {
      final actions = FakeActions();
      final store = OrderStore()
        ..formsStream = ObservableStream(Stream.value([_form('f1')]));
      await _pump(
        tester,
        screen(store, actions: actions),
        args: {'order': _order()},
      );

      await tester.drag(find.text('1 de 3 respondidas'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();
      expect(actions.calls, ['deleteChecklist:f1']);
    });
  });

  group('photos and documents', () {
    Order withMedia() => _order()
      ..photos = [OrderPhoto()..url = 'p1', OrderPhoto()..url = 'p2']
      ..documents = [
        OrderDocument()
          ..id = 'doc1'
          ..fileName = 'nota.pdf'
          ..contentType = 'application/pdf'
          ..type = OrderDocumentType.invoice
          ..fileSize = 2048,
      ];

    testWidgets('"Documento" adds media', (tester) async {
      final actions = FakeActions();
      await _pump(
        tester,
        screen(OrderStore(), actions: actions),
        args: {'order': _order()},
      );
      await _openMenu(tester);
      await tester.tap(find.text('Documento'));
      await tester.pumpAndSettle();
      expect(actions.calls, ['media']);
    });

    testWidgets('photos and documents show only when they exist', (
      tester,
    ) async {
      await _pump(tester, screen(OrderStore()), args: {'order': _order()});
      expect(find.text('Fotos'), findsNothing);
      expect(find.text('Detalhes'), findsNothing);
    });

    testWidgets('tapping a photo or a document opens it', (tester) async {
      final actions = FakeActions();
      await _pump(
        tester,
        screen(OrderStore(), actions: actions),
        args: {'order': withMedia()},
      );

      expect(find.text('Fotos'), findsOneWidget);
      await tester.tap(find.text('thumb p2'));
      await tester.pumpAndSettle();
      expect(find.text('Detalhes'), findsOneWidget);
      expect(find.text('Nota Fiscal · 2KB'), findsOneWidget);
      await tester.tap(find.text('nota.pdf'));
      await tester.pumpAndSettle();
      expect(actions.calls, ['photo:1', 'doc:nota.pdf']);
    });

    testWidgets('swipe removes a document after confirming', (tester) async {
      final store = OrderStore();
      await _pump(tester, screen(store), args: {'order': withMedia()});

      await tester.drag(find.text('nota.pdf'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();
      expect(store.documents, isEmpty);
      expect(find.text('nota.pdf'), findsNothing);
    });
  });

  group('comments', () {
    OrderComment comment(String text, String author) => OrderComment()
      ..text = text
      ..author = (CommentAuthor()..name = author);

    testWidgets('the last two and "Ver todos (N)", which opens the list', (
      tester,
    ) async {
      final actions = FakeActions()
        ..commentList = [
          comment('Primeiro', 'Rafa'),
          comment('Peça chegou', 'Rafa'),
          comment('Cliente ligou', 'Bia'),
        ];
      await _pump(
        tester,
        screen(OrderStore(), actions: actions),
        args: {'order': _order()},
      );
      expect(find.text('Comentários'), findsOneWidget);
      expect(find.text('Primeiro'), findsNothing);
      expect(find.text('Peça chegou'), findsOneWidget);
      expect(find.text('Cliente ligou'), findsOneWidget);
      // No box to write on the order screen.
      expect(find.byType(CupertinoTextField), findsNothing);

      await tester.tap(find.text('Ver todos (3)'));
      await tester.pumpAndSettle();
      expect(actions.calls, ['comments:o1:']);
    });

    testWidgets('no comments, no section', (tester) async {
      await _pump(tester, screen(OrderStore()), args: {'order': _order()});
      expect(find.text('Comentários'), findsNothing);
    });

    testWidgets('opened from a notification goes to the comments', (
      tester,
    ) async {
      final actions = FakeActions();
      await _pump(
        tester,
        screen(OrderStore(), actions: actions),
        args: {'order': _order(), 'scrollToComments': true, 'commentId': 'k9'},
      );
      expect(actions.calls, ['comments:o1:k9']);
    });

    testWidgets('"Comentário" in the menu opens the comments', (tester) async {
      final actions = FakeActions();
      await _pump(
        tester,
        screen(OrderStore(), actions: actions),
        args: {'order': _order()},
      );
      await _openMenu(tester);
      await tester.tap(find.text('Comentário'));
      await tester.pumpAndSettle();
      expect(actions.calls, ['comments:o1:']);
    });
  });

  group('address, schedule and due date', () {
    testWidgets('address is added in a sheet and shows in "Detalhes"', (
      tester,
    ) async {
      final store = OrderStore();
      await _pump(tester, screen(store), args: {'order': _order()});
      await _openMenu(tester);
      await tester.tap(find.text('Local do atendimento'));
      await tester.pumpAndSettle();

      expect(
        find.text('Cancelar'),
        findsOneWidget,
      ); // sheet, Cancelar on the left
      await tester.enterText(
        find.byType(CupertinoTextField),
        '  Rua das Flores, 10  ',
      );
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(store.address, 'Rua das Flores, 10');
      expect(find.text('Detalhes'), findsOneWidget);
      expect(find.text('Local do atendimento'), findsOneWidget);
      expect(find.text('Rua das Flores, 10'), findsOneWidget);
    });

    testWidgets('address row opens maps, changes or removes', (tester) async {
      final actions = FakeActions();
      final store = OrderStore();
      await _pump(
        tester,
        screen(store, actions: actions),
        args: {'order': _order()..address = 'Rua A, 1'},
      );

      await tester.tap(find.text('Rua A, 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abrir no Mapa'));
      await tester.pumpAndSettle();
      expect(actions.calls, ['maps']);

      await tester.tap(find.text('Rua A, 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tirar endereço'));
      await tester.pumpAndSettle();
      expect(store.address, isNull);
      expect(find.text('Rua A, 1'), findsNothing);
    });

    testWidgets('schedule is picked and shows "Agendado"', (tester) async {
      final store = OrderStore();
      await _pump(tester, screen(store), args: {'order': _order()});
      await _openMenu(tester);
      await tester.tap(find.text('Agendar dia e hora'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoDatePicker), findsOneWidget);
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(store.order!.scheduledDate, isNotNull);
      expect(find.text('Agendado'), findsOneWidget);
    });

    testWidgets('due date shows in the header as "Fica pronto"', (
      tester,
    ) async {
      final now = DateTime.now();
      final due = DateTime(now.year, now.month, now.day + 1, 17);
      await _pump(
        tester,
        screen(OrderStore()),
        args: {'order': _order()..dueDate = due},
      );
      final time = (FormatService()..setLocale('pt')).formatTime(due);
      expect(find.text('Fica pronto amanhã, $time'), findsOneWidget);
    });

    testWidgets('midnight due date shows the day only', (tester) async {
      final now = DateTime.now();
      final due = DateTime(now.year, now.month, now.day + 1);
      await _pump(
        tester,
        screen(OrderStore()),
        args: {'order': _order()..dueDate = due},
      );
      expect(find.text('Fica pronto amanhã'), findsOneWidget);
    });

    testWidgets('late: dot and status in danger, in bold', (tester) async {
      final now = DateTime.now();
      final due = DateTime(now.year, now.month, now.day - 1);
      await _pump(
        tester,
        screen(OrderStore()),
        args: {'order': _order(status: 'progress')..dueDate = due},
      );
      expect(find.text('Era para ficar pronto ontem'), findsOneWidget);
      final status = tester.widget<Text>(find.textContaining('Atrasada'));
      expect(status.style?.fontWeight, FontWeight.w700);
      expect(
        tester.widget<StatusDot>(find.byType(StatusDot)).color,
        OrderStatusStyle.overdueColor,
      );
    });
  });

  group('responsible', () {
    testWidgets('"Responsável" picks someone of the team and shows the row', (
      tester,
    ) async {
      final order = _order(status: 'approved');
      await _pump(
        tester,
        screen(OrderStore(), actions: FakeActions()),
        args: {'order': order},
      );
      await _openMenu(tester);
      await tester.tap(find.text('Responsável'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rafa Técnico'));
      await tester.pumpAndSettle();

      expect(order.assignedTo?.id, 'u1');
      expect(find.text('Responsável'), findsOneWidget);
      expect(find.text('Rafa Técnico'), findsOneWidget);
    });
  });

  group('discount', () {
    testWidgets('after approval "Desconto" opens the discount sheet', (
      tester,
    ) async {
      final actions = FakeActions();
      await _pump(
        tester,
        screen(OrderStore(), actions: actions),
        args: {'order': _order(status: 'approved')},
      );
      await _openMenu(tester);
      await tester.tap(find.text('Desconto'));
      await tester.pumpAndSettle();
      expect(actions.calls, ['discount:500.0/500.0']);
    });

    testWidgets('a given discount shows above the total', (tester) async {
      final order = _order(status: 'approved')..discount = 50;
      await _pump(tester, screen(OrderStore()), args: {'order': order});
      expect(find.text('Desconto'), findsOneWidget);
      expect(find.text('− ${_money(50)}'), findsOneWidget);
      expect(find.text(_money(450)), findsWidgets);
    });

    testWidgets('no discount without viewPrices', (tester) async {
      await _pump(
        tester,
        screen(OrderStore(), prices: false),
        args: {'order': _order(status: 'approved')},
      );
      await _openMenu(tester);
      expect(find.text('Desconto'), findsNothing);
    });
  });

  group('recurring contract', () {
    testWidgets('"Repetir esta OS" turns the contract on and opens it', (
      tester,
    ) async {
      final actions = FakeActions();
      final store = OrderStore();
      await _pump(
        tester,
        screen(store, actions: actions),
        args: {'order': _order()},
      );
      await _openMenu(tester);
      await tester.tap(find.text('Repetir todo mês (contrato)'));
      await tester.pumpAndSettle();

      expect(store.hasContract, isTrue);
      expect(actions.calls, ['editContract']);
      expect(find.text('Contrato recorrente'), findsOneWidget);
    });

    testWidgets('contract row shows frequency and next date; opens Repetir', (
      tester,
    ) async {
      final actions = FakeActions();
      final next = DateTime(2026, 11, 10);
      final order = _order()
        ..contract = (OrderContract()
          ..frequency = 'monthly'
          ..nextDueDate = next);
      await _pump(
        tester,
        screen(OrderStore(), actions: actions),
        args: {'order': order},
      );

      final date = (FormatService()..setLocale('pt')).formatDate(next);
      expect(find.text('Mensal · próxima em $date'), findsOneWidget);
      await tester.tap(find.text('Contrato recorrente'));
      await tester.pumpAndSettle();
      // Opens the Repetir screen directly, no action sheet in between.
      expect(find.text('Mudar contrato'), findsNothing);
      expect(actions.calls, ['editContract']);
    });

    testWidgets('an order generated by a contract links to it', (tester) async {
      final actions = FakeActions();
      final order = _order()
        ..contract = (OrderContract()
          ..parentOrderId = 'parent'
          ..parentOrderNumber = 100);
      await _pump(
        tester,
        screen(OrderStore(), actions: actions),
        args: {'order': order},
      );
      await tester.tap(find.text('Ordem de Serviço 100'));
      await tester.pumpAndSettle();
      expect(actions.calls, ['order:parent']);
    });
  });

  group('"Avisar o cliente?"', () {
    // Starts approved and unpaid so the status change does not touch the
    // payment fields (Firestore).
    Order approved({String? phone}) =>
        _order(status: 'approved', phone: phone)..payment = 'unpaid';

    testWidgets('after a status change, offers to send to the customer', (
      tester,
    ) async {
      final actions = FakeActions();
      await _pump(
        tester,
        screen(OrderStore(), actions: actions),
        args: {'order': approved(phone: '11999990000')},
      );

      await tester.tap(find.text('Começar serviço'));
      await tester.pumpAndSettle();
      expect(find.text('Serviço em andamento!'), findsOneWidget);
      await tester.tap(find.text('Enviar via WhatsApp'));
      await tester.pumpAndSettle();
      expect(actions.calls, ['notify:progress']);
    });

    testWidgets('"Agora não" is not asked again for this order', (
      tester,
    ) async {
      final actions = FakeActions();
      final store = OrderStore();
      await _pump(
        tester,
        screen(store, actions: actions),
        args: {'order': approved(phone: '11999990000')},
      );

      await tester.tap(find.text('Começar serviço'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agora não'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Marcar como pronta'));
      await tester.pumpAndSettle();

      expect(store.status, 'done');
      expect(find.byType(CupertinoAlertDialog), findsNothing);
      expect(actions.calls, isEmpty);
    });

    testWidgets('no prompt when the customer has no phone', (tester) async {
      final store = OrderStore();
      await _pump(tester, screen(store), args: {'order': approved()});
      await tester.tap(find.text('Começar serviço'));
      await tester.pumpAndSettle();
      expect(store.status, 'progress');
      expect(find.byType(CupertinoAlertDialog), findsNothing);
    });
  });
}
