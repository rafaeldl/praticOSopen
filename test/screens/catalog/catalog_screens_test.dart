import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/permission.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/screens/catalog/catalog_item_form.dart';
import 'package:praticos/screens/catalog/catalog_list_screen.dart';
import 'package:praticos/screens/catalog/catalog_source.dart';
import 'package:praticos/screens/widgets/app_sheet.dart';
import 'package:provider/provider.dart';

class FakeSource implements CatalogSource {
  FakeSource({
    this.services = const [],
    this.products = const [],
  });

  final List<CatalogItem> services;
  final List<CatalogItem> products;
  final List<CatalogItem> saved = [];
  final List<CatalogItem> deleted = [];

  @override
  Stream<List<CatalogItem>> watch(CatalogKind kind) =>
      Stream.value(kind == CatalogKind.service ? services : products);

  @override
  Future<void> save(CatalogKind kind, CatalogItem item) async {
    item.id ??= 'new';
    saved.add(item);
  }

  @override
  Future<void> delete(CatalogKind kind, CatalogItem item) async =>
      deleted.add(item);

  @override
  Future<String?> uploadPhoto(
          CatalogKind kind, CatalogItem item, PhotoOrigin from) async =>
      null;
}

CatalogItem item(String id, String name, [double? value]) =>
    CatalogItem(id: id, name: name, value: value, origin: Object());

const allPermissions = CatalogPermissions(_all);
bool _all(PermissionType p) => true;

CatalogPermissions only(Set<PermissionType> set) =>
    CatalogPermissions(set.contains);

Future<List<RouteSettings>> pump(
  WidgetTester tester,
  Widget screen, {
  Map<String, dynamic>? args,
  Locale locale = const Locale('pt'),
}) async {
  final pushed = <RouteSettings>[];
  await tester.pumpWidget(
    ChangeNotifierProvider<SegmentConfigProvider>(
      create: (_) => SegmentConfigProvider(),
      child: CupertinoApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        onGenerateRoute: (settings) {
          if (settings.name == '/') {
            return CupertinoPageRoute(
              settings: RouteSettings(name: '/', arguments: args),
              builder: (_) => screen,
            );
          }
          pushed.add(settings);
          return CupertinoPageRoute(
            settings: settings,
            builder: (_) => const Text('pushed'),
          );
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return pushed;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  final source = FakeSource(
    services: [item('s1', 'Troca de óleo', 120), item('s2', 'Alinhamento')],
    products: [item('p1', 'Filtro de óleo', 35.5)],
  );

  group('catalog list: Mais usados', () {
    final src = FakeSource(
      services: [
        item('s1', 'Troca de óleo', 120),
        item('s2', 'Alinhamento'),
        item('s3', 'Balanceamento'),
      ],
      products: [item('p1', 'Filtro de óleo', 35.5)],
    );

    testWidgets('shows the most used items of the kind on top, then all',
        (tester) async {
      await pump(
        tester,
        CatalogListScreen(
          source: src,
          permissions: allPermissions,
          mostUsed: () async => ['service:s3', 'product:p1', 'service:zz'],
        ),
      );
      expect(find.text('Mais usados'), findsOneWidget);
      expect(find.text('Todos'), findsOneWidget);
      // Balanceamento appears twice (Mais usados + all); products do not leak.
      expect(find.text('Balanceamento'), findsNWidgets(2));
      expect(find.text('Filtro de óleo'), findsNothing);
      final used = tester.getTopLeft(find.text('Mais usados')).dy;
      final first = tester.getTopLeft(find.text('Balanceamento').first).dy;
      final troca = tester.getTopLeft(find.text('Troca de óleo')).dy;
      expect(used, lessThan(first));
      expect(first, lessThan(troca));
    });

    testWidgets('is hidden while searching and when nothing was used',
        (tester) async {
      await pump(
        tester,
        CatalogListScreen(
          source: src,
          permissions: allPermissions,
          mostUsed: () async => ['service:s3'],
        ),
      );
      await tester.enterText(find.byType(CupertinoSearchTextField), 'bal');
      await tester.pumpAndSettle();
      expect(find.text('Mais usados'), findsNothing);
      expect(find.text('Balanceamento'), findsOneWidget);

      await pump(
        tester,
        CatalogListScreen(
          source: src,
          permissions: allPermissions,
          mostUsed: () async => const [],
        ),
      );
      expect(find.text('Mais usados'), findsNothing);
    });

    testWidgets('a failure loading usage keeps the plain list',
        (tester) async {
      await pump(
        tester,
        CatalogListScreen(
          source: src,
          permissions: allPermissions,
          mostUsed: () async => throw StateError('offline'),
        ),
      );
      expect(find.text('Mais usados'), findsNothing);
      expect(find.text('Troca de óleo'), findsOneWidget);
    });
  });

  group('catalog list: Serviços | Produtos', () {
    testWidgets('segmented control switches between services and products',
        (tester) async {
      await pump(tester,
          CatalogListScreen(source: source, permissions: allPermissions));
      expect(find.text('Catálogo'), findsWidgets);
      expect(find.text('Troca de óleo'), findsOneWidget);
      expect(find.text('Filtro de óleo'), findsNothing);

      await tester.tap(find.text('Produtos'));
      await tester.pumpAndSettle();
      expect(find.text('Filtro de óleo'), findsOneWidget);
      expect(find.text('Troca de óleo'), findsNothing);
    });

    testWidgets('item without price shows "sem valor"; priced one shows money',
        (tester) async {
      await pump(tester,
          CatalogListScreen(source: source, permissions: allPermissions));
      expect(find.text('sem valor'), findsOneWidget);
      expect(find.textContaining('120,00'), findsOneWidget);
    });

    testWidgets('prices are hidden without viewPrices', (tester) async {
      await pump(
        tester,
        CatalogListScreen(
          source: source,
          permissions: only({
            PermissionType.viewServices,
            PermissionType.viewProducts,
            PermissionType.manageServices,
          }),
        ),
      );
      expect(find.text('sem valor'), findsNothing);
      expect(find.textContaining('120,00'), findsNothing);
    });

    testWidgets('search filters the current segment', (tester) async {
      await pump(tester,
          CatalogListScreen(source: source, permissions: allPermissions));
      await tester.enterText(find.byType(CupertinoSearchTextField), 'alinh');
      await tester.pumpAndSettle();
      expect(find.text('Alinhamento'), findsOneWidget);
      expect(find.text('Troca de óleo'), findsNothing);
      await tester.enterText(find.byType(CupertinoSearchTextField), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('Nada com “zzz”'), findsOneWidget);
    });

    testWidgets('empty catalog explains what to do', (tester) async {
      await pump(tester,
          CatalogListScreen(source: FakeSource(), permissions: allPermissions));
      expect(find.text('Você ainda não tem serviços'), findsOneWidget);
    });

    testWidgets('tapping a row edits it (push with chevron, no swipe)',
        (tester) async {
      await pump(tester,
          CatalogListScreen(source: source, permissions: allPermissions));
      expect(find.byType(Dismissible), findsNothing);
      expect(find.byIcon(CupertinoIcons.chevron_forward), findsWidgets);
      await tester.tap(find.text('Troca de óleo'));
      await tester.pumpAndSettle();
      expect(find.byType(CatalogItemForm), findsOneWidget);
      expect(find.byType(AppSheet), findsNothing);
    });

    testWidgets('/product_list style entry opens on products', (tester) async {
      await pump(
        tester,
        CatalogListScreen(
          initialKind: CatalogKind.product,
          source: source,
          permissions: allPermissions,
        ),
      );
      expect(find.text('Filtro de óleo'), findsOneWidget);
    });
  });

  group('catalog permissions', () {
    testWidgets('manager sees the new button for the current kind',
        (tester) async {
      await pump(tester,
          CatalogListScreen(source: source, permissions: allPermissions));
      expect(find.text('Novo serviço'), findsOneWidget);
      await tester.tap(find.text('Produtos'));
      await tester.pumpAndSettle();
      expect(find.text('Novo produto'), findsOneWidget);
    });

    testWidgets('viewer has no create button, no chevron and rows do not open',
        (tester) async {
      await pump(
        tester,
        CatalogListScreen(
          source: source,
          permissions: only({
            PermissionType.viewServices,
            PermissionType.viewProducts,
          }),
        ),
      );
      expect(find.text('Novo serviço'), findsNothing);
      expect(find.byIcon(CupertinoIcons.chevron_forward), findsNothing);
      await tester.tap(find.text('Troca de óleo'));
      await tester.pumpAndSettle();
      expect(find.byType(CatalogItemForm), findsNothing);
    });

    testWidgets('managing services does not allow creating products',
        (tester) async {
      await pump(
        tester,
        CatalogListScreen(
          source: source,
          permissions: only({
            PermissionType.viewServices,
            PermissionType.viewProducts,
            PermissionType.manageServices,
          }),
        ),
      );
      expect(find.text('Novo serviço'), findsOneWidget);
      await tester.tap(find.text('Produtos'));
      await tester.pumpAndSettle();
      expect(find.text('Novo produto'), findsNothing);
    });

    testWidgets('only one viewable kind hides the segmented control',
        (tester) async {
      await pump(
        tester,
        CatalogListScreen(
          initialKind: CatalogKind.product,
          source: source,
          permissions: only({PermissionType.viewServices}),
        ),
      );
      expect(find.byType(CupertinoSlidingSegmentedControl<CatalogKind>),
          findsNothing);
      // Falls back to the kind the user can see.
      expect(find.text('Troca de óleo'), findsOneWidget);
    });
  });

  group('selection mode (from the order)', () {
    testWidgets('titles the task, no segments/chevron/swipe, tap opens item',
        (tester) async {
      final pushed = await pump(
        tester,
        CatalogListScreen(source: source, permissions: allPermissions),
        args: {'orderStore': 'store'},
      );
      expect(find.text('Qual serviço?'), findsOneWidget);
      expect(find.byType(CupertinoSlidingSegmentedControl<CatalogKind>),
          findsNothing);
      expect(find.byType(Dismissible), findsNothing);
      expect(find.byIcon(CupertinoIcons.chevron_forward), findsNothing);
      expect(find.text('Novo serviço'), findsOneWidget); // AddRow at the top

      await tester.tap(find.text('Troca de óleo'));
      await tester.pumpAndSettle();
      expect(pushed.single.name, '/order_service');
      final args = pushed.single.arguments as Map;
      expect(args['orderStore'], 'store');
      expect(args['service'], isNotNull);
    });

    testWidgets('cannot create without manage permission', (tester) async {
      await pump(
        tester,
        CatalogListScreen(
          source: source,
          permissions: only({PermissionType.viewServices}),
        ),
        args: {'orderStore': 'store'},
      );
      expect(find.text('Novo serviço'), findsNothing);
    });
  });

  group('catalog item form', () {
    Future<void> openSheet(
      WidgetTester tester,
      FakeSource src, {
      CatalogKind kind = CatalogKind.service,
      Locale locale = const Locale('pt'),
    }) async {
      await pump(
        tester,
        CatalogItemForm(
          kind: kind,
          source: src,
          permissions: allPermissions,
          asSheet: true,
        ),
        locale: locale,
      );
    }

    testWidgets('new item opens as a sheet with Cancelar and Salvar',
        (tester) async {
      await pump(
        tester,
        CatalogListScreen(source: source, permissions: allPermissions),
      );
      await tester.tap(find.text('Novo serviço'));
      await tester.pumpAndSettle();
      expect(find.byType(AppSheet), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Salvar'), findsOneWidget);
      expect(find.text('Preço'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.byType(AppSheet), findsNothing);
    });

    testWidgets('name is required', (tester) async {
      final src = FakeSource();
      await openSheet(tester, src);
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      expect(find.text('Digite o nome do serviço'), findsOneWidget);
      expect(src.saved, isEmpty);
    });

    testWidgets('blank price saves null', (tester) async {
      final src = FakeSource();
      await openSheet(tester, src);
      await tester.enterText(find.byType(CupertinoTextField).first, 'Revisão');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      expect(src.saved.single.name, 'Revisão');
      expect(src.saved.single.value, isNull);
    });

    testWidgets('typed price saves the amount', (tester) async {
      final src2 = FakeSource();
      await openSheet(tester, src2);
      await tester.enterText(find.byType(CupertinoTextField).first, 'Revisão');
      await tester.enterText(find.byType(CupertinoTextField).at(1), '15000');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      expect(src2.saved.single.value, 150.0);
    });

    testWidgets('product uses product labels', (tester) async {
      await openSheet(tester, FakeSource(), kind: CatalogKind.product);
      expect(find.text('Novo produto'), findsOneWidget);
      expect(find.text('Ex.: Filtro de óleo'), findsOneWidget);
      expect(find.text('+ Foto do produto'), findsOneWidget);
    });

    testWidgets('english locale formats the price hint in dollars',
        (tester) async {
      await openSheet(tester, FakeSource(), locale: const Locale('en'));
      expect(find.text('New service'), findsOneWidget);
      expect(find.text(r'$0.00'), findsOneWidget);
    });

    Future<void> pumpEdit(WidgetTester tester, FakeSource src,
        CatalogPermissions perms) async {
      await pump(
        tester,
        CatalogItemForm(
          kind: CatalogKind.service,
          source: src,
          permissions: perms,
          item: item('s1', 'Troca de óleo', 120),
        ),
      );
    }

    testWidgets('editing: "…" menu deletes after confirmation',
        (tester) async {
      final src = FakeSource();
      await pumpEdit(tester, src, allPermissions);
      expect(find.text('Salvar serviço'), findsOneWidget);
      await tester.tap(find.byIcon(CupertinoIcons.ellipsis_circle));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apagar serviço'));
      await tester.pumpAndSettle();
      expect(find.text('Apagar Troca de óleo?'), findsOneWidget);
      expect(src.deleted, isEmpty);
      await tester.tap(find.text('Apagar'));
      await tester.pumpAndSettle();
      expect(src.deleted.single.id, 's1');
    });

    testWidgets(
        'without viewPrices (values and billing off) the price field is '
        'hidden and the stored price is kept on save', (tester) async {
      final src = FakeSource();
      await pumpEdit(
        tester,
        src,
        CatalogPermissions((p) => p != PermissionType.viewPrices),
      );
      expect(find.text('Preço'), findsNothing);
      await tester.tap(find.text('Salvar serviço'));
      await tester.pumpAndSettle();
      expect(src.saved.single.value, 120);
    });

    testWidgets('editing without manage permission has no delete menu',
        (tester) async {
      await pumpEdit(tester, FakeSource(),
          only({PermissionType.viewServices}));
      expect(find.byIcon(CupertinoIcons.ellipsis_circle), findsNothing);
    });
  });
}
