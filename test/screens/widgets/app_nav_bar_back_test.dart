import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/screens/widgets/glass_bar_button.dart';

/// First screen whose content changes while another screen covers it.
class _Root extends StatefulWidget {
  const _Root({required this.redraw});

  final ValueNotifier<int> redraw;

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: widget.redraw,
      builder: (context, count, _) => CupertinoPageScaffold(
        child: CustomScrollView(
          slivers: [
            // Not const: the bar is rebuilt with the page, as on new data.
            AppNavBar(largeTitle: Text('Clientes ($count)')),
            SliverToBoxAdapter(
              child: CupertinoButton(
                child: const Text('Cliente 01'),
                onPressed: () => Navigator.of(context).push(
                  CupertinoPageRoute<void>(
                    builder: (_) => const CupertinoPageScaffold(
                      child: CustomScrollView(
                        slivers: [AppNavBar(largeTitle: Text('Detalhe'))],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  testWidgets('first screen shows no back button after one above closes, '
      'even when it was redrawn while covered', (tester) async {
    final redraw = ValueNotifier(0);
    addTearDown(redraw.dispose);
    await tester.pumpWidget(
      CupertinoApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: _Root(redraw: redraw),
      ),
    );
    expect(find.byType(GlassBackButton), findsNothing);

    await tester.tap(find.text('Cliente 01'));
    await tester.pumpAndSettle();
    expect(find.byType(GlassBackButton), findsOneWidget);

    // New data arrives for the list while the customer is open.
    redraw.value++;
    await tester.pump();

    Navigator.of(tester.element(find.text('Detalhe'))).pop();
    await tester.pumpAndSettle();
    expect(find.text('Detalhe'), findsNothing);
    expect(find.byType(GlassBackButton), findsNothing);
  });
}
