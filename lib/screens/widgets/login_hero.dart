import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_typography.dart';

/// Illustration of the login screen, from the home of the site: photos of two
/// trades with the spoken order under the people. What was said turns into a
/// ready order, once. With Reduce Motion it is already complete.
///
/// Being a picture, it is hidden from VoiceOver. The card shrinks to fit, and
/// the photos leave first when the space above the panel gets short.
class LoginHero extends StatefulWidget {
  const LoginHero({super.key});

  @override
  State<LoginHero> createState() => _LoginHeroState();
}

class _LoginHeroState extends State<LoginHero>
    with SingleTickerProviderStateMixin {
  static const _minHeight = 96.0;

  /// Height of the card at normal text size, to keep the people above it.
  static const _cardHeight = 124.0;
  static const _cardBottom = 14.0;
  static const _cardOverlap = 24.0;
  static const _minPhotoHeight = 72.0;
  static const _margin = 20.0;
  static const _gap = 10.0;
  static const _cardMaxWidth = 340.0;
  static const _radius = BorderRadius.all(Radius.circular(10));

  late final AnimationController _controller;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
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
          if (constraints.maxHeight < _minHeight) {
            return const SizedBox.shrink();
          }

          final card = MediaQuery.textScalerOf(context).scale(_cardHeight);
          final top = constraints.maxHeight - 16;
          final photosBottom = card + _cardBottom - _cardOverlap;
          final showPhotos = top - photosBottom >= _minPhotoHeight;

          return Padding(
            padding: const EdgeInsets.fromLTRB(_margin, 16, _margin, 0),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (showPhotos)
                  Padding(
                    padding: EdgeInsets.only(bottom: photosBottom),
                    child: _buildPhotos(context),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    10,
                    0,
                    10,
                    _cardBottom,
                  ),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.bottomCenter,
                      child: SizedBox(
                        width: _cardMaxWidth,
                        child: _buildCard(context),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPhotos(BuildContext context) {
    final l10n = context.l10n;
    return ClipRRect(
      borderRadius: _radius,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: _buildPhoto(
              'assets/images/login_mechanic.webp',
              l10n.loginTradeAuto,
              const Alignment(0, 0.45),
            ),
          ),
          const SizedBox(width: _gap),
          Expanded(
            flex: 2,
            child: _buildPhoto(
              'assets/images/login_hvac.webp',
              l10n.loginTradeHvac,
              const Alignment(0, 0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoto(String asset, String label, Alignment alignment) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          asset,
          fit: BoxFit.cover,
          alignment: alignment,
          cacheWidth: 640,
        ),
        Positioned(
          top: 8,
          left: 8,
          right: 8,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.brandYellow,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.label.copyWith(
                  color: AppColors.brandNavy,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Fades [child] in between [start] and [end] of the pass, rising a little.
  Widget _reveal(double start, double end, Widget child) {
    final progress = _controller.drive(
      CurveTween(curve: Interval(start, end, curve: Curves.easeOutCubic)),
    );
    return FadeTransition(
      opacity: progress,
      child: SlideTransition(
        position: progress.drive(
          Tween(begin: const Offset(0, 0.25), end: Offset.zero),
        ),
        child: child,
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    final l10n = context.l10n;
    final text = AppColors.text.resolveFrom(context);
    final success = AppColors.success.resolveFrom(context);

    return _reveal(
      0,
      0.3,
      DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface.resolveFrom(context),
          borderRadius: _radius,
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.black.withValues(alpha: 0.3),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: _radius,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.loginSampleSaid,
                            style: AppTypography.label.copyWith(
                              color: AppColors.textSecondary.resolveFrom(
                                context,
                              ),
                            ),
                          ),
                        ),
                        _buildVoiceBars(context),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.loginSampleLine,
                      style: AppTypography.bodyStrong.copyWith(
                        color: text,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              _reveal(
                0.5,
                0.9,
                ColoredBox(
                  color: success.withValues(alpha: 0.13),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.loginSampleDone,
                            style: AppTypography.label.copyWith(
                              color: text,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.loginSampleTotal,
                          style: AppTypography.label.copyWith(
                            color: text,
                            fontWeight: FontWeight.w700,
                            fontFeatures: AppTypography.tabular,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceBars(BuildContext context) {
    final color = AppColors.accentText.resolveFrom(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final height in const [5.0, 10.0, 14.0, 8.0, 12.0, 6.0, 10.0, 5.0])
          Container(
            width: 2,
            height: height,
            margin: const EdgeInsets.only(left: 2),
            color: color,
          ),
      ],
    );
  }
}
