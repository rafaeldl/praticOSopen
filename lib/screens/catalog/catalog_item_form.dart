import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/screens/catalog/catalog_source.dart';
import 'package:praticos/screens/widgets/app_form_field.dart';
import 'package:praticos/screens/widgets/form_sheet.dart';
import 'package:praticos/screens/widgets/money_field.dart';
import 'package:praticos/screens/widgets/section_label.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';
import 'package:praticos/widgets/cached_image.dart';
import 'package:praticos/widgets/dynamic_field_builder.dart';
import 'package:provider/provider.dart';

/// New / edit service or product (one form for both [CatalogKind]s).
///
/// A new item opens as a [FormSheet] (`asSheet: true`, open it with
/// [FormSheet.show]): "X" and "✓" at the top, name and price in a white card
/// and the photo and the segment fields in a "Mais dados" card that opens in
/// place. The "✓" turns blue once the name is filled. Editing is a pushed
/// screen with a floating "Salvar" button and a "…" menu with "Apagar" (only
/// with the manage permission). Leaving the price blank saves `value = null`.
///
/// Pops with the saved [CatalogItem]; pops with null when cancelled or
/// deleted.
class CatalogItemForm extends StatefulWidget {
  const CatalogItemForm({
    super.key,
    required this.kind,
    required this.source,
    required this.permissions,
    this.item,
    this.asSheet = false,
  });

  final CatalogKind kind;
  final CatalogSource source;
  final CatalogPermissions permissions;

  /// Item to edit; a new one is created when null.
  final CatalogItem? item;
  final bool asSheet;

  @override
  State<CatalogItemForm> createState() => _CatalogItemFormState();
}

class _CatalogItemFormState extends State<CatalogItemForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final CatalogItem _item;
  bool _saving = false;
  bool _uploading = false;
  late String _name = widget.item?.name ?? '';
  bool _touched = false;

  bool get _isService => widget.kind == CatalogKind.service;
  bool get _isEditing => widget.item?.id != null;

  @override
  void initState() {
    super.initState();
    final i = widget.item;
    // Work on a copy: nothing changes in the list until saved.
    _item = CatalogItem(
      id: i?.id,
      name: i?.name,
      value: i?.value,
      photo: i?.photo,
      customData: Map<String, dynamic>.of(i?.customData ?? const {}),
      origin: i?.origin,
    );
  }

  /// The sheet can be saved once the name is filled.
  bool get _canSave => _name.trim().isNotEmpty;

  /// Something was filled since the sheet opened: closing asks first.
  bool get _dirty => _touched || _name.trim() != (widget.item?.name ?? '');

  void _touch() {
    if (!_touched) setState(() => _touched = true);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    _formKey.currentState!.save();
    if (_item.customData != null && _item.customData!.isEmpty) {
      _item.customData = null;
    }
    try {
      await widget.source.save(widget.kind, _item);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (mounted) Navigator.pop(context, _item);
  }

  Future<void> _confirmDelete() async {
    final l10n = context.l10n;
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(l10n.catalogDeleteTitle(_item.name ?? '')),
        content: Text(l10n.catalogDeleteMessage),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.back),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.deleteAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await widget.source.delete(widget.kind, _item);
    if (mounted) Navigator.pop(context);
  }

  void _showMenu() {
    final l10n = context.l10n;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(sheetContext);
              _confirmDelete();
            },
            child: Text(_isService
                ? l10n.deleteServiceAction
                : l10n.deleteProductAction),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: Text(l10n.cancel),
        ),
      ),
    );
  }

  void _pickPhoto() {
    final l10n = context.l10n;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text(l10n.changePhoto),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              _upload(PhotoOrigin.camera);
            },
            child: Text(l10n.takePhoto),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              _upload(PhotoOrigin.gallery);
            },
            child: Text(l10n.gallery),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: Text(l10n.cancel),
        ),
      ),
    );
  }

  Future<void> _upload(PhotoOrigin from) async {
    setState(() => _uploading = true);
    try {
      await widget.source.uploadPhoto(widget.kind, _item, from);
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
          if (_item.photo != widget.item?.photo) _touched = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<SegmentConfigProvider>();
    final l10n = context.l10n;
    final title = _isEditing
        ? (_item.name ?? '')
        : (_isService ? l10n.catalogNewService : l10n.catalogNewProduct);
    if (widget.asSheet) {
      return Form(
        key: _formKey,
        child: FormSheet(
          title: title,
          canSave: _canSave,
          missingHint: l10n.customerSaveNeedsName,
          dirty: _dirty,
          busy: _saving,
          onSave: _save,
          children: [
            FormFieldsCard(children: _mainFields()),
            FormMoreCard(
              title: l10n.formMoreData,
              hint: _hasCustomFields(config)
                  ? l10n.catalogMoreDataHintFields
                  : l10n.photo,
              initiallyOpen: _hasMoreData,
              children: [
                _buildPhoto(),
                ..._buildCustomFieldSections(config, inCard: true),
              ],
            ),
          ],
        ),
      );
    }

    final body = Form(
      key: _formKey,
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: 120),
        children: [
          ..._mainFields(),
          ..._buildCustomFieldSections(config, inCard: false),
          _buildPhoto(),
        ],
      ),
    );

    final canDelete = _isEditing && widget.permissions.canManage(widget.kind);
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background.resolveFrom(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text(title),
        trailing: canDelete
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(44, 44),
                onPressed: _showMenu,
                child: Semantics(
                  label: l10n.catalogItemActions,
                  child: const Icon(CupertinoIcons.ellipsis_circle),
                ),
              )
            : null,
      ),
      child: SafeArea(
        child: Stack(
          children: [
            body,
            Positioned(
              left: AppSpacing.blockMargin,
              right: AppSpacing.blockMargin,
              bottom: AppSpacing.lg,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size.fromHeight(AppSizes.primaryButtonHeight),
                color: AppColors.accent.resolveFrom(context),
                borderRadius: BorderRadius.circular(AppRadii.button),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const CupertinoActivityIndicator()
                    : Text(
                        _isService
                            ? l10n.saveServiceButton
                            : l10n.saveProductButton,
                        style: AppTypography.bodyStrong.copyWith(
                          color: AppColors.onAccent.resolveFrom(context),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Name and price (price hidden without `viewPrices`, e.g.
  /// `Company.useFinancial == false`; the stored value is kept on save).
  List<Widget> _mainFields() {
    final l10n = context.l10n;
    return [
      AppFormField(
        label: l10n.name,
        initialValue: _item.name,
        placeholder: _isService ? l10n.serviceNameHint : l10n.productNameHint,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.next,
        autofocus: !_isEditing,
        onChanged: (v) => setState(() => _name = v),
        onSaved: (v) => _item.name = v.trim(),
        validator: (v) => v.trim().isEmpty
            ? (_isService ? l10n.serviceNameRequired : l10n.productNameRequired)
            : null,
      ),
      if (widget.permissions.canViewPrices)
        MoneyField(
          label: l10n.catalogPriceLabel,
          initialValue: _item.value,
          hint: l10n.catalogPriceHint,
          onChanged: (_) => _touch(),
          onSavedNullable: (v) => _item.value = v,
        ),
    ];
  }

  bool get _hasMoreData =>
      (_item.photo?.isNotEmpty ?? false) ||
      (_item.customData?.isNotEmpty ?? false);

  bool _hasCustomFields(SegmentConfigProvider config) => config
      .fieldsGroupedBySectionLocalized(
        widget.kind.name,
        exclude: _builtInFieldKeys,
      )
      .isNotEmpty;

  Widget _buildPhoto() {
    final l10n = context.l10n;
    final hasPhoto = _item.photo != null && _item.photo!.isNotEmpty;
    final label = hasPhoto
        ? l10n.changePhoto
        : '+ ${_isService ? l10n.addServicePhoto : l10n.addProductPhoto}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageMargin),
      child: Row(
        children: [
          if (hasPhoto) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.field),
              child: CachedImage(
                imageUrl: _item.photo!,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
          ],
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(AppSizes.minTouchTarget, AppSizes.minTouchTarget),
            onPressed: _uploading ? null : _pickPhoto,
            child: _uploading
                ? const CupertinoActivityIndicator()
                : Text(
                    label,
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

  /// Keys of the built-in fields already rendered above.
  Set<String> get _builtInFieldKeys => {
        '${widget.kind.name}.name',
        '${widget.kind.name}.value',
      };

  /// [inCard]: inside the sheet's "Mais dados" card, so no inset sections.
  List<Widget> _buildCustomFieldSections(
    SegmentConfigProvider config, {
    required bool inCard,
  }) {
    final grouped = config.fieldsGroupedBySectionLocalized(
      widget.kind.name,
      exclude: _builtInFieldKeys,
    );
    if (grouped.isEmpty) return const [];
    final locale = config.locale;
    final sections = <Widget>[];
    for (final entry in grouped.entries) {
      sections.add(SectionLabel(entry.key));
      final fields = entry.value.map((field) {
            return DynamicFieldBuilder(
              field: field,
              value: _item.customData?[field.fieldName] ??
                  _item.customData?[field.key],
              locale: locale,
              onChanged: (newValue) {
                setState(() {
                  _touched = true;
                  _item.customData ??= {};
                  if (newValue == null) {
                    _item.customData!.remove(field.fieldName);
                  } else {
                    _item.customData![field.fieldName] = newValue;
                  }
                  _item.customData!.remove(field.key); // migrate old key
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
