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
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(
          AppSizes.minTouchTarget,
          AppSizes.minTouchTarget,
        ),
        onPressed: onPressed,
        child: AppGlass(
          elevated: true,
          borderRadius: BorderRadius.circular(AppSizes.glassBarButton / 2),
          // Minimum size, not a fixed one: the content may grow.
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: AppSizes.glassBarButton,
              minHeight: AppSizes.glassBarButton,
            ),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child:
                  child ??
                  Icon(icon, color: AppColors.text.resolveFrom(context)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Glass capsule with a chevron and the name of the previous screen.
class GlassBackButton extends StatelessWidget {
  const GlassBackButton({super.key, this.previousTitle, this.onPressed});

  /// Name of the screen we came from; falls back to the previous route's
  /// title, then to "Voltar".
  final String? previousTitle;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    final routeTitle = route is CupertinoRouteTransitionMixin
        ? route.previousTitle.value
        : null;
    final title =
        previousTitle ??
        ((routeTitle?.isNotEmpty ?? false) ? routeTitle! : context.l10n.back);
    // Prototype: label color on glass, not the accent.
    final color = AppColors.text.resolveFrom(context);
    return Semantics(
      button: true,
      label: title,
      excludeSemantics: true,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(
          AppSizes.minTouchTarget,
          AppSizes.minTouchTarget,
        ),
        onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
        child: AppGlass(
          elevated: true,
          borderRadius: BorderRadius.circular(AppSizes.glassBarButton / 2),
          child: Container(
            constraints: const BoxConstraints(
              minHeight: AppSizes.glassBarButton,
            ),
            padding: const EdgeInsets.only(left: 8, right: 14),
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
  });

  final Widget largeTitle;
  final String? previousTitle;
  final Widget? trailing;

  /// Replaces the automatic back button.
  final Widget? leading;

  /// Bar background, as in iOS 26: the bar is clear while the page is at the
  /// top (only the glass buttons show) and turns into frosted glass, with the
  /// small title, once content scrolls under it (`automaticBackgroundVisibility`).
  /// Screens that build their own [CupertinoSliverNavigationBar] use it with
  /// `alwaysShowMiddle: false` to match [AppNavBar].
  static Color barBackground(BuildContext context) =>
      AppColors.background.resolveFrom(context).withValues(alpha: 0.8);

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    return CupertinoSliverNavigationBar(
      automaticallyImplyLeading: false,
      leading:
          leading ??
          (canPop ? GlassBackButton(previousTitle: previousTitle) : null),
      largeTitle: largeTitle,
      alwaysShowMiddle: false,
      backgroundColor: barBackground(context),
      border: null,
      trailing: trailing,
    );
  }
}
