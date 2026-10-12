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
  }) : super(backgroundColor: _transparent);

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
    final shadowAlpha = CupertinoTheme.brightnessOf(context) == Brightness.dark
        ? 0.4
        : 0.14;

    return SizedBox(
      height: barHeight + safeBottom,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, bottomGap),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(capsuleHeight / 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF000000).withValues(alpha: shadowAlpha),
                  blurRadius: 24,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: AppGlass(
              reduceTransparency: reduceTransparency,
              borderRadius: BorderRadius.circular(capsuleHeight / 2),
              opacity: 0.88,
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
                            selectedFill: AppColors.secondaryFill.resolveFrom(
                              context,
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
