import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart' show ObservableList;
import 'package:praticos/mobx/auth_store.dart';
import 'package:praticos/mobx/invite_store.dart';
import 'package:praticos/models/invite.dart';
import 'package:praticos/screens/auth_wrapper.dart';

class _FakeAuthStore implements AuthStore {
  final reload = Completer<void>();
  int reloadCalls = 0;

  @override
  Future<void> reloadUserAndCompany() {
    reloadCalls++;
    return reload.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeInvites implements InviteStore {
  _FakeInvites({this.error, this.count = 0});

  final String? error;
  final int count;

  @override
  Future<void> loadPendingInvites() async {}

  @override
  String? get errorMessage => error;

  @override
  ObservableList<Invite> get pendingInvites =>
      ObservableList.of(List.generate(count, (_) => Invite()));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('hasPendingInvites', () {
    test('a failed load is an error, not "no invites"', () async {
      await expectLater(
        hasPendingInvites(_FakeInvites(error: 'unavailable')),
        throwsStateError,
      );
    });

    test('answers whether there are invites', () async {
      expect(await hasPendingInvites(_FakeInvites(count: 1)), isTrue);
      expect(await hasPendingInvites(_FakeInvites()), isFalse);
    });
  });

  testWidgets('accepted invite reloads the company, then restarts at the root',
      (tester) async {
    final auth = _FakeAuthStore();
    final navigatorKey = GlobalKey<NavigatorState>();
    late BuildContext rootContext;
    var rootBuilds = 0;

    await tester.pumpWidget(
      CupertinoApp(
        navigatorKey: navigatorKey,
        routes: {
          '/': (context) {
            rootContext = context;
            rootBuilds++;
            return const Text('root');
          },
        },
      ),
    );
    navigatorKey.currentState!.push(
      CupertinoPageRoute<void>(builder: (_) => const Text('invite detail')),
    );
    await tester.pumpAndSettle();
    final buildsBefore = rootBuilds;

    final done = enterCompanyAfterInvite(rootContext, auth);
    await tester.pump();

    // The stale store must not reach the root: it would open onboarding.
    expect(auth.reloadCalls, 1);
    expect(rootBuilds, buildsBefore);
    expect(find.text('invite detail'), findsOneWidget);

    auth.reload.complete();
    await done;
    await tester.pumpAndSettle();

    expect(find.text('invite detail'), findsNothing);
    expect(find.text('root'), findsOneWidget);
    expect(rootBuilds, greaterThan(buildsBefore));
  });
}
