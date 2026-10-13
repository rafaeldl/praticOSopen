import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/screens/widgets/glass_bar_button.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_glass.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';

/// Pieces of the "Nova OS" sheet (prototype "Nova OS · campos por ordem de
/// importância"), drawn like the Lembretes and Calendário sheets: gray
/// background, white rounded cards, "X" and "✓" in glass at the top and the
/// assistant tools (Foto, Falar) in a glass bar at the bottom.

/// Radius of the white cards of the form.
const double kFormCardRadius = 26;

/// "X" | title | "✓" over the gray background. The "✓" is gray until the
/// order can be saved (HIG: inactive while the task is incomplete) and blue
/// filled once it can.
class NewOrderTopBar extends StatelessWidget {
  const NewOrderTopBar({
    super.key,
    required this.title,
    required this.onClose,
    required this.onSave,
  });

  final String title;
  final VoidCallback onClose;

  /// Null while the order cannot be saved.
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.blockMargin,
        AppSpacing.md,
        AppSpacing.blockMargin,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          GlassBarButton(
            key: const ValueKey('new_order_close'),
            label: l10n.cancel,
            icon: CupertinoIcons.xmark,
            onPressed: onClose,
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.bodyStrong.copyWith(
                color: AppColors.text.resolveFrom(context),
              ),
            ),
          ),
          _SaveButton(onPressed: onSave),
        ],
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final icon = Icon(
      CupertinoIcons.checkmark_alt,
      color: enabled
          ? AppColors.onAccent.resolveFrom(context)
          : AppColors.textSecondary.resolveFrom(context),
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: context.l10n.save,
      excludeSemantics: true,
      child: CupertinoButton(
        key: const ValueKey('new_order_save'),
        padding: EdgeInsets.zero,
        minimumSize: const Size(
          AppSizes.minTouchTarget,
          AppSizes.minTouchTarget,
        ),
        onPressed: onPressed,
        child: enabled
            // The one blue action of the sheet: opaque, not glass.
            ? Container(
                width: AppSizes.minTouchTarget,
                height: AppSizes.minTouchTarget,
                decoration: BoxDecoration(
                  color: AppColors.accent.resolveFrom(context),
                  shape: BoxShape.circle,
                ),
                child: icon,
              )
            : AppGlass(
                elevated: true,
                borderRadius: BorderRadius.circular(
                  AppSizes.minTouchTarget / 2,
                ),
                child: SizedBox(
                  width: AppSizes.minTouchTarget,
                  height: AppSizes.minTouchTarget,
                  child: icon,
                ),
              ),
      ),
    );
  }
}

/// White rounded card holding [FormRow]s, with an optional section title
/// above and a note below (gray, like "Marque este lembrete…").
class FormCard extends StatelessWidget {
  const FormCard({super.key, this.title, required this.children, this.note});

  final String? title;
  final List<Widget> children;
  final String? note;

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
    final secondary = AppColors.textSecondary.resolveFrom(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.blockMargin,
        AppSpacing.lg,
        AppSpacing.blockMargin,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  title!,
                  style: AppTypography.callout.copyWith(
                    color: secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ClipRRect(
            borderRadius: BorderRadius.circular(kFormCardRadius),
            child: ColoredBox(
              color: AppColors.surface.resolveFrom(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: rows,
              ),
            ),
          ),
          if (note != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                0,
              ),
              child: Text(
                note!,
                key: const ValueKey('form_card_note'),
                style: AppTypography.label.copyWith(color: secondary),
              ),
            ),
        ],
      ),
    );
  }
}

/// One line of a [FormCard]: icon, title (and subtitle), value at the right
/// and "›" when it opens something. [accent] draws an "add" line in blue.
/// The text wraps; nothing is cut with an ellipsis.
class FormRow extends StatelessWidget {
  const FormRow({
    super.key,
    required this.title,
    this.icon,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.accent = false,
    this.marked = false,
    this.showChevron = true,
  });

  final String title;
  final IconData? icon;
  final String? subtitle;
  final String? value;

  /// Replaces [value] (e.g. the date pills).
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool accent;

  /// Filled by the assistant: title on the marca-texto until touched.
  final bool marked;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final text = AppColors.text.resolveFrom(context);
    final secondary = AppColors.textSecondary.resolveFrom(context);
    final accentText = AppColors.accentText.resolveFrom(context);
    final titleStyle = AppTypography.body.copyWith(
      color: accent ? accentText : text,
      fontWeight: accent ? FontWeight.w600 : null,
      backgroundColor: marked ? AppColors.marker.resolveFrom(context) : null,
    );
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 54),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: icon == null
                  ? null
                  : Icon(icon, size: 22, color: accent ? accentText : secondary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: titleStyle),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Text(
                      subtitle!,
                      style: AppTypography.label.copyWith(color: secondary),
                    ),
                ],
              ),
            ),
            if (trailing != null)
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.sm),
                child: trailing,
              )
            else if (value != null)
              // Tight, so the value hugs the right edge next to the chevron.
              Flexible(
                fit: FlexFit.tight,
                child: Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.sm),
                  child: Text(
                    value!,
                    textAlign: TextAlign.end,
                    style: AppTypography.body.copyWith(
                      color: secondary,
                      fontFeatures: AppTypography.tabular,
                    ),
                  ),
                ),
              ),
            if (onTap != null && showChevron && !accent)
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.sm),
                child: Icon(
                  CupertinoIcons.chevron_forward,
                  size: 16,
                  color: AppColors.separator.resolveFrom(context),
                ),
              ),
          ],
        ),
      ),
    );
    if (onTap == null) return content;
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: content,
      ),
    );
  }
}

/// Gray pill with a value, like the dates of the Calendário sheet.
class FormPill extends StatelessWidget {
  const FormPill(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.secondaryFill.resolveFrom(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: AppTypography.callout.copyWith(
          color: AppColors.text.resolveFrom(context),
          fontFeatures: AppTypography.tabular,
        ),
      ),
    );
  }
}

/// Glass bar at the bottom of the sheet with the assistant tools: "Foto"
/// and "Falar" (HIG: a toolbar acts on the content of the screen). While the
/// assistant reads, it shows what it is doing instead.
class AssistantToolbar extends StatelessWidget {
  const AssistantToolbar({
    super.key,
    required this.onPhoto,
    required this.onTalk,
    this.busyLabel,
  });

  final VoidCallback onPhoto;
  final VoidCallback onTalk;

  /// Shown with a spinner while the assistant reads; hides the tools.
  final String? busyLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = AppColors.text.resolveFrom(context);
    Widget tool(Key key, IconData icon, String label, VoidCallback onTap) {
      return Expanded(
        child: Semantics(
          button: true,
          label: label,
          excludeSemantics: true,
          child: CupertinoButton(
            key: key,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            minimumSize: const Size(
              AppSizes.minTouchTarget,
              AppSizes.minTouchTarget,
            ),
            onPressed: onTap,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: text),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    label,
                    style: AppTypography.callout.copyWith(
                      color: text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AppGlass(
      elevated: true,
      borderRadius: BorderRadius.circular(30),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: busyLabel != null
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CupertinoActivityIndicator(),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        busyLabel!,
                        key: const ValueKey('assistant_busy'),
                        style: AppTypography.callout.copyWith(color: text),
                      ),
                    ),
                  ],
                ),
              )
            : Row(
                children: [
                  tool(
                    const ValueKey('assistant_photo'),
                    CupertinoIcons.camera,
                    l10n.orderAssistantPhoto,
                    onPhoto,
                  ),
                  tool(
                    const ValueKey('assistant_talk'),
                    CupertinoIcons.mic,
                    l10n.orderAssistantTalkShort,
                    onTalk,
                  ),
                ],
              ),
      ),
    );
  }
}
