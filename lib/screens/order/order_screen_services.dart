import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/mobx/collaborator_store.dart';
import 'package:praticos/mobx/company_store.dart';
import 'package:praticos/mobx/customer_store.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/form_definition.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/order_document.dart';
import 'package:praticos/models/order_form.dart' as of_model;
import 'package:praticos/models/permission.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/screens/forms/form_fill_screen.dart';
import 'package:praticos/screens/forms/form_selection_screen.dart';
import 'package:praticos/screens/payments/widgets/receive_discount_sheet.dart';
import 'package:praticos/screens/widgets/contract_config_sheet.dart';
import 'package:praticos/screens/widgets/device_picker_sheet.dart';
import 'package:praticos/screens/widgets/order_comments_widget.dart';
import 'package:praticos/screens/widgets/order_media_actions.dart';
import 'package:praticos/screens/widgets/order_media_widget.dart'
    show PhotoViewerScreen;
import 'package:praticos/screens/widgets/order_status_share.dart';
import 'package:praticos/screens/widgets/share_link_sheet.dart';
import 'package:praticos/services/authorization_service.dart';
import 'package:praticos/services/forms_service.dart';
import 'package:praticos/services/location_service.dart';
import 'package:praticos/services/pdf/pdf_localizations.dart';
import 'package:praticos/services/pdf/pdf_service.dart';
import 'package:praticos/widgets/cached_image.dart';

/// Permission checks used by the new order screen, injectable for tests.
class OrderPermissions {
  const OrderPermissions({
    required this.canViewPrices,
    required this.availableStatuses,
    required this.canChangeStatus,
    required this.canDelete,
    this.canEditMainFields = _anyOrder,
    this.canManageForms = _anyOrder,
    this.canAttachMedia = _always,
  });

  static bool _anyOrder(Order order) => true;
  static bool _always() => true;

  /// Checks against the current user's role ([AuthorizationService]).
  factory OrderPermissions.current() {
    final auth = AuthorizationService.instance;
    return OrderPermissions(
      canViewPrices: () => auth.hasPermission(PermissionType.viewPrices),
      availableStatuses: auth.getAvailableStatuses,
      canChangeStatus: auth.canChangeOrderStatus,
      canDelete: auth.canDeleteOrder,
      canEditMainFields: auth.canEditOrderMainFields,
      canManageForms: auth.canManageOrderForms,
      canAttachMedia: () => auth.hasPermission(PermissionType.attachPhotos),
    );
  }

  final bool Function() canViewPrices;
  final List<String> Function(Order order) availableStatuses;
  final bool Function(Order order, String status) canChangeStatus;
  final bool Function(Order order) canDelete;

  /// Customer, vehicle, dates and address.
  final bool Function(Order order) canEditMainFields;

  /// Add, fill and remove checklists.
  final bool Function(Order order) canManageForms;

  /// Add and remove photos and documents.
  final bool Function() canAttachMedia;
}

/// Side effects of the order screen that leave it (other screens, sharing,
/// PDF). Injectable so the screen can be tested without Firebase.
class OrderScreenActions {
  const OrderScreenActions();

  /// People of the company, to pick the "Responsável" of an order.
  Future<List<UserAggr>> teamMembers() async {
    final store = CollaboratorStore();
    await store.loadCollaborators();
    return [
      for (final m in store.collaborators)
        if (m.user?.id != null) m.user!,
    ];
  }

  /// "Receber" / payments of the order.
  Future<void> openPayments(BuildContext context, OrderStore store) {
    return Navigator.pushNamed(
      context,
      '/payment_management',
      arguments: {'orderStore': store, 'fromOrder': true},
    );
  }

  /// "Mandar para o cliente": the share link sheet (approve, comment, ...).
  Future<void> shareWithCustomer(BuildContext context, Order order) {
    return ShareLinkSheet.show(context, order);
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
      builder: (_) =>
          const CupertinoAlertDialog(content: CupertinoActivityIndicator()),
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
      await PdfService().shareOsPdf(
        OsPdfData(
          order: order,
          customer: customer,
          company: company,
          forms: forms,
          config: config,
          localizations: pdfLocalizations,
        ),
      );
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

  // ─── "Nesta OS" ──────────────────────────────────────────────────────────

  /// "Fotos ou documento": camera, gallery or files.
  Future<void> addMedia(BuildContext context, OrderStore store) =>
      showAddOrderMediaSheet(context, store);

  /// Full-screen photo viewer (share, delete).
  Future<void> viewPhoto(
    BuildContext context,
    OrderStore store,
    int index,
    SegmentConfigProvider config,
  ) {
    return Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => PhotoViewerScreen(
          photos: store.photos.toList(),
          initialIndex: index,
          onDelete: store.deletePhoto,
          onSetCover: store.setPhotoCover,
          config: config,
        ),
      ),
    );
  }

  /// Square photo thumbnail (network, cached).
  Widget photoThumb(String url, double size, BorderRadius radius) =>
      CachedImage(
        imageUrl: url,
        width: size,
        height: size,
        borderRadius: radius,
      );

  Future<void> openDocument(BuildContext context, OrderDocument doc) =>
      openOrderDocument(context, doc);

  /// Picks a checklist template (and the vehicle, with 2 or more), adds it
  /// to the order and opens it to fill.
  Future<void> addChecklist(BuildContext context, OrderStore store) async {
    final companyId = store.companyId;
    final orderId = store.order?.id;
    if (companyId == null || orderId == null) return;
    String? deviceId;
    if (store.devices.length >= 2) {
      final result = await DevicePickerSheet.show(
        context,
        store.devices.toList(),
      );
      if (result == null) return;
      if (result.action == DevicePickerAction.specific) {
        deviceId = result.device?.id;
      } else if (result.action == DevicePickerAction.multiSpecific) {
        deviceId = result.deviceIds?.first;
      }
    }
    if (!context.mounted) return;
    final template = await Navigator.push<FormDefinition>(
      context,
      CupertinoPageRoute(
        builder: (_) => FormSelectionScreen(companyId: companyId),
      ),
    );
    if (template == null || !context.mounted) return;
    final form = await FormsService().addFormToOrder(
      companyId,
      orderId,
      template,
      deviceId: deviceId,
    );
    if (!context.mounted) return;
    await openChecklist(context, store, form);
  }

  Future<void> openChecklist(
    BuildContext context,
    OrderStore store,
    of_model.OrderForm form,
  ) {
    final companyId = store.companyId;
    final orderId = store.order?.id;
    if (companyId == null || orderId == null) return Future.value();
    return Navigator.push(
      context,
      CupertinoPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => FormFillScreen(
          orderId: orderId,
          companyId: companyId,
          orderForm: form,
          devices: store.devices.toList(),
        ),
      ),
    );
  }

  Future<void> deleteChecklist(OrderStore store, of_model.OrderForm form) {
    final companyId = store.companyId;
    final orderId = store.order?.id;
    if (companyId == null || orderId == null) return Future.value();
    return FormsService().deleteOrderForm(companyId, orderId, form.id);
  }

  /// Comments of the order (internal or for the customer).
  Widget comments(Order order, {String? highlightCommentId}) {
    return OrderCommentsWidget(
      orderId: order.id!,
      companyId: order.company!.id!,
      showInternalToggle: true,
      highlightCommentId: highlightCommentId,
    );
  }

  /// "Avisar o cliente?" answered yes: native share with the customer link.
  Future<void> notifyCustomer(
    BuildContext context,
    Order order,
    String status,
  ) {
    return shareOrderLinkNatively(context, order, statusContext: status);
  }

  Future<void> openInMaps(OrderStore store) {
    return LocationService().openInMaps(
      lat: store.latitude,
      lng: store.longitude,
      address: store.address,
    );
  }

  /// The discount sheet of "Receber". Resolves with the amount, or null.
  Future<double?> askDiscount(
    BuildContext context, {
    required double currentTotal,
    required double maxDiscount,
  }) {
    return showReceiveDiscountSheet(
      context,
      currentTotal: currentTotal,
      maxDiscount: maxDiscount,
    );
  }

  /// Frequency, interval, start, end, automatic generation and reminder of
  /// the recurring contract.
  Future<void> editContract(BuildContext context, OrderStore store) {
    final contract = store.order?.contract;
    if (contract == null) return Future.value();
    return showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => ContractConfigSheet(
        contract: contract,
        onFrequencyChanged: store.setContractFrequency,
        onIntervalChanged: store.setContractInterval,
        onStartDateChanged: store.setContractStartDate,
        onEndDateChanged: store.setContractEndDate,
        onAutoGenerateChanged: store.setContractAutoGenerate,
        onReminderDaysChanged: store.setContractReminderDays,
      ),
    );
  }

  /// Another order (contract parent or generated child).
  Future<void> openOrder(BuildContext context, Order order) {
    return Navigator.of(
      context,
      rootNavigator: true,
    ).pushNamed('/order', arguments: {'order': order});
  }
}
