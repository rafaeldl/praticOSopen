import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_glass.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';

/// Round 44pt top bar button on glass (design system rule 11).
///
/// [label] is the accessibility label (required: screen readers and the
/// simulator automation only reach elements that have one).
class GlassBarButton extends StatelessWidget {
  const GlassBarButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.child,
    this.identifier,
  }) : assert(icon != null || child != null);

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Custom content (e.g. a bell with a badge); replaces [icon].
  final Widget? child;
  final String? identifier;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: identifier,
      button: true,
      label: label,
      excludeSemantics: true,
      child: AppGlass(
        elevated: true,
        borderRadius: BorderRadius.circular(AppSizes.minTouchTarget / 2),
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(
            AppSizes.minTouchTarget,
            AppSizes.minTouchTarget,
          ),
          onPressed: onPressed,
          child:
              child ?? Icon(icon, color: AppColors.text.resolveFrom(context)),
        ),
      ),
    );
  }
}

/// Glass capsule with a chevron and the name of the previous screen.
class GlassBackButton extends StatelessWidget {
  const GlassBackButton({super.key, this.previousTitle, this.onPressed});

  /// Name of the screen we came from; falls back to "Voltar".
  final String? previousTitle;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final title = previousTitle ?? context.l10n.back;
    final color = AppColors.accentText.resolveFrom(context);
    return Semantics(
      button: true,
      label: title,
      excludeSemantics: true,
      child: AppGlass(
        elevated: true,
        borderRadius: BorderRadius.circular(AppSizes.minTouchTarget / 2),
        child: CupertinoButton(
          padding: const EdgeInsets.only(left: 8, right: 14),
          minimumSize: const Size(
            AppSizes.minTouchTarget,
            AppSizes.minTouchTarget,
          ),
          onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.chevron_back, size: 22, color: color),
              Flexible(
                child: Text(
                  title,
                  style: AppTypography.body.copyWith(color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Large-title navigation bar sliver with the glass top buttons: back capsule
/// (only when there is a screen to go back to) and an optional [trailing].
class AppNavBar extends StatelessWidget {
  const AppNavBar({
    super.key,
    required this.largeTitle,
    this.previousTitle,
    this.trailing,
    this.leading,
    this.backgroundColor,
  });

  final Widget largeTitle;
  final String? previousTitle;
  final Widget? trailing;

  /// Replaces the automatic back button.
  final Widget? leading;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    return CupertinoSliverNavigationBar(
      automaticallyImplyLeading: false,
      leading:
          leading ??
          (canPop ? GlassBackButton(previousTitle: previousTitle) : null),
      largeTitle: largeTitle,
      backgroundColor:
          backgroundColor ?? AppColors.background.resolveFrom(context),
      border: null,
      trailing: trailing,
    );
  }
}
