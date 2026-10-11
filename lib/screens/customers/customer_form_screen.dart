import 'package:easy_mask/easy_mask.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/mobx/customer_store.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/screens/widgets/app_form_field.dart';
import 'package:praticos/screens/widgets/app_sheet.dart';
import 'package:praticos/screens/widgets/more_fields_link.dart';
import 'package:praticos/screens/widgets/section_label.dart';
import 'package:praticos/services/location_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';
import 'package:praticos/widgets/dynamic_field_builder.dart';
import 'package:praticos/widgets/tax_id_form_field.dart';

/// New / edit customer.
///
/// A new customer opens as an [AppSheet] (`asSheet: true`, "Cancelar" on the
/// left, "Salvar" on the right); editing stays a pushed screen. Only name and
/// phone show at first; e-mail, CPF/CNPJ, address and the segment fields sit
/// behind a [MoreFieldsLink] (open right away when editing a customer that
/// already has any of them).
///
/// Pops with the saved [Customer].
class CustomerFormScreen extends StatefulWidget {
  const CustomerFormScreen({
    super.key,
    this.customer,
    this.asSheet = false,
    this.onSave,
  });

  /// Customer to edit. Falls back to the `customer` route argument; a new one
  /// is created when neither is given.
  final Customer? customer;

  /// Present as the content of an [AppSheet].
  final bool asSheet;

  /// Saves the customer. Defaults to [CustomerStore.saveCustomer].
  final Future<void> Function(Customer customer)? onSave;

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  Customer? _customer;
  CustomerStore? _store;
  bool _isLoading = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      _customer = widget.customer ??
          (args?['customer'] as Customer?) ??
          Customer();
      _customer!.customData ??= {};
      _initialized = true;
    }
  }

  bool get _isEditing => _customer?.id != null;

  bool get _hasMoreData {
    final c = _customer!;
    bool filled(String? v) => v != null && v.isNotEmpty;
    return filled(c.email) ||
        filled(c.taxId) ||
        filled(c.address) ||
        (c.customData?.isNotEmpty ?? false);
  }

  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    _formKey.currentState!.save();
    // Avoid storing an empty map in Firestore.
    if (_customer!.customData != null && _customer!.customData!.isEmpty) {
      _customer!.customData = null;
    }
    try {
      final onSave = widget.onSave;
      if (onSave != null) {
        await onSave(_customer!);
      } else {
        await (_store ??= CustomerStore()).saveCustomer(_customer!);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
    if (mounted) Navigator.pop(context, _customer);
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<SegmentConfigProvider>();
    final l10n = context.l10n;
    final title = _isEditing ? l10n.editCustomer : l10n.newCustomer;
    final body = Form(
      key: _formKey,
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.only(
          top: AppSpacing.sm,
          bottom: AppSpacing.xxl,
        ),
        children: _buildFields(config),
      ),
    );

    if (widget.asSheet) {
      return AppSheet(
        title: title,
        primaryLabel: l10n.saveEntityButton(config.customer.toLowerCase()),
        onAction: _saveCustomer,
        busy: _isLoading,
        child: body,
      );
    }

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background.resolveFrom(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text(title),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _isLoading ? null : _saveCustomer,
          child: _isLoading
              ? const CupertinoActivityIndicator()
              : Text(
                  l10n.save,
                  style: AppTypography.callout.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.accentText.resolveFrom(context),
                  ),
                ),
        ),
      ),
      child: SafeArea(child: body),
    );
  }

  List<Widget> _buildFields(SegmentConfigProvider config) {
    final l10n = context.l10n;
    final customer = _customer!;
    final phoneMasks = config.getMasks('customer.phone');
    final hasAddress = (customer.address?.isNotEmpty ?? false) ||
        (customer.latitude != null && customer.longitude != null);

    return [
      AppFormField(
        label: l10n.name,
        initialValue: customer.name,
        placeholder: l10n.customerNamePlaceholder,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.next,
        autofocus: !_isEditing,
        onSaved: (v) => customer.name = v.trim(),
        validator: (v) =>
            v.trim().isEmpty ? l10n.customerNameRequired : null,
      ),
      AppFormField(
        label: l10n.customerPhoneLabel,
        initialValue: customer.phone,
        hint: l10n.customerPhoneHint,
        keyboardType: TextInputType.phone,
        inputFormatters: phoneMasks.isEmpty
            ? null
            : [
                TextInputMask(
                  mask: phoneMasks.length == 1 ? phoneMasks.first : phoneMasks,
                ),
              ],
        onSaved: (v) => customer.phone = v.isEmpty ? null : v,
      ),
      MoreFieldsLink(
        label: l10n.moreCustomerData,
        initiallyExpanded: _hasMoreData,
        children: [
          AppFormField(
            label: l10n.email,
            initialValue: customer.email,
            placeholder: l10n.emailPlaceholder,
            keyboardType: TextInputType.emailAddress,
            onSaved: (v) => customer.email = v.isEmpty ? null : v,
          ),
          // CPF/CNPJ (Brazil only): required by Asaas to charge
          if (config.countryCode == null || config.countryCode == 'BR')
            CupertinoListSection.insetGrouped(
              children: [
                TaxIdFormField(
                  initialValue: customer.taxId,
                  onSaved: (val) => customer.taxId = val,
                ),
              ],
            ),
          AppFormField(
            label: l10n.address,
            initialValue: customer.address,
            placeholder: l10n.addressPlaceholder,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (v) => customer.address = v,
            onSaved: (v) => customer.address = v.isEmpty ? null : v,
          ),
          if (hasAddress)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pageMargin,
                ),
                minimumSize: const Size(44, 44),
                onPressed: () => LocationService().openInMaps(
                  lat: customer.latitude,
                  lng: customer.longitude,
                  address: customer.address,
                ),
                child: Text(
                  l10n.openInMap,
                  style: AppTypography.callout.copyWith(
                    color: AppColors.accentText.resolveFrom(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ..._buildCustomFieldSections(config),
        ],
      ),
    ];
  }

  /// Keys of hardcoded fields already rendered above.
  /// The segment may configure these fields (label, mask, validation)
  /// but they must not appear as duplicate dynamic fields.
  static const _builtInFieldKeys = {
    'customer.name',
    'customer.phone',
    'customer.email',
    'customer.address',
    'customer.taxId',
  };

  List<Widget> _buildCustomFieldSections(SegmentConfigProvider config) {
    final grouped = config.fieldsGroupedBySectionLocalized(
      'customer',
      exclude: _builtInFieldKeys,
    );
    if (grouped.isEmpty) return [];

    final locale = config.locale;
    final sections = <Widget>[];

    for (final entry in grouped.entries) {
      sections.add(SectionLabel(entry.key));
      sections.add(
        CupertinoListSection.insetGrouped(
          children: entry.value.map((field) {
            return DynamicFieldBuilder(
              field: field,
              value: _customer?.customData?[field.fieldName] ??
                  _customer?.customData?[field.key],
              locale: locale,
              onChanged: (newValue) {
                setState(() {
                  _customer?.customData ??= {};
                  if (newValue == null) {
                    _customer!.customData!.remove(field.fieldName);
                  } else {
                    _customer!.customData![field.fieldName] = newValue;
                  }
                  _customer!.customData!.remove(field.key); // migrate old key
                });
              },
            );
          }).toList(),
        ),
      );
    }

    return sections;
  }
}
