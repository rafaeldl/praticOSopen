import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/l10n/app_localizations_pt.dart';
import 'package:praticos/models/order_comment.dart';
import 'package:praticos/screens/order/order_comments_screen.dart';
import 'package:praticos/screens/widgets/app_toast.dart';
import 'package:praticos/screens/widgets/order_comments_widget.dart';

void main() {
  final l10n = AppLocalizationsPt();

  OrderComment comment(
    String id,
    String text, {
    String? name,
    String authorType = 'internal',
    bool internal = false,
  }) => OrderComment()
    ..id = id
    ..text = text
    ..authorType = authorType
    ..isInternal = internal
    ..author = (CommentAuthor()..name = name)
    ..createdAt = DateTime(2026, 10, 1, 9, 30);

  Widget app(Widget home, {double scale = 1}) => CupertinoApp(
    locale: const Locale('pt'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: home,
  );

  Future<void> pump(
    WidgetTester tester,
    List<OrderComment> comments, {
    OrderCommentSender? onSend,
    double scale = 1,
  }) async {
    await tester.pumpWidget(
      app(
        OrderCommentsScreen(
          orderId: 'o1',
          companyId: 'c1',
          commentsStream: Stream.value(comments),
          onSend: onSend ?? (_, _) async {},
        ),
        scale: scale,
      ),
    );
    await tester.pumpAndSettle();
  }

  final thread = [
    comment('1', 'Peça chega amanhã de manhã.', name: 'Marina'),
    comment(
      '2',
      'Pode trocar, obrigado!',
      name: 'João Silva',
      authorType: 'customer',
    ),
    comment(
      '3',
      'Cobrar a mão de obra à parte.',
      name: 'Marina',
      internal: true,
    ),
  ];

  testWidgets('conversa: autor e hora em cima, texto embaixo', (tester) async {
    await pump(tester, thread);

    expect(find.text(l10n.comments), findsOneWidget);
    expect(find.text('Peça chega amanhã de manhã.'), findsOneWidget);
    expect(
      find.textContaining('João Silva · ${l10n.commentFromCustomer}'),
      findsOneWidget,
    );
    expect(find.textContaining(l10n.commentTeamOnlyTag), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.lock_fill), findsOneWidget);
    expect(find.byKey(const ValueKey('order_comments_empty')), findsNothing);
  });

  testWidgets('sem comentários: uma linha', (tester) async {
    await pump(tester, const []);

    expect(find.byKey(const ValueKey('order_comments_empty')), findsOneWidget);
    expect(find.text(l10n.commentsEmpty), findsOneWidget);
  });

  testWidgets('envia para o cliente por padrão e só para a equipe com o '
      'interruptor', (tester) async {
    final sent = <(String, bool)>[];
    await pump(
      tester,
      const [],
      onSend: (text, internal) async {
        sent.add((text, internal));
      },
    );

    expect(find.text(l10n.commentsCustomerSees), findsOneWidget);
    final send = find.byKey(const ValueKey('order_comments_send'));
    expect(tester.widget<CupertinoButton>(send).onPressed, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('order_comments_field')),
      '  Olá  ',
    );
    await tester.pump();
    await tester.tap(send);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('order_comments_internal')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.commentsCustomerHidden), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('order_comments_field')),
      'Interno',
    );
    await tester.pump();
    await tester.tap(send);
    await tester.pumpAndSettle();

    expect(sent, [('Olá', false), ('Interno', true)]);
  });

  testWidgets('erro ao enviar aparece no aviso e mantém o texto', (
    tester,
  ) async {
    await pump(tester, const [], onSend: (_, _) async => throw StateError('x'));

    await tester.enterText(
      find.byKey(const ValueKey('order_comments_field')),
      'Oi',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('order_comments_send')));
    await tester.pumpAndSettle();

    expect(find.text(l10n.commentSendError), findsOneWidget);
    expect(find.text('Oi'), findsOneWidget);
    await tester.pump(kAppToastDuration);
    await tester.pumpAndSettle();
  });

  testWidgets('texto grande não estoura', (tester) async {
    await pump(tester, thread, scale: 2);

    expect(tester.takeException(), isNull);
    expect(find.text('Pode trocar, obrigado!'), findsOneWidget);
  });
}
