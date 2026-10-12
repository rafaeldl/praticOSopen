import 'package:flutter/widgets.dart';
import 'package:praticos/theme/app_colors.dart';

/// The soft scroll-edge fade of iOS 26 under the status bar.
///
/// Navigation bars are transparent (only the glass buttons float over the
/// content), so this keeps scrolled content from colliding with the clock.
class StatusBarFade extends StatelessWidget {
  const StatusBarFade({super.key, required this.child});

  final Widget child;

  /// How far the fade reaches below the status bar.
  static const double fadeExtent = 28;

  static const _fadeStops = [0.0, 0.25, 0.5, 0.75, 1.0];
  static const _alphas = [0.94, 0.94, 0.7, 0.4, 0.15, 0.0];

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    if (top == 0) return child;
    final background = AppColors.background.resolveFrom(context);
    return Stack(
      children: [
        child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: top + fadeExtent,
          child: IgnorePointer(
            child: DecoratedBox(
              key: const ValueKey('status_bar_fade'),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  // Eased fade, so there is no visible edge where it ends.
                  colors: [
                    for (final alpha in _alphas)
                      background.withValues(alpha: alpha),
                  ],
                  stops: [
                    0,
                    for (final t in _fadeStops)
                      (top + fadeExtent * t) / (top + fadeExtent) -
                          (t == 0 ? 0.0001 : 0),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
