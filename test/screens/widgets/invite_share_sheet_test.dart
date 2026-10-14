import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/l10n/app_localizations_pt.dart';
import 'package:praticos/screens/widgets/app_toast.dart';
import 'package:praticos/screens/widgets/invite_share_sheet.dart';
import 'package:praticos/screens/widgets/primary_button.dart';
import 'package:praticos/theme/app_colors.dart';

void main() {
  final l10n = AppLocalizationsPt();

  Future<void> open(
    WidgetTester tester, {
    double scale = 1,
    VoidCallback? onCancelInvite,
    Future<void> Function(String)? onShare,
    Future<void> Function(Uri)? onOpenUrl,
  }) async {
    await tester.pumpWidget(
      CupertinoApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => CupertinoButton(
            child: const Text('abrir'),
            onPressed: () => showCupertinoModalPopup<void>(
              context: context,
              builder: (_) => InviteShareSheet(
                token: 'ABC123',
                whatsappPhone: '+55 (48) 99999-0000',
                expirationDays: 7,
                onCancelInvite: onCancelInvite,
                onShare: onShare ?? (_) async {},
                onOpenUrl: onOpenUrl ?? (_) async {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('título, frase, código e um botão azul', (tester) async {
    await open(tester);

    expect(find.text(l10n.inviteSheetTitle), findsOneWidget);
    expect(find.text(l10n.inviteShareSentence(7)), findsOneWidget);
    expect(find.byKey(const Key('inviteCode')), findsOneWidget);
    expect(find.text('ABC123'), findsOneWidget);
    expect(find.byType(PrimaryButton), findsOneWidget);
    expect(find.text(l10n.inviteShareButton), findsOneWidget);
    expect(find.text(l10n.inviteSendWhatsApp), findsOneWidget);
    expect(find.text(l10n.inviteCopyCode), findsOneWidget);
    // Without a cancel callback there is no "…".
    expect(find.byKey(const Key('inviteShareMenu')), findsNothing);
  });

  testWidgets('compartilhar e WhatsApp levam a mensagem com o código', (
    tester,
  ) async {
    String? shared;
    Uri? opened;
    await open(
      tester,
      onShare: (message) async => shared = message,
      onOpenUrl: (url) async => opened = url,
    );

    await tester.tap(find.byKey(const Key('inviteSharePrimary')));
    await tester.pumpAndSettle();
    expect(shared, l10n.inviteWhatsAppMessage('ABC123'));

    await tester.tap(find.byKey(const Key('inviteShareWhatsApp')));
    await tester.pumpAndSettle();
    expect(opened.toString(), startsWith('https://wa.me/5548999990000?text='));
  });

  testWidgets('copiar código mostra o aviso', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await open(tester);

    await tester.tap(find.byKey(const Key('inviteShareCopy')));
    await tester.pumpAndSettle();

    expect(copied, 'ABC123');
    expect(find.text(l10n.inviteCodeCopied), findsOneWidget);
    await tester.pump(kAppToastDuration);
    await tester.pumpAndSettle();
  });

  testWidgets('"…" tem Cancelar convite em vermelho', (tester) async {
    var canceled = 0;
    await open(tester, onCancelInvite: () => canceled++);

    await tester.tap(find.byKey(const Key('inviteShareMenu')));
    await tester.pumpAndSettle();
    final item = tester.widget<Text>(find.text(l10n.teamCancelInvite));
    expect(item.style?.color?.toARGB32(), AppColors.danger.color.toARGB32());

    await tester.tap(find.text(l10n.teamCancelInvite));
    await tester.pumpAndSettle();
    expect(canceled, 1);
    expect(find.text(l10n.inviteSheetTitle), findsNothing);
  });

  testWidgets('texto grande não estoura', (tester) async {
    await open(tester, scale: 2, onCancelInvite: () {});

    expect(tester.takeException(), isNull);
    expect(find.text(l10n.inviteShareButton), findsOneWidget);
  });
}
