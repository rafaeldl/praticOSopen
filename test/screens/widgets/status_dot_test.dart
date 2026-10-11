import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/screens/widgets/status_dot.dart';
import 'package:praticos/theme/app_colors.dart';

void main() {
  testWidgets('renders a circle of the given size and color', (tester) async {
    await tester.pumpWidget(const CupertinoApp(
      home: Center(child: StatusDot(color: AppColors.danger, size: 10)),
    ));
    final box = tester.getSize(find.byType(StatusDot));
    expect(box, const Size(10, 10));
    final deco = tester
        .widget<Container>(find.descendant(
            of: find.byType(StatusDot), matching: find.byType(Container)))
        .decoration as BoxDecoration;
    expect(deco.shape, BoxShape.circle);
    expect(deco.color!.toARGB32(), AppColors.danger.color.toARGB32());
  });

  testWidgets('resolves dark variant', (tester) async {
    await tester.pumpWidget(const CupertinoApp(
      theme: CupertinoThemeData(brightness: Brightness.dark),
      home: Center(child: StatusDot(color: AppColors.success)),
    ));
    final deco = tester
        .widget<Container>(find.descendant(
            of: find.byType(StatusDot), matching: find.byType(Container)))
        .decoration as BoxDecoration;
    expect(deco.color!.toARGB32(), AppColors.success.darkColor.toARGB32());
    expect(tester.getSize(find.byType(StatusDot)), const Size(8, 8));
  });
}
