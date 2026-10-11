import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/services/segment_config_service.dart';

void main() {
  tearDown(() => SegmentConfigService().clear());

  group('SegmentConfigService.useFinancial', () {
    test('defaults to on, also for the segment default', () {
      final service = SegmentConfigService()..clear();
      expect(service.useFinancial, isTrue);
      expect(service.segmentUseFinancialDefault, isTrue);
    });

    test('setCompanyConfig without useFinancial keeps it on', () {
      final service = SegmentConfigService()
        ..setCompanyConfig(
          fieldService: true,
          useScheduling: true,
          useDeviceManagement: false,
          useContracts: false,
        );
      expect(service.useFinancial, isTrue);
    });

    test('setCompanyConfig and clear', () {
      final service = SegmentConfigService()
        ..setCompanyConfig(
          fieldService: true,
          useScheduling: true,
          useDeviceManagement: false,
          useContracts: false,
          useFinancial: false,
        );
      expect(service.useFinancial, isFalse);
      service.clear();
      expect(service.useFinancial, isTrue);
    });
  });

  group('SegmentConfigProvider.setUseFinancial', () {
    test('updates the service and notifies only on change', () {
      final provider = SegmentConfigProvider();
      var notified = 0;
      provider.addListener(() => notified++);

      provider.setUseFinancial(true);
      expect(notified, 0);

      provider.setUseFinancial(false);
      expect(notified, 1);
      expect(provider.useFinancial, isFalse);
      expect(SegmentConfigService().useFinancial, isFalse);
    });
  });
}
