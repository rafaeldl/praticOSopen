import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:praticos/mobx/customer_store.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/services/location_service.dart';
import 'package:praticos/widgets/dynamic_text_field.dart';
import 'package:praticos/widgets/dynamic_field_builder.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/extensions/context_extensions.dart';

class CustomerFormScreen extends StatefulWidget {
  const CustomerFormScreen({super.key});

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  Customer? _customer;
  final CustomerStore _customerStore = CustomerStore();
  bool _isLoading = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null && args['customer'] != null) {
        _customer = args['customer'] as Customer;
      } else {
        _customer = Customer();
      }
      _customer!.customData ??= {};
      _initialized = true;
    }
  }

  bool get _isEditing => _customer?.id != null;

  Future<void> _saveCustomer() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      _formKey.currentState!.save();
      // Clean up empty customData to avoid storing empty map in Firestore
      if (_customer!.customData != null && _customer!.customData!.isEmpty) {
        _customer!.customData = null;
      }
      await _customerStore.saveCustomer(_customer!);
      setState(() => _isLoading = false);
      if (mounted) {
        Navigator.pop(context, _customer);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<SegmentConfigProvider>();
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text(_isEditing
            ? context.l10n.editCustomer
            : context.l10n.newCustomer),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _isLoading ? null : _saveCustomer,
          child: _isLoading
              ? const CupertinoActivityIndicator()
              : Text(context.l10n.save,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const SizedBox(height: 20),

              // Header Icon (Placeholder since no photo)
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey5.resolveFrom(context),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    CupertinoIcons.person,
                    size: 50,
                    color: CupertinoColors.systemGrey.resolveFrom(context),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Form Fields
              CupertinoListSection.insetGrouped(
                children: [
                  CupertinoTextFormFieldRow(
                    prefix: Text(context.l10n.name,
                        style: const TextStyle(fontSize: 16)),
                    initialValue: _customer?.name,
                    placeholder: context.l10n.fullName,
                    textCapitalization: TextCapitalization.words,
                    textAlign: TextAlign.right,
                    onSaved: (val) => _customer?.name = val,
                    validator: (val) => val == null || val.isEmpty
                        ? context.l10n.requiredField
                        : null,
                  ),
                  DynamicTextField(
                    fieldKey: 'customer.phone',
                    initialValue: _customer?.phone,
                    onSaved: (val) => _customer?.phone = val,
                  ),
                  CupertinoTextFormFieldRow(
                    prefix: Text(context.l10n.email,
                        style: const TextStyle(fontSize: 16)),
                    initialValue: _customer?.email,
                    placeholder: context.l10n.emailPlaceholder,
                    keyboardType: TextInputType.emailAddress,
                    textAlign: TextAlign.right,
                    onSaved: (val) => _customer?.email = val,
                  ),
                  CupertinoTextFormFieldRow(
                    prefix: GestureDetector(
                      onTap: (_customer?.address != null && _customer!.address!.isNotEmpty) ||
                              (_customer?.latitude != null && _customer?.longitude != null)
                          ? () => LocationService().openInMaps(
                                lat: _customer?.latitude,
                                lng: _customer?.longitude,
                                address: _customer?.address,
                              )
                          : null,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.location_solid,
                            size: 16,
                            color: (_customer?.address != null && _customer!.address!.isNotEmpty) ||
                                    (_customer?.latitude != null && _customer?.longitude != null)
                                ? CupertinoTheme.of(context).primaryColor
                                : CupertinoColors.systemGrey.resolveFrom(context),
                          ),
                          const SizedBox(width: 4),
                          Text(context.l10n.address,
                              style: const TextStyle(fontSize: 16)),
                        ],
                      ),
                    ),
                    initialValue: _customer?.address,
                    placeholder: context.l10n.addressPlaceholder,
                    textCapitalization: TextCapitalization.sentences,
                    textAlign: TextAlign.right,
                    onChanged: (val) => _customer?.address = val,
                    onSaved: (val) => _customer?.address = val,
                  ),
                ],
              ),

              // Dynamic Custom Field Sections (from segment config)
              ..._buildCustomFieldSections(config),
            ],
          ),
        ),
      ),
    );
  }

  /// Keys of hardcoded fields already rendered above.
  /// The segment may configure these fields (label, mask, validation)
  /// but they must not appear as duplicate dynamic fields.
  static const _builtInFieldKeys = {
    'customer.name',
    'customer.phone',
    'customer.email',
    'customer.address',
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
      final sectionName = entry.key;
      final fields = entry.value;

      sections.add(
        CupertinoListSection.insetGrouped(
          header: Text(
            sectionName.toUpperCase(),
            style: TextStyle(
              fontSize: 13,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          children: fields.map((field) {
            return DynamicFieldBuilder(
              field: field,
              value: _customer?.customData?[field.key],
              locale: locale,
              onChanged: (newValue) {
                setState(() {
                  _customer?.customData ??= {};
                  if (newValue == null) {
                    _customer!.customData!.remove(field.key);
                  } else {
                    _customer!.customData![field.key] = newValue;
                  }
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
