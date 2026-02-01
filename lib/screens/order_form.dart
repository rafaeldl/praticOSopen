import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Material, MaterialType, Divider;
// Keeping Material for some specific helpers or if absolutely needed, but main UI is Cupertino.
// Actually, strict HIG means avoiding Material widgets where possible.
// I will try to rely purely on Cupertino for the visual tree.

import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/mobx/company_store.dart';
import 'package:praticos/mobx/customer_store.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/permission.dart';
import 'package:praticos/screens/widgets/order_photos_widget.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/constants/label_keys.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/services/authorization_service.dart';

// Formulários Dinâmicos
import 'package:praticos/models/order_form.dart' as of_model; // Alias para evitar conflito com esta classe OrderForm
import 'package:praticos/services/forms_service.dart';
import 'package:praticos/screens/forms/form_selection_screen.dart';
import 'package:praticos/screens/forms/form_fill_screen.dart';

import 'package:praticos/services/pdf/pdf_localizations.dart';
import 'package:praticos/services/pdf/pdf_service.dart';
import 'package:praticos/services/share_link_service.dart';
import 'package:praticos/screens/widgets/share_link_sheet.dart';
import 'package:praticos/screens/widgets/order_comments_widget.dart';

class OrderForm extends StatefulWidget {
  @override
  _OrderFormState createState() => _OrderFormState();
}

class _OrderFormState extends State<OrderForm> {
  late OrderStore _store;
  final FormsService _formsService = FormsService();
  final AuthorizationService _authService = AuthorizationService.instance;

  /// Gets the current locale code for i18n (e.g., 'pt', 'en', 'es')
  String? get _localeCode => context.l10n.localeName;

  @override
  void initState() {
    super.initState();
    _store = OrderStore();

    Future.delayed(Duration.zero, () {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

      if (args != null && args.containsKey('order')) {
        Order orderArg = args['order'];

        if (orderArg.id != null) {
          _store.repository.getSingle(_store.companyId!, orderArg.id!).then((updatedOrder) {
            _store.setOrder(updatedOrder ?? orderArg);
          });
        } else if (orderArg.number != null) {
          _store.repository.getOrderByNumber(_store.companyId!, orderArg.number!).then((
            existingOrder,
          ) {
            _store.setOrder(existingOrder ?? orderArg);
          });
        } else {
          _store.setOrder(orderArg);
        }
      } else {
        _store.loadOrder();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<SegmentConfigProvider>();
    // Using CupertinoPageScaffold for iOS look
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: Material(
        type: MaterialType.transparency,
        child: CustomScrollView(
          slivers: [
            _buildNavigationBar(context, config),
            SliverSafeArea(
              top: false,
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildPhotosSection(context, config),
                  _buildClientDeviceSection(context, config),
                  _buildSummarySection(context, config),
                  _buildServicesSection(context, config),
                  _buildProductsSection(context, config),
                  _buildFormsSection(context, config),
                  _buildCommentsSection(context),
                  _buildRatingSection(context),
                  const SizedBox(height: 40),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationBar(BuildContext context, SegmentConfigProvider config) {
    return CupertinoSliverNavigationBar(
      largeTitle: Observer(
        builder: (_) {
          Order? os = _store.orderStream?.value;
          return Text(
            os?.number != null ? "${context.l10n.orderShort} #${os!.number}" : config.label(LabelKeys.createServiceOrder),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        },
      ),
      trailing: Observer(
        builder: (_) {
          final order = _store.orderStream?.value;
          final hasOrder = order?.id != null;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasOrder)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _shareOrShowSheet,
                  child: const Icon(CupertinoIcons.share),
                ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => _showActionSheet(context, config),
                child: const Icon(CupertinoIcons.ellipsis_circle),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPhotosSection(BuildContext context, SegmentConfigProvider config) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
      child: OrderPhotosWidget(
        store: _store,
        onAddPhoto: () => _showAddPhotoOptions(config),
      ),
    );
  }

  /// Seção de resumo - Status, Total e Datas no padrão iOS
  Widget _buildSummarySection(BuildContext context, SegmentConfigProvider config) {
    return Observer(
      builder: (_) {
        final total = _store.total ?? 0.0;
        final payment = _store.payment ?? '';
        final isPaid = payment == 'Pago' || payment == 'paid';
        final isPartial = payment == 'Parcial' || payment == 'partial';
        final hasCreatedDate = _store.order?.id != null;
        final status = _store.status;

        // Pagamentos só disponíveis a partir de 'approved'
        final canManagePayments = !['quote', 'canceled'].contains(status);

        // Verificar se o usuário pode visualizar valores financeiros
        final canViewPrices = _authService.hasPermission(PermissionType.viewPrices);

        return _buildGroupedSection(
          header: context.l10n.overview.toUpperCase(),
          children: [
            _buildListTile(
              context: context,
              icon: CupertinoIcons.flag_fill,
              title: context.l10n.orderStatus,
              value: config.getStatus(_store.status),
              onTap: () => _selectStatus(config),
              showChevron: true,
              valueColor: _getStatusColorCupertino(_store.status),
            ),
            if (hasCreatedDate)
              _buildListTile(
                context: context,
                icon: CupertinoIcons.clock,
                title: context.l10n.createdAt,
                value: _store.formattedCreatedDate,
                onTap: () {},
                showChevron: false,
              ),
            _buildListTile(
              context: context,
              icon: CupertinoIcons.calendar,
              title: context.l10n.statusDelivery,
              value: _store.dueDate ?? context.l10n.select,
              placeholder: context.l10n.select,
              onTap: _selectDueDate,
              showChevron: true,
              enabled: _store.order != null
                  ? _authService.canEditOrderMainFields(_store.order!)
                  : true,
            ),
            // Apenas mostrar total se usuário pode ver preços
            if (canViewPrices)
              _buildListTile(
                context: context,
                icon: CupertinoIcons.money_dollar_circle_fill,
                title: config.label(LabelKeys.total),
                value: _convertToCurrency(total),
                onTap: canManagePayments ? _openPaymentManagement : () {},
                showChevron: canManagePayments,
                isBold: true,
                isLast: !canManagePayments, // Último item se não mostra status de pagamento
              ),
            // Mostrar status de pagamento apenas se pode gerenciar pagamentos
            if (canViewPrices && canManagePayments)
              _buildListTile(
                context: context,
                icon: isPaid
                    ? CupertinoIcons.checkmark_circle_fill
                    : (isPartial ? CupertinoIcons.circle_lefthalf_fill : CupertinoIcons.clock_fill),
                title: context.l10n.payment,
                value: isPaid ? context.l10n.paid : (isPartial ? context.l10n.partiallyPaid : context.l10n.toReceive),
                onTap: _openPaymentManagement,
                showChevron: true,
                valueColor: isPaid
                    ? CupertinoColors.systemGreen
                    : (isPartial ? CupertinoColors.systemBlue : CupertinoColors.systemOrange),
                isLast: true,
                identifier: 'payment_button',
              ),
          ],
        );
      },
    );
  }

  Widget _buildClientDeviceSection(BuildContext context, SegmentConfigProvider config) {
    return Observer(
      builder: (_) {
        final canEditFields = _store.order != null
            ? _authService.canEditOrderMainFields(_store.order!)
            : true;

        return _buildGroupedSection(
          header: "${config.customer.toUpperCase()} E ${config.device.toUpperCase()}",
          children: [
            _buildListTile(
              context: context,
              icon: CupertinoIcons.person_fill,
              title: config.customer,
              value: _store.customerName,
              placeholder: "${context.l10n.select} ${config.customer}",
              onTap: _selectCustomer,
              showChevron: true,
              enabled: canEditFields,
            ),
            _buildListTile(
              context: context,
              icon: config.deviceIcon,
              title: config.device,
              value: _store.deviceName,
              placeholder: "${context.l10n.select} ${config.device}",
              onTap: _selectDevice,
              showChevron: true,
              isLast: true,
              enabled: canEditFields,
            ),
          ],
        );
      },
    );
  }
  Widget _buildFormsSection(BuildContext context, SegmentConfigProvider config) {
    return Observer(
      builder: (_) {
        final hasOrder = _store.order?.id != null && _store.companyId != null;
        // Usar canManageOrderForms para procedimentos (Supervisor pode gerenciar em OS ativa)
        final canManageForms = _store.order != null
            ? _authService.canManageOrderForms(_store.order!)
            : true;

        return StreamBuilder<List<of_model.OrderForm>>(
          stream: _store.formsStream,
          initialData: _store.formsStream?.value,
          builder: (context, snapshot) {
            final isLoading = hasOrder && snapshot.connectionState == ConnectionState.waiting;
            final forms = snapshot.data ?? [];

            return _buildGroupedSection(
              header: context.l10n.forms.toUpperCase(),
              trailing: forms.isNotEmpty && canManageForms ? _buildAddButton(onTap: () => _addForm(config), label: context.l10n.add) : null,
              children: [
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CupertinoActivityIndicator()),
                  )
                else if (forms.isEmpty)
                  _buildListTile(
                    context: context,
                    icon: CupertinoIcons.plus_circle,
                    title: "${context.l10n.add} ${context.l10n.form}",
                    value: "",
                    onTap: () {
                      if (canManageForms) {
                        _addForm(config);
                      }
                    },
                    showChevron: canManageForms,
                    isLast: true,
                    textColor: canManageForms
                        ? CupertinoTheme.of(context).primaryColor
                        : CupertinoColors.tertiaryLabel.resolveFrom(context),
                    enabled: canManageForms,
                  )
                else
                  ...forms.asMap().entries.map((entry) {
                    final index = entry.key;
                    final form = entry.value;
                    return _buildFormRow(context, form, index == forms.length - 1, canManageForms);
                  }),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildFormRow(BuildContext context, of_model.OrderForm form, bool isLast, bool canDelete) {
    final total = form.items.length;
    final answered = form.responses.length;
    final progress = total > 0 ? (answered / total) : 0.0;
    final percent = (progress * 100).toInt();
    final isCompleted = form.status == of_model.FormStatus.completed;

    return _buildDismissibleItem(
      context: context,
      index: form.id.hashCode,
      onDelete: () => _confirmDeleteForm(form),
      canDelete: canDelete,
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            CupertinoPageRoute(
              fullscreenDialog: true,
              builder: (context) => FormFillScreen(
                orderId: _store.order!.id!,
                companyId: _store.companyId!,
                orderForm: form,
              ),
            ),
          );
        },
        child: Container(
          color: Colors.transparent,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    // Indicador de status
                    Container(
                      width: 24,
                      height: 24,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCompleted
                          ? CupertinoColors.systemGreen
                          : CupertinoColors.systemOrange,
                      ),
                      child: Icon(
                        isCompleted
                          ? CupertinoIcons.checkmark
                          : CupertinoIcons.clock,
                        size: 14,
                        color: CupertinoColors.white,
                      ),
                    ),
                    // Título e subtítulo
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            form.getLocalizedTitle(_localeCode),
                            style: TextStyle(
                              fontSize: 17,
                              color: CupertinoColors.label.resolveFrom(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isCompleted
                              ? context.l10n.statusCompleted
                              : "$answered de $total ($percent%)",
                            style: TextStyle(
                              fontSize: 13,
                              color: isCompleted
                                ? CupertinoColors.systemGreen
                                : CupertinoColors.systemOrange,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Chevron
                    Icon(
                      CupertinoIcons.chevron_right,
                      size: 16,
                      color: CupertinoColors.systemGrey3.resolveFrom(context),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  indent: 52,
                  color: CupertinoColors.systemGrey5.resolveFrom(context),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteForm(of_model.OrderForm form) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('${context.l10n.delete} ${context.l10n.form}'),
        content: Text(context.l10n.confirmDeleteMessageNamed(form.getLocalizedTitle(_localeCode))),
        actions: [
          CupertinoDialogAction(
            child: Text(context.l10n.cancel),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              _formsService.deleteOrderForm(_store.companyId!, _store.order!.id!, form.id);
            },
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
  }

  void _addForm(SegmentConfigProvider config) async {
    // Se a OS ainda não foi salva, salva automaticamente
    if (_store.order?.id == null) {
      if (_store.companyId == null) return;
      
      await _store.repository.createItem(_store.companyId!, _store.order!);
      _store.setOrder(_store.order); // Atualiza estado com novo ID
    }

    // Double check após salvar
    if (_store.order?.id == null || _store.companyId == null) return;

    final template = await Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => FormSelectionScreen(
          companyId: _store.companyId!,
        ),
      ),
    );

    if (template != null && _store.order?.id != null && _store.companyId != null) {
      final newForm = await _formsService.addFormToOrder(_store.companyId!, _store.order!.id!, template);
      
      if (mounted) {
        Navigator.push(
          context,
          CupertinoPageRoute(
            fullscreenDialog: true,
            builder: (context) => FormFillScreen(
              orderId: _store.order!.id!,
              companyId: _store.companyId!,
              orderForm: newForm,
            ),
          ),
        );
      }
    }
  }

  /// Comments section - shows customer and team comments on the order
  Widget _buildCommentsSection(BuildContext context) {
    return Observer(
      builder: (_) {
        final order = _store.order;
        // Only show comments section if order is saved (has id and company)
        if (order?.id == null || order?.company?.id == null) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: OrderCommentsWidget(
            orderId: order!.id!,
            companyId: order.company!.id!,
            showInternalToggle: true,
          ),
        );
      },
    );
  }

  /// Rating section - shows customer rating for completed orders
  Widget _buildRatingSection(BuildContext context) {
    return Observer(
      builder: (_) {
        final order = _store.order;
        final rating = order?.rating;

        // Only show rating if order has one
        if (rating == null || !rating.hasRating) {
          return const SizedBox.shrink();
        }

        return _buildGroupedSection(
          header: context.l10n.customerRating.toUpperCase(),
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Star rating display
                  Row(
                    children: [
                      ...List.generate(5, (index) {
                        return Icon(
                          index < (rating.score ?? 0)
                              ? CupertinoIcons.star_fill
                              : CupertinoIcons.star,
                          color: index < (rating.score ?? 0)
                              ? const Color(0xFFFFD700)
                              : CupertinoColors.systemGrey3.resolveFrom(context),
                          size: 24,
                        );
                      }),
                      const SizedBox(width: 12),
                      Text(
                        context.l10n.ratingScore(rating.score ?? 0),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.label.resolveFrom(context),
                        ),
                      ),
                    ],
                  ),
                  // Comment if exists
                  if (rating.comment != null && rating.comment!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey6.resolveFrom(context),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '"${rating.comment}"',
                        style: TextStyle(
                          fontSize: 15,
                          fontStyle: FontStyle.italic,
                          color: CupertinoColors.secondaryLabel.resolveFrom(context),
                        ),
                      ),
                    ),
                  ],
                  // Customer name and date
                  const SizedBox(height: 8),
                  Text(
                    '— ${rating.customerName ?? context.l10n.customer}',
                    style: TextStyle(
                      fontSize: 13,
                      color: CupertinoColors.tertiaryLabel.resolveFrom(context),
                    ),
                  ),
                  if (rating.createdAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      FormatService().formatDateTime(rating.createdAt!),
                      style: TextStyle(
                        fontSize: 12,
                        color: CupertinoColors.tertiaryLabel.resolveFrom(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildServicesSection(BuildContext context, SegmentConfigProvider config) {
    return Observer(
      builder: (_) {
        final services = _store.services ?? [];
        final canEditFields = _store.order != null
            ? _authService.canEditOrderMainFields(_store.order!)
            : true;

        return _buildGroupedSection(
          header: context.l10n.services.toUpperCase(),
          trailing: services.isNotEmpty && canEditFields
              ? _buildAddButton(onTap: _addService, label: context.l10n.add)
              : null,
          children: [
            if (services.isEmpty)
              _buildListTile(
                context: context,
                icon: CupertinoIcons.plus_circle,
                title: config.label(LabelKeys.createService),
                value: "",
                onTap: _addService,
                showChevron: true,
                isLast: true,
                textColor: CupertinoTheme.of(context).primaryColor,
                enabled: canEditFields,
              )
            else
              ...services.asMap().entries.map((entry) {
                final index = entry.key;
                final service = entry.value;
                return _buildServiceRow(context, service, index, index == services.length - 1, config);
              }),
          ],
        );
      },
    );
  }

  Widget _buildProductsSection(BuildContext context, SegmentConfigProvider config) {
    return Observer(
      builder: (_) {
        final products = _store.products ?? [];
        final canEditFields = _store.order != null
            ? _authService.canEditOrderMainFields(_store.order!)
            : true;

        return _buildGroupedSection(
          header: context.l10n.products.toUpperCase(),
          trailing: products.isNotEmpty && canEditFields
              ? _buildAddButton(onTap: _addProduct, label: context.l10n.add)
              : null,
          children: [
            if (products.isEmpty)
              _buildListTile(
                context: context,
                icon: CupertinoIcons.plus_circle,
                title: config.label(LabelKeys.createProduct),
                value: "",
                onTap: _addProduct,
                showChevron: true,
                isLast: true,
                textColor: CupertinoTheme.of(context).primaryColor,
                enabled: canEditFields,
              )
            else
              ...products.asMap().entries.map((entry) {
                final index = entry.key;
                final product = entry.value;
                return _buildProductRow(context, product, index, index == products.length - 1, config);
              }),
          ],
        );
      },
    );
  }

  // --- Helper Widgets for iOS Style ---

  Widget _buildGroupedSection({
    required String header,
    required List<Widget> children,
    Widget? trailing,
  }) {
    return Builder(
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 24, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  header,
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: CupertinoColors.systemBackground.resolveFrom(context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  /// Botão de adicionar no padrão iOS (texto azul simples)
  Widget _buildAddButton({required VoidCallback onTap, String? label}) {
    return Builder(
      builder: (context) => CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        onPressed: onTap,
        child: Text(
          label ?? context.l10n.add,
          style: TextStyle(
            fontSize: 17,
            color: CupertinoTheme.of(context).primaryColor,
          ),
        ),
      ),
    );
  }

  Widget _buildListTile({
    required BuildContext context,
    IconData? icon,
    required String title,
    String? value,
    String placeholder = "",
    required VoidCallback onTap,
    bool showChevron = true,
    bool isLast = false,
    Color? valueColor,
    Color? textColor,
    bool isBold = false,
    bool enabled = true,
    String? identifier,
  }) {
    final hasValue = value != null && value.isNotEmpty;
    final tile = GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        color: Colors.transparent, // Hit test
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: CupertinoTheme.of(context).primaryColor, size: 22),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 17,
                        color: enabled
                            ? (textColor ?? CupertinoColors.label.resolveFrom(context))
                            : CupertinoColors.tertiaryLabel.resolveFrom(context),
                        fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        hasValue ? value : placeholder,
                        style: TextStyle(
                          fontSize: 17,
                          color: enabled
                              ? (hasValue
                                  ? (valueColor ?? CupertinoColors.secondaryLabel.resolveFrom(context))
                                  : CupertinoColors.placeholderText.resolveFrom(context))
                              : CupertinoColors.tertiaryLabel.resolveFrom(context),
                        ),
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ),
                  if (showChevron && enabled) ...[
                    const SizedBox(width: 6),
                    Icon(
                      CupertinoIcons.chevron_right,
                      size: 16,
                      color: CupertinoColors.systemGrey3.resolveFrom(context),
                    ),
                  ],
                ],
              ),
            ),
            if (!isLast)
              Divider(
                height: 1,
                indent: 50, // Matches standard iOS indent
                color: CupertinoColors.systemGrey5.resolveFrom(context),
              ),
          ],
        ),
      ),
    );

    // Wrap with Semantics if identifier is provided
    if (identifier != null) {
      return Semantics(
        identifier: identifier,
        button: true,
        child: tile,
      );
    }

    return tile;
  }
  
  Widget _buildServiceRow(BuildContext context, dynamic service, int index, bool isLast, SegmentConfigProvider config) {
    // Verificar se o usuário pode visualizar valores financeiros
    final canViewPrices = _authService.hasPermission(PermissionType.viewPrices);
    // Verificar se pode editar campos principais (incluindo delete)
    final canEditFields = _store.order != null
        ? _authService.canEditOrderMainFields(_store.order!)
        : true;

    return _buildDismissibleItem(
      context: context,
      index: index,
      onDelete: () => _confirmDeleteService(index, config),
      canDelete: canEditFields,
      child: _buildItemRow(
        context: context,
        title: service.service?.name ?? "Serviço",
        subtitle: service.description,
        trailing: canViewPrices ? _convertToCurrency(service.value) : "",
        onTap: () => _editService(index),
        isLast: isLast,
      ),
    );
  }

  Widget _buildProductRow(BuildContext context, dynamic product, int index, bool isLast, SegmentConfigProvider config) {
    // Verificar se o usuário pode visualizar valores financeiros
    final canViewPrices = _authService.hasPermission(PermissionType.viewPrices);
    // Verificar se pode editar campos principais (incluindo delete)
    final canEditFields = _store.order != null
        ? _authService.canEditOrderMainFields(_store.order!)
        : true;

    return _buildDismissibleItem(
      context: context,
      index: index,
      onDelete: () => _confirmDeleteProduct(index, config),
      canDelete: canEditFields,
      child: _buildItemRow(
        context: context,
        title: product.product?.name ?? "Produto",
        subtitle: "${product.quantity}x • ${product.description ?? ''}",
        trailing: canViewPrices ? _convertToCurrency(product.total) : "",
        onTap: () => _editProduct(index),
        isLast: isLast,
      ),
    );
  }

  Widget _buildDismissibleItem({
    required BuildContext context,
    required int index,
    required VoidCallback onDelete,
    required Widget child,
    bool canDelete = true,
  }) {
    // Se não pode deletar, retorna apenas o child sem o Dismissible
    if (!canDelete) {
      return child;
    }

    return Dismissible(
      key: ValueKey('item_$index'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        onDelete();
        return false; // Don't auto-dismiss, let the confirmation handle it
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: CupertinoColors.systemRed,
        child: const Icon(
          CupertinoIcons.trash,
          color: CupertinoColors.white,
        ),
      ),
      child: child,
    );
  }

  Widget _buildItemRow({
    required BuildContext context,
    required String title,
    String? subtitle,
    required String trailing,
    required VoidCallback onTap,
    required bool isLast,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.transparent,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 17,
                            color: CupertinoColors.label.resolveFrom(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle != null && subtitle.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2.0),
                            child: Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: 13,
                                color: CupertinoColors.secondaryLabel.resolveFrom(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        trailing,
                        style: TextStyle(
                          fontSize: 15,
                          color: CupertinoColors.label.resolveFrom(context),
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    CupertinoIcons.chevron_right,
                    size: 16,
                    color: CupertinoColors.systemGrey3.resolveFrom(context),
                  ),
                ],
              ),
            ),
            if (!isLast)
              Divider(
                height: 1,
                indent: 16,
                color: CupertinoColors.systemGrey5.resolveFrom(context),
              ),
          ],
        ),
      ),
    );
  }

  // --- Actions ---

  void _showActionSheet(BuildContext context, SegmentConfigProvider config) {
    // Verificar se o usuário pode visualizar valores (necessário para gerar PDF completo)
    final canViewPrices = _authService.hasPermission(PermissionType.viewPrices);

    // Verificar permissão de exclusão usando RBAC
    bool canDelete = false;
    if (_store.order != null) {
      canDelete = _authService.canDeleteOrder(_store.order!);
    }

    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            child: Text(config.label(LabelKeys.addPhoto)),
            onPressed: () {
              Navigator.pop(context);
              _showAddPhotoOptions(config);
            },
          ),
          // Enviar link para cliente
          if (_store.order?.id != null)
            CupertinoActionSheetAction(
              child: Text(context.l10n.shareWithCustomer),
              onPressed: () {
                Navigator.pop(context);
                _openShareLinkSheet();
              },
            ),
          // Compartilhar PDF para usuários com acesso a valores
          if (canViewPrices)
            CupertinoActionSheetAction(
              child: Text('${context.l10n.share} PDF'),
              onPressed: () {
                Navigator.pop(context);
                _onShare(context, _store.order, config);
              },
            ),
          // Excluir OS (se permitido)
          if (canDelete)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              child: Text('${context.l10n.delete} ${config.serviceOrder}'),
              onPressed: () {
                Navigator.pop(context);
                _showDeleteConfirmation(config);
              },
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: Text(context.l10n.cancel),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  /// Share directly if link exists, otherwise open sheet
  Future<void> _shareOrShowSheet() async {
    final order = _store.order;
    if (order?.id == null || order?.company?.id == null) return;

    // Check if order has an active share link
    final shareLink = order!.shareLink;
    if (shareLink != null && !shareLink.isExpired && shareLink.url != null) {
      // Has active link - share directly
      final service = ShareLinkService.instance;
      final message = service.buildShareMessage(
        customerName: order.customer?.name ?? '',
        orderNumber: order.number ?? 0,
        companyName: order.company?.name,
        locale: context.l10n.localeName,
      );

      // Get share position for iPad
      final box = context.findRenderObject() as RenderBox?;
      final sharePositionOrigin = box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : null;

      await service.shareViaSheet(
        url: shareLink.url!,
        message: message,
        subject: '${context.l10n.order} #${order.number}',
        sharePositionOrigin: sharePositionOrigin,
      );
    } else if (mounted) {
      // No active link - show sheet to create one
      ShareLinkSheet.show(context, order);
    }
  }

  /// Always open the share link sheet (for menu item)
  void _openShareLinkSheet() {
    final order = _store.order;
    if (order?.id == null) return;
    ShareLinkSheet.show(context, order!);
  }

  void _selectCustomer() {
    Navigator.pushNamed(
      context,
      '/customer_list',
      arguments: {'order': _store.order},
    ).then((customer) {
      if (customer != null) {
        _store.setCustomer(customer as Customer);
      }
    });
  }

  void _selectDevice() {
    Navigator.pushNamed(
      context,
      '/device_list',
      arguments: {'order': _store.order},
    ).then((device) {
      if (device != null) {
        _store.setDevice(device as Device);
      }
    });
  }

  void _selectDueDate() {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        height: 216,
        padding: const EdgeInsets.only(top: 6.0),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: SafeArea(
          top: false,
          child: CupertinoDatePicker(
            initialDateTime: (_store.order?.dueDate != null) ? _store.order!.dueDate! : DateTime.now(),
            mode: CupertinoDatePickerMode.date,
            use24hFormat: true,
            onDateTimeChanged: (DateTime newDate) {
              _store.setDueDate(newDate);
            },
          ),
        ),
      ),
    );
  }

  void _selectStatus(SegmentConfigProvider config) {
     // Obter apenas os status disponíveis para o perfil do usuário
     final order = _store.order;
     if (order == null) return;

     final availableStatuses = _authService.getAvailableStatuses(order);

     // Se não há status disponíveis, mostrar alerta
     if (availableStatuses.isEmpty) {
       showCupertinoDialog(
         context: context,
         builder: (context) => CupertinoAlertDialog(
           title: Text(context.l10n.permissionDenied),
           content: Text(context.l10n.permissionDenied),
           actions: [
             CupertinoDialogAction(
               child: Text(context.l10n.ok),
               onPressed: () => Navigator.pop(context),
             ),
           ],
         ),
       );
       return;
     }

     showCupertinoModalPopup(
       context: context,
       builder: (context) => CupertinoActionSheet(
         title: Text(context.l10n.changeStatus),
         actions: availableStatuses.map((key) {
           return CupertinoActionSheetAction(
             child: Text(config.getStatus(key)),
             onPressed: () {
               Navigator.pop(context);
               _trySetStatus(key, config);
             },
           );
         }).toList(),
         cancelButton: CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(context.l10n.cancel),
          ),
       ),
     );
  }

  /// Tenta alterar o status, verificando permissões e formulários pendentes
  void _trySetStatus(String newStatus, SegmentConfigProvider config) {
    final order = _store.order;
    if (order == null) return;

    // Verificar se o usuário tem permissão para fazer esta mudança de status
    if (!_authService.canChangeOrderStatus(order, newStatus)) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text(context.l10n.permissionDenied),
          content: Text(context.l10n.permissionDenied),
          actions: [
            CupertinoDialogAction(
              child: Text(context.l10n.ok),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
      return;
    }

    // Se não for "done", permite alterar diretamente
    if (newStatus != 'done') {
      _store.setStatus(newStatus);
      return;
    }

    // Verifica se há formulários pendentes
    final forms = _store.formsStream?.value ?? [];
    final pendingForms = forms.where(
      (form) => form.status != of_model.FormStatus.completed
    ).toList();

    if (pendingForms.isEmpty) {
      // Todos os formulários estão concluídos, permite alterar
      _store.setStatus(newStatus);
      return;
    }

    // Há formulários pendentes, mostra alerta
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('${context.l10n.checklists} ${context.l10n.statusPending}'),
        content: Text(
          pendingForms.length == 1
            ? '${context.l10n.checklist} "${pendingForms.first.getLocalizedTitle(_localeCode)}" ${context.l10n.incomplete}.'
            : '${pendingForms.length} ${context.l10n.checklists} ${context.l10n.incomplete}:\n\n${pendingForms.map((f) => '• ${f.getLocalizedTitle(_localeCode)}').join('\n')}',
        ),
        actions: [
          CupertinoDialogAction(
            child: Text(context.l10n.ok),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _openPaymentManagement() {
    Navigator.pushNamed(
      context,
      '/payment_management',
      arguments: {'orderStore': _store},
    );
  }

  void _addService() {
    Navigator.pushNamed(
      context,
      '/service_list',
      arguments: {'orderStore': _store},
    );
  }

  void _editService(int index) {
    Navigator.pushNamed(
      context,
      '/order_service',
      arguments: {
        'orderStore': _store,
        'orderServiceIndex': index,
      },
    );
  }

  void _addProduct() {
    Navigator.pushNamed(
      context,
      '/product_list',
      arguments: {'orderStore': _store},
    );
  }

  void _editProduct(int index) {
    Navigator.pushNamed(
      context,
      '/order_product',
      arguments: {
        'orderStore': _store,
        'orderProductIndex': index,
      },
    );
  }

  void _confirmDeleteService(int index, SegmentConfigProvider config) {
    final service = _store.services?[index];
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('${config.label(LabelKeys.remove)} ${config.label(LabelKeys.editService).split(' ').last}'),
        content: Text('Deseja remover "${service?.service?.name ?? 'este serviço'}" da ${config.serviceOrder}?'),
        actions: [
          CupertinoDialogAction(
            child: Text(config.label(LabelKeys.cancel)),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: Text(config.label(LabelKeys.remove)),
            onPressed: () {
              Navigator.pop(context);
              _store.deleteService(index);
            },
          ),
        ],
      ),
    );
  }

  void _confirmDeleteProduct(int index, SegmentConfigProvider config) {
    final product = _store.products?[index];
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('${config.label(LabelKeys.remove)} ${config.label(LabelKeys.editProduct).split(' ').last}'),
        content: Text('Deseja remover "${product?.product?.name ?? 'este produto'}" da ${config.serviceOrder}?'),
        actions: [
          CupertinoDialogAction(
            child: Text(config.label(LabelKeys.cancel)),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: Text(config.label(LabelKeys.remove)),
            onPressed: () {
              Navigator.pop(context);
              _store.deleteProduct(index);
            },
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(SegmentConfigProvider config) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Excluir ${config.serviceOrder}'),
        content: Text('Tem certeza que deseja excluir esta ${config.serviceOrder}?'),
        actions: [
          CupertinoDialogAction(
            child: Text(config.label(LabelKeys.cancel)),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: Text(config.label(LabelKeys.delete)),
            onPressed: () {
              _store.deleteOrder().then((_) {
                if (mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              });
            },
          ),
        ],
      ),
    );
  }
  
  void _showAddPhotoOptions(SegmentConfigProvider config) {
    // Save the widget's context before entering the action sheet builder
    final widgetContext = context;

    showCupertinoModalPopup(
      context: context,
      builder: (actionSheetContext) => CupertinoActionSheet(
        title: Text(context.l10n.addPhoto),
        actions: [
           CupertinoActionSheetAction(
            child: Text(context.l10n.takePhoto),
            onPressed: () async {
              Navigator.pop(actionSheetContext);
              final success = await _store.addPhotoFromCamera();
              if (!success && mounted) {
                showCupertinoDialog(
                  context: widgetContext,
                  builder: (dialogContext) => CupertinoAlertDialog(
                    title: Text(widgetContext.l10n.errorOccurred),
                    content: Text(widgetContext.l10n.errorOccurred),
                    actions: [
                      CupertinoDialogAction(
                        child: Text(widgetContext.l10n.ok),
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                    ],
                  ),
                );
              }
            },
          ),
           CupertinoActionSheetAction(
            child: Text(context.l10n.chooseFromGallery),
            onPressed: () async {
              Navigator.pop(actionSheetContext);
              final success = await _store.addPhotoFromGallery();
              if (!success && mounted) {
                showCupertinoDialog(
                  context: widgetContext,
                  builder: (dialogContext) => CupertinoAlertDialog(
                    title: Text(widgetContext.l10n.errorOccurred),
                    content: Text(widgetContext.l10n.errorOccurred),
                    actions: [
                      CupertinoDialogAction(
                        child: Text(widgetContext.l10n.ok),
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                    ],
                  ),
                );
              }
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: Text(context.l10n.cancel),
          onPressed: () => Navigator.pop(actionSheetContext),
        ),
      ),
    );
  }

  Color _getStatusColorCupertino(String? status) {
    if (status == null) return CupertinoColors.systemGrey;
    switch (status) {
      case 'quote':
        return CupertinoColors.systemOrange;
      case 'approved':
        return CupertinoColors.systemBlue;
      case 'progress':
        return CupertinoColors.systemPurple;
      case 'done':
        return CupertinoColors.systemGreen;
      case 'canceled':
        return CupertinoColors.systemRed;
      default:
        return CupertinoColors.systemGrey;
    }
  }

  String _convertToCurrency(double? total) {
    return FormatService().formatCurrency(total ?? 0.0);
  }
  
  // PDF Generation Logic - Usando novo PdfService
  _onShare(BuildContext context, Order? order, SegmentConfigProvider config) async {
    if (order == null) return;

    // Store navigator reference before async operations
    final navigator = Navigator.of(context, rootNavigator: true);

    // Create PDF localizations from context before async operations
    final pdfLocalizations = PdfLocalizations.fromContext(context);

    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return CupertinoAlertDialog(
          content: Column(
            children: [
              const CupertinoActivityIndicator(),
              const SizedBox(height: 10),
              Text('${context.l10n.loading}...'),
            ],
          ),
        );
      },
    );

    try {
      // 1. Coletar dados
      CompanyStore companyStore = CompanyStore();
      Company company = await companyStore.retrieveCompany(order.company!.id);

      Customer? customer;
      if (order.customer != null) {
        if (order.customer!.id != null && _store.companyId != null) {
          try {
            CustomerStore customerStore = CustomerStore();
            customerStore.companyId = _store.companyId;
            customer = await customerStore.retrieveCustomer(order.customer!.id);
          } catch (e) {
            // Silently fail and use fallback
          }
        }

        // Fallback: usar dados do agregado se a busca falhou
        customer ??= Customer()
          ..id = order.customer!.id
          ..name = order.customer!.name
          ..phone = order.customer!.phone
          ..email = order.customer!.email;
      }

      // 2. Buscar formularios anexados a OS
      List<of_model.OrderForm> forms = [];
      if (_store.companyId != null && order.id != null) {
        forms = await _formsService
            .getOrderForms(_store.companyId!, order.id!)
            .first;
      }

      // 3. Criar dados para o PDF
      final pdfData = OsPdfData(
        order: order,
        customer: customer,
        company: company,
        forms: forms,
        config: config,
        localizations: pdfLocalizations,
      );

      // 4. Gerar e compartilhar PDF
      final pdfService = PdfService();
      await pdfService.shareOsPdf(pdfData);

      if (mounted) {
        navigator.pop();
      }
    } catch (e) {
      if (context.mounted) {
        navigator.pop();

        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: Text(context.l10n.errorOccurred),
            content: Text('${context.l10n.errorOccurred}: $e'),
            actions: [
              CupertinoDialogAction(
                child: Text(context.l10n.ok),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    }
  }
}
