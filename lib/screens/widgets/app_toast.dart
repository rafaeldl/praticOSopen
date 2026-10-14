import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/semantics.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';

/// How long the "aviso rápido" stays on screen.
const Duration kAppToastDuration = Duration(seconds: 2);

/// Fade/slide in and out.
const Duration kAppToastAnimation = Duration(milliseconds: 220);

/// Room left for the tab bar (and the floating button above it) so the
/// notice never covers it.
const double _kTabBarRoom = 56;

OverlayEntry? _currentToast;

/// Shows a quick, non-blocking notice ("aviso rápido") that confirms an action
/// already done ("Link copiado", "Foto apagada"). It floats near the bottom,
/// above the tab bar and the safe area, goes away on its own after
/// [kAppToastDuration] and is read by VoiceOver.
///
/// Only one notice at a time: a new one replaces the one on screen. Errors and
/// questions stay in alerts; this is only for "done".
void showAppToast(
  BuildContext context,
  String message, {
  IconData? icon,
  Duration duration = kAppToastDuration,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  hideAppToast();

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _AppToast(
      key: UniqueKey(),
      message: message,
      icon: icon ?? CupertinoIcons.checkmark_circle_fill,
      duration: duration,
      onDismissed: () {
        if (identical(_currentToast, entry)) _currentToast = null;
        if (entry.mounted) entry.remove();
      },
    ),
  );
  _currentToast = entry;
  overlay.insert(entry);

  final view = View.maybeOf(context);
  if (view != null) {
    SemanticsService.sendAnnouncement(
      view,
      message,
      Directionality.maybeOf(context) ?? TextDirection.ltr,
    );
  }
}

/// Removes the notice on screen, if any.
void hideAppToast() {
  final current = _currentToast;
  _currentToast = null;
  if (current != null && current.mounted) current.remove();
}

class _AppToast extends StatefulWidget {
  const _AppToast({
    super.key,
    required this.message,
    required this.icon,
    required this.duration,
    required this.onDismissed,
  });

  final String message;
  final IconData icon;
  final Duration duration;
  final VoidCallback onDismissed;

  @override
  State<_AppToast> createState() => _AppToastState();
}

class _AppToastState extends State<_AppToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: kAppToastAnimation,
  );
  Timer? _timer;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
    _timer = Timer(widget.duration, _dismiss);
  }

  Future<void> _dismiss() async {
    if (!mounted) return;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _controller.value = 0;
    } else {
      await _controller.reverse();
    }
    if (mounted) widget.onDismissed();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottom =
        (media.viewInsets.bottom > media.viewPadding.bottom
            ? media.viewInsets.bottom
            : media.viewPadding.bottom + _kTabBarRoom) +
        AppSpacing.md;
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return Positioned(
      left: AppSpacing.lg,
      right: AppSpacing.lg,
      bottom: bottom,
      child: IgnorePointer(
        child: SafeArea(
          top: false,
          bottom: false,
          child: Center(
            child: FadeTransition(
              opacity: curve,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.4),
                  end: Offset.zero,
                ).animate(curve),
                child: _ToastCard(message: widget.message, icon: widget.icon),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToastCard extends StatelessWidget {
  const _ToastCard({required this.message, required this.icon});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final textStyle = AppTypography.callout.copyWith(
      color: AppColors.text.resolveFrom(context),
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.none,
    );
    return Semantics(
      container: true,
      child: DefaultTextStyle(
        style: textStyle,
        child: Container(
          key: const ValueKey('app_toast'),
          constraints: const BoxConstraints(
            minHeight: AppSizes.minTouchTarget,
            maxWidth: 520,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            // Content stays opaque: glass is only for navigation.
            color: AppColors.surface.resolveFrom(context),
            borderRadius: BorderRadius.circular(AppRadii.block),
            boxShadow: const [
              BoxShadow(
                color: Color(0x26000000),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Icon(
                  icon,
                  size: 22,
                  color: AppColors.success.resolveFrom(context),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(child: Text(message, style: textStyle)),
            ],
          ),
        ),
      ),
    );
  }
}
