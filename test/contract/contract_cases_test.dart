// Runs docs/web-app/contract-cases/*.json against the real app code, as
// test/models/permission_matrix_test.dart does with the RBAC file.
//
// A case wants `divergesIn.dart` merged over `correct ?? expect`. An entry in
// `divergesIn.dart` is what the app does today: when the app is fixed the test
// fails on purpose, and the entry goes away. See
// docs/web-app/business-rules-map.md.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Locale;

import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart';
import 'package:praticos/global.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/mobx/user_store.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/custom_field.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/payment_transaction.dart';
import 'package:praticos/models/permission.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/models/user_role.dart';
import 'package:praticos/screens/menu_navigation/home_groups.dart';
import 'package:praticos/services/authorization_service.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/services/segment_config_service.dart';
import 'package:praticos/utils/customer_utils.dart';
import 'package:praticos/utils/order_payment_math.dart';
import 'package:praticos/utils/payment_allocation.dart';
import 'package:praticos/utils/phone_format.dart';
import 'package:praticos/utils/receipt_plan.dart';
import 'package:praticos/utils/tax_id.dart';

const _dir = 'docs/web-app/contract-cases';
const _lang = 'dart';
const _languages = {'dart', 'functions', 'web'};
const _uid = 'me';
const _companyId = 'c1';
const _statuses = ['quote', 'approved', 'progress', 'done', 'canceled'];

/// Every file this runner reads. A new file with `dart` in `runsIn` must be
/// added here, or the "contract files" group fails.
const _covered = {
  'currency.json',
  'order-delete.json',
  'order-items.json',
  'order-permissions.json',
  'order-receive.json',
  'order-totals.json',
  'overdue.json',
  'payment-status.json',
  'payment-transactions.json',
  'phone.json',
  'receipts.json',
  'round-money.json',
  'segment-labels.json',
  'status-transitions.json',
  'tax-id.json',
  'visibility.json',
};

class _FirebaseMock extends MockFirebaseApp {
  @override
  Future<List<CoreInitializeResponse>> initializeCore() async => [
        CoreInitializeResponse(
          name: defaultFirebaseAppName,
          options: CoreFirebaseOptions(
            apiKey: '123',
            projectId: '123',
            appId: '123',
            messagingSenderId: '123',
            storageBucket: 'test.appspot.com',
          ),
          pluginConstants: {},
        ),
      ];
}

class _FakeUser implements auth.User {
  @override
  String get uid => _uid;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> _file(String file) =>
    jsonDecode(File('$_dir/$file').readAsStringSync()) as Map<String, dynamic>;

List<Map<String, dynamic>> _cases(String file) =>
    (_file(file)['cases'] as List).cast<Map<String, dynamic>>();

Map<String, dynamic> _base(Map c) =>
    ((c['correct'] ?? c['expect']) as Map).cast<String, dynamic>();

Map<String, dynamic>? _divergence(Map c, [String lang = _lang]) =>
    ((c['divergesIn'] as Map?)?[lang] as Map?)?.cast<String, dynamic>();

/// What this language must do today.
Map<String, dynamic> _want(Map c) => {..._base(c), ...?_divergence(c)};

double? _d(Object? v) => (v as num?)?.toDouble();

OrderService _service(Map s) => OrderService()..value = _d(s['value']);

OrderProduct _product(Map p) => OrderProduct()
  ..value = _d(p['value'])
  ..quantity = p['quantity'] as int?
  ..total = _d(p['total']);

Order _order(Map g) {
  final order = Order()
    ..id = 'o1'
    ..status = g['status'] as String?
    ..services = [for (final s in (g['services'] ?? []) as List) _service(s as Map)]
    ..products = [for (final p in (g['products'] ?? []) as List) _product(p as Map)]
    ..total = _d(g['total'])
    ..discount = _d(g['discount'])
    ..paidAmount = _d(g['paidAmount'])
    ..payment = g['payment'] as String?
    ..paid = g['payment'] == 'paid';
  order.transactions = [
    for (final t in (g['transactions'] ?? []) as List)
      PaymentTransaction.fromJson((t as Map).cast<String, dynamic>()),
  ];
  return order;
}

/// Same steps as OrderStore.updateTotal, on the real store.
OrderStore _storeWith(Order order) => OrderStore()
  ..deferSave = true
  ..order = order
  ..services = (order.services ?? []).asObservable()
  ..products = (order.products ?? []).asObservable();

void _setRole(String role) {
  final user = User()
    ..companies = [
      CompanyRoleAggr()
        ..company = (CompanyAggr()..id = _companyId)
        ..role = rolesTypeFromJson(role),
    ];
  AuthorizationService.setUserStore(
    UserStore()..user = ObservableStream<User>(const Stream.empty(), initialValue: user),
  );
}

Order _orderOf(bool isCreator, String status) => Order()
  ..status = status
  ..createdBy = (UserAggr()..id = isCreator ? _uid : 'someone-else');

int _unpriced(Order order) => [
      ...order.services!.where((s) => s.value == null),
      ...order.products!.where((p) => p.value == null),
    ].length;

void _applyItemOp(OrderStore store, Map op) {
  final order = store.order!;
  switch (op['kind']) {
    case 'addService':
      store.addService(_service(op));
    case 'addProduct':
      store.addProduct(_product(op));
    case 'removeService':
      store.deleteService(op['index'] as int);
    case 'removeProduct':
      store.deleteProduct(op['index'] as int);
    case 'editService':
      order.services![op['index'] as int].value = _d(op['value']);
      store.refreshLines();
    case 'editProduct':
      // Same as the order screen: the line total follows value × quantity.
      final line = order.products![op['index'] as int];
      if (op.containsKey('value')) line.value = _d(op['value']);
      if (op.containsKey('quantity')) line.quantity = op['quantity'] as int?;
      line.total = line.value == null ? null : line.value! * (line.quantity ?? 1);
      store.refreshLines();
    default:
      fail('unknown op ${op['kind']}');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestFirebaseCoreHostApi.setUp(_FirebaseMock());
    await Firebase.initializeApp();
    Global.currentUser = _FakeUser();
    Global.companyAggr = CompanyAggr()..id = _companyId;
  });

  group('contract files', () {
    final files = Directory(_dir)
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .where((name) => name.endsWith('.json'))
        .toList()
      ..sort();

    test('this runner reads every file that names it in runsIn', () {
      final mine = {
        for (final name in files)
          if ((_file(name)['runsIn'] as List).contains(_lang)) name,
      };
      expect(mine, _covered);
    });

    for (final name in files) {
      test('$name is well formed', () {
        final cases = _cases(name);
        final ids = cases.map((c) => c['id']).toList();
        expect(ids.toSet().length, ids.length, reason: 'repeated id');
        for (final c in cases) {
          final id = c['id'];
          final diverges = (c['divergesIn'] as Map?) ?? const {};
          expect(c.containsKey('correct') && c.containsKey('expect'), isFalse, reason: '$id: correct or expect');
          expect(c.containsKey('correct') || c.containsKey('expect'), isTrue, reason: '$id: no result');
          if (c.containsKey('correct')) {
            expect(diverges, isNotEmpty, reason: '$id: `correct` without `divergesIn`: move it to `expect`');
          }
          expect(_languages.containsAll(diverges.keys), isTrue, reason: '$id: unknown language');
          for (final lang in diverges.keys) {
            final today = {..._divergence(c, lang as String)!}..remove('offline');
            final base = _base(c);
            final differs = today.entries.any(
              (e) => jsonEncode(e.value) != jsonEncode(base[e.key]),
            );
            expect(
              differs || _divergence(c, lang)!.containsKey('offline'),
              isTrue,
              reason: '$id: `divergesIn.$lang` equals the decision: delete it',
            );
          }
        }
      });
    }
  });

  group('order-totals', () {
    for (final c in _cases('order-totals.json')) {
      test(c['id'], () {
        final g = (c['given'] as Map);
        final want = _want(c);
        final order = _order(g);
        final store = _storeWith(order)..updateTotal();
        expect(order.total, _d(want['total']));
        expect(OrderPaymentMath.computeTotal(order), _d(want['paymentMathTotal']));
        expect(_unpriced(order), want['unpricedCount']);
        expect(store.total, _d(want['total']));
      });
    }
  });

  group('round-money', () {
    for (final c in _cases('round-money.json')) {
      test(c['id'], () {
        final value = _d((c['given'] as Map)['value'])!;
        expect(OrderPaymentMath.roundMoney(value), _d(_want(c)['rounded']));
      });
    }
  });

  group('payment-status', () {
    for (final c in _cases('payment-status.json')) {
      test(c['id'], () {
        final g = c['given'] as Map;
        final want = _want(c);
        final order = _order({...g, 'payment': null});
        OrderPaymentMath.applyOrderStatus(order, g['status'] as String?);
        final payment = order.payment;
        expect(payment, want['payment']);
        expect(payment == 'paid', want['paid']);
        expect(OrderPaymentMath.remainingBalance(order), _d(want['remaining']));

        final clear = OrderPaymentMath.orderStatusPaymentUpdate(g['status'] as String?);
        final update = clear ??
            OrderPaymentMath.activeStatusPaymentUpdate(
              total: _d(g['total'])!,
              paidAmount: _d(g['paidAmount'])!,
            );
        expect(update['payment'], want['payment']);
        expect(update['paid'], want['paid']);
      });
    }
  });

  group('payment-transactions', () {
    for (final c in _cases('payment-transactions.json')) {
      test(c['id'], () {
        final g = (c['given'] as Map);
        final op = g['op'] as Map;
        final want = _want(c);
        final order = _order(g['order'] as Map);
        final amount = _d(op['amount']);

        final baseOffline = c['expectOffline'] as Map?;
        if (baseOffline != null) {
          final offline = {...baseOffline, ...?(_divergence(c)?['offline'] as Map?)};
          final tx = op['kind'] == 'addPayment'
              ? PaymentTransaction.payment(amount: amount!)
              : PaymentTransaction.discount(amount: amount!);
          final update = op['kind'] == 'addPayment'
              ? OrderPaymentMath.addPaymentUpdate(current: order, tx: tx)
              : OrderPaymentMath.addDiscountUpdate(current: order, tx: tx);
          expect(update['payment'], offline['payment']);
          expect(update['paid'], offline['paid']);
          if (offline['paidAmountIncrement'] != null) {
            expect((update['paidAmount'] as IncrementOp).by, _d(offline['paidAmountIncrement']));
          }
          if (offline['discountIncrement'] != null) {
            expect((update['discount'] as IncrementOp).by, _d(offline['discountIncrement']));
            expect((update['total'] as IncrementOp).by, _d(offline['totalIncrement']));
          }
        }

        void run() {
          switch (op['kind']) {
            case 'addPayment':
              OrderPaymentMath.addPayment(order, PaymentTransaction.payment(amount: amount!));
            case 'addDiscount':
              OrderPaymentMath.addDiscount(order, PaymentTransaction.discount(amount: amount!));
            case 'removeTransaction':
              final target = order.transactions!.firstWhere((t) => t.id == op['transactionId']);
              OrderPaymentMath.removeTransaction(order, target);
            case 'resetPayments':
              OrderPaymentMath.resetPayments(order);
            case 'markAsFullyPaid':
              OrderPaymentMath.markAsFullyPaid(
                order,
                (remaining) => PaymentTransaction.payment(amount: remaining),
              );
            default:
              fail('unknown op ${op['kind']}');
          }
        }

        if (want['error'] == 'asaasLocked') {
          expect(run, throwsA(isA<AsaasTransactionLockedException>()));
          return;
        }
        run();
        expect(order.total, _d(want['total']));
        expect(order.discount, _d(want['discount']));
        expect(order.paidAmount, _d(want['paidAmount']));
        expect(order.payment, want['payment']);
        expect(order.paid, want['paid']);
        expect(OrderPaymentMath.remainingBalance(order), _d(want['remaining']));
        if (want['transactionIds'] != null) {
          expect(order.transactions!.map((t) => t.id).toList(), want['transactionIds']);
        }
        if (want['transactionCount'] != null) {
          expect(order.transactions!.length, want['transactionCount']);
        }
      });
    }
  });

  group('order-items', () {
    for (final c in _cases('order-items.json')) {
      test(c['id'], () {
        final g = c['given'] as Map;
        final want = _want(c);
        final order = _order(g['order'] as Map);
        final store = _storeWith(order);
        _applyItemOp(store, g['op'] as Map);
        expect(order.total, _d(want['total']));
        expect(order.payment, want['payment']);
        expect(order.paid, want['paid']);
        expect(OrderPaymentMath.remainingBalance(order), _d(want['remaining']));
        expect(_unpriced(order), want['unpricedCount']);
      });
    }
  });

  group('status-transitions', () {
    final doc = _file('status-transitions.json');
    final sameStatus = (doc['sameStatus'] as Map)[_lang] as bool;
    for (final c in (doc['cases'] as List).cast<Map<String, dynamic>>()) {
      test(c['id'], () {
        final g = c['given'] as Map;
        _setRole(g['role'] as String);
        final from = g['from'] as String;
        final order = _orderOf(g['isCreator'] as bool, from);
        final allowed = (_want(c)['allowed'] as List).cast<String>();
        final authorization = AuthorizationService.instance;
        expect(authorization.getAvailableStatuses(order).toSet(), allowed.toSet());
        for (final to in _statuses) {
          expect(
            authorization.canChangeOrderStatus(order, to),
            to == from ? sameStatus : allowed.contains(to),
            reason: to,
          );
        }
      });
    }
  });

  group('order-permissions', () {
    for (final c in _cases('order-permissions.json')) {
      test(c['id'], () {
        final g = c['given'] as Map;
        final e = _want(c);
        final rules = c['firestoreRules'] as Map;
        _setRole(g['role'] as String);
        final order = _orderOf(g['isCreator'] as bool, g['status'] as String);
        final authorization = AuthorizationService.instance;
        expect(authorization.canAccessOrder(order), e['canAccess']);
        expect(authorization.canEditOrder(order), e['canEdit']);
        expect(authorization.canExecuteOrder(order), e['canExecute']);
        expect(authorization.canAssignOrder(order), e['canAssign']);
        expect(authorization.canDeleteOrder(order), e['canDelete']);
        expect(authorization.canEditOrderMainFields(order), e['canEditMainFields']);
        expect(authorization.canManageOrderForms(order), e['canManageForms']);
        // These two mirror firestore.rules; `update` is wider on purpose (gap).
        expect(rules['read'], e['canAccess']);
        expect(rules['delete'], e['canDelete']);
      });
    }
  });

  group('order-receive', () {
    for (final c in _cases('order-receive.json')) {
      test(c['id'], () {
        final g = c['given'] as Map;
        final want = _want(c);
        final role = rolesTypeFromJson(g['role']);
        final useFinancial = g['useFinancial'] as bool;
        expect(
          AuthorizationService.canReceiveOnOrderFor(
            role: role,
            userId: _uid,
            order: _orderOf(g['isCreator'] as bool, g['status'] as String),
            useFinancial: useFinancial,
          ),
          want['canReceive'],
        );
        expect(
          RolePermissions.hasPermissionInCompany(
            role!,
            PermissionType.viewFinancialReports,
            useFinancial: useFinancial,
          ),
          want['canDiscount'],
        );
      });
    }
  });

  group('order-delete', () {
    for (final c in _cases('order-delete.json')) {
      test(c['id'], () {
        final g = c['given'] as Map;
        _setRole(g['role'] as String);
        final order = _orderOf(g['isCreator'] as bool, g['status'] as String)
          ..paidAmount = g['hasMoney'] == true ? 10 : 0;
        expect(AuthorizationService.instance.canDeleteOrder(order), _want(c)['allowed']);
      });
    }
  });

  group('visibility', () {
    for (final c in _cases('visibility.json')) {
      test(c['id'], () {
        final g = c['given'] as Map;
        expect(
          RolePermissions.hasPermissionInCompany(
            rolesTypeFromJson(g['role'])!,
            PermissionType.viewPrices,
            useFinancial: g['useFinancial'] as bool,
          ),
          _want(c)['showPrices'],
        );
      });
    }
  });

  group('overdue', () {
    for (final c in _cases('overdue.json')) {
      test(c['id'], () {
        final g = c['given'] as Map;
        final due = g['dueDate'] as String?;
        final order = Order()
          ..status = g['status'] as String?
          ..dueDate = due == null ? null : DateTime.parse(due);
        expect(
          HomeRules.isOverdue(order, DateTime.parse(g['now'] as String)),
          _want(c)['overdue'],
        );
      });
    }
  });

  group('currency', () {
    tearDown(() => FormatService().setLocale('pt-BR'));

    for (final c in _cases('currency.json')) {
      test(c['id'], () {
        final g = c['given'] as Map;
        final want = _want(c);
        final format = FormatService()..setLocale(g['appLocale'] as String);
        expect(format.currencyFormat.currencyName, want['currency']);
        expect(format.locale, want['locale']);
      });
    }
  });

  group('phone', () {
    for (final c in _cases('phone.json')) {
      test(c['id'], () {
        final g = c['given'] as Map;
        final want = _want(c);
        final raw = g['raw'] as String;
        final country = g['country'] as String?;
        switch (g['kind']) {
          case 'normalize':
            expect(whatsappNumber(raw, country: country), want['number']);
          case 'display':
            expect(formatPhone(raw, country: country), want['text']);
          case 'matchKey':
            expect(phoneMatchKey(raw, country: country), want['number']);
          default:
            fail('unknown kind ${g['kind']}');
        }
      });
    }
  });

  group('tax-id', () {
    for (final c in _cases('tax-id.json')) {
      test(c['id'], () {
        final g = c['given'] as Map;
        final want = _want(c);
        final value = g['value'] as String;
        switch (g['kind']) {
          case 'normalize':
            expect(normalizeTaxId(value), want['result']);
          case 'format':
            expect(formatTaxId(value), want['result']);
          case 'cpf':
            expect(isValidCpf(value), want['valid']);
          case 'cnpj':
            expect(isValidCnpj(value), want['valid']);
          case 'taxId':
            expect(isValidTaxId(value), want['valid']);
          default:
            fail('unknown kind ${g['kind']}');
        }
      });
    }
  });

  group('segment-labels', () {
    tearDown(() {
      SegmentConfigService()
        ..clear()
        ..setLocale('pt-BR');
      FormatService().setLocale('pt-BR');
    });

    for (final c in _cases('segment-labels.json')) {
      test(c['id'], () {
        final g = c['given'] as Map;
        final locale = g['locale'] as String;
        final service = SegmentConfigService()
          ..clear()
          ..setL10n(lookupAppLocalizations(Locale(locale.split('-').first)))
          ..setLocale(locale)
          ..debugSetCustomFields([
            for (final f in (g['customFields'] as List).cast<Map>())
              CustomField(
                key: f['key'] as String,
                type: f['type'] as String,
                labels: (f['labels'] as Map).cast<String, String>(),
              ),
          ]);
        expect(service.label(g['key'] as String), _want(c)['label']);
      });
    }
  });

  group('receipts', () {
    for (final c in _cases('receipts.json')) {
      test(c['id'], () {
        final g = c['given'] as Map;
        final want = _want(c);
        switch (g['kind']) {
          case 'allocate':
            final balances = [
              for (final b in (g['balances'] as List).cast<Map>())
                OpenBalance(orderId: b['orderId'] as String, open: _d(b['open'])!),
            ];
            final result = allocatePayment(balances, _d(g['amount'])!);
            expect(
              [
                for (final a in result) {'orderId': a.orderId, 'amount': a.amount},
              ],
              want['allocations'],
            );
            expect(totalOpen(balances), _d(want['totalOpen']));
          case 'register':
            final orders = [
              for (final o in (g['orders'] as List).cast<Map>())
                Order()
                  ..id = o['id'] as String
                  ..status = o['status'] as String
                  ..total = _d(o['total'])
                  ..paidAmount = _d(o['paidAmount']),
            ];
            final plan = buildReceiptPlan(
              receiptId: 'r1',
              customer: null,
              orders: orders,
              allocations: [
                for (final a in (g['allocations'] as List).cast<Map>())
                  PaymentAllocation(orderId: a['orderId'] as String, amount: _d(a['amount'])!),
              ],
              paidAt: DateTime.utc(2026, 1, 1),
              now: DateTime.utc(2026, 1, 1),
            );
            expect(want['error'], isNull, reason: 'the plan did not refuse');
            expect(plan.receipt.amount, _d(want['amount']));
            final byId = {for (final o in orders) o.id: o};
            expect(
              [
                for (final entry in plan.orderUpdates.entries)
                  {
                    'id': entry.key,
                    'payment': entry.value['payment'],
                    'paid': entry.value['paid'],
                    'paidAmount': OrderPaymentMath.roundMoney(
                      byId[entry.key]!.paidAmount! + (entry.value['paidAmount'] as IncrementOp).by,
                    ),
                  },
              ],
              want['orders'],
            );
          case 'canReceive':
            expect(
              AuthorizationService.canReceivePaymentsFor(
                role: rolesTypeFromJson(g['role']),
                useFinancial: g['useFinancial'] as bool,
              ),
              want['allowed'],
            );
          default:
            fail('unknown kind ${g['kind']}');
        }
      });
    }
  });
}
