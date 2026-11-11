import 'package:flutter/cupertino.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_glass.dart';

const Color _transparent = Color(0x00000000);

/// Tab bar as a floating capsule on the glass material ([AppGlass]):
/// translucent fill over a backdrop blur, so content scrolls behind it. The
/// selected tab sits on a filled capsule in the accent color. Falls back to an opaque fill
/// (and the scaffold stops extending content behind the bar) with "Increase
/// Contrast", [reduceTransparency] or when glass is disabled.
///
/// Extends [CupertinoTabBar] so it plugs into [CupertinoTabScaffold], which
/// calls [copyWith] and [opaque] on the bar.
class GlassTabBar extends CupertinoTabBar {
  const GlassTabBar({
    super.key,
    required super.items,
    super.onTap,
    super.currentIndex,
    super.activeColor,
    super.inactiveColor,
    super.iconSize,
    super.height,
    super.border,
    this.reduceTransparency = false,
    this.action,
  }) : super(backgroundColor: _transparent);

  /// Round button beside the capsule ("Nova OS"), the screen's main action
  /// within thumb reach. It is a button, not a tab: [NewOrderTabButton].
  final Widget? action;

  /// Width of one tab when the capsule does not span the screen.
  static const double compactTabWidth = 105;

  /// iOS "Reduce Transparency" (not exposed by `MediaQuery`).
  final bool reduceTransparency;

  @override
  bool opaque(BuildContext context) =>
      AppGlass.isOpaque(context, reduceTransparency: reduceTransparency);

  /// Height of the floating capsule (design system: "Abas").
  static const double capsuleHeight = 64;

  /// Space reserved above the safe area (capsule + gap), used by
  /// [CupertinoTabScaffold] to inset the tab content.
  static const double barHeight = 72;

  /// Clear glass, like the iOS 26 tab bar: content shows through softly.
  static const double glassOpacity = 0.4;
  static const double glassBlur = 12;

  /// The most the tab labels grow with the iPhone text size.
  static const double maxLabelScale = 1.3;

  @override
  Size get preferredSize => const Size.fromHeight(barHeight);

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
    // The capsule floats slightly into the home indicator area, as in iOS 26.
    final bottomGap = safeBottom > 0 ? safeBottom - 6 : 8.0;
    final activeColor = CupertinoDynamicColor.maybeResolve(
      this.activeColor ?? AppColors.accentText,
      context,
    )!;
    return SizedBox(
      height: barHeight + safeBottom,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, bottomGap),
          child: _layout(
            AppGlass(
              elevated: true,
              reduceTransparency: reduceTransparency,
              borderRadius: BorderRadius.circular(capsuleHeight / 2),
              opacity: GlassTabBar.glassOpacity,
              blurSigma: GlassTabBar.glassBlur,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: capsuleHeight),
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: Row(
                    children: [
                      for (var i = 0; i < items.length; i++)
                        Expanded(
                          child: _TabItem(
                            item: items[i],
                            selected: i == currentIndex,
                            activeColor: activeColor,
                            inactiveColor: AppColors.text.resolveFrom(context),
                            selectedFill: activeColor.withValues(
                              alpha:
                                  CupertinoTheme.brightnessOf(context) ==
                                      Brightness.dark
                                  ? 0.16
                                  : 0.12,
                            ),
                            onTap: onTap == null ? null : () => onTap!(i),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// With [action], the capsule fills the room left of it. Without it, a
  /// short tab list (fewer than 3 tabs) sits centered instead of
  /// stretching from edge to edge.
  Widget _layout(Widget capsule) {
    final action = this.action;
    if (action != null) {
      return Row(
        children: [
          Expanded(child: capsule),
          const SizedBox(width: 12),
          action,
        ],
      );
    }
    if (items.length < 3) {
      return Center(
        child: SizedBox(
          width: items.length * compactTabWidth + 10,
          child: capsule,
        ),
      );
    }
    return capsule;
  }

  @override
  GlassTabBar copyWith({
    Key? key,
    List<BottomNavigationBarItem>? items,
    Color? backgroundColor,
    Color? activeColor,
    Color? inactiveColor,
    double? iconSize,
    double? height,
    Border? border,
    int? currentIndex,
    ValueChanged<int>? onTap,
  }) {
    // backgroundColor is ignored: the fill comes from AppGlass.
    return GlassTabBar(
      key: key ?? this.key,
      items: items ?? this.items,
      activeColor: activeColor ?? this.activeColor,
      inactiveColor: inactiveColor ?? this.inactiveColor,
      iconSize: iconSize ?? this.iconSize,
      height: height ?? this.height,
      border: border ?? this.border,
      currentIndex: currentIndex ?? this.currentIndex,
      onTap: onTap ?? this.onTap,
      reduceTransparency: reduceTransparency,
      action: action,
    );
  }
}

/// The "+" beside the tab capsule: starts a new order from any tab.
///
/// On a tab's first screen it is the screen's yellow action ([primary]):
/// solid, with a hairline edge. With another screen open on the tab, which
/// may have its own yellow button, it steps back to glass with a navy "+",
/// like the top bar buttons, as the web's "Nova OS" while an order is open.
/// The large "+" set apart from the capsule keeps it reading as an action,
/// not one more tab.
class NewOrderTabButton extends StatelessWidget {
  const NewOrderTabButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = false,
  });

  /// Spoken name ("Nova OS").
  final String label;
  final VoidCallback onPressed;

  /// Yellow ([AppColors.action]) when true, glass otherwise.
  final bool primary;

  @override
  Widget build(BuildContext context) {
    const size = GlassTabBar.capsuleHeight;
    final Widget button = primary
        ? Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: AppColors.action.resolveFrom(context),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.actionBorder.resolveFrom(context),
              ),
            ),
            child: Icon(
              CupertinoIcons.add,
              size: 30,
              color: AppColors.onAction.resolveFrom(context),
            ),
          )
        : AppGlass(
            elevated: true,
            borderRadius: BorderRadius.circular(size / 2),
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(
                CupertinoIcons.add,
                size: 30,
                color: AppColors.text.resolveFrom(context),
              ),
            ),
          );
    return Semantics(
      identifier: 'add_order_button',
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: button,
      ),
    );
  }
}

/// One tab: icon over label; the selected tab sits on a filled capsule.
class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.item,
    required this.selected,
    required this.activeColor,
    required this.inactiveColor,
    required this.selectedFill,
    this.onTap,
  });

  final BottomNavigationBarItem item;
  final bool selected;
  final Color activeColor;
  final Color inactiveColor;
  final Color selectedFill;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? activeColor : inactiveColor;
    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: selected,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            constraints: const BoxConstraints(minHeight: 54),
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: selected ? selectedFill : const Color(0x00000000),
              borderRadius: BorderRadius.circular(27),
            ),
            child: IconTheme(
              data: IconThemeData(color: color, size: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  selected ? item.activeIcon : item.icon,
                  const SizedBox(height: 1),
                  if (item.label != null)
                    // Like the native iOS tab bar, the label grows only a
                    // little with the iPhone text size, so the bar keeps
                    // its height (iOS shows the Large Content Viewer).
                    MediaQuery.withClampedTextScaling(
                      maxScaleFactor: GlassTabBar.maxLabelScale,
                      child: Text(
                        item.label!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
