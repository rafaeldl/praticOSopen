import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/models/nfse.dart';
import 'package:praticos/screens/order/new_order_form.dart';
import 'package:praticos/screens/payments/asaas_error_text.dart';
import 'package:praticos/screens/widgets/app_form_field.dart';
import 'package:praticos/screens/widgets/form_sheet.dart';
import 'package:praticos/screens/widgets/list_states.dart';
import 'package:praticos/services/asaas_api_service.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';
import 'package:praticos/utils/tax_id.dart';

/// "Emitir nota fiscal": one NFS-e for one order (from the order's "…") or
/// for several orders of one customer (from the customer screen).
///
/// Shows what the server will send (POST /invoices/preview): the value
/// (only services, minus their share of the discount), the text, the day
/// and, when the customer has no CPF/CNPJ, a field for it (saved on the
/// customer by the server). The city also needs the customer's e-mail and
/// address with CEP: what the preview says is missing is asked here and the
/// server sends it to the Asaas customer. ✓ creates the nota; pops with the
/// [NfseInvoice].
class NfseIssueSheet extends StatefulWidget {
  const NfseIssueSheet({
    super.key,
    required this.orderIds,
    this.customerId,
    this.service,
  });

  final List<String> orderIds;

  /// Required by the server when there are several orders.
  final String? customerId;

  /// Test seam; defaults to [AsaasApiService.instance].
  final AsaasApiService? service;

  /// Opens the sheet over the tab bar.
  static Future<NfseInvoice?> show(
    BuildContext context, {
    required List<String> orderIds,
    String? customerId,
    AsaasApiService? service,
  }) => FormSheet.show<NfseInvoice>(
    context,
    (_) => NfseIssueSheet(
      orderIds: orderIds,
      customerId: customerId,
      service: service,
    ),
  );

  @override
  State<NfseIssueSheet> createState() => _NfseIssueSheetState();
}

class _NfseIssueSheetState extends State<NfseIssueSheet> {
  final _format = FormatService();
  final _description = TextEditingController();
  NfsePreview? _preview;
  String? _loadError;
  late DateTime _date = _today();
  String _taxIdInput = '';
  bool _submitting = false;

  /// Customer e-mail/address typed here (keys as in [NfsePreview.customerMissing]).
  final Map<String, String> _contact = {};

  AsaasApiService get _service => widget.service ?? AsaasApiService.instance;

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  /// [keepText]: reload after the server asked for customer data; the text
  /// the user edited stays.
  Future<void> _load({bool keepText = false}) async {
    setState(() => _loadError = null);
    try {
      final preview = await _service.previewInvoice(
        widget.orderIds,
        customerId: widget.customerId,
      );
      if (!mounted) return;
      if (!keepText) _description.text = preview.serviceDescription;
      for (final e in preview.customerContact.entries) {
        _contact.putIfAbsent(e.key, () => e.value);
      }
      setState(() => _preview = preview);
    } on AsaasApiException catch (e) {
      if (!mounted) return;
      final message = asaasErrorText(context.l10n, e, nota: true);
      setState(() => _loadError = message);
    } catch (_) {
      if (mounted) setState(() => _loadError = context.l10n.asaasErrorGeneric);
    }
  }

  /// What still blocks the ✓, in plain words; null when it can go.
  String? _missing(NfsePreview preview) {
    final l10n = context.l10n;
    if (preview.invoicedOrders.isNotEmpty) {
      final numbers = [
        for (final o in preview.orders)
          if (preview.invoicedOrders.containsKey(o.orderId))
            '${o.orderNumber ?? ''}',
      ].join(', ');
      return l10n.nfseAlreadyIssued(numbers);
    }
    if (preview.value <= 0) return l10n.nfseNothingToIssue;
    if (!preview.customerHasTaxId && !isValidTaxId(_taxIdInput)) {
      return l10n.nfseTaxIdMissing;
    }
    if (_askedContact(preview).any((field) => !_validContact(field))) {
      return l10n.nfseCustomerDataMissing;
    }
    return null;
  }

  static const _addressFields = [
    'postalCode',
    'address',
    'addressNumber',
    'province',
  ];
  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  /// Required fields shown: the e-mail when missing, the whole address when
  /// any part of it is missing.
  List<String> _askedContact(NfsePreview preview) => [
    if (preview.customerMissing.contains('email')) 'email',
    if (_addressFields.any(preview.customerMissing.contains)) ..._addressFields,
  ];

  bool _validContact(String field) {
    final value = (_contact[field] ?? '').trim();
    switch (field) {
      case 'email':
        return _emailPattern.hasMatch(value);
      case 'postalCode':
        return value.replaceAll(RegExp(r'\D'), '').length == 8;
      default:
        return value.isNotEmpty;
    }
  }

  /// What goes to the server: the fields asked (and the complement with the
  /// address), trimmed.
  Map<String, String>? _contactInput(NfsePreview preview) {
    final asked = _askedContact(preview);
    if (asked.isEmpty) return null;
    return {
      for (final field in [
        ...asked,
        if (asked.contains('address')) 'complement',
      ])
        if ((_contact[field] ?? '').trim().isNotEmpty)
          field: _contact[field]!.trim(),
    };
  }

  Future<void> _submit() async {
    final preview = _preview;
    if (_submitting || preview == null || _missing(preview) != null) return;
    setState(() => _submitting = true);
    String failure;
    try {
      final invoice = await _service.createInvoice(
        widget.orderIds,
        customerId: widget.customerId,
        serviceDescription: _description.text,
        effectiveDate: _date == _today() ? null : _date,
        customerTaxId: preview.customerHasTaxId ? null : _taxIdInput,
        customerData: _contactInput(preview),
      );
      if (!mounted) return;
      Navigator.pop(context, invoice);
      return;
    } on AsaasApiException catch (e) {
      failure = asaasErrorText(context.l10n, e, nota: true);
      // The server found data missing: show the fields for it.
      if (e.code == 'CUSTOMER_DATA_REQUIRED') unawaited(_load(keepText: true));
    } catch (_) {
      failure = context.l10n.asaasErrorGeneric;
    }
    if (!mounted) return;
    setState(() => _submitting = false);
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        content: Text(failure),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(dialogContext.l10n.ok),
          ),
        ],
      ),
    );
  }

  void _pickDate() {
    var selected = _date;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (popupContext) => Container(
        height: 300,
        color: AppColors.surface.resolveFrom(popupContext),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: CupertinoButton(
                  onPressed: () {
                    setState(() => _date = selected);
                    Navigator.pop(popupContext);
                  },
                  child: Text(popupContext.l10n.confirm),
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: _date,
                  minimumDate: _today(),
                  onDateTimeChanged: (date) =>
                      selected = DateTime(date.year, date.month, date.day),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final preview = _preview;
    final missing = preview == null ? null : _missing(preview);
    return FormSheet(
      key: const Key('nfseIssueSheet'),
      title: l10n.nfseRowTitle,
      canSave: preview != null && missing == null,
      missingHint: missing,
      dirty: _taxIdInput.isNotEmpty || _contactTyped,
      busy: _submitting,
      onSave: _submit,
      children: preview == null
          ? [
              if (_loadError != null)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.pageMargin),
                  child: Column(
                    children: [
                      Text(
                        _loadError!,
                        key: const Key('nfseIssueLoadError'),
                        textAlign: TextAlign.center,
                        style: AppTypography.body.copyWith(
                          color: AppColors.text.resolveFrom(context),
                        ),
                      ),
                      CupertinoButton(
                        onPressed: _load,
                        child: Text(l10n.tryAgain),
                      ),
                    ],
                  ),
                )
              else
                const SizedBox(height: 200, child: LoadingState()),
            ]
          : _buildPreview(preview),
    );
  }

  List<Widget> _buildPreview(NfsePreview preview) {
    final l10n = context.l10n;
    final secondary = AppColors.textSecondary.resolveFrom(context);
    final several = preview.orders.length > 1;
    final hasDiscount = preview.orders.any((o) => o.discount > 0);
    final notes = [
      if (preview.hasProducts) l10n.nfseOnlyServicesNote,
      if (hasDiscount && preview.hasProducts) l10n.nfseDiscountNote,
    ];
    final name = preview.customerName ?? l10n.customerWithoutName;
    final numbers = [
      for (final o in preview.orders) '${o.orderNumber ?? ''}',
    ].join(', ');
    return [
      FormCard(
        note: notes.isEmpty ? null : notes.join(' '),
        children: [
          // Wraps (value under the label) when the text is large.
          ConstrainedBox(
            key: const Key('nfseIssueValue'),
            constraints: const BoxConstraints(minHeight: 54),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: AppSpacing.md,
                children: [
                  Text(
                    l10n.nfseValueLabel,
                    style: AppTypography.body.copyWith(
                      color: AppColors.text.resolveFrom(context),
                    ),
                  ),
                  Text(
                    _format.formatBrl(preview.value),
                    style: AppTypography.bodyStrong.copyWith(
                      color: AppColors.text.resolveFrom(context),
                      fontFeatures: AppTypography.tabular,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (several)
            for (final o in preview.orders)
              FormRow(
                title: l10n.nfseOrderLine(
                  '${o.orderNumber ?? ''}',
                  _format.formatBrl(o.value),
                ),
                showChevron: false,
              ),
        ],
      ),
      if (several)
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pageMargin,
          ),
          child: Text(
            l10n.nfseSeveralIntro(preview.orders.length, name, numbers),
            style: AppTypography.callout.copyWith(color: secondary),
          ),
        ),
      FormFieldsCard(
        children: [
          AppFormField(
            key: const Key('nfseIssueDescription'),
            label: l10n.nfseDescriptionLabel,
            controller: _description,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
          ),
          if (!preview.customerHasTaxId)
            AppFormField(
              key: const Key('nfseIssueTaxId'),
              label: l10n.cpfCnpj,
              hint: l10n.nfseTaxIdHint,
              keyboardType: TextInputType.text,
              textCapitalization: TextCapitalization.characters,
              onChanged: (text) =>
                  setState(() => _taxIdInput = normalizeTaxId(text)),
            ),
        ],
      ),
      ..._buildContact(preview),
      FormCard(
        children: [
          FormRow(
            key: const Key('nfseIssueDate'),
            icon: CupertinoIcons.calendar,
            title: l10n.nfseDateLabel,
            trailing: Text(
              _date == _today() ? l10n.today : _format.formatDate(_date),
              style: AppTypography.body.copyWith(color: secondary),
            ),
            onTap: _submitting ? null : _pickDate,
          ),
          if (preview.municipalServiceName.isNotEmpty)
            FormRow(
              title: l10n.nfseServiceRow,
              subtitle: preview.municipalServiceName,
              showChevron: false,
            ),
        ],
      ),
    ];
  }

  bool get _contactTyped {
    final preview = _preview;
    if (preview == null) return false;
    return _contact.entries.any(
      (e) => e.value.trim() != (preview.customerContact[e.key] ?? ''),
    );
  }

  /// E-mail and address the city needs, when the customer lacks them.
  List<Widget> _buildContact(NfsePreview preview) {
    final asked = _askedContact(preview);
    if (asked.isEmpty) return const [];
    final l10n = context.l10n;
    Widget field(
      String key,
      String label, {
      TextInputType? keyboard,
      TextCapitalization caps = TextCapitalization.words,
    }) => AppFormField(
      key: Key('nfseIssueContact_$key'),
      label: label,
      initialValue: _contact[key],
      keyboardType: keyboard,
      textCapitalization: caps,
      onChanged: (text) => setState(() => _contact[key] = text),
    );
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageMargin,
          AppSpacing.lg,
          AppSpacing.pageMargin,
          0,
        ),
        child: Text(
          l10n.nfseCustomerDataIntro,
          key: const Key('nfseIssueContactIntro'),
          style: AppTypography.callout.copyWith(
            color: AppColors.textSecondary.resolveFrom(context),
          ),
        ),
      ),
      FormFieldsCard(
        children: [
          if (asked.contains('email'))
            field(
              'email',
              l10n.email,
              keyboard: TextInputType.emailAddress,
              caps: TextCapitalization.none,
            ),
          if (asked.contains('postalCode')) ...[
            field(
              'postalCode',
              l10n.nfsePostalCode,
              keyboard: TextInputType.number,
              caps: TextCapitalization.none,
            ),
            field('address', l10n.nfseStreet),
            field(
              'addressNumber',
              l10n.number,
              caps: TextCapitalization.characters,
            ),
            field(
              'complement',
              l10n.nfseAddressComplement,
              caps: TextCapitalization.sentences,
            ),
            field('province', l10n.nfseDistrict),
          ],
        ],
      ),
    ];
  }
}
