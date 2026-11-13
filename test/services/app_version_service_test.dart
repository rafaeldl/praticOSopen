import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/services/app_version_service.dart';

void main() {
  group('parseAppVersion', () {
    test('reads dotted numbers and ignores build and suffix', () {
      expect(parseAppVersion('1.109.0'), [1, 109, 0]);
      expect(parseAppVersion('1.109.0+204'), [1, 109, 0]);
      expect(parseAppVersion('1.110.0-rc'), [1, 110, 0]);
      expect(parseAppVersion(' 2.0 '), [2, 0]);
    });

    test('returns null for anything that is not a version', () {
      expect(parseAppVersion(null), isNull);
      expect(parseAppVersion(''), isNull);
      expect(parseAppVersion('abc'), isNull);
      expect(parseAppVersion('1..2'), isNull);
    });
  });

  test('compareAppVersions compares numerically, missing parts are zero', () {
    expect(compareAppVersions([1, 56, 0], [1, 110, 0]), lessThan(0));
    expect(compareAppVersions([1, 110, 0], [1, 110]), 0);
    expect(compareAppVersions([2, 0, 0], [1, 999, 9]), greaterThan(0));
  });

  group('AppVersionConfig.fromMap', () {
    const data = {
      'iosMinimum': '1.110.0',
      'iosRecommended': '1.111.0',
      'androidMinimum': ' ',
      'androidRecommended': '1.112.0',
    };

    test('picks the fields of the platform', () {
      expect(
        AppVersionConfig.fromMap(data, TargetPlatform.iOS),
        const AppVersionConfig(minimum: '1.110.0', recommended: '1.111.0'),
      );
      expect(
        AppVersionConfig.fromMap(data, TargetPlatform.android),
        const AppVersionConfig(recommended: '1.112.0'),
      );
    });

    test('missing document or other platform is disabled', () {
      expect(AppVersionConfig.fromMap(null, TargetPlatform.iOS),
          AppVersionConfig.disabled);
      expect(AppVersionConfig.fromMap(data, TargetPlatform.macOS),
          AppVersionConfig.disabled);
      expect(AppVersionConfig.fromMap({'iosMinimum': 110}, TargetPlatform.iOS),
          AppVersionConfig.disabled);
    });
  });

  group('evaluateAppVersion', () {
    test('starts off: empty config never asks for an update', () {
      expect(evaluateAppVersion('1.56.0', AppVersionConfig.disabled),
          AppVersionStatus.upToDate);
    });

    test('below the minimum is required', () {
      expect(
        evaluateAppVersion(
            '1.56.0', const AppVersionConfig(minimum: '1.110.0')),
        AppVersionStatus.updateRequired,
      );
    });

    test('at the minimum but below the recommended is recommended', () {
      expect(
        evaluateAppVersion('1.110.0',
            const AppVersionConfig(minimum: '1.110.0', recommended: '1.111.0')),
        AppVersionStatus.updateRecommended,
      );
    });

    test('required wins over recommended', () {
      expect(
        evaluateAppVersion('1.0.0',
            const AppVersionConfig(minimum: '1.110.0', recommended: '1.111.0')),
        AppVersionStatus.updateRequired,
      );
    });

    test('at or above both is up to date', () {
      expect(
        evaluateAppVersion('1.111.0',
            const AppVersionConfig(minimum: '1.110.0', recommended: '1.111.0')),
        AppVersionStatus.upToDate,
      );
    });

    test('unreadable versions never block', () {
      expect(evaluateAppVersion('?', const AppVersionConfig(minimum: '9.0.0')),
          AppVersionStatus.upToDate);
      expect(
          evaluateAppVersion('1.0.0', const AppVersionConfig(minimum: 'x')),
          AppVersionStatus.upToDate);
    });
  });

  test('store page per platform', () {
    expect(storeUrlFor(TargetPlatform.iOS), appStoreUrl);
    expect(storeUrlFor(TargetPlatform.android), playStoreUrl);
    expect(storeUrlFor(TargetPlatform.windows), isNull);
  });
}
