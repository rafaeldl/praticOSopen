import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/screens/widgets/app_toast.dart';

void main() {
  Future<BuildContext> pump(
    WidgetTester tester, {
    double textScale = 1,
    bool disableAnimations = false,
  }) async {
    late BuildContext captured;
    await tester.pumpWidget(
      CupertinoApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: disableAnimations,
          ),
          child: child!,
        ),
        home: Builder(
          builder: (context) {
            captured = context;
            return const CupertinoPageScaffold(child: SizedBox.expand());
          },
        ),
      ),
    );
    return captured;
  }

  final toast = find.byKey(const ValueKey('app_toast'));

  testWidgets('shows the message and goes away on its own', (tester) async {
    final context = await pump(tester);
    showAppToast(context, 'Link copiado');
    await tester.pump();
    await tester.pump(kAppToastAnimation);
    expect(find.text('Link copiado'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.checkmark_circle_fill), findsOneWidget);

    // Does not block: no dialog, nothing to tap.
    expect(find.byType(CupertinoAlertDialog), findsNothing);

    await tester.pump(kAppToastDuration);
    await tester.pumpAndSettle();
    expect(toast, findsNothing);
    expect(find.text('Link copiado'), findsNothing);
  });

  testWidgets('a new notice replaces the one on screen', (tester) async {
    final context = await pump(tester);
    showAppToast(context, 'Foto apagada');
    await tester.pump(const Duration(milliseconds: 500));
    showAppToast(context, 'Capa definida', icon: CupertinoIcons.star_fill);
    await tester.pump(kAppToastAnimation);

    expect(toast, findsOneWidget);
    expect(find.text('Foto apagada'), findsNothing);
    expect(find.text('Capa definida'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.star_fill), findsOneWidget);

    // The replaced one's timer does not take the new one away early.
    await tester.pump(const Duration(milliseconds: 1600));
    expect(find.text('Capa definida'), findsOneWidget);
    await tester.pump(kAppToastDuration);
    await tester.pumpAndSettle();
    expect(toast, findsNothing);
  });

  testWidgets('long text at the largest size wraps without overflow', (
    tester,
  ) async {
    final context = await pump(tester, textScale: 3);
    showAppToast(
      context,
      'O colaborador foi adicionado à empresa e já pode abrir as ordens',
    );
    await tester.pump();
    await tester.pump(kAppToastAnimation);
    expect(tester.takeException(), isNull);
    final text = tester.widget<Text>(
      find.text(
        'O colaborador foi adicionado à empresa e já pode abrir as ordens',
      ),
    );
    expect(text.maxLines, isNull);
    expect(text.overflow, isNot(TextOverflow.ellipsis));
    expect(tester.getSize(toast).height, greaterThan(100));
    await tester.pump(kAppToastDuration);
    await tester.pumpAndSettle();
  });

  testWidgets('reduce motion: appears at once, no slide', (tester) async {
    final context = await pump(tester, disableAnimations: true);
    showAppToast(context, 'Link copiado');
    await tester.pump();
    final fade = tester.widget<FadeTransition>(
      find.ancestor(of: toast, matching: find.byType(FadeTransition)).first,
    );
    expect(fade.opacity.value, 1);
    await tester.pump(kAppToastDuration);
    await tester.pump();
    expect(toast, findsNothing);
  });

  testWidgets('is announced to VoiceOver', (tester) async {
    final announced = <String>[];
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(
      SystemChannels.accessibility,
      (message) async {
        final data = (message as Map)['data'] as Map?;
        if ((message)['type'] == 'announce') {
          announced.add(data!['message'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<dynamic>(
            SystemChannels.accessibility,
            null,
          ),
    );
    final context = await pump(tester);
    showAppToast(context, 'Link copiado');
    await tester.pump();
    expect(announced, ['Link copiado']);
    await tester.pump(kAppToastDuration);
    await tester.pumpAndSettle();
  });
}
