import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_typography.dart';

/// Illustration of the login screen: a sample service order, stamped as
/// approved by the customer, sliding up from behind the sign-in panel.
///
/// It is drawn instead of shipped as an image so it follows the language and
/// dark mode. Being a picture, it is hidden from VoiceOver, and it shrinks (or
/// leaves) when the space above the panel gets short.
///
/// Fills its parent, whose [ClipRect] hides what goes below the panel, so with
/// large text the sheet grows and the panel cuts it like any other page.
class LoginSampleOrder extends StatefulWidget {
  const LoginSampleOrder({super.key});

  @override
  State<LoginSampleOrder> createState() => _LoginSampleOrderState();
}

class _LoginSampleOrderState extends State<LoginSampleOrder>
    with SingleTickerProviderStateMixin {
  /// Space that shows the whole order, stamp included.
  static const _contentHeight = 262.0;

  /// Most of the sheet ever shown: on an iPad the rest stays below the panel.
  static const _maxVisibleHeight = 340.0;
  static const _minVisibleHeight = 96.0;
  static const _topGap = 20.0;
  static const _sideMargin = 30.0;
  static const _maxWidth = 340.0;
  static const _radius = BorderRadius.all(Radius.circular(14));

  late final AnimationController _controller;
  late final Animation<double> _slide;
  late final Animation<double> _stamp;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _slide = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.65, curve: Curves.easeOutCubic),
    );
    _stamp = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.65, 1, curve: Curves.easeOutBack),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final visible = math.min(
            constraints.maxHeight - _topGap,
            _maxVisibleHeight,
          );
          if (visible < _minVisibleHeight) return const SizedBox.shrink();

          final width = math.min(
            constraints.maxWidth - _sideMargin * 2,
            _maxWidth,
          );
          final scale = math.min(1.0, visible / _contentHeight);

          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                top: constraints.maxHeight - visible,
                width: width,
                child: AnimatedBuilder(
                  animation: _slide,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(0, (1 - _slide.value) * visible),
                    child: child,
                  ),
                  child: Transform.scale(
                    scale: scale,
                    alignment: Alignment.topCenter,
                    child: _buildSheets(context),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSheets(BuildContext context) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final surface = AppColors.surface.resolveFrom(context);
    final accent = AppColors.accent.resolveFrom(context);

    return SizedBox(
      height: _maxVisibleHeight + 80,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Second copy of the order underneath, for depth.
          Transform.rotate(
            angle: 2.2 * math.pi / 180,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.onAccent
                    .resolveFrom(context)
                    .withValues(alpha: isDark ? 0.1 : 0.28),
                borderRadius: _radius,
              ),
            ),
          ),
          Transform.rotate(
            angle: -2.4 * math.pi / 180,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: surface,
                borderRadius: _radius,
                boxShadow: [
                  BoxShadow(
                    color: CupertinoColors.black.withValues(alpha: 0.3),
                    blurRadius: 30,
                    offset: Offset(0, 14),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: _radius,
                // Not for scrolling: lets large text run past the sheet's end.
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ColoredBox(
                        color: accent,
                        child: const SizedBox(height: 6),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                        child: _buildContent(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final l10n = context.l10n;
    final textColor = AppColors.text.resolveFrom(context);
    final total = AppTypography.callout.copyWith(
      color: textColor,
      fontWeight: FontWeight.w700,
      fontFeatures: AppTypography.tabular,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(
                l10n.loginSampleTitle,
                style: AppTypography.callout.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              l10n.loginSampleNumber,
              style: AppTypography.label.copyWith(
                color: AppColors.accentText.resolveFrom(context),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ColoredBox(color: textColor, child: const SizedBox(height: 1.5)),
        _buildRow(
          context,
          l10n.loginSampleCustomerLabel,
          l10n.loginSampleCustomer,
        ),
        _buildRow(
          context,
          l10n.loginSampleServiceLabel,
          l10n.loginSampleService,
        ),
        _buildRow(
          context,
          l10n.loginSampleDeliveryLabel,
          l10n.loginSampleDelivery,
        ),
        _buildRow(
          context,
          l10n.loginSampleTotalLabel,
          l10n.loginSampleTotal,
          valueStyle: total,
          divider: false,
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: ScaleTransition(
            scale: Tween<double>(begin: 1.5, end: 1).animate(_stamp),
            child: FadeTransition(
              opacity: _stamp.drive(Tween(begin: 0.0, end: 1.0)),
              child: _buildStamp(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRow(
    BuildContext context,
    String label,
    String value, {
    TextStyle? valueStyle,
    bool divider = true,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: divider
          ? BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppColors.separator.resolveFrom(context),
                ),
              ),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            label,
            style: AppTypography.label.copyWith(
              color: AppColors.textSecondary.resolveFrom(context),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style:
                  valueStyle ??
                  AppTypography.label.copyWith(
                    color: AppColors.text.resolveFrom(context),
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStamp(BuildContext context) {
    final color = AppColors.success.resolveFrom(context);
    return Transform.rotate(
      angle: -8 * math.pi / 180,
      child: Container(
        width: 118,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          context.l10n.loginSampleStamp.toUpperCase(),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontSize: 11.5,
            height: 1.15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}
