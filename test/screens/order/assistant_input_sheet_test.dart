import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/screens/order/assistant/assistant_input_sheet.dart';
import 'package:praticos/services/ai_order_assist_service.dart';

// 1x1 transparent PNG.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

void main() {
  Future<void> pumpSheet(
    WidgetTester tester, {
    List<AiPhoto> photos = const [],
  }) {
    return tester.pumpWidget(
      CupertinoApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CupertinoPageScaffold(
          child: AssistantInputSheet(
            initialPhotos: photos,
            capturePhoto: () async => null,
          ),
        ),
      ),
    );
  }

  testWidgets('no photo yet: offers "Tirar foto", not "outra"', (tester) async {
    await pumpSheet(tester);
    expect(find.text('Tirar foto'), findsOneWidget);
    expect(find.text('Tirar outra foto'), findsNothing);
  });

  testWidgets('with a photo: offers "Tirar outra foto"', (tester) async {
    await pumpSheet(tester, photos: [AiPhoto(_png, mimeType: 'image/png')]);
    expect(find.text('Tirar outra foto'), findsOneWidget);
    expect(find.text('Tirar foto'), findsNothing);
  });
}
