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

  testWidgets('valueBesideTitle: value on the title line, subtitle full width',
      (tester) async {
    await tester.pumpWidget(host(
      AppListRow(
        title: 'Larissa',
        subtitle: '3 OS · desde 24/10/2020',
        trailing: 'R\$ 3.411,47',
        valueBesideTitle: true,
        onTap: () {},
      ),
    ));

    final title = tester.getRect(find.text('Larissa'));
    final value = tester.getRect(find.text('R\$ 3.411,47'));
    final subtitle = tester.getRect(find.text('3 OS · desde 24/10/2020'));
    // Same line as the name.
    expect(value.top, title.top);
    // The subtitle is not squeezed by the value column: it fits on one line.
    expect(subtitle.height, lessThan(title.height * 1.5));
    expect(subtitle.top, greaterThan(title.bottom - 1));
  });

  testWidgets('trailingWidget: beside the title, under it at large text',
      (tester) async {
    Widget row() => AppListRow(
          title: 'Ana Ribeiro',
          subtitle: '(11) 90000-0001',
          trailingWidget: const Text('R\$ 166 a receber'),
          trailing: 'ignored',
          onTap: () {},
        );
    await tester.pumpWidget(host(row()));
    expect(find.text('ignored'), findsNothing);
    var title = tester.getRect(find.text('Ana Ribeiro'));
    var value = tester.getRect(find.text('R\$ 166 a receber'));
    expect(value.left, greaterThan(title.right));

    await tester.pumpWidget(host(MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(2)),
      child: row(),
    )));
    title = tester.getRect(find.text('Ana Ribeiro'));
    value = tester.getRect(find.text('R\$ 166 a receber'));
    expect(value.top, greaterThan(title.bottom - 1));
    expect(value.left, title.left);
  });
}
