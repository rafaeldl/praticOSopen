import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/theme/app_typography.dart';

void main() {
  test('title is the iOS Large Title size (34 bold)', () {
    expect(AppTypography.title.fontSize, 34);
    expect(AppTypography.title.fontWeight, FontWeight.w700);
  });

  test('line heights are multipliers, never fixed pixel heights', () {
    for (final style in [
      AppTypography.title,
      AppTypography.highlight,
      AppTypography.body,
      AppTypography.bodyStrong,
      AppTypography.callout,
      AppTypography.label,
    ]) {
      expect(style.height == null || style.height! < 2, isTrue);
    }
  });

  testWidgets('text grows with the system text scaler (Dynamic Type)', (
    tester,
  ) async {
    Future<double> heightAt(double scale) async {
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: Center(child: Text('Ordens', style: AppTypography.body)),
          ),
        ),
      );
      return tester.getSize(find.text('Ordens')).height;
    }

    final normal = await heightAt(1.0);
    final large = await heightAt(2.0);
    expect(large, closeTo(normal * 2, 1));
  });
}
