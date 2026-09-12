import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/services/tracking_transparency_service.dart';

void main() {
  group('TrackingTransparencyService.requestIfEligible', () {
    late int requests;
    late List<TrackingStatus> consentSyncs;
    late List<Duration> waits;

    setUp(() {
      requests = 0;
      consentSyncs = [];
      waits = [];
    });

    /// [lifecycle] e consumido em ordem; o ultimo valor repete.
    TrackingTransparencyService build({
      bool isIOS = true,
      TrackingStatus status = TrackingStatus.notDetermined,
      TrackingStatus resultStatus = TrackingStatus.authorized,
      List<AppLifecycleState?> lifecycle = const [AppLifecycleState.resumed],
    }) {
      var lifecycleReads = 0;
      return TrackingTransparencyService.withHooks(
        isIOS: isIOS,
        readStatus: () async => status,
        requestAuthorization: () async {
          requests++;
          return resultStatus;
        },
        syncConsent: (status) async => consentSyncs.add(status),
        readLifecycle: () {
          final index = lifecycleReads < lifecycle.length
              ? lifecycleReads
              : lifecycle.length - 1;
          lifecycleReads++;
          return lifecycle[index];
        },
        wait: (duration) async => waits.add(duration),
      );
    }

    test('does not request outside iOS', () async {
      await build(isIOS: false).requestIfEligible();

      expect(requests, 0);
      expect(consentSyncs, isEmpty);
    });

    test('syncs consent without asking when the system already decided', () async {
      await build(status: TrackingStatus.denied).requestIfEligible();

      expect(requests, 0);
      expect(consentSyncs, [TrackingStatus.denied]);
    });

    test('asks and syncs consent when the app is active', () async {
      await build().requestIfEligible();

      expect(requests, 1);
      expect(consentSyncs, [TrackingStatus.authorized]);
      expect(waits, isEmpty);
    });

    test('waits for the app to become active before asking', () async {
      // Pedir antes do app ativo faz o iOS negar em silencio, sem alerta
      await build(
        lifecycle: const [
          AppLifecycleState.inactive,
          AppLifecycleState.inactive,
          AppLifecycleState.resumed,
        ],
      ).requestIfEligible();

      expect(requests, 1);
      expect(waits, isNotEmpty);
      expect(consentSyncs, [TrackingStatus.authorized]);
    });

    test('does not ask when the app never becomes active', () async {
      await build(lifecycle: const [AppLifecycleState.inactive])
          .requestIfEligible();

      expect(requests, 0);
      expect(consentSyncs, isEmpty);
    });

    test('asks again on a later call while the system has no decision', () async {
      // Sem flag propria: se o alerta nao apareceu, o app tenta de novo
      final service = build(resultStatus: TrackingStatus.notDetermined);

      await service.requestIfEligible();
      await service.requestIfEligible();

      expect(requests, 2);
    });
  });
}
