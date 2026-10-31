import 'package:praticos/global.dart';
import 'package:praticos/utils/financial_summary.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Debts opened in this window are charged first.
const int kNextChargeRecentDays = 90;

/// How long "Agora não" keeps a customer out of Próxima cobrança.
const int kNextChargeSnoozeDays = 30;

/// Who to charge next, best first: debts of the last
/// [kNextChargeRecentDays] days, oldest first (the sooner, the likelier to be
/// paid); then the older ones, newest first. [snoozed] holds `Debtor.key`s.
List<Debtor> nextChargeCandidates(
  Iterable<Debtor> debtors, {
  required DateTime now,
  Set<String> snoozed = const {},
}) {
  final limit = now.subtract(const Duration(days: kNextChargeRecentDays));
  final recent = <Debtor>[];
  final older = <Debtor>[];
  for (final debtor in debtors) {
    if (snoozed.contains(debtor.key)) continue;
    final since = debtor.since;
    (since != null && !since.isBefore(limit) ? recent : older).add(debtor);
  }
  int bySince(Debtor a, Debtor b) => a.since!.compareTo(b.since!);
  final dated = older.where((d) => d.since != null).toList()
    ..sort((a, b) => bySince(b, a));
  return [
    ...recent..sort(bySince),
    ...dated,
    ...older.where((d) => d.since == null),
  ];
}

/// "Agora não" of Próxima cobrança: kept on this device, per company and
/// customer, never in the database. It only hides the suggestion: the customer
/// stays in A receber.
class NextChargeSnoozes {
  NextChargeSnoozes({String? Function()? companyId, DateTime Function()? clock})
    : _companyId = companyId ?? (() => Global.companyAggr?.id),
      _clock = clock ?? DateTime.now;

  final String? Function() _companyId;
  final DateTime Function() _clock;

  String get _prefix => 'financialNextChargeSnooze.${_companyId()}.';

  /// Keys of the debtors still paused. Expired entries are removed.
  Future<Set<String>> active() async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = _prefix;
    final limit = _clock()
        .subtract(const Duration(days: kNextChargeSnoozeDays))
        .millisecondsSinceEpoch;
    final active = <String>{};
    for (final key in prefs.getKeys().where((k) => k.startsWith(prefix))) {
      if ((prefs.getInt(key) ?? 0) > limit) {
        active.add(key.substring(prefix.length));
      } else {
        await prefs.remove(key);
      }
    }
    return active;
  }

  Future<void> snooze(String debtorKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      '$_prefix$debtorKey',
      _clock().millisecondsSinceEpoch,
    );
  }
}
