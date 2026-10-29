import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/form_definition.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/order_form.dart' as of_model;
import 'package:praticos/screens/order/order_extras.dart';
import 'package:praticos/screens/widgets/order_media_actions.dart';
import 'package:praticos/screens/widgets/order_status_share.dart';

Order _order({String? id = 'o1', String? phone = '11999990000'}) => Order()
  ..id = id
  ..customer = (CustomerAggr()
    ..name = 'Ana'
    ..phone = phone);

void main() {
  group('shouldOfferStatusShare', () {
    test('approved, in progress and done offer to tell the customer', () {
      for (final status in ['approved', 'progress', 'done']) {
        expect(
          shouldOfferStatusShare(_order(), status),
          isTrue,
          reason: status,
        );
      }
    });

    test('quote and canceled do not', () {
      expect(shouldOfferStatusShare(_order(), 'quote'), isFalse);
      expect(shouldOfferStatusShare(_order(), 'canceled'), isFalse);
    });

    test('unsaved order or customer without phone do not', () {
      expect(shouldOfferStatusShare(_order(id: null), 'done'), isFalse);
      expect(shouldOfferStatusShare(_order(phone: null), 'done'), isFalse);
      expect(shouldOfferStatusShare(_order(phone: ''), 'done'), isFalse);
    });

    test('an active link or "Agora não" for this order skip it', () {
      final linked = _order()
        ..shareLink = (OrderShareLink()
          ..token = 't'
          ..expiresAt = DateTime.now().add(const Duration(days: 3)));
      expect(shouldOfferStatusShare(linked, 'done'), isFalse);

      final expired = _order()
        ..shareLink = (OrderShareLink()
          ..token = 't'
          ..expiresAt = DateTime.now().subtract(const Duration(days: 1)));
      expect(shouldOfferStatusShare(expired, 'done'), isTrue);

      expect(
        shouldOfferStatusShare(_order(), 'done', dismissedOrderIds: {'o1'}),
        isFalse,
      );
    });
  });

  test('checklistMissing counts unanswered questions, never below zero', () {
    of_model.OrderForm form(int items, int answered) => of_model.OrderForm(
      id: 'f',
      formDefinitionId: 'd',
      title: 'Entrada',
      items: [
        for (var i = 0; i < items; i++)
          FormItemDefinition(id: '$i', label: 'P$i', type: FormItemType.text),
      ],
      responses: [
        for (var i = 0; i < answered; i++) of_model.FormResponse(itemId: '$i'),
      ],
    );
    expect(checklistMissing(form(5, 2)), 3);
    expect(checklistMissing(form(2, 2)), 0);
    expect(checklistMissing(form(1, 3)), 0);
  });

  test('orderDocumentContentType maps known extensions', () {
    expect(orderDocumentContentType('PDF'), 'application/pdf');
    expect(orderDocumentContentType('jpeg'), 'image/jpeg');
    expect(orderDocumentContentType('png'), 'image/png');
    expect(orderDocumentContentType('zip'), 'application/octet-stream');
  });
}
