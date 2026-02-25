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
import 'package:praticos/screens/widgets/device_picker_sheet.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/constants/label_keys.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/services/authorization_service.dart';
import 'package:praticos/mobx/reminder_store.dart';

// Formulários Dinâmicos
import 'package:praticos/models/order_form.dart' as of_model; // Alias para evitar conflito com esta classe OrderForm
import 'package:praticos/services/forms_service.dart';
import 'package:praticos/screens/forms/form_selection_screen.dart';
import 'package:praticos/screens/forms/form_fill_screen.dart';

import 'package:praticos/services/pdf/pdf_localizations.dart';
import 'package:praticos/services/pdf/pdf_service.dart';
import 'package:praticos/screens/widgets/share_link_sheet.dart';
import 'package:praticos/screens/widgets/order_comments_widget.dart';
import 'package:praticos/services/location_service.dart';

class OrderForm extends StatefulWidget {
  @override
  _OrderFormState createState() => _OrderFormState();
}

class _OrderFormState extends State<OrderForm> {
  late OrderStore _store;
  final FormsService _formsService = FormsService();
  final AuthorizationService _authService = AuthorizationService.instance;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _addressController = TextEditingController();
  bool _shouldScrollToComments = false;
  String? _highlightCommentId;
  final Set<String> _dismissedSharePrompts = {};

  /// Gets the current locale code for i18n (e.g., 'pt', 'en', 'es')
  String? get _localeCode => context.l10n.localeName;

  @override
  void initState() {
    super.initState();
    _store = OrderStore();

    Future.delayed(Duration.zero, () {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

      // Check if we should scroll to comments
      _shouldScrollToComments = args?['scrollToComments'] == true;
      _highlightCommentId = args?['commentId'] as String?;

      if (args != null && args.containsKey('order')) {
        Order orderArg = args['order'];

        if (orderArg.id != null) {
          _store.repository.getSingle(_store.companyId!, orderArg.id!).then((updatedOrder) {
            _store.setOrder(updatedOrder ?? orderArg);
            _scrollToCommentsIfNeeded();
          });
        } else if (orderArg.number != null) {
          _store.repository.getOrderByNumber(_store.companyId!, orderArg.number!).then((
            existingOrder,
          ) {
            _store.setOrder(existingOrder ?? orderArg);
            _scrollToCommentsIfNeeded();
          });
        } else {
          _store.setOrder(orderArg);
          _scrollToCommentsIfNeeded();
        }
      } else {
        _store.loadOrder();
      }
    });
  }

  void _scrollToCommentsIfNeeded() {
    if (!_shouldScrollToComments) return;
    _shouldScrollToComments = false; // Only scroll once

    // Wait for the page to be fully rendered, then scroll to bottom (where comments are)
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _addressController.dispose();
    super.dispose();
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
          controller: _scrollController,
          slivers: [
            _buildNavigationBar(context, config),
            SliverSafeArea(
              top: false,
              sliver: Observer(
                builder: (_) {
                  final services = _store.services ?? [];
                  final products = _store.products ?? [];
                  final forms = _store.formsStream?.value ?? [];

                  return SliverList(
                    delegate: SliverChildListDelegate([
                      _buildPhotosSection(context, config),
                      _buildClientDeviceSection(context, config),
                      _buildSummarySection(context, config),
                      _buildDevicesSection(context, config),
                      // Items sections — conditional on device grouping
                      if (_store.devices.length >= 2) ...[
                        _buildGroupedItemsByDevice(context, config, services, products, forms),
                      ] else ...[
                        if (services.isNotEmpty)
                          _buildServicesSection(context, config),
                        if (products.isNotEmpty)
                          _buildProductsSection(context, config),
                        if (forms.isNotEmpty)
                          _buildFormsSection(context, config),
                      ],
                      // Always show consolidated add button
                      _buildConsolidatedAddSection(context, config),
                      _buildCommentsSection(context),
                      const SizedBox(height: 40),
                    ]),
                  );
                },
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
          final rating = os?.rating;
          final hasRating = rating?.hasRating == true;

          if (!hasRating) {
            return Text(
              os?.number != null ? "${context.l10n.orderShort} #${os!.number}" : config.label(LabelKeys.createServiceOrder),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            );
          }

          return Row(
            children: [
              Text(
                os?.number != null ? "${context.l10n.orderShort} #${os!.number}" : config.label(LabelKeys.createServiceOrder),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      CupertinoIcons.star_fill,
                      color: Color(0xFFFFD700),
                      size: 18,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${rating!.score}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.secondaryLabel.resolveFrom(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      trailing: Observer(
        builder: (_) {
          final order = _store.orderStream?.value;
          final isSaved = order?.id != null;

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Add items button
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => _showConsolidatedAddOptions(config),
                child: const Icon(CupertinoIcons.plus),
              ),
              // Share button - only for saved orders
              if (isSaved)
                Semantics(
                  identifier: 'share_order_button',
                  button: true,
                  label: context.l10n.shareWithCustomer,
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _openShareLinkSheet,
                    child: const Icon(CupertinoIcons.square_arrow_up),
                  ),
                ),
              // Menu button
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
          trailing: hasCreatedDate
              ? Text(
                  '${context.l10n.createdAt} ${_store.formattedCreatedDate}',
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.tertiaryLabel.resolveFrom(context),
                    fontWeight: FontWeight.w400,
                  ),
                )
              : null,
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
            _buildScheduledDateTile(context),
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
        final hasAddress = _store.address != null && _store.address!.isNotEmpty;
        final hasCoordinates = _store.latitude != null && _store.longitude != null;

        return _buildGroupedSection(
          header: config.customer.toUpperCase(),
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
            // Address inline text field
            _buildAddressField(context, canEditFields, hasAddress, hasCoordinates),
          ],
        );
      },
    );
  }

  Widget _buildAddressField(BuildContext context, bool canEditFields, bool hasAddress, bool hasCoordinates) {
    // Sync controller with store (e.g. auto-fill from customer)
    final storeAddress = _store.address ?? '';
    if (_addressController.text != storeAddress) {
      _addressController.text = storeAddress;
    }

    final canOpenMaps = hasAddress || hasCoordinates;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              GestureDetector(
                onTap: canOpenMaps
                    ? () => LocationService().openInMaps(
                          lat: _store.latitude,
                          lng: _store.longitude,
                          address: _store.address,
                        )
                    : null,
                child: Icon(
                  CupertinoIcons.location_solid,
                  color: canOpenMaps
                      ? CupertinoTheme.of(context).primaryColor
                      : CupertinoColors.systemGrey.resolveFrom(context),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CupertinoTextField(
                  controller: _addressController,
                  placeholder: context.l10n.addressPlaceholder,
                  textCapitalization: TextCapitalization.sentences,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
                  decoration: null,
                  style: TextStyle(
                    fontSize: 17,
                    color: canEditFields
                        ? CupertinoColors.label.resolveFrom(context)
                        : CupertinoColors.tertiaryLabel.resolveFrom(context),
                  ),
                  placeholderStyle: TextStyle(
                    fontSize: 17,
                    color: CupertinoColors.placeholderText.resolveFrom(context),
                  ),
                  enabled: canEditFields,
                  onChanged: (text) {
                    final trimmed = text.trim();
                    _store.setAddress(
                      trimmed.isEmpty ? null : trimmed,
                      lat: trimmed.isEmpty ? null : _store.latitude,
                      lng: trimmed.isEmpty ? null : _store.longitude,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDevicesSection(BuildContext context, SegmentConfigProvider config) {
    return Observer(builder: (_) {
      final devicesList = _store.devices.toList();
      if (devicesList.isEmpty) return const SizedBox.shrink();

      final canEdit = _store.order != null
          ? _authService.canEditOrderMainFields(_store.order!)
          : true;

      return _buildGroupedSection(
        header: config.device.toUpperCase(),
        trailing: canEdit
            ? _buildAddButton(onTap: _selectDevice, label: context.l10n.add)
            : null,
        children: devicesList.asMap().entries.map((entry) {
          final d = entry.value;
          final displayName = d.serial != null && d.serial!.trim().isNotEmpty
              ? '${d.name} - ${d.serial}'
              : d.name ?? '';
          final tile = _buildListTile(
            context: context,
            icon: config.deviceIcon,
            title: displayName,
            value: '',
            onTap: () {
              if (canEdit) _editDevice(d);
            },
            showChevron: canEdit,
            isLast: entry.key == devicesList.length - 1,
            enabled: canEdit,
          );
          if (!canEdit || d.id == null) return tile;
          return Dismissible(
            key: ValueKey(d.id),
            direction: DismissDirection.endToStart,
            confirmDismiss: (_) async {
              _confirmRemoveDevice(d, config);
              return false;
            },
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              color: CupertinoColors.systemRed,
              child: const Icon(CupertinoIcons.delete, color: CupertinoColors.white),
            ),
            child: tile,
          );
        }).toList(),
      );
    });
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
            final isLoading = hasOrder && !snapshot.hasData;
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
      key: ValueKey('form_${form.id}'),
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
                devices: _store.devices.toList(),
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

  void _addForm(SegmentConfigProvider config, {String? presetDeviceId}) async {
    String? formDeviceId = presetDeviceId;

    // Multi-device: ask which device before selecting form (unless preset)
    if (formDeviceId == null && _store.devices.length >= 2) {
      final result = await DevicePickerSheet.show(context, _store.devices.toList());
      if (result == null) return;
      if (result.action == DevicePickerAction.specific) {
        formDeviceId = result.device?.id;
      } else if (result.action == DevicePickerAction.multiSpecific) {
        // For forms, use first selected device (forms don't duplicate)
        formDeviceId = result.deviceIds?.first;
      }
      // "all" and "general" → deviceId stays null
    }

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
      final newForm = await _formsService.addFormToOrder(
        _store.companyId!,
        _store.order!.id!,
        template,
        deviceId: formDeviceId,
      );

      if (mounted) {
        Navigator.push(
          context,
          CupertinoPageRoute(
            fullscreenDialog: true,
            builder: (context) => FormFillScreen(
              orderId: _store.order!.id!,
              companyId: _store.companyId!,
              orderForm: newForm,
              devices: _store.devices.toList(),
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
            highlightCommentId: _highlightCommentId,
          ),
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

  // --- Grouped Items by Device ---

  Widget _buildGroupedItemsByDevice(
    BuildContext context,
    SegmentConfigProvider config,
    List<dynamic> services,
    List<dynamic> products,
    List<of_model.OrderForm> forms,
  ) {
    final canEditFields = _store.order != null
        ? _authService.canEditOrderMainFields(_store.order!)
        : true;
    final canManageForms = _store.order != null
        ? _authService.canManageOrderForms(_store.order!)
        : true;

    // Build list of device groups: each device + "General" (null)
    final deviceGroups = <MapEntry<String?, String>>[];

    for (final d in _store.devices) {
      final displayName = d.serial != null && d.serial!.trim().isNotEmpty
          ? '${d.name} - ${d.serial}'
          : d.name ?? '';
      deviceGroups.add(MapEntry(d.id, displayName));
    }

    // Add "General" group for items without deviceId
    deviceGroups.add(MapEntry(null, context.l10n.generalNoDevice));

    final widgets = <Widget>[];

    for (final group in deviceGroups) {
      final deviceId = group.key;
      final groupName = group.value;

      // Filter items for this device
      final groupServices = services
          .where((s) => s.deviceId == deviceId)
          .toList();
      final groupProducts = products
          .where((p) => p.deviceId == deviceId)
          .toList();
      final groupForms = forms
          .where((f) => f.deviceId == deviceId)
          .toList();

      if (groupServices.isEmpty && groupProducts.isEmpty && groupForms.isEmpty) {
        continue;
      }

      final children = <Widget>[];

      // Services in this group
      for (var i = 0; i < groupServices.length; i++) {
        final service = groupServices[i];
        final globalIndex = _store.services!.indexOf(service);
        final isLast = i == groupServices.length - 1 &&
            groupProducts.isEmpty &&
            groupForms.isEmpty;
        children.add(_buildServiceRow(context, service, globalIndex, isLast, config));
      }

      // Products in this group
      for (var i = 0; i < groupProducts.length; i++) {
        final product = groupProducts[i];
        final globalIndex = _store.products!.indexOf(product);
        final isLast = i == groupProducts.length - 1 && groupForms.isEmpty;
        children.add(_buildProductRow(context, product, globalIndex, isLast, config));
      }

      // Forms in this group
      for (var i = 0; i < groupForms.length; i++) {
        final form = groupForms[i];
        final isLast = i == groupForms.length - 1;
        children.add(_buildFormRow(context, form, isLast, canManageForms));
      }

      widgets.add(
        _buildGroupedSection(
          header: groupName.toUpperCase(),
          trailing: (canEditFields || canManageForms)
              ? _buildAddButton(
                  onTap: () => _showAddOptionsForDevice(config, deviceId),
                  label: context.l10n.add,
                )
              : null,
          children: children,
        ),
      );
    }

    return Column(children: widgets);
  }

  /// Show add options pre-scoped to a specific device (skips picker)
  void _showAddOptionsForDevice(SegmentConfigProvider config, String? deviceId) {
    final canEditFields = _store.order != null
        ? _authService.canEditOrderMainFields(_store.order!)
        : true;
    final canManageForms = _store.order != null
        ? _authService.canManageOrderForms(_store.order!)
        : true;

    final actions = <CupertinoActionSheetAction>[];

    if (canEditFields) {
      actions.add(_buildActionWithIcon(
        CupertinoIcons.wrench,
        '${context.l10n.add} ${context.l10n.service}',
        () {
          Navigator.pop(context);
          _addService(presetDeviceId: deviceId);
        },
      ));
      actions.add(_buildActionWithIcon(
        CupertinoIcons.cube_box,
        '${context.l10n.add} ${context.l10n.product}',
        () {
          Navigator.pop(context);
          _addProduct(presetDeviceId: deviceId);
        },
      ));
    }

    if (canManageForms) {
      actions.add(_buildActionWithIcon(
        CupertinoIcons.doc_text,
        '${context.l10n.add} ${context.l10n.form}',
        () {
          Navigator.pop(context);
          _addForm(config, presetDeviceId: deviceId);
        },
      ));
    }

    actions.add(_buildActionWithIcon(
      CupertinoIcons.camera,
      context.l10n.addPhoto,
      () {
        Navigator.pop(context);
        _showAddPhotoOptions(config);
      },
    ));

    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(context.l10n.add),
        actions: actions,
        cancelButton: CupertinoActionSheetAction(
          child: Text(context.l10n.cancel),
          onPressed: () => Navigator.pop(ctx),
        ),
      ),
    );
  }

  // --- Helper Methods ---

  CupertinoActionSheetAction _buildActionWithIcon(
    IconData icon, String label, VoidCallback onPressed,
  ) {
    return CupertinoActionSheetAction(
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  /// Show action sheet with consolidated add options
  void _showConsolidatedAddOptions(SegmentConfigProvider config) {
    final canEditFields = _store.order != null
        ? _authService.canEditOrderMainFields(_store.order!)
        : true;
    final canManageForms = _store.order != null
        ? _authService.canManageOrderForms(_store.order!)
        : true;

    final actions = <CupertinoActionSheetAction>[];

    if (canEditFields) {
      actions.add(_buildActionWithIcon(
        config.deviceIcon,
        '${context.l10n.add} ${config.device}',
        () { Navigator.pop(context); _selectDevice(); },
      ));
      actions.add(_buildActionWithIcon(
        CupertinoIcons.wrench,
        '${context.l10n.add} ${context.l10n.service}',
        () { Navigator.pop(context); _addService(); },
      ));
      actions.add(_buildActionWithIcon(
        CupertinoIcons.cube_box,
        '${context.l10n.add} ${context.l10n.product}',
        () { Navigator.pop(context); _addProduct(); },
      ));
    }

    if (canManageForms) {
      actions.add(_buildActionWithIcon(
        CupertinoIcons.doc_text,
        '${context.l10n.add} ${context.l10n.form}',
        () { Navigator.pop(context); _addForm(config); },
      ));
    }

    actions.add(_buildActionWithIcon(
      CupertinoIcons.camera,
      context.l10n.addPhoto,
      () { Navigator.pop(context); _showAddPhotoOptions(config); },
    ));

    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(context.l10n.add),
        actions: actions,
        cancelButton: CupertinoActionSheetAction(
          child: Text(context.l10n.cancel),
          onPressed: () => Navigator.pop(ctx),
        ),
      ),
    );
  }

  /// Build consolidated add section - always visible for adding items
  /// Follows iOS HIG pattern: same style as other grouped rows with primary color text
  Widget _buildConsolidatedAddSection(BuildContext context, SegmentConfigProvider config) {
    final canEditFields = _store.order != null
        ? _authService.canEditOrderMainFields(_store.order!)
        : true;
    final canManageForms = _store.order != null
        ? _authService.canManageOrderForms(_store.order!)
        : true;

    // Only show if user has at least one permission
    if (!canEditFields && !canManageForms) {
      return const SizedBox.shrink();
    }

    return _buildGroupedSection(
      header: '',
      children: [
        _buildListTile(
          context: context,
          icon: CupertinoIcons.plus_circle_fill,
          title: context.l10n.addItems,
          value: '',
          onTap: () => _showConsolidatedAddOptions(config),
          showChevron: true,
          isLast: true,
          textColor: CupertinoTheme.of(context).primaryColor,
        ),
      ],
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
          // Only show header if not empty
          if (header.isNotEmpty || trailing != null)
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
            )
          else
            const SizedBox(height: 16),
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
      key: ValueKey('service_$index'),
      onDelete: () => _confirmDeleteService(index, config),
      canDelete: canEditFields,
      child: _buildItemRow(
        context: context,
        icon: CupertinoIcons.wrench,
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
      key: ValueKey('product_$index'),
      onDelete: () => _confirmDeleteProduct(index, config),
      canDelete: canEditFields,
      child: _buildItemRow(
        context: context,
        icon: CupertinoIcons.cube_box,
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
    required ValueKey key,
    required VoidCallback onDelete,
    required Widget child,
    bool canDelete = true,
  }) {
    // Se não pode deletar, retorna apenas o child sem o Dismissible
    if (!canDelete) {
      return child;
    }

    return Dismissible(
      key: key,
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
    IconData? icon,
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
                  if (icon != null) ...[
                    Icon(icon, color: CupertinoColors.secondaryLabel.resolveFrom(context), size: 20),
                    const SizedBox(width: 10),
                  ],
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
                indent: icon != null ? 46 : 16,
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

  /// Open the share link sheet
  void _openShareLinkSheet({String? statusContext}) {
    final order = _store.order;
    if (order?.id == null) return;
    ShareLinkSheet.show(context, order!, statusContext: statusContext);
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

  void _editDevice(DeviceAggr deviceAggr) {
    // Convert DeviceAggr to Device for the form screen
    final device = Device.fromJson(deviceAggr.toJson());
    Navigator.pushNamed(
      context,
      '/device_form',
      arguments: {'device': device},
    ).then((result) {
      if (result != null && result is Device) {
        // Update the device in the order
        final aggr = result.toAggr();
        final idx = _store.order!.devices?.indexWhere((d) => d.id == aggr.id) ?? -1;
        if (idx >= 0) {
          _store.order!.devices![idx] = aggr;
          _store.devices[idx] = aggr;
          // Sync backward compat
          if (_store.order!.devices!.first.id == aggr.id) {
            _store.order!.device = aggr;
            _store.device = aggr;
          }
          _store.createItem();
        }
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
        _store.addDevice(device as Device);
      }
    });
  }

  void _confirmRemoveDevice(DeviceAggr device, SegmentConfigProvider config) {
    if (device.id == null) return;
    final deviceId = device.id!;

    // Count associated items
    final serviceCount = (_store.order?.services ?? [])
        .where((s) => s.deviceId == deviceId).length;
    final productCount = (_store.order?.products ?? [])
        .where((p) => p.deviceId == deviceId).length;
    final itemCount = serviceCount + productCount;

    if (itemCount == 0) {
      // No associated items — simple dialog
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: Text(context.l10n.removeDevice),
          content: Text(context.l10n.confirmRemoveDevice(device.name ?? '')),
          actions: [
            CupertinoDialogAction(
              child: Text(context.l10n.cancel),
              onPressed: () => Navigator.pop(ctx),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              child: Text(context.l10n.removeDevice),
              onPressed: () {
                Navigator.pop(ctx);
                _store.removeDevice(deviceId);
              },
            ),
          ],
        ),
      );
    } else {
      // Has associated items — 3-option dialog
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: Text(context.l10n.removeDevice),
          content: Text(context.l10n.removeDeviceHasItems(
            device.name ?? '', itemCount.toString(),
          )),
          actions: [
            CupertinoDialogAction(
              child: Text(context.l10n.cancel),
              onPressed: () => Navigator.pop(ctx),
            ),
            CupertinoDialogAction(
              child: Text(context.l10n.removeDeviceKeepItems),
              onPressed: () {
                Navigator.pop(ctx);
                _store.removeDevice(deviceId);
              },
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              child: Text(context.l10n.removeDeviceAndItems),
              onPressed: () {
                Navigator.pop(ctx);
                _store.removeDeviceAndItems(deviceId);
              },
            ),
          ],
        ),
      );
    }
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
            mode: CupertinoDatePickerMode.dateAndTime,
            use24hFormat: true,
            onDateTimeChanged: (DateTime newDate) {
              _store.setDueDate(newDate);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildScheduledDateTile(BuildContext context) {
    return Observer(
      builder: (_) {
        final hasScheduledDate = _store.scheduledDate != null;
        final canEdit = _store.order != null
            ? _authService.canEditOrderMainFields(_store.order!)
            : true;

        return GestureDetector(
          onTap: canEdit ? _selectScheduledDate : null,
          child: Container(
            color: CupertinoColors.systemBackground.resolveFrom(context).withValues(alpha: 0),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(CupertinoIcons.calendar_badge_plus,
                          color: CupertinoTheme.of(context).primaryColor, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          context.l10n.scheduledDate,
                          style: TextStyle(
                            fontSize: 17,
                            color: canEdit
                                ? CupertinoColors.label.resolveFrom(context)
                                : CupertinoColors.tertiaryLabel.resolveFrom(context),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            hasScheduledDate ? _store.scheduledDate! : context.l10n.select,
                            style: TextStyle(
                              fontSize: 17,
                              color: canEdit
                                  ? (hasScheduledDate
                                      ? CupertinoColors.secondaryLabel.resolveFrom(context)
                                      : CupertinoColors.placeholderText.resolveFrom(context))
                                  : CupertinoColors.tertiaryLabel.resolveFrom(context),
                            ),
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ),
                      if (hasScheduledDate && canEdit) ...[
                        const SizedBox(width: 6),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(24, 24),
                          onPressed: () => _store.clearScheduledDate(),
                          child: Icon(
                            CupertinoIcons.xmark_circle_fill,
                            size: 18,
                            color: CupertinoColors.systemGrey3.resolveFrom(context),
                          ),
                        ),
                      ] else if (canEdit) ...[
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
                // No divider - this is before other items that have their own divider
              ],
            ),
          ),
        );
      },
    );
  }

  void _selectScheduledDate() {
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
            initialDateTime: (_store.order?.scheduledDate != null)
                ? _store.order!.scheduledDate!
                : DateTime.now(),
            mode: CupertinoDatePickerMode.dateAndTime,
            use24hFormat: true,
            onDateTimeChanged: (DateTime newDate) {
              final reminderStore = Provider.of<ReminderStore>(context, listen: false);
              _store.setScheduledDate(newDate, reminderStore: reminderStore);
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
      _promptShareAfterStatusChange(newStatus);
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
      _promptShareAfterStatusChange(newStatus);
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

  /// Prompt user to share status update with customer via WhatsApp
  void _promptShareAfterStatusChange(String newStatus) {
    final order = _store.order;
    if (order == null || order.id == null) return;

    // Only prompt for relevant statuses
    if (newStatus != 'approved' && newStatus != 'progress' && newStatus != 'done') return;

    // Skip if customer already has an active share link
    final existingLink = order.shareLink;
    if (existingLink != null && !existingLink.isExpired && existingLink.token != null) return;

    // Skip if user already dismissed for this order in this session
    if (_dismissedSharePrompts.contains(order.id)) return;

    // Only prompt if customer has a phone
    final customerName = order.customer?.name;
    final customerPhone = order.customer?.phone;
    if (customerPhone == null || customerPhone.isEmpty) return;

    // Status-specific dialog title
    String statusTitle(BuildContext ctx) {
      switch (newStatus) {
        case 'approved':
          return ctx.l10n.statusUpdateApproved;
        case 'progress':
          return ctx.l10n.statusUpdateProgress;
        case 'done':
          return ctx.l10n.statusUpdateDone;
        default:
          return ctx.l10n.notifyCustomerQuestion;
      }
    }

    // Show dialog after a brief delay to let the status update settle
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: Text(statusTitle(ctx)),
          content: Text(ctx.l10n.notifyCustomerDescription(customerName ?? ctx.l10n.customer)),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () {
                _dismissedSharePrompts.add(order.id!);
                Navigator.pop(ctx);
              },
              child: Text(ctx.l10n.notNow),
            ),
            CupertinoDialogAction(
              onPressed: () {
                Navigator.pop(ctx);
                _openShareLinkSheet(statusContext: newStatus);
              },
              child: Text(ctx.l10n.sendViaWhatsApp),
            ),
          ],
        ),
      );
    });
  }

  void _openPaymentManagement() {
    Navigator.pushNamed(
      context,
      '/payment_management',
      arguments: {'orderStore': _store},
    );
  }

  void _addService({String? presetDeviceId}) async {
    if (presetDeviceId != null) {
      _store.pendingDeviceId = presetDeviceId;
      _store.pendingDuplicateAll = false;
      _store.pendingDeviceIds = null;
    } else if (_store.devices.length >= 2) {
      final result = await DevicePickerSheet.show(context, _store.devices.toList());
      if (result == null) return;
      if (result.action == DevicePickerAction.specific) {
        _store.pendingDeviceId = result.device?.id;
        _store.pendingDuplicateAll = false;
        _store.pendingDeviceIds = null;
      } else if (result.action == DevicePickerAction.all) {
        _store.pendingDeviceId = null;
        _store.pendingDuplicateAll = true;
        _store.pendingDeviceIds = null;
      } else if (result.action == DevicePickerAction.multiSpecific) {
        _store.pendingDeviceId = null;
        _store.pendingDuplicateAll = false;
        _store.pendingDeviceIds = result.deviceIds;
      } else {
        _store.pendingDeviceId = null;
        _store.pendingDuplicateAll = false;
        _store.pendingDeviceIds = null;
      }
    }
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

  void _addProduct({String? presetDeviceId}) async {
    if (presetDeviceId != null) {
      _store.pendingDeviceId = presetDeviceId;
      _store.pendingDuplicateAll = false;
      _store.pendingDeviceIds = null;
    } else if (_store.devices.length >= 2) {
      final result = await DevicePickerSheet.show(context, _store.devices.toList());
      if (result == null) return;
      if (result.action == DevicePickerAction.specific) {
        _store.pendingDeviceId = result.device?.id;
        _store.pendingDuplicateAll = false;
        _store.pendingDeviceIds = null;
      } else if (result.action == DevicePickerAction.all) {
        _store.pendingDeviceId = null;
        _store.pendingDuplicateAll = true;
        _store.pendingDeviceIds = null;
      } else if (result.action == DevicePickerAction.multiSpecific) {
        _store.pendingDeviceId = null;
        _store.pendingDuplicateAll = false;
        _store.pendingDeviceIds = result.deviceIds;
      } else {
        _store.pendingDeviceId = null;
        _store.pendingDuplicateAll = false;
        _store.pendingDeviceIds = null;
      }
    }
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
