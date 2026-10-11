import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/screens/menu_navigation/widgets/glass_tab_bar.dart';
import 'package:praticos/theme/app_glass.dart';

final _items = [
  BottomNavigationBarItem(icon: Icon(CupertinoIcons.house), label: 'Início'),
  BottomNavigationBarItem(
    icon: Icon(CupertinoIcons.person_2),
    label: 'Clientes',
  ),
  BottomNavigationBarItem(icon: Icon(CupertinoIcons.ellipsis), label: 'Mais'),
];

Future<void> _pump(
  WidgetTester tester, {
  bool highContrast = false,
  bool reduceTransparency = false,
  ValueChanged<int>? onTap,
}) {
  return tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(highContrast: highContrast),
      child: CupertinoApp(
        home: CupertinoTabScaffold(
          tabBar: GlassTabBar(
            items: _items,
            onTap: onTap,
            reduceTransparency: reduceTransparency,
          ),
          tabBuilder: (context, index) => Center(child: Text('page $index')),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders the tabs on blurred glass', (tester) async {
    await _pump(tester);

    expect(find.text('Início'), findsOneWidget);
    expect(find.text('Clientes'), findsOneWidget);
    expect(find.text('Mais'), findsOneWidget);
    expect(find.byType(AppGlass), findsOneWidget);
    // Only the AppGlass blur: the inner bar must not add its own.
    expect(find.byType(BackdropFilter), findsOneWidget);
  });

  testWidgets('switches tabs on tap', (tester) async {
    final taps = <int>[];
    await _pump(tester, onTap: taps.add);

    await tester.tap(find.text('Mais'));
    await tester.pump();

    expect(taps, [2]);
    expect(find.text('page 2'), findsOneWidget);
  });

  testWidgets('falls back to opaque with Increase Contrast', (tester) async {
    await _pump(tester, highContrast: true);
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('falls back to opaque with Reduce Transparency', (tester) async {
    await _pump(tester, reduceTransparency: true);
    expect(find.byType(BackdropFilter), findsNothing);
  });

  test('copyWith keeps the glass bar', () {
    final bar = GlassTabBar(items: _items, reduceTransparency: true);
    final copy = bar.copyWith(currentIndex: 1);
    expect(copy, isA<GlassTabBar>());
    expect(copy.currentIndex, 1);
    expect(copy.reduceTransparency, isTrue);
  });
}
