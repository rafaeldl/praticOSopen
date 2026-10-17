import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show CircularProgressIndicator;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:praticos/main.dart' as app;

/// Store screenshots (App Store and Google Play) of the redesigned app.
///
/// Signs in with the demo account of [TEST_LOCALE] (docs/DEMO_ACCOUNTS.md)
/// and captures, in store order:
///
/// 01_ai_order   "Nova OS" filled by the assistant from what was said
/// 02_home       Início: the orders and what to do next
/// 03_order      An order: customer, status, next step
/// 04_agenda     Agenda
/// 05_financial  Financeiro ("Falta receber")
/// 06_checklist  A checklist of the order, with photos
/// 07_customer   The customer, with their orders
///
/// A screen that cannot be reached is skipped (logged with ⚠️), never
/// replaced by another one, so a file name always means the same screen.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture store screenshots', (WidgetTester tester) async {
    const locale = String.fromEnvironment('TEST_LOCALE', defaultValue: 'pt-BR');
    const brightness = String.fromEnvironment(
      'TEST_BRIGHTNESS',
      defaultValue: 'light',
    );
    const forceLogout = bool.fromEnvironment(
      'FORCE_LOGOUT',
      defaultValue: true,
    );
    print('📱 Store screenshots · $locale · $brightness');

    tester.platformDispatcher.platformBrightnessTestValue = brightness == 'dark'
        ? Brightness.dark
        : Brightness.light;

    app.main();
    await _wait(tester, 6);

    if (_byId('email_login_link').evaluate().isEmpty) {
      if (forceLogout) {
        print('Already signed in: signing out to use the demo account');
        await _performLogout(tester);
      } else {
        print('Already signed in: keeping the current account');
      }
    }

    // The video records the screen itself: keep the live surface.
    if (!_videoMode) await binding.convertFlutterSurfaceToImage();

    if (_byId('email_login_link').evaluate().isNotEmpty) {
      await _performLogin(tester, locale);
    }

    await _waitFor(tester, () => _byIdPrefix(tester, 'order_card_') != null);
    await _wait(tester, 3);
    await _dismissBanners(tester);

    if (_videoMode) {
      await _videoFlow(tester, locale);
      return;
    }

    // 02 Início
    await _shot(binding, tester, '02_home');

    // 02 Order, 06 checklist and 07 customer all start from one order.
    // The order of the demo's first customer (it has the checklist).
    final hero = find.text(_heroCustomer[locale] ?? '');
    final orderCard = hero.evaluate().isNotEmpty ? hero.first : _pickOrderCard(tester);
    if (orderCard != null) {
      await tester.tap(orderCard);
      await _waitImages(tester);
      await _shot(binding, tester, '03_order');

      final form = _firstKeyPrefix(tester, 'form_');
      if (form != null) {
        await tester.ensureVisible(form);
        await _wait(tester, 1);
        await tester.tap(form);
        await _waitImages(tester);
        await _shot(binding, tester, '06_checklist');
        await _pop(tester);
      } else {
        print('⚠️ Order has no checklist: skipping 06_checklist');
      }

      await _pop(tester);
    } else {
      print('⚠️ No order on Início: skipping 03 and 06');
    }

    // 07 Customer: profile button → Clientes → the customer of the first
    // order (the order header's name opens the customer picker instead).
    final profile = _byId('home_profile_button');
    if (profile.evaluate().isNotEmpty) {
      await tester.tap(profile.first);
      await _wait(tester, 2);
      final customers = find.byKey(const ValueKey('more_row_customers'));
      if (customers.evaluate().isNotEmpty) {
        await tester.tap(customers.first);
        await _wait(tester, 3);
        final name = find.text(_heroCustomer[locale] ?? '');
        if (name.evaluate().isNotEmpty) {
          await tester.tap(name.first);
          await _waitImages(tester);
          await _shot(binding, tester, '07_customer');
          await _pop(tester);
        } else {
          print('⚠️ Customer not in the list: skipping 07_customer');
        }
        await _pop(tester);
      }
      await _pop(tester);
    } else {
      print('⚠️ Profile button not found: skipping 07_customer');
    }

    // 01 Nova OS filled by the assistant: "Falar" hears a fixed sentence
    // (ScriptedSpeechListener, SCREENSHOT_MODE) and the real assistant
    // fills customer, vehicle, services and parts.
    final add = _byId('add_order_button');
    if (add.evaluate().isNotEmpty) {
      await tester.tap(add.first);
      await _wait(tester, 3);
      // "Falar" shows once the server says the assistant is on.
      final talk = find.byKey(const ValueKey('assistant_talk'));
      await _waitFor(tester, () => talk.evaluate().isNotEmpty, seconds: 12);
      if (talk.evaluate().isEmpty) {
        print('⚠️ Assistant off: no "Falar", skipping 01_ai_order');
      } else {
        await tester.tap(talk.first);
        await _wait(tester, 7);
        await tester.tap(find.byKey(const ValueKey('assistant_stop')).first);
        await _wait(tester, 2);
        await _waitFor(
          tester,
          () => find.byKey(const ValueKey('assistant_busy')).evaluate().isEmpty,
          seconds: 60,
        );
        await _waitImages(tester);
        await _shot(binding, tester, '01_ai_order');
      }
      final close = find.byIcon(CupertinoIcons.xmark);
      if (close.evaluate().isNotEmpty) {
        await tester.tap(close.first);
      } else {
        await tester.state<NavigatorState>(find.byType(Navigator).first).maybePop();
      }
      await _wait(tester, 2);
      // Filled: "Descartar?" asks first.
      final discard = find.byType(CupertinoDialogAction);
      if (discard.evaluate().isNotEmpty) {
        await tester.tap(discard.last);
        await _wait(tester, 2);
      }
    } else {
      print('⚠️ "+" not found: skipping 01_ai_order');
    }

    // 04 Agenda
    if (await _openTab(tester, 'tab_agenda')) {
      await _wait(tester, 3);
      await _shot(binding, tester, '04_agenda');
    }

    // 05 Financeiro
    if (await _openTab(tester, 'tab_financial')) {
      await _wait(tester, 4);
      await _shot(binding, tester, '05_financial');
    }

    await _openTab(tester, 'tab_home');
    print('✅ Store screenshots done ($locale · $brightness)');
  });
}

// ------------------------------------------------------------ store video

/// `--dart-define=STORE_VIDEO=true`: instead of screenshots, walks the
/// store video at a watchable pace while the simulator records the screen
/// (ios/fastlane `store_video`). Prints 🎬 marks where the video starts and
/// ends, to cut the recording.
const _videoMode = bool.fromEnvironment('STORE_VIDEO');

Future<void> _videoFlow(WidgetTester tester, String locale) async {
  print('🎬 start ${DateTime.now().millisecondsSinceEpoch}');
  await _wait(tester, 2);

  // Nova OS: Falar, the sentence shows up as it is "heard", then the
  // assistant fills the order.
  final add = _byId('add_order_button');
  if (add.evaluate().isEmpty) throw StateError('"+" not found');
  await tester.tap(add.first);
  await _wait(tester, 2);
  final talk = find.byKey(const ValueKey('assistant_talk'));
  await _waitFor(tester, () => talk.evaluate().isNotEmpty, seconds: 12);
  if (talk.evaluate().isEmpty) throw StateError('Assistant off: no "Falar"');
  await tester.tap(talk.first);
  await _wait(tester, 5);
  await tester.tap(find.byKey(const ValueKey('assistant_stop')).first);
  await _wait(tester, 1);
  await _waitFor(
    tester,
    () => find.byKey(const ValueKey('assistant_busy')).evaluate().isEmpty,
    seconds: 60,
  );
  await _wait(tester, 5);
  await tester.tap(find.byIcon(CupertinoIcons.xmark).first);
  await _wait(tester, 1);
  final discard = find.byType(CupertinoDialogAction);
  if (discard.evaluate().isNotEmpty) await tester.tap(discard.last);
  await _wait(tester, 2);

  // An order, then what is left to collect.
  final hero = find.text(_heroCustomer[locale] ?? '');
  if (hero.evaluate().isNotEmpty) {
    await tester.tap(hero.first);
    await _wait(tester, 4);
    await _pop(tester);
    await _wait(tester, 1);
  }
  if (await _openTab(tester, 'tab_financial')) await _wait(tester, 3);
  print('🎬 end ${DateTime.now().millisecondsSinceEpoch}');
}

// ---------------------------------------------------------------- helpers

/// Customer of the first order of each demo account
/// (firebase/scripts/seed_demo_store_data.js).
const _heroCustomer = {
  'pt-BR': 'Marcos Pereira',
  'en-US': 'Mark Peterson',
  'es-ES': 'Marcos Pérez',
};

/// Pumps for [seconds] without waiting for the app to settle (Firestore
/// streams and MobX observers keep it busy forever).
Future<void> _wait(WidgetTester tester, int seconds) async {
  for (var i = 0; i < seconds * 4; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _waitFor(
  WidgetTester tester,
  bool Function() done, {
  int seconds = 30,
}) async {
  for (var i = 0; i < seconds * 2 && !done(); i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

/// Waits for the screen to open and its photos to load (spinners gone).
Future<void> _waitImages(WidgetTester tester) async {
  await _wait(tester, 5);
  await _waitFor(
    tester,
    () =>
        find.byType(CircularProgressIndicator).evaluate().isEmpty &&
        find.byType(CupertinoActivityIndicator).evaluate().isEmpty,
    seconds: 15,
  );
  await _wait(tester, 2);
}

Future<void> _shot(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
  String name,
) async {
  await tester.pump();
  print('📸 $name');
  await binding.takeScreenshot(name);
}

Finder _byId(String identifier) => find.byWidgetPredicate(
  (w) => w is Semantics && w.properties.identifier == identifier,
);

Finder? _byIdPrefix(WidgetTester tester, String prefix) {
  final finder = find.byWidgetPredicate(
    (w) =>
        w is Semantics &&
        (w.properties.identifier?.startsWith(prefix) ?? false),
  );
  return finder.evaluate().isEmpty ? null : finder.first;
}

Finder? _firstKeyPrefix(WidgetTester tester, String prefix) {
  final finder = find.byWidgetPredicate(
    (w) =>
        w.key is ValueKey<String> &&
        (w.key as ValueKey<String>).value.startsWith(prefix),
    skipOffstage: false,
  );
  return finder.evaluate().isEmpty ? null : finder.first;
}

/// The order card to open: the first one on Início (the list puts what
/// needs attention first).
Finder? _pickOrderCard(WidgetTester tester) => _byIdPrefix(tester, 'order_card_');

Future<bool> _openTab(WidgetTester tester, String id) async {
  final tab = _byId(id);
  if (tab.evaluate().isEmpty) {
    print('⚠️ Tab $id not found');
    return false;
  }
  await tester.tap(tab.first);
  await _wait(tester, 1);
  return true;
}

/// Back one screen on the navigator that is showing it.
Future<void> _pop(WidgetTester tester) async {
  final navigators = find.byType(Navigator);
  for (final element in navigators.evaluate().toList().reversed) {
    final state = (element as StatefulElement).state as NavigatorState;
    if (state.canPop()) {
      state.pop();
      break;
    }
  }
  await _wait(tester, 2);
}

/// Closes one-off banners (WhatsApp setup, tips) so Início shows the
/// orders.
Future<void> _dismissBanners(WidgetTester tester) async {
  final close = find.byIcon(CupertinoIcons.xmark);
  if (close.evaluate().isNotEmpty) {
    await tester.tap(close.first);
    await _wait(tester, 1);
  }
}

/// Signs out from the profile screen (profile button on Início → "Sair").
Future<void> _performLogout(WidgetTester tester) async {
  final profile = _byId('home_profile_button');
  if (profile.evaluate().isEmpty) {
    print('⚠️ Profile button not found for sign out');
    return;
  }
  await tester.tap(profile.first);
  await _wait(tester, 2);

  final logout = find.text('Sair', skipOffstage: false).evaluate().isNotEmpty
      ? find.text('Sair', skipOffstage: false)
      : find.text('Sign Out', skipOffstage: false).evaluate().isNotEmpty
      ? find.text('Sign Out', skipOffstage: false)
      : find.text('Cerrar Sesión', skipOffstage: false);
  if (logout.evaluate().isEmpty) {
    print('⚠️ Sign out row not found');
    return;
  }
  await tester.ensureVisible(logout.first);
  await _wait(tester, 1);
  await tester.tap(logout.first);
  await _wait(tester, 1);

  final actions = find.descendant(
    of: find.byType(CupertinoAlertDialog),
    matching: find.byType(CupertinoDialogAction),
  );
  if (actions.evaluate().isNotEmpty) {
    await tester.tap(actions.last);
  }
  await _wait(tester, 4);
}

String _emailFor(String locale) => switch (locale) {
  'en-US' => 'demo-en@praticos.com.br',
  'es-ES' => 'demo-es@praticos.com.br',
  _ => 'demo-pt@praticos.com.br',
};

Future<void> _performLogin(WidgetTester tester, String locale) async {
  final email = _emailFor(locale);
  print('🔐 Signing in as $email');

  await tester.tap(_byId('email_login_link').first);
  await _wait(tester, 2);

  final emailField = find.descendant(
    of: _byId('email_field'),
    matching: find.byType(EditableText),
  );
  final passwordField = find.descendant(
    of: _byId('password_field'),
    matching: find.byType(EditableText),
  );
  await tester.enterText(emailField.first, email);
  await tester.enterText(passwordField.first, 'Demo@2024!');
  FocusManager.instance.primaryFocus?.unfocus();
  await _wait(tester, 1);

  final button = _byId('email_login_button');
  await tester.ensureVisible(button.first);
  await tester.tap(button.first);
  await _wait(tester, 10);
  // A failed sign-in (no network on a fresh emulator) leaves the login
  // screen up: stop here instead of saving it as every screenshot.
  expect(
    _byId('email_login_button'),
    findsNothing,
    reason: 'Sign-in failed for $email',
  );
}
