import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/screens/menu_navigation/tab_stack.dart';

void main() {
  testWidgets('tracks screens opened on the tab and pops back to its first', (
    tester,
  ) async {
    final stack = TabStack();
    addTearDown(stack.dispose);
    var changes = 0;
    stack.changes.addListener(() => changes++);

    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoTabScaffold(
          tabBar: CupertinoTabBar(
            items: const [
              BottomNavigationBarItem(icon: Icon(CupertinoIcons.house)),
              BottomNavigationBarItem(icon: Icon(CupertinoIcons.calendar)),
            ],
          ),
          tabBuilder: (context, index) => CupertinoTabView(
            navigatorKey: index == 0 ? stack.key : null,
            navigatorObservers: index == 0 ? [stack.observer] : const [],
            builder: (context) => Center(
              child: CupertinoButton(
                child: const Text('Veículos'),
                onPressed: () => Navigator.of(context).push(
                  CupertinoPageRoute<void>(
                    builder: (_) => const Center(child: Text('Tela interna')),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(stack.atRoot, isTrue);

    await tester.tap(find.text('Veículos'));
    await tester.pumpAndSettle();
    expect(find.text('Tela interna'), findsOneWidget);
    expect(stack.atRoot, isFalse);
    final opened = changes;
    expect(opened, greaterThan(0));

    stack.popToRoot();
    await tester.pumpAndSettle();
    expect(find.text('Tela interna'), findsNothing);
    expect(find.text('Veículos'), findsOneWidget);
    expect(stack.atRoot, isTrue);
    expect(changes, greaterThan(opened));
  });

  testWidgets('popToRoot before the tab is built does nothing', (tester) async {
    final stack = TabStack();
    addTearDown(stack.dispose);
    stack.popToRoot();
    expect(stack.atRoot, isTrue);
  });
}
