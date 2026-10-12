import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/screens/menu_navigation/widgets/glass_tab_bar.dart';
import 'package:praticos/theme/app_colors.dart';
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

  testWidgets('selected tab sits on a filled capsule in the accent color', (
    tester,
  ) async {
    await _pump(tester);

    final label = tester.widget<Text>(find.text('Início'));
    final other = tester.widget<Text>(find.text('Clientes'));
    expect(
      label.style!.color!.toARGB32(),
      AppColors.accentText.color.toARGB32(),
    );
    expect(label.style!.fontWeight, FontWeight.w600);
    expect(other.style!.color!.toARGB32(), AppColors.text.color.toARGB32());

    final capsule = tester.widget<AnimatedContainer>(
      find.ancestor(
        of: find.text('Início'),
        matching: find.byType(AnimatedContainer),
      ),
    );
    expect(
      (capsule.decoration! as BoxDecoration).color!.toARGB32(),
      AppColors.secondaryFill.color.toARGB32(),
    );
  });

  testWidgets('floats as a 64pt capsule inset from the screen edges', (
    tester,
  ) async {
    await _pump(tester);
    final glass = tester.getRect(find.byType(AppGlass));
    expect(glass.height, GlassTabBar.capsuleHeight);
    expect(glass.left, 16);
    expect(
      glass.right,
      tester.view.physicalSize.width / tester.view.devicePixelRatio - 16,
    );
  });

  testWidgets('keeps its height with the largest iPhone text size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(750, 1334); // iPhone SE
    tester.view.devicePixelRatio = 2;
    tester.platformDispatcher.textScaleFactorTestValue = 3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await _pump(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Clientes'), findsOneWidget);
    final label = tester.widget<Text>(find.text('Clientes'));
    expect(label.overflow, isNot(TextOverflow.ellipsis));
  });
}
