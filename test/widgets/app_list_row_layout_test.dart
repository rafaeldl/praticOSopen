import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';

void main() {
  Widget host(Widget child) => CupertinoApp(
        home: CupertinoPageScaffold(child: SafeArea(child: child)),
      );

  testWidgets('trailing value sits next to the chevron, at the right edge',
      (tester) async {
    await tester.pumpWidget(host(
      AppListRow(title: 'Plano', trailing: 'Pro', onTap: () {}),
    ));

    final value = tester.getRect(find.text('Pro'));
    final chevron = tester.getRect(find.byIcon(CupertinoIcons.chevron_forward));
    expect(chevron.left - value.right, lessThan(16));
  });

  testWidgets('a tappable row is announced as a button', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host(
      AppListRow(title: 'Equipe', onTap: () {}),
    ));

    expect(
      tester.getSemantics(find.text('Equipe')),
      matchesSemantics(isButton: true, label: 'Equipe', hasTapAction: true),
    );
    handle.dispose();
  });
}
