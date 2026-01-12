import 'package:easy_mask/easy_mask.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:praticos/mobx/device_store.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/widgets/cached_image.dart';
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
      _initialized = true;
    }
  }

  bool get _isEditing => _device?.id != null;

  Future<void> _saveDevice() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      _formKey.currentState!.save();
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
                            CupertinoIcons.car_detailed,
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
                        context.l10n.deviceCategory,
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
                    onTap: () => _selectCategory(context),
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
                  _buildCupertinoFormField(
                    label: config.label(LabelKeys.deviceSerialNumber),
                    initialValue: _device?.serial,
                    placeholder: "ABC1D23",
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [TextInputMask(mask: 'AAA9N99')],
                    onSaved: (val) => _device?.serial = val?.toUpperCase(),
                    validator: (val) => val == null || val.isEmpty ? config.label(LabelKeys.required) : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectCategory(BuildContext context) async {
    final value = await Navigator.pushNamed(
      context,
      '/accumulated_value_list',
      arguments: {
        'fieldType': 'deviceCategory',
        'title': context.l10n.deviceCategory,
        'currentValue': _device?.category,
      },
    );

    if (value != null && value is String) {
      setState(() {
        _device?.category = value;
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
      },
    );

    if (value != null && value is String) {
      setState(() {
        _device?.manufacturer = value;
        // Clear model when brand changes
        _device?.name = null;
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
        'group': _device?.manufacturer,
      },
    );

    if (value != null && value is String) {
      setState(() {
        _device?.name = value;
      });
    }
  }

  Widget _buildCupertinoFormField({
    required String label,
    String? initialValue,
    String? placeholder,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    required FormFieldSetter<String> onSaved,
    required FormFieldValidator<String> validator,
  }) {
    return CupertinoListTile(
      title: SizedBox(
        width: 80,
        child: Text(label, style: const TextStyle(fontSize: 16)),
      ),
      additionalInfo: SizedBox(
        width: 200, // Constrain width or use Expanded logic if possible within ListTile
        child: CupertinoTextFormFieldRow(
          initialValue: initialValue,
          placeholder: placeholder,
          textCapitalization: textCapitalization,
          inputFormatters: inputFormatters,
          padding: EdgeInsets.zero,
          textAlign: TextAlign.right,
          decoration: null, // Remove border
          style: TextStyle(color: CupertinoColors.label.resolveFrom(context)),
          validator: validator,
          onSaved: onSaved,
        ),
      ),
    );
  }
}
