import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_typography.dart';

/// Illustration of the login screen, from the home of the site: a reel with the
/// photos of every trade and the spoken order below the people. What was said
/// turns into a ready order, once. With Reduce Motion it is already complete.
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
  static const _margin = 30.0;
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
            padding: const EdgeInsets.only(top: 16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (showPhotos)
                  Padding(
                    padding: EdgeInsets.only(bottom: photosBottom),
                    child: const _TradeReel(),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    _margin,
                    0,
                    _margin,
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

/// Photos of the trades passing slowly to the side, endlessly, like the reels
/// of the site. A tap pauses them and a drag moves them by hand. With Reduce
/// Motion they stand still and only the drag is left.
class _TradeReel extends StatefulWidget {
  const _TradeReel();

  @override
  State<_TradeReel> createState() => _TradeReelState();
}

class _TradeReelState extends State<_TradeReel>
    with SingleTickerProviderStateMixin {
  /// Points per second: the pace of the site's reels.
  static const _speed = 20.0;
  static const _gap = 10.0;
  static const _photoRatio = 800 / 993;

  final _scroll = ScrollController();
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  bool _paused = false;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _syncTicker();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _syncTicker() {
    final shouldRun = !_paused && !_reduceMotion;
    if (shouldRun && !_ticker.isActive) {
      _lastTick = Duration.zero;
      _ticker.start();
    } else if (!shouldRun && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _onTick(Duration elapsed) {
    final seconds = (elapsed - _lastTick).inMicroseconds / 1000000;
    _lastTick = elapsed;
    if (!_scroll.hasClients) return;
    // The finger wins while it drags or flings the reel.
    if (_scroll.position.isScrollingNotifier.value) return;
    _scroll.jumpTo(_scroll.offset + _speed * seconds);
  }

  void _togglePause() {
    _paused = !_paused;
    _syncTicker();
  }

  List<(String, String)> _trades(AppLocalizations l10n) => [
    ('automotivo', l10n.loginTradeAutomotivo),
    ('refrigeracao', l10n.loginTradeRefrigeracao),
    ('eletrica', l10n.loginTradeEletrica),
    ('assistencia-celular', l10n.loginTradeAssistenciaCelular),
    ('hidraulica', l10n.loginTradeHidraulica),
    ('energia-solar', l10n.loginTradeEnergiaSolar),
    ('informatica', l10n.loginTradeInformatica),
    ('limpeza', l10n.loginTradeLimpeza),
    ('eletronica', l10n.loginTradeEletronica),
    ('seguranca-cftv', l10n.loginTradeSegurancaCftv),
    ('bicicletaria', l10n.loginTradeBicicletaria),
    ('eletrodomesticos', l10n.loginTradeEletrodomesticos),
    ('impressoras', l10n.loginTradeImpressoras),
    ('automacao', l10n.loginTradeAutomacao),
    ('dedetizacao', l10n.loginTradeDedetizacao),
    ('elevadores', l10n.loginTradeElevadores),
    ('manutencao-predial', l10n.loginTradeManutencaoPredial),
    ('moveis', l10n.loginTradeMoveis),
    ('manutencao-ativos', l10n.loginTradeManutencaoAtivos),
    ('obras-publicas', l10n.loginTradeObrasPublicas),
  ];

  @override
  Widget build(BuildContext context) {
    final trades = _trades(context.l10n);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _togglePause,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxHeight * _photoRatio;
          return ListView.builder(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 20),
            itemExtent: width + _gap,
            itemBuilder: (context, index) {
              final (slug, label) = trades[index % trades.length];
              return Padding(
                padding: const EdgeInsets.only(right: _gap),
                child: _buildPhoto(slug, label),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPhoto(String slug, String label) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/trades/$slug.webp',
            fit: BoxFit.cover,
            cacheWidth: 560,
            gaplessPlayback: true,
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
      ),
    );
  }
}
