import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:praticos/mobx/company_store.dart';
import 'package:praticos/mobx/customer_store.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/order_form.dart' as of_model;
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/services/forms_service.dart';
import 'package:praticos/services/pdf/pdf_localizations.dart';
import 'package:praticos/services/pdf/pdf_service.dart';

/// The order PDF, ready to show or to send.
class OrderPdfFile {
  const OrderPdfFile({required this.bytes, required this.filename});

  final Uint8List bytes;
  final String filename;
}

/// Draws the PDF of [order] in the app's language: the company, the full
/// customer (falls back to what the order has), the checklists and the
/// segment labels. Throws when something fails; callers show the error.
Future<OrderPdfFile> buildOrderPdf(
  BuildContext context,
  Order order,
  SegmentConfigProvider config,
) async {
  final companyId = order.company?.id;
  if (companyId == null) throw StateError('order without company');
  final pdfLocalizations = PdfLocalizations.fromContext(context);

  final company = await CompanyStore().retrieveCompany(companyId);
  Customer? customer;
  if (order.customer != null) {
    if (order.customer!.id != null) {
      try {
        final customerStore = CustomerStore()..companyId = companyId;
        customer = await customerStore.retrieveCustomer(order.customer!.id);
      } catch (_) {
        // Falls back to the aggregate below.
      }
    }
    customer ??= Customer()
      ..id = order.customer!.id
      ..name = order.customer!.name
      ..phone = order.customer!.phone
      ..email = order.customer!.email;
  }
  var forms = <of_model.OrderForm>[];
  if (order.id != null) {
    forms = await FormsService().getOrderForms(companyId, order.id!).first;
  }
  final data = OsPdfData(
    order: order,
    customer: customer,
    company: company,
    forms: forms,
    config: config,
    localizations: pdfLocalizations,
  );
  final bytes = await PdfService().generateOsPdf(data);
  return OrderPdfFile(bytes: bytes, filename: PdfService.osPdfFilename(data));
}
