import 'package:easy_mask/easy_mask.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/mobx/customer_store.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/screens/widgets/app_form_field.dart';
import 'package:praticos/screens/widgets/form_sheet.dart';
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
/// A new customer opens as a [FormSheet] (`asSheet: true`, open it with
/// [FormSheet.show]): "X" and "✓" at the top, name and phone in a white card
/// and e-mail, CPF/CNPJ, address and the segment fields in a "Mais dados"
/// card that opens in place. The "✓" turns blue once the name is filled.
/// Editing stays a pushed screen, with those fields behind a
/// [MoreFieldsLink] (open right away when the customer already has any).
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

  /// Present as a [FormSheet] (new customer).
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
  final TextEditingController _name = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _address = TextEditingController();
  String _taxId = '';
  bool _customTouched = false;
  late String _initialSnapshot;

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
      final c = _customer!;
      _name.text = c.name ?? '';
      _phone.text = c.phone ?? '';
      _email.text = c.email ?? '';
      _address.text = c.address ?? '';
      _taxId = c.taxId ?? '';
      _initialSnapshot = _snapshot;
      for (final controller in [_name, _phone, _email, _address]) {
        controller.addListener(_onEdit);
      }
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    super.dispose();
  }

  void _onEdit() {
    if (mounted) setState(() {});
  }

  String get _snapshot => [
        _name.text.trim(),
        _phone.text.trim(),
        _email.text.trim(),
        _address.text.trim(),
        _taxId,
      ].join('\u0000');

  /// The sheet can be saved once the name is filled.
  bool get _canSave => _name.text.trim().isNotEmpty;

  /// Something was typed since the sheet opened: closing asks first.
  bool get _dirty => _customTouched || _snapshot != _initialSnapshot;

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
    if (widget.asSheet) {
      return Form(
        key: _formKey,
        child: FormSheet(
          title: title,
          canSave: _canSave,
          missingHint: l10n.customerSaveNeedsName,
          dirty: _dirty,
          busy: _isLoading,
          onSave: _saveCustomer,
          children: _buildSheetCards(config),
        ),
      );
    }
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

  /// Fields of the pushed edit screen.
  List<Widget> _buildFields(SegmentConfigProvider config) {
    return [
      _nameField(),
      _phoneField(config),
      MoreFieldsLink(
        label: context.l10n.moreCustomerData,
        initiallyExpanded: _hasMoreData,
        children: _moreFields(config, inCard: false),
      ),
    ];
  }

  /// Cards of the new-customer sheet.
  List<Widget> _buildSheetCards(SegmentConfigProvider config) {
    final l10n = context.l10n;
    return [
      FormFieldsCard(children: [_nameField(), _phoneField(config)]),
      FormMoreCard(
        title: l10n.formMoreData,
        hint: l10n.customerMoreDataHint,
        initiallyOpen: _hasMoreData,
        children: _moreFields(config, inCard: true),
      ),
    ];
  }

  Widget _nameField() {
    final l10n = context.l10n;
    return AppFormField(
      label: l10n.name,
      controller: _name,
      placeholder: l10n.customerNamePlaceholder,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.next,
      autofocus: !_isEditing,
      onSaved: (v) => _customer!.name = v.trim(),
      validator: (v) => v.trim().isEmpty ? l10n.customerNameRequired : null,
    );
  }

  Widget _phoneField(SegmentConfigProvider config) {
    final l10n = context.l10n;
    final phoneMasks = config.getMasks('customer.phone');
    return AppFormField(
      label: l10n.customerPhoneLabel,
      controller: _phone,
      hint: l10n.customerPhoneHint,
      keyboardType: TextInputType.phone,
      inputFormatters: phoneMasks.isEmpty
          ? null
          : [
              TextInputMask(
                mask: phoneMasks.length == 1 ? phoneMasks.first : phoneMasks,
              ),
            ],
      onSaved: (v) => _customer!.phone = v.isEmpty ? null : v,
    );
  }

  /// E-mail, CPF/CNPJ, address and the segment fields. [inCard]: inside the
  /// sheet's "Mais dados" card, so no inset sections (no card in a card).
  List<Widget> _moreFields(
    SegmentConfigProvider config, {
    required bool inCard,
  }) {
    final l10n = context.l10n;
    final customer = _customer!;
    final hasAddress = (customer.address?.isNotEmpty ?? false) ||
        (customer.latitude != null && customer.longitude != null);
    final taxId = TaxIdFormField(
      initialValue: customer.taxId,
      onChanged: (v) => setState(() => _taxId = v),
      onSaved: (val) => customer.taxId = val,
    );
    return [
      AppFormField(
        label: l10n.email,
        controller: _email,
        placeholder: l10n.emailPlaceholder,
        keyboardType: TextInputType.emailAddress,
        onSaved: (v) => customer.email = v.isEmpty ? null : v,
      ),
      // CPF/CNPJ (Brazil only): required by Asaas to charge
      if (config.countryCode == null || config.countryCode == 'BR')
        inCard
            ? Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                ),
                child: taxId,
              )
            : CupertinoListSection.insetGrouped(children: [taxId]),
      AppFormField(
        label: l10n.address,
        controller: _address,
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
      ..._buildCustomFieldSections(config, inCard: inCard),
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

  List<Widget> _buildCustomFieldSections(
    SegmentConfigProvider config, {
    required bool inCard,
  }) {
    final grouped = config.fieldsGroupedBySectionLocalized(
      'customer',
      exclude: _builtInFieldKeys,
    );
    if (grouped.isEmpty) return [];

    final locale = config.locale;
    final sections = <Widget>[];

    for (final entry in grouped.entries) {
      sections.add(SectionLabel(entry.key));
      final fields = entry.value.map((field) {
        return DynamicFieldBuilder(
          field: field,
          value: _customer?.customData?[field.fieldName] ??
              _customer?.customData?[field.key],
          locale: locale,
          onChanged: (newValue) {
            setState(() {
              _customTouched = true;
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
      }).toList();
      sections.add(
        inCard
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: fields,
              )
            : CupertinoListSection.insetGrouped(children: fields),
      );
    }

    return sections;
  }
}
