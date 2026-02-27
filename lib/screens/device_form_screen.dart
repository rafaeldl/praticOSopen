import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:praticos/mobx/device_store.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/widgets/cached_image.dart';
import 'package:praticos/widgets/dynamic_text_field.dart';
import 'package:praticos/widgets/dynamic_field_builder.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/constants/label_keys.dart';
import 'package:praticos/extensions/context_extensions.dart';

class DeviceFormScreen extends StatefulWidget {
  const DeviceFormScreen({super.key});

  @override
  State<DeviceFormScreen> createState() => _DeviceFormScreenState();
}

class _DeviceFormScreenState extends State<DeviceFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  Device? _device;
  final DeviceStore _deviceStore = DeviceStore();
  bool _isLoading = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null && args.containsKey('device')) {
        _device = args['device'];
      } else {
        _device = Device();
      }
      _device!.customData ??= {};
      _initialized = true;
    }
  }

  bool get _isEditing => _device?.id != null;

  Future<void> _saveDevice() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      _formKey.currentState!.save();
      // Clean up empty customData to avoid storing empty map in Firestore
      if (_device!.customData != null && _device!.customData!.isEmpty) {
        _device!.customData = null;
      }
      await _deviceStore.saveDevice(_device!);
      setState(() => _isLoading = false);
      if (mounted) {
        Navigator.pop(context, _device);
      }
    }
  }

  Future<void> _pickImage() async {
    final config = context.read<SegmentConfigProvider>();
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: Text(config.label(LabelKeys.changePhoto)),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            child: Text(context.l10n.takePhoto),
            onPressed: () async {
              Navigator.pop(context);
              final file = await _deviceStore.photoService.takePhoto();
              if (file != null) {
                await _deviceStore.uploadDevicePhoto(file, _device!);
                setState(() {});
              }
            },
          ),
          CupertinoActionSheetAction(
            child: Text(context.l10n.chooseFromGallery),
            onPressed: () async {
              Navigator.pop(context);
              final file = await _deviceStore.photoService.pickImageFromGallery();
              if (file != null) {
                await _deviceStore.uploadDevicePhoto(file, _device!);
                setState(() {});
              }
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: Text(config.label(LabelKeys.cancel)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<SegmentConfigProvider>();

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text(_isEditing
            ? config.label(LabelKeys.editDevice)
            : config.label(LabelKeys.createDevice)),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _isLoading ? null : _saveDevice,
          child: _isLoading
              ? const CupertinoActivityIndicator()
              : Text(config.label(LabelKeys.save), style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const SizedBox(height: 20),
              
              // Photo Section
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      if (_device?.photo != null && _device!.photo!.isNotEmpty)
                        ClipOval(
                          child: CachedImage(
                            imageUrl: _device!.photo!,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemGrey5.resolveFrom(context),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            config.deviceIcon,
                            size: 50,
                            color: CupertinoColors.systemGrey.resolveFrom(context),
                          ),
                        ),
                      if (_deviceStore.isUploading)
                        Positioned.fill(
                          child: Container(
                            decoration: const BoxDecoration(
                              color: CupertinoColors.black,
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: CupertinoActivityIndicator(color: CupertinoColors.white),
                            ),
                          ),
                        ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: CupertinoColors.activeBlue,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            CupertinoIcons.camera_fill,
                            size: 16,
                            color: CupertinoColors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Form Fields
              CupertinoListSection.insetGrouped(
                header: Text(context.l10n.basicInfo.toUpperCase()),
                children: [
                  // Category Field
                  CupertinoListTile(
                    title: SizedBox(
                      width: 100,
                      child: Text(
                        config.label(LabelKeys.deviceCategory),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    additionalInfo: Text(
                      _device?.category ?? context.l10n.select,
                      style: TextStyle(
                        fontSize: 16,
                        color: _device?.category != null
                            ? CupertinoColors.label.resolveFrom(context)
                            : CupertinoColors.placeholderText.resolveFrom(context),
                      ),
                    ),
                    trailing: Icon(
                      CupertinoIcons.chevron_right,
                      size: 20,
                      color: CupertinoColors.systemGrey.resolveFrom(context),
                    ),
                    onTap: () => _selectCategory(context, config),
                  ),

                  // Brand/Manufacturer Field
                  CupertinoListTile(
                    title: SizedBox(
                      width: 100,
                      child: Text(
                        config.label(LabelKeys.deviceBrand),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    additionalInfo: Text(
                      _device?.manufacturer ?? context.l10n.select,
                      style: TextStyle(
                        fontSize: 16,
                        color: _device?.manufacturer != null
                            ? CupertinoColors.label.resolveFrom(context)
                            : CupertinoColors.placeholderText.resolveFrom(context),
                      ),
                    ),
                    trailing: Icon(
                      CupertinoIcons.chevron_right,
                      size: 20,
                      color: CupertinoColors.systemGrey.resolveFrom(context),
                    ),
                    onTap: () => _selectBrand(context, config),
                  ),

                  // Model Field
                  CupertinoListTile(
                    title: SizedBox(
                      width: 100,
                      child: Text(
                        config.label(LabelKeys.deviceModel),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    additionalInfo: Text(
                      _device?.name ?? context.l10n.select,
                      style: TextStyle(
                        fontSize: 16,
                        color: _device?.name != null
                            ? CupertinoColors.label.resolveFrom(context)
                            : CupertinoColors.placeholderText.resolveFrom(context),
                      ),
                    ),
                    trailing: Icon(
                      CupertinoIcons.chevron_right,
                      size: 20,
                      color: CupertinoColors.systemGrey.resolveFrom(context),
                    ),
                    onTap: () => _selectModel(context, config),
                  ),

                  // Serial Number Field
                  DynamicTextField(
                    fieldKey: 'device.serial',
                    initialValue: _device?.serial,
                    onSaved: (val) => _device?.serial = val?.toUpperCase(),
                    required: true,
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

  /// Keys dos campos hardcoded que já são renderizados acima.
  /// O segmento pode configurar esses campos (label, mask, validation)
  /// mas eles não devem aparecer como campos dinâmicos duplicados.
  static const _builtInFieldKeys = {
    'device.category',
    'device.brand',
    'device.model',
    'device.serial',
  };

  List<Widget> _buildCustomFieldSections(SegmentConfigProvider config) {
    final grouped = config.fieldsGroupedBySectionLocalized(
      'device',
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
              value: _device?.customData?[field.key],
              locale: locale,
              onChanged: (newValue) {
                setState(() {
                  _device?.customData ??= {};
                  if (newValue == null) {
                    _device!.customData!.remove(field.key);
                  } else {
                    _device!.customData![field.key] = newValue;
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

  Future<void> _selectCategory(BuildContext context, SegmentConfigProvider config) async {
    final value = await Navigator.pushNamed(
      context,
      '/accumulated_value_list',
      arguments: {
        'fieldType': 'deviceCategory',
        'title': config.label(LabelKeys.deviceCategory),
        'currentValue': _device?.category,
        'allowClear': true,
      },
    );

    if (value is String && value != 'clear') {
      setState(() {
        _device?.category = value;
        // Note: We don't clear the model anymore to preserve legacy data
        // The user can clear it manually if needed
      });
    } else if (value == 'clear') {
      // User explicitly cleared the selection
      setState(() {
        _device?.category = null;
      });
    }
  }

  Future<void> _selectBrand(BuildContext context, SegmentConfigProvider config) async {
    final value = await Navigator.pushNamed(
      context,
      '/accumulated_value_list',
      arguments: {
        'fieldType': 'deviceBrand',
        'title': config.label(LabelKeys.deviceBrand),
        'currentValue': _device?.manufacturer,
        'allowClear': true,
      },
    );

    if (value is String && value != 'clear') {
      setState(() {
        _device?.manufacturer = value;
        // Note: We don't clear the model anymore to preserve legacy data
        // The user can clear it manually if needed
      });
    } else if (value == 'clear') {
      // User explicitly cleared the selection
      setState(() {
        _device?.manufacturer = null;
      });
    }
  }

  Future<void> _selectModel(BuildContext context, SegmentConfigProvider config) async {
    final value = await Navigator.pushNamed(
      context,
      '/accumulated_value_list',
      arguments: {
        'fieldType': 'deviceModel',
        'title': config.label(LabelKeys.deviceModel),
        'currentValue': _device?.name,
        'group': [_device?.category, _device?.manufacturer],
        'allowClear': true,
      },
    );

    if (value is String && value != 'clear') {
      setState(() {
        _device?.name = value;
      });
    } else if (value == 'clear') {
      // User explicitly cleared the selection
      setState(() {
        _device?.name = null;
      });
    }
  }
}
