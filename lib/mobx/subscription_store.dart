import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:mobx/mobx.dart';
import 'package:praticos/global.dart';
import 'package:praticos/models/subscription.dart';
import 'package:praticos/services/subscription_service.dart';

part 'subscription_store.g.dart';

/// Source of the company document data.
typedef CompanyDocStream = Stream<Map<String, dynamic>?> Function(String companyId);

Stream<Map<String, dynamic>?> _firestoreCompanyDoc(String companyId) =>
    FirebaseFirestore.instance
        .collection(SubscriptionUsagePaths.collection)
        .doc(companyId)
        .snapshots()
        .map((snapshot) => snapshot.data());

class SubscriptionStore = _SubscriptionStore with _$SubscriptionStore;

/// Live subscription of the current company.
///
/// Listens to `companies/{companyId}`, exposes `subscription` and keeps
/// [Global.subscription] in sync for [FeatureGateService], `OrderStore`,
/// `PhotoService` and `PdfService`. Also links the RevenueCat customer to the
/// company (`appUserID = companyId`).
abstract class _SubscriptionStore with Store {
  /// Company document source. Tests replace it with a fake stream.
  CompanyDocStream companyDocStream = _firestoreCompanyDoc;

  /// Links the RevenueCat customer to the company. No-op without SDK key.
  Future<void> Function(String companyId) identify =
      SubscriptionService.instance.initialize;

  /// Resets the RevenueCat customer. No-op when the SDK is not configured.
  Future<void> Function() resetIdentity = SubscriptionService.instance.logout;

  StreamSubscription<Map<String, dynamic>?>? _listener;

  @observable
  String? companyId;

  @observable
  Subscription? latest;

  /// Subscription written by the server, or null (Free) when absent.
  @computed
  Subscription? get subscription => latest;

  /// Plan in force now (expired plans count as Free).
  @computed
  SubscriptionPlan get effectivePlan =>
      (latest ?? Subscription()).effectivePlan(DateTime.now());

  /// Starts following [id]. Called after login and on company switch.
  @action
  Future<void> bindCompany(String id) async {
    if (companyId == id && _listener != null) return;

    // Swap state synchronously so concurrent calls cannot interleave.
    final old = _listener;
    companyId = id;
    latest = null;
    Global.subscription = null;
    _listener = companyDocStream(id).listen(
      (data) {
        if (companyId != id) return;
        applyCompanyDoc(data);
      },
      onError: (Object e) => debugPrint('SubscriptionStore: listener error: $e'),
    );
    await old?.cancel();

    try {
      await identify(id);
    } catch (e) {
      // RevenueCat failures must not block login or the Firestore listener.
      debugPrint('SubscriptionStore: RevenueCat identify failed: $e');
    }
  }

  /// Applies a company document snapshot.
  @action
  void applyCompanyDoc(Map<String, dynamic>? data) {
    final raw = data?['subscription'];
    Subscription? parsed;
    if (raw is Map) {
      try {
        parsed = Subscription.fromJson(Map<String, dynamic>.from(raw));
      } catch (e) {
        debugPrint('SubscriptionStore: invalid subscription data: $e');
      }
    }
    latest = parsed;
    Global.subscription = parsed;
  }

  /// Stops following the company. Called on logout and account deletion.
  @action
  Future<void> unbind() async {
    await _listener?.cancel();
    _listener = null;
    companyId = null;
    latest = null;
    Global.subscription = null;

    try {
      await resetIdentity();
    } catch (e) {
      debugPrint('SubscriptionStore: RevenueCat logout failed: $e');
    }
  }
}
