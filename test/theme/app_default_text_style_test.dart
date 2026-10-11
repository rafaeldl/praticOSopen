import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/theme/app_default_text_style.dart';

void main() {
  testWidgets('loose Text under MaterialApp gets the Cupertino style, '
      'not the underlined error style', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => CupertinoTheme(
          data: const CupertinoThemeData(),
          child: AppDefaultTextStyle(child: child!),
        ),
        home: const CupertinoPageScaffold(child: Center(child: Text('Oi'))),
      ),
    );

    final style = DefaultTextStyle.of(tester.element(find.text('Oi'))).style;
    expect(style.decoration, isNot(TextDecoration.underline));
    expect(style.decorationColor, isNot(const Color(0xFFFFFF00)));
    expect(style.fontSize, 17);
  });
}
