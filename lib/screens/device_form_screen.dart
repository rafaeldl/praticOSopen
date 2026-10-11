import 'package:easy_mask/easy_mask.dart';
import 'package:flutter/cupertino.dart';
import 'package:praticos/constants/label_keys.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/global.dart';
import 'package:praticos/mobx/device_store.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/repositories/repository.dart';
import 'package:praticos/repositories/tenant/tenant_device_repository.dart';
import 'package:praticos/screens/widgets/app_form_field.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/screens/widgets/app_sheet.dart';
import 'package:praticos/screens/widgets/more_fields_link.dart';
import 'package:praticos/screens/widgets/section_label.dart';
import 'package:praticos/screens/widgets/status_dot.dart';
import 'package:praticos/screens/widgets/suggest_field.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';
import 'package:praticos/theme/status_style.dart';
import 'package:praticos/utils/device_suggestions.dart';
import 'package:praticos/widgets/cached_image.dart';
import 'package:praticos/widgets/dynamic_field_builder.dart';
import 'package:provider/provider.dart';

/// New / edit vehicle (device) in a single screen.
///
/// A new one opens as an [AppSheet] (`asSheet: true`, "Cancelar" on the left,
/// "Salvar" on the right); editing stays a pushed screen. Only the model
/// (with suggestions taken from the company's own devices, which also fill
/// brand and category) and the plate/serial show at first; photo, brand,
/// category, status (editing, with device management) and the segment fields
/// sit behind a [MoreFieldsLink].
///
/// Pops with the saved [Device].
class DeviceFormScreen extends StatefulWidget {
  const DeviceFormScreen({
    super.key,
    this.device,
    this.asSheet = false,
    this.onSave,
    this.loadDevices,
  });

  /// Device to edit. Falls back to the `device` route argument; a new one is
  /// created when neither is given.
  final Device? device;

  /// Present as the content of an [AppSheet].
  final bool asSheet;

  /// Saves the device. Defaults to [DeviceStore.saveDevice].
  final Future<void> Function(Device device)? onSave;

  /// Devices the model suggestions come from. Defaults to the company's.
  final Future<List<Device>> Function()? loadDevices;

  @override
  State<DeviceFormScreen> createState() => _DeviceFormScreenState();
}

class _DeviceFormScreenState extends State<DeviceFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _model = TextEditingController();
  final TextEditingController _serial = TextEditingController();
  final TextEditingController _brand = TextEditingController();
  final TextEditingController _category = TextEditingController();
  DeviceStore? _store;
  Device? _device;
  List<Device> _known = const [];
  bool _isLoading = false;
  bool _initialized = false;

  DeviceStore get _deviceStore => _store ??= DeviceStore();

  @override
  void initState() {
    super.initState();
    _loadKnownDevices();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _device = widget.device ?? (args?['device'] as Device?) ?? Device();
    _device!.customData ??= {};
    _model.text = _device!.name ?? '';
    _serial.text = _device!.serial ?? '';
    _brand.text = _device!.manufacturer ?? '';
    _category.text = _device!.category ?? '';
    _initialized = true;
  }

  @override
  void dispose() {
    _model.dispose();
    _serial.dispose();
    _brand.dispose();
    _category.dispose();
    super.dispose();
  }

  Future<void> _loadKnownDevices() async {
    try {
      final loader = widget.loadDevices ?? _defaultLoader;
      final devices = await loader();
      if (mounted) setState(() => _known = devices);
    } catch (_) {
      // Suggestions are a convenience; the form works without them.
    }
  }

  Future<List<Device>> _defaultLoader() async {
    final id = Global.companyAggr?.id;
    if (id == null) return const [];
    final list = await TenantDeviceRepository()
        .getQueryList(id, orderBy: [OrderBy('name')]);
    return list.whereType<Device>().toList();
  }

  bool get _isEditing => _device?.id != null;

  bool get _hasMoreData {
    final d = _device!;
    bool filled(String? v) => v != null && v.isNotEmpty;
    return filled(d.photo) ||
        filled(d.manufacturer) ||
        filled(d.category) ||
        (d.customData?.isNotEmpty ?? false);
  }

  Future<void> _saveDevice() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    _formKey.currentState!.save();
    final device = _device!;
    String? orNull(String v) => v.trim().isEmpty ? null : v.trim();
    device.name = orNull(_model.text);
    device.manufacturer = orNull(_brand.text);
    device.category = orNull(_category.text);
    // Avoid storing an empty map in Firestore.
    if (device.customData != null && device.customData!.isEmpty) {
      device.customData = null;
    }
    try {
      final onSave = widget.onSave;
      if (onSave != null) {
        await onSave(device);
      } else {
        await _deviceStore.saveDevice(device);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
    if (mounted) Navigator.pop(context, device);
  }

  void _pickStatus() {
    final l10n = context.l10n;
    const statuses = ['active', 'maintenance', 'inactive', 'decommissioned'];
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(l10n.status),
        actions: [
          for (final status in statuses)
            CupertinoActionSheetAction(
              onPressed: () {
                setState(() => _device?.status = status);
                Navigator.pop(ctx);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  StatusDot(color: DeviceStatusStyle.dotColor(status), size: 10),
                  const SizedBox(width: AppSpacing.sm),
                  Text(DeviceStatusStyle.label(l10n, status)),
                ],
              ),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l10n.cancel),
        ),
      ),
    );
  }

  Future<void> _pickPhoto() async {
    final l10n = context.l10n;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(ctx);
              final file = await _deviceStore.photoService.takePhoto();
              if (file != null) {
                await _deviceStore.uploadDevicePhoto(file, _device!);
                if (mounted) setState(() {});
              }
            },
            child: Text(l10n.takePhoto),
          ),
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(ctx);
              final file =
                  await _deviceStore.photoService.pickImageFromGallery();
              if (file != null) {
                await _deviceStore.uploadDevicePhoto(file, _device!);
                if (mounted) setState(() {});
              }
            },
            child: Text(l10n.chooseFromGallery),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l10n.cancel),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<SegmentConfigProvider>();
    final l10n = context.l10n;
    final title = _isEditing
        ? config.label(LabelKeys.editDevice)
        : l10n.newEntity(config.device.toLowerCase());
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
        actionLabel: l10n.save,
        onAction: _saveDevice,
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
          onPressed: _isLoading ? null : _saveDevice,
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
    final serialLabel = config.label(LabelKeys.deviceSerialNumber);
    final serialField = config.getField('device.serial');
    final modelField = config.getField('device.model');
    final masks = config.getMasks('device.serial');

    return [
      SuggestField<DeviceSuggestion>(
        label: config.label(LabelKeys.deviceModel),
        controller: _model,
        placeholder: modelField?.placeholder,
        autofocus: !_isEditing,
        textInputAction: TextInputAction.next,
        suggestions: (text) => [
          for (final s in deviceSuggestions(_known, text))
            SuggestOption(value: s, title: s.name, subtitle: s.detail),
        ],
        onSelected: (s) => setState(() {
          _brand.text = s.manufacturer ?? '';
          _category.text = s.category ?? '';
        }),
      ),
      AppFormField(
        label: serialLabel,
        controller: _serial,
        placeholder: serialField?.placeholder,
        keyboardType: config.getKeyboardType('device.serial'),
        textCapitalization: TextCapitalization.characters,
        inputFormatters: masks.isEmpty
            ? null
            : [TextInputMask(mask: masks.length == 1 ? masks.first : masks)],
        onSaved: (v) => _device!.serial = v.trim().toUpperCase(),
        validator: (v) {
          final value = v.trim();
          if (value.isEmpty) return l10n.fieldRequiredHint(serialLabel);
          final pattern = serialField?.pattern;
          if (pattern != null && !RegExp(pattern).hasMatch(value)) {
            return l10n.invalidFormat;
          }
          return null;
        },
      ),
      MoreFieldsLink(
        label: l10n.photoAndMoreData,
        initiallyExpanded: _hasMoreData,
        children: [
          _buildPhotoRow(config),
          AppFormField(
            label: config.label(LabelKeys.deviceBrand),
            controller: _brand,
            textCapitalization: TextCapitalization.words,
          ),
          AppFormField(
            label: config.label(LabelKeys.deviceCategory),
            controller: _category,
            textCapitalization: TextCapitalization.sentences,
          ),
          if (_isEditing && config.useDeviceManagement)
            AppListRow(
              leading: StatusDot(
                color: DeviceStatusStyle.dotColor(_device?.status),
                size: 10,
              ),
              title: l10n.status,
              trailing: DeviceStatusStyle.label(l10n, _device?.status),
              onTap: _pickStatus,
            ),
          ..._buildCustomFieldSections(config),
        ],
      ),
    ];
  }

  Widget _buildPhotoRow(SegmentConfigProvider config) {
    final hasPhoto = _device?.photo != null && _device!.photo!.isNotEmpty;
    final secondary = AppColors.secondaryFill.resolveFrom(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageMargin,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.field),
            child: SizedBox(
              width: 64,
              height: 64,
              child: hasPhoto
                  ? CachedImage(
                      imageUrl: _device!.photo!,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    )
                  : ColoredBox(
                      color: secondary,
                      child: Icon(
                        config.deviceIcon,
                        size: 30,
                        color: AppColors.textSecondary.resolveFrom(context),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          if (_store?.isUploading ?? false)
            const CupertinoActivityIndicator()
          else
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(44, 44),
              onPressed: _pickPhoto,
              child: Text(
                hasPhoto
                    ? config.label(LabelKeys.changePhoto)
                    : context.l10n.addPhoto,
                style: AppTypography.callout.copyWith(
                  color: AppColors.accentText.resolveFrom(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Keys of hardcoded fields already rendered above.
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
      sections.add(SectionLabel(entry.key));
      sections.add(
        CupertinoListSection.insetGrouped(
          children: entry.value.map((field) {
            return DynamicFieldBuilder(
              field: field,
              value: _device?.customData?[field.fieldName] ??
                  _device?.customData?[field.key],
              locale: locale,
              onChanged: (newValue) {
                setState(() {
                  _device?.customData ??= {};
                  if (newValue == null) {
                    _device!.customData!.remove(field.fieldName);
                  } else {
                    _device!.customData![field.fieldName] = newValue;
                  }
                  _device!.customData!.remove(field.key); // migrate old key
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
