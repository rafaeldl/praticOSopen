import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/screens/order/pdf_viewer_screen.dart';
import 'package:printing/printing.dart';

void main() {
  testWidgets('shows the document; sharing is a second step on the top bar', (
    tester,
  ) async {
    var shared = 0;
    await tester.pumpWidget(
      CupertinoApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PdfViewerScreen(
          title: 'OS 12',
          bytes: Uint8List(0),
          filename: 'OS-12.pdf',
          onShare: () async => shared++,
        ),
      ),
    );

    expect(find.text('OS 12'), findsOneWidget);
    expect(find.byType(PdfPreview), findsOneWidget);
    expect(shared, 0);

    await tester.tap(find.byKey(const ValueKey('pdf_viewer_share')));
    await tester.pump();
    expect(shared, 1);
  });
}
