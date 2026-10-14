import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/order_photo.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/screens/widgets/order_media_widget.dart';

void main() {
  final config = SegmentConfigProvider()
    ..injectL10n(lookupAppLocalizations(const Locale('pt')));

  List<OrderPhoto> photos(int n) => [
    for (var i = 0; i < n; i++) OrderPhoto()..url = 'https://example.com/$i.jpg',
  ];

  Future<void> pump(
    WidgetTester tester,
    PhotoViewerScreen viewer, {
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      CupertinoApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: viewer,
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  Finder key(String k) => find.byKey(ValueKey(k));

  testWidgets('title says which photo; first photo has no "capa" option', (
    tester,
  ) async {
    await pump(
      tester,
      PhotoViewerScreen(
        photos: photos(3),
        initialIndex: 0,
        onDelete: (_) async => true,
        onSetCover: (_) {},
        config: config,
      ),
    );

    expect(find.text('1 de 3'), findsOneWidget);
    await tester.tap(key('photo_viewer_more'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Definir como capa'), findsNothing);
    expect(find.text('Apagar foto'), findsOneWidget);
  });

  testWidgets('"…" > Definir como capa calls back with the photo', (
    tester,
  ) async {
    int? cover;
    await pump(
      tester,
      PhotoViewerScreen(
        photos: photos(3),
        initialIndex: 2,
        onDelete: (_) async => true,
        onSetCover: (i) => cover = i,
        config: config,
      ),
    );

    await tester.tap(key('photo_viewer_more'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Definir como capa'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(cover, 2);
    expect(find.text('Foto definida como capa'), findsOneWidget);
    expect(find.byType(CupertinoAlertDialog), findsNothing);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('"…" > Apagar foto asks first; cancel keeps, confirm deletes', (
    tester,
  ) async {
    final deleted = <int>[];
    await pump(
      tester,
      PhotoViewerScreen(
        photos: photos(2),
        initialIndex: 1,
        onDelete: (i) async {
          deleted.add(i);
          return true;
        },
        onSetCover: (_) {},
        config: config,
      ),
    );

    Future<void> askDelete() async {
      await tester.tap(key('photo_viewer_more'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Apagar foto'));
      await tester.pump(const Duration(milliseconds: 300));
    }

    await askDelete();
    expect(find.text('Apagar esta foto?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(deleted, isEmpty);

    await askDelete();
    await tester.tap(key('order_photo_delete_confirm'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(deleted, [1]);
    expect(find.text('Foto apagada'), findsOneWidget);
    expect(find.byType(CupertinoAlertDialog), findsNothing);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('share failure shows a plain message', (tester) async {
    await pump(
      tester,
      PhotoViewerScreen(
        photos: photos(1),
        initialIndex: 0,
        onDelete: (_) async => true,
        onSetCover: (_) {},
        config: config,
        onShare: (_, _) async => throw Exception('offline'),
      ),
    );

    await tester.tap(key('photo_viewer_share'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.text('Não deu para compartilhar a foto. Tente de novo.'),
      findsOneWidget,
    );
  });

  testWidgets('top buttons are at least 44 and survive large text', (
    tester,
  ) async {
    await pump(
      tester,
      PhotoViewerScreen(
        photos: photos(12),
        initialIndex: 10,
        onDelete: (_) async => true,
        onSetCover: (_) {},
        config: config,
      ),
      textScale: 2,
    );

    for (final k in ['photo_viewer_back', 'photo_viewer_share', 'photo_viewer_more']) {
      final size = tester.getSize(key(k));
      expect(size.width >= 44 && size.height >= 44, isTrue, reason: k);
    }
    expect(tester.takeException(), isNull);
  });
}
