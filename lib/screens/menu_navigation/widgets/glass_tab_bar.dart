import 'package:flutter/cupertino.dart';
import 'package:praticos/theme/app_glass.dart';

const Color _transparent = Color(0x00000000);

/// Tab bar on the glass material ([AppGlass]): translucent fill over a
/// backdrop blur, so content scrolls behind it. Falls back to an opaque fill
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

  @override
  Widget build(BuildContext context) {
    return AppGlass(
      reduceTransparency: reduceTransparency,
      child: _BareTabBar(
        items: items,
        onTap: onTap,
        currentIndex: currentIndex,
        activeColor: activeColor,
        inactiveColor: inactiveColor,
        iconSize: iconSize,
        height: height,
        border: border,
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

/// Tab bar content without its own background or blur: [AppGlass] paints them.
class _BareTabBar extends CupertinoTabBar {
  const _BareTabBar({
    required super.items,
    super.onTap,
    super.currentIndex,
    super.activeColor,
    required super.inactiveColor,
    required super.iconSize,
    required super.height,
    super.border,
  }) : super(backgroundColor: _transparent);

  // Reported as opaque so CupertinoTabBar skips its built-in blur.
  @override
  bool opaque(BuildContext context) => true;
}
