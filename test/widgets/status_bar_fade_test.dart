import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/screens/widgets/status_bar_fade.dart';

Widget _wrap(double top) => CupertinoApp(
      home: MediaQuery(
        data: MediaQueryData(padding: EdgeInsets.only(top: top)),
        child: const StatusBarFade(child: Text('page')),
      ),
    );

void main() {
  testWidgets('fades the content under the status bar', (tester) async {
    await tester.pumpWidget(_wrap(62));

    final fade = find.byKey(const ValueKey('status_bar_fade'));
    expect(fade, findsOneWidget);
    expect(
      tester.getSize(fade).height,
      62 + StatusBarFade.fadeExtent,
    );
    // Taps go through to the content.
    expect(
      find.ancestor(of: fade, matching: find.byType(IgnorePointer)),
      findsWidgets,
    );
  });

  testWidgets('adds nothing without a status bar', (tester) async {
    await tester.pumpWidget(_wrap(0));
    expect(find.byKey(const ValueKey('status_bar_fade')), findsNothing);
    expect(find.text('page'), findsOneWidget);
  });
}
