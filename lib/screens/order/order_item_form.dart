import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/screens/order/new_order_form.dart';
import 'package:praticos/screens/widgets/glass_bar_button.dart';
import 'package:praticos/screens/widgets/money_field.dart';
import 'package:praticos/screens/widgets/picker_screen.dart';
import 'package:praticos/screens/widgets/pull_down_menu.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';
import 'package:praticos/widgets/cached_image.dart';

// Pieces shared by the editors of one line of the order
// (OrderServiceScreen, OrderProductScreen): a pushed screen with "Salvar"
// and "…" at the top, white cards on the grouped background.

/// Money mask of the app locale (R$ 1.234,56 / $1,234.56 / 1.234,56 €).
MoneyInputFormatter orderItemMoneyFormatter(BuildContext context) {
  final service = FormatService()..setLocale(context.l10n.localeName);
  return MoneyInputFormatter(service.currencyFormat);
}

/// Pushed editor of an order line: title at the top, "…" (only with
/// [onMore]) and "Salvar" on the right, cards below.
class OrderItemScaffold extends StatelessWidget {
  const OrderItemScaffold({
    super.key,
    required this.title,
    required this.onSave,
    required this.children,
    this.onMore,
    this.busy = false,
  });

  final String title;
  final VoidCallback onSave;
  final VoidCallback? onMore;
  final bool busy;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return CupertinoPageScaffold(
      backgroundColor: AppColors.groupedBackground.resolveFrom(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text(title),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onMore != null) ...[
              GlassBarButton(
                key: const ValueKey('order_item_more'),
                label: l10n.orderMoreActions,
                icon: CupertinoIcons.ellipsis,
                onPressed: busy ? null : onMore,
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            CupertinoButton(
              key: const ValueKey('order_item_save'),
              padding: EdgeInsets.zero,
              minimumSize: const Size(
                AppSizes.minTouchTarget,
                AppSizes.minTouchTarget,
              ),
              onPressed: busy ? null : onSave,
              child: busy
                  ? const CupertinoActivityIndicator()
                  : Text(
                      l10n.save,
                      style: AppTypography.callout.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.accentText.resolveFrom(context),
                      ),
                    ),
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
          children: children,
        ),
      ),
    );
  }
}

/// White card that names the line: photo (or [icon]) and the item name,
/// which wraps instead of being cut.
class OrderItemHeaderCard extends StatelessWidget {
  const OrderItemHeaderCard({
    super.key,
    required this.name,
    required this.icon,
    this.photoUrl,
    this.kind,
  });

  final String name;
  final IconData icon;
  final String? photoUrl;

  /// "Serviço" / "Produto", under the name.
  final String? kind;

  static const double _thumb = 56;

  @override
  Widget build(BuildContext context) {
    final secondary = AppColors.textSecondary.resolveFrom(context);
    final photo = photoUrl;
    final thumb = photo != null && photo.isNotEmpty
        ? CachedImage(
            imageUrl: photo,
            width: _thumb,
            height: _thumb,
            fit: BoxFit.cover,
            borderRadius: BorderRadius.circular(AppRadii.field),
          )
        : Container(
            width: _thumb,
            height: _thumb,
            decoration: BoxDecoration(
              color: AppColors.secondaryFill.resolveFrom(context),
              borderRadius: BorderRadius.circular(AppRadii.field),
            ),
            child: Icon(icon, size: 28, color: secondary),
          );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.blockMargin,
        AppSpacing.lg,
        AppSpacing.blockMargin,
        0,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kFormCardRadius),
        child: ColoredBox(
          color: AppColors.surface.resolveFrom(context),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                ExcludeSemantics(child: thumb),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        key: const ValueKey('order_item_name'),
                        style: AppTypography.bodyStrong.copyWith(
                          color: AppColors.text.resolveFrom(context),
                        ),
                      ),
                      if (kind != null)
                        Text(
                          kind!,
                          style: AppTypography.label.copyWith(color: secondary),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// White card with rows ([FormRow]) split by separators.
class OrderItemRowsCard extends StatelessWidget {
  const OrderItemRowsCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(
          Padding(
            padding: const EdgeInsets.only(left: 56),
            child: Container(
              height: 0.5,
              color: AppColors.separator.resolveFrom(context),
            ),
          ),
        );
      }
      rows.add(children[i]);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.blockMargin,
        AppSpacing.lg,
        AppSpacing.blockMargin,
        0,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kFormCardRadius),
        child: ColoredBox(
          color: AppColors.surface.resolveFrom(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: rows,
          ),
        ),
      ),
    );
  }
}

/// Quantity with "−" and "+" (44pt each) around a number field. Validates
/// that it is a whole number of at least 1.
class OrderItemQuantityField extends StatelessWidget {
  const OrderItemQuantityField({
    super.key,
    required this.label,
    required this.controller,
    required this.onSaved,
    this.enabled = true,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<int> onSaved;
  final bool enabled;

  int? get _quantity => int.tryParse(controller.text.trim());

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = AppColors.text.resolveFrom(context);
    final secondary = AppColors.textSecondary.resolveFrom(context);
    final danger = AppColors.danger.resolveFrom(context);
    return FormField<String>(
      initialValue: controller.text,
      validator: (_) {
        final raw = controller.text.trim();
        if (raw.isEmpty) return l10n.required;
        final q = int.tryParse(raw);
        if (q == null || q <= 0) return l10n.orderItemQuantityInvalid;
        return null;
      },
      onSaved: (_) => onSaved(int.parse(controller.text.trim())),
      builder: (state) {
        void set(int q) {
          controller.text = '$q';
          state.didChange(controller.text);
        }

        final q = _quantity;
        final error = state.errorText;
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pageMargin,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text(
                  label,
                  style: AppTypography.label.copyWith(color: secondary),
                ),
              ),
              Row(
                children: [
                  _StepButton(
                    key: const ValueKey('order_item_less'),
                    icon: CupertinoIcons.minus_circle,
                    label: l10n.orderItemLess,
                    onPressed: enabled && q != null && q > 1
                        ? () => set(q - 1)
                        : null,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Semantics(
                      label: label,
                      child: CupertinoTextField(
                        key: const ValueKey('order_item_quantity'),
                        controller: controller,
                        enabled: enabled,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: AppTypography.bodyStrong.copyWith(
                          color: enabled ? text : secondary,
                          fontFeatures: AppTypography.tabular,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.md + 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryFill.resolveFrom(context),
                          borderRadius: BorderRadius.circular(AppRadii.field),
                          border: error == null
                              ? null
                              : Border.all(color: danger, width: 1.5),
                        ),
                        onChanged: state.didChange,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _StepButton(
                    key: const ValueKey('order_item_more_one'),
                    icon: CupertinoIcons.plus_circle,
                    label: l10n.orderItemMore,
                    onPressed: enabled ? () => set((q ?? 0) + 1) : null,
                  ),
                ],
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    error,
                    style: AppTypography.label.copyWith(color: danger),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      excludeSemantics: true,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(
          AppSizes.minTouchTarget,
          AppSizes.minTouchTarget,
        ),
        onPressed: onPressed,
        child: Icon(
          icon,
          size: 30,
          color: onPressed == null
              ? AppColors.separator.resolveFrom(context)
              : AppColors.accentText.resolveFrom(context),
        ),
      ),
    );
  }
}

/// "Total" and its value, both wrapping with large text.
class OrderItemTotalRow extends StatelessWidget {
  const OrderItemTotalRow({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.bodyStrong.copyWith(
      color: AppColors.text.resolveFrom(context),
    );
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageMargin,
          AppSpacing.sm,
          AppSpacing.pageMargin,
          AppSpacing.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(label, style: style)),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                value,
                key: const ValueKey('order_item_total'),
                textAlign: TextAlign.end,
                style: style.copyWith(fontFeatures: AppTypography.tabular),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Name shown for a device of the order ("Gol 2018", serial apart).
DeviceAggr? orderItemDevice(List<DeviceAggr> devices, String? id) {
  if (id == null) return null;
  for (final d in devices) {
    if (d.id == id) return d;
  }
  return null;
}

/// Row "Veículo: Gol 2018 ›" of a line in an order with 2+ devices. Tapping
/// opens the picker; [onChanged] gets the new id (null = "Geral").
class OrderItemDeviceRow extends StatelessWidget {
  const OrderItemDeviceRow({
    super.key,
    required this.label,
    required this.devices,
    required this.deviceId,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final List<DeviceAggr> devices;
  final String? deviceId;
  final ValueChanged<String?> onChanged;
  final bool enabled;

  static const _general = '';

  Future<void> _pick(BuildContext context) async {
    final l10n = context.l10n;
    final picked = await pickOne<String>(
      context,
      title: l10n.selectDeviceFor,
      selected: deviceId ?? _general,
      options: [
        PickerItem<String>(value: _general, title: l10n.generalNoDevice),
        for (final d in devices)
          if (d.id != null)
            PickerItem<String>(
              value: d.id!,
              title: d.name ?? '',
              subtitle: (d.serial?.trim().isNotEmpty ?? false)
                  ? d.serial
                  : null,
            ),
      ],
    );
    if (picked == null) return;
    onChanged(picked == _general ? null : picked);
  }

  @override
  Widget build(BuildContext context) {
    final device = orderItemDevice(devices, deviceId);
    final name = device == null
        ? context.l10n.generalNoDevice
        : [
            device.name ?? '',
            if (device.serial?.trim().isNotEmpty ?? false) device.serial!,
          ].where((s) => s.isNotEmpty).join(' · ');
    return FormRow(
      key: const ValueKey('order_item_device'),
      icon: CupertinoIcons.car_detailed,
      title: label,
      value: name,
      showChevron: enabled,
      onTap: enabled ? () => _pick(context) : null,
    );
  }
}

/// "…" of a line: only "Tirar da OS", in red. Resolves true when picked
/// and confirmed.
Future<bool> askRemoveOrderItem(BuildContext context, String name) async {
  final l10n = context.l10n;
  final choice = await showPullDownMenu(
    context,
    groups: [
      PullDownGroup([
        PullDownItem(
          value: 'remove',
          label: l10n.orderItemRemove,
          icon: CupertinoIcons.minus_circle,
          destructive: true,
        ),
      ]),
    ],
  );
  if (choice != 'remove' || !context.mounted) return false;
  final confirmed = await showCupertinoDialog<bool>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(l10n.orderItemRemoveTitle),
      content: Text(l10n.orderItemRemoveMessage(name)),
      actions: [
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l10n.cancel),
        ),
        CupertinoDialogAction(
          key: const ValueKey('order_item_remove_confirm'),
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l10n.orderItemRemove),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
