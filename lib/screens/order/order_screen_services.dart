import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/mobx/company_store.dart';
import 'package:praticos/mobx/customer_store.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/order_form.dart' as of_model;
import 'package:praticos/models/permission.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/screens/order_form.dart';
import 'package:praticos/screens/widgets/share_link_sheet.dart';
import 'package:praticos/services/authorization_service.dart';
import 'package:praticos/services/forms_service.dart';
import 'package:praticos/services/pdf/pdf_localizations.dart';
import 'package:praticos/services/pdf/pdf_service.dart';

/// Permission checks used by the new order screen, injectable for tests.
class OrderPermissions {
  const OrderPermissions({
    required this.canViewPrices,
    required this.availableStatuses,
    required this.canChangeStatus,
    required this.canDelete,
  });

  /// Checks against the current user's role ([AuthorizationService]).
  factory OrderPermissions.current() {
    final auth = AuthorizationService.instance;
    return OrderPermissions(
      canViewPrices: () => auth.hasPermission(PermissionType.viewPrices),
      availableStatuses: auth.getAvailableStatuses,
      canChangeStatus: auth.canChangeOrderStatus,
      canDelete: auth.canDeleteOrder,
    );
  }

  final bool Function() canViewPrices;
  final List<String> Function(Order order) availableStatuses;
  final bool Function(Order order, String status) canChangeStatus;
  final bool Function(Order order) canDelete;
}

/// Side effects of the order screen that leave it (other screens, sharing,
/// PDF). Injectable so the screen can be tested without Firebase.
class OrderScreenActions {
  const OrderScreenActions();

  /// "Receber" / payments of the order.
  Future<void> openPayments(BuildContext context, OrderStore store) {
    return Navigator.pushNamed(
      context,
      '/payment_management',
      arguments: {'orderStore': store},
    );
  }

  /// "Mandar para o cliente": the share link sheet (approve, comment, ...).
  Future<void> shareWithCustomer(BuildContext context, Order order) {
    return ShareLinkSheet.show(context, order);
  }

  /// Rare features not rebuilt yet (checklist, photos and documents,
  /// comments, address, schedule, contract) open the complete screen.
  Future<void> openCompleteScreen(BuildContext context, Order order) {
    return Navigator.of(context).push(
      CupertinoPageRoute<void>(
        // Named '/order' so the legacy item screens can popUntil it.
        settings: RouteSettings(name: '/order', arguments: {'order': order}),
        builder: (_) => OrderForm(),
      ),
    );
  }

  /// Generates the order PDF and opens the share sheet (same as the legacy
  /// screen).
  Future<void> sharePdf(
    BuildContext context,
    Order order,
    SegmentConfigProvider config,
  ) async {
    final companyId = order.company?.id;
    if (companyId == null) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    final pdfLocalizations = PdfLocalizations.fromContext(context);
    final l10n = context.l10n;

    showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CupertinoAlertDialog(
        content: CupertinoActivityIndicator(),
      ),
    );

    try {
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
      await PdfService().shareOsPdf(OsPdfData(
        order: order,
        customer: customer,
        company: company,
        forms: forms,
        config: config,
        localizations: pdfLocalizations,
      ));
      navigator.pop();
    } catch (_) {
      navigator.pop();
      if (!context.mounted) return;
      showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: Text(l10n.errorOccurred),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.ok),
            ),
          ],
        ),
      );
    }
  }
}
