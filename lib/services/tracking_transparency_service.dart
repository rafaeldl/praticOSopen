import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/widgets.dart';

/// Pedido de permissao de rastreamento do iOS (App Tracking Transparency).
///
/// O iOS mostra esse alerta uma unica vez por instalacao e somente com o app
/// ativo: pedido antes disso, o sistema nega em silencio e o rastreamento fica
/// negado para sempre naquela instalacao. Por isso o servico espera o app
/// ficar ativo antes de pedir, e adia o pedido se isso nao acontecer.
///
/// Quem controla se o alerta ja apareceu e o proprio sistema, via
/// [TrackingStatus.notDetermined]. O servico nao guarda estado proprio, para
/// nunca bloquear um pedido que ainda nao aconteceu de fato.
///
/// A Apple exige o alerta antes de qualquer coleta que possa rastrear o
/// usuario, entao a chamada fica no inicio do app (`main`), antes do login.
class TrackingTransparencyService {
  TrackingTransparencyService._()
      : _isIOS = Platform.isIOS,
        _readStatus = _defaultReadStatus,
        _requestAuthorization = _defaultRequestAuthorization,
        _syncConsent = _defaultSyncConsent,
        _readLifecycle = _defaultReadLifecycle,
        _wait = _defaultWait;

  @visibleForTesting
  TrackingTransparencyService.withHooks({
    required bool isIOS,
    required Future<TrackingStatus> Function() readStatus,
    required Future<TrackingStatus> Function() requestAuthorization,
    required Future<void> Function(TrackingStatus status) syncConsent,
    required AppLifecycleState? Function() readLifecycle,
    required Future<void> Function(Duration duration) wait,
  })  : _isIOS = isIOS,
        _readStatus = readStatus,
        _requestAuthorization = requestAuthorization,
        _syncConsent = syncConsent,
        _readLifecycle = readLifecycle,
        _wait = wait;

  static final TrackingTransparencyService instance =
      TrackingTransparencyService._();

  /// Intervalo entre duas checagens do estado do app.
  static const _activationCheckInterval = Duration(milliseconds: 200);

  /// Numero de checagens antes de adiar o pedido (~5s no total).
  static const _maxActivationChecks = 25;

  final bool _isIOS;
  final Future<TrackingStatus> Function() _readStatus;
  final Future<TrackingStatus> Function() _requestAuthorization;
  final Future<void> Function(TrackingStatus status) _syncConsent;
  final AppLifecycleState? Function() _readLifecycle;
  final Future<void> Function(Duration duration) _wait;

  bool _isRequestInFlight = false;

  Future<void> requestIfEligible() async {
    if (!_isIOS || _isRequestInFlight) return;

    _isRequestInFlight = true;
    try {
      final status = await _readStatus();

      if (status != TrackingStatus.notDetermined) {
        await _syncConsent(status);
        return;
      }

      if (!await _waitUntilActive()) {
        // Adia em vez de queimar o unico alerta que o sistema permite
        debugPrint('ATT: app nao ficou ativo, pedido adiado');
        return;
      }

      final newStatus = await _requestAuthorization();
      await _syncConsent(newStatus);
    } catch (e, stack) {
      debugPrint('Error requesting ATT permission: $e');
      debugPrintStack(stackTrace: stack);
    } finally {
      _isRequestInFlight = false;
    }
  }

  Future<bool> _waitUntilActive() async {
    for (var attempt = 0; attempt < _maxActivationChecks; attempt++) {
      if (_readLifecycle() == AppLifecycleState.resumed) return true;
      await _wait(_activationCheckInterval);
    }
    return _readLifecycle() == AppLifecycleState.resumed;
  }

  static Future<TrackingStatus> _defaultReadStatus() =>
      AppTrackingTransparency.trackingAuthorizationStatus;

  static Future<TrackingStatus> _defaultRequestAuthorization() =>
      AppTrackingTransparency.requestTrackingAuthorization();

  static Future<void> _defaultSyncConsent(TrackingStatus status) {
    final granted = status == TrackingStatus.authorized;
    return FirebaseAnalytics.instance.setConsent(
      analyticsStorageConsentGranted: true,
      adStorageConsentGranted: granted,
      adUserDataConsentGranted: granted,
      adPersonalizationSignalsConsentGranted: granted,
    );
  }

  static AppLifecycleState? _defaultReadLifecycle() =>
      WidgetsBinding.instance.lifecycleState;

  static Future<void> _defaultWait(Duration duration) =>
      Future<void>.delayed(duration);
}
