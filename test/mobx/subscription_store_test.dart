import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/global.dart';
import 'package:praticos/mobx/subscription_store.dart';
import 'package:praticos/models/subscription.dart';

void main() {
  late SubscriptionStore store;
  late Map<String, StreamController<Map<String, dynamic>?>> docs;
  late List<String> identified;
  late int resets;

  Future<void> flush() => Future<void>.delayed(Duration.zero);

  setUp(() {
    docs = {};
    identified = [];
    resets = 0;
    Global.subscription = null;
    store = SubscriptionStore()
      ..companyDocStream = (id) {
        final controller = StreamController<Map<String, dynamic>?>();
        docs[id] = controller;
        return controller.stream;
      }
      ..identify = (id) async {
        identified.add(id);
      }
      ..resetIdentity = () async {
        resets++;
      };
  });

  tearDown(() => Global.subscription = null);

  test('bindCompany identifies the company and follows its document', () async {
    await store.bindCompany('c1');

    expect(identified, ['c1']);
    expect(store.companyId, 'c1');

    docs['c1']!.add({
      'subscription': {'plan': 'pro', 'status': 'active'},
    });
    await flush();

    expect(store.subscription!.plan, SubscriptionPlan.pro);
    expect(store.effectivePlan, SubscriptionPlan.pro);
    expect(Global.subscription, same(store.subscription));
  });

  test('live updates replace the subscription', () async {
    await store.bindCompany('c1');
    docs['c1']!.add({'subscription': {'plan': 'starter'}});
    await flush();
    docs['c1']!.add({'subscription': {'plan': 'business'}});
    await flush();

    expect(store.subscription!.plan, SubscriptionPlan.business);
    expect(Global.subscription!.plan, SubscriptionPlan.business);
  });

  test('company without subscription is Free', () async {
    await store.bindCompany('c1');
    docs['c1']!.add({'name': 'ACME'});
    await flush();

    expect(store.subscription, isNull);
    expect(Global.subscription, isNull);
    expect(store.effectivePlan, SubscriptionPlan.free);
  });

  test('expired plan is Free in effectivePlan', () async {
    await store.bindCompany('c1');
    docs['c1']!.add({
      'subscription': {
        'plan': 'pro',
        'status': 'cancelled',
        'expiresAt': DateTime.now().subtract(const Duration(days: 1)).toUtc().toIso8601String(),
      },
    });
    await flush();

    expect(store.subscription!.plan, SubscriptionPlan.pro);
    expect(store.effectivePlan, SubscriptionPlan.free);
  });

  test('malformed subscription does not throw and counts as Free', () async {
    await store.bindCompany('c1');
    docs['c1']!.add({
      'subscription': {'limits': 'oops'},
    });
    await flush();

    expect(store.subscription, isNull);
    expect(store.effectivePlan, SubscriptionPlan.free);
  });

  test('binding the same company twice keeps one listener', () async {
    await store.bindCompany('c1');
    await store.bindCompany('c1');

    expect(identified, ['c1']);
    expect(docs.length, 1);
  });

  test('switching companies cancels the previous listener', () async {
    await store.bindCompany('c1');
    docs['c1']!.add({'subscription': {'plan': 'business'}});
    await flush();

    await store.bindCompany('c2');

    expect(docs['c1']!.hasListener, isFalse);
    expect(identified, ['c1', 'c2']);
    expect(store.subscription, isNull);
    expect(Global.subscription, isNull);

    docs['c2']!.add({'subscription': {'plan': 'starter'}});
    await flush();
    expect(Global.subscription!.plan, SubscriptionPlan.starter);
  });

  test('unbind clears the state and logs out of RevenueCat', () async {
    await store.bindCompany('c1');
    docs['c1']!.add({'subscription': {'plan': 'pro'}});
    await flush();

    await store.unbind();

    expect(docs['c1']!.hasListener, isFalse);
    expect(store.subscription, isNull);
    expect(store.companyId, isNull);
    expect(Global.subscription, isNull);
    expect(resets, 1);
  });

  test('RevenueCat failure does not stop the Firestore listener', () async {
    store.identify = (_) async => throw StateError('boom');

    await store.bindCompany('c1');
    docs['c1']!.add({'subscription': {'plan': 'pro'}});
    await flush();

    expect(store.subscription!.plan, SubscriptionPlan.pro);
  });
}
