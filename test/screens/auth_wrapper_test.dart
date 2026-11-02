import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/mobx/auth_store.dart';
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

void main() {
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
