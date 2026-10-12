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
  static const double fadeExtent = 16;

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
                  colors: [
                    background.withValues(alpha: 0.92),
                    background.withValues(alpha: 0.92),
                    background.withValues(alpha: 0),
                  ],
                  stops: [0, top / (top + fadeExtent), 1],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
