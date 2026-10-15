import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/screens/widgets/picker_screen.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/utils/payment_allocation.dart';

/// "Quais OS ele está pagando?": multiple choice over the customer's open
/// orders (oldest first), each with what is still open and its date. The ✓
/// in the top bar confirms (gray while nothing is chosen).
///
/// Completes with the chosen order ids, or null when the user went back.
Future<Set<String>?> pickReceiveOrders(
  BuildContext context, {
  required List<Order> orders,
  required Set<String> selected,
}) {
  return Navigator.of(context).push<Set<String>>(
    CupertinoPageRoute<Set<String>>(
      builder: (_) => ReceiveOrdersPicker(orders: orders, selected: selected),
    ),
  );
}

class ReceiveOrdersPicker extends StatefulWidget {
  const ReceiveOrdersPicker({
    super.key,
    required this.orders,
    required this.selected,
  });

  /// Open orders, oldest first.
  final List<Order> orders;
  final Set<String> selected;

  @override
  State<ReceiveOrdersPicker> createState() => _ReceiveOrdersPickerState();
}

class _ReceiveOrdersPickerState extends State<ReceiveOrdersPicker> {
  late final Set<String> _selected = {...widget.selected};

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final format = FormatService();
    final orders = widget.orders;
    return PickerScaffold<String>(
      title: l10n.receiveCustomerPickTitle,
      itemCount: orders.length,
      multiple: true,
      onConfirm: _selected.isEmpty
          ? null
          : () => Navigator.of(context).pop(<String>{..._selected}),
      onSelect: (id) => setState(() {
        if (!_selected.remove(id)) _selected.add(id);
      }),
      sections: (query) => [
        PickerSection<String>(
          items: [
            for (final order in orders)
              if (pickerMatches('${order.number ?? ''}', query) ||
                  pickerMatches(order.customer?.name, query))
                PickerItem(
                  key: ValueKey('receivePick_${order.id}'),
                  value: order.id ?? '',
                  title: l10n.receiveCustomerPickRow(order.number ?? 0),
                  subtitle: l10n.receiveCustomerPickSubtitle(
                    format.formatCurrency(OpenBalance.ofOrder(order).open),
                    order.createdAt == null
                        ? '-'
                        : format.formatDate(order.createdAt!),
                  ),
                  selected: _selected.contains(order.id),
                ),
          ],
        ),
      ],
    );
  }
}
