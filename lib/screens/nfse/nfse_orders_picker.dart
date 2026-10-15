import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/screens/nfse/nfse_access.dart';
import 'package:praticos/screens/widgets/picker_screen.dart';
import 'package:praticos/services/format_service.dart';

/// "Quais OS entram na nota?": picks the orders of one customer for a
/// single nota (monthly or contract customers). Only orders that can have a
/// nota and have none yet are offered. Pops with the order ids.
class NfseOrdersPicker extends StatefulWidget {
  const NfseOrdersPicker({super.key, required this.orders, this.previousTitle});

  final List<Order> orders;
  final String? previousTitle;

  static Future<List<String>?> open(
    BuildContext context, {
    required List<Order> orders,
    String? previousTitle,
  }) => Navigator.of(context, rootNavigator: true).push<List<String>>(
    CupertinoPageRoute<List<String>>(
      builder: (_) =>
          NfseOrdersPicker(orders: orders, previousTitle: previousTitle),
    ),
  );

  @override
  State<NfseOrdersPicker> createState() => _NfseOrdersPickerState();
}

class _NfseOrdersPickerState extends State<NfseOrdersPicker> {
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final format = FormatService();
    final orders = [
      for (final o in widget.orders)
        if (o.id != null) o,
    ];
    return PickerScaffold<String>(
      key: const Key('nfseOrdersPicker'),
      title: l10n.nfsePickOrdersTitle,
      previousTitle: widget.previousTitle,
      itemCount: orders.length,
      multiple: true,
      strongTitles: false,
      emptyTitle: l10n.nfseNoOrdersToPick,
      onSelect: (id) => setState(() {
        if (!_selected.remove(id)) _selected.add(id);
      }),
      onConfirm: _selected.isEmpty
          ? null
          : () => Navigator.of(context).pop([
              for (final o in orders)
                if (_selected.contains(o.id)) o.id!,
            ]),
      sections: (query) {
        final q = query.toLowerCase();
        return [
          PickerSection(
            items: [
              for (final o in orders)
                if (q.isEmpty || '${o.number ?? ''}'.contains(q))
                  PickerItem(
                    key: ValueKey('nfsePickOrder_${o.id}'),
                    value: o.id!,
                    title: l10n.receiveCustomerPickRow(o.number ?? 0),
                    subtitle: l10n.nfsePickOrderSubtitle(
                      format.formatCurrency(nfseValueOfOrder(o)),
                      format.formatDate(o.createdAt),
                    ),
                    selected: _selected.contains(o.id),
                  ),
            ],
          ),
        ];
      },
    );
  }
}
