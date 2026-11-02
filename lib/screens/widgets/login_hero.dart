import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_typography.dart';

/// One trade of the reel, with the order someone in it would dictate.
class _Trade {
  const _Trade(this.slug, this.label, this.line, this.total);

  final String slug;
  final String label;
  final String line;
  final num total;
}

List<_Trade> _tradesOf(AppLocalizations l10n) => [
  _Trade(
    'automotivo',
    l10n.loginTradeAutomotivo,
    l10n.loginSampleAutomotivo,
    200,
  ),
  _Trade(
    'refrigeracao',
    l10n.loginTradeRefrigeracao,
    l10n.loginSampleRefrigeracao,
    350,
  ),
  _Trade('eletrica', l10n.loginTradeEletrica, l10n.loginSampleEletrica, 280),
  _Trade(
    'assistencia-celular',
    l10n.loginTradeAssistenciaCelular,
    l10n.loginSampleAssistenciaCelular,
    650,
  ),
  _Trade(
    'hidraulica',
    l10n.loginTradeHidraulica,
    l10n.loginSampleHidraulica,
    180,
  ),
  _Trade(
    'energia-solar',
    l10n.loginTradeEnergiaSolar,
    l10n.loginSampleEnergiaSolar,
    2400,
  ),
  _Trade(
    'informatica',
    l10n.loginTradeInformatica,
    l10n.loginSampleInformatica,
    390,
  ),
  _Trade('limpeza', l10n.loginTradeLimpeza, l10n.loginSampleLimpeza, 260),
  _Trade(
    'eletronica',
    l10n.loginTradeEletronica,
    l10n.loginSampleEletronica,
    320,
  ),
  _Trade(
    'seguranca-cftv',
    l10n.loginTradeSegurancaCftv,
    l10n.loginSampleSegurancaCftv,
    1800,
  ),
  _Trade(
    'bicicletaria',
    l10n.loginTradeBicicletaria,
    l10n.loginSampleBicicletaria,
    240,
  ),
  _Trade(
    'eletrodomesticos',
    l10n.loginTradeEletrodomesticos,
    l10n.loginSampleEletrodomesticos,
    270,
  ),
  _Trade(
    'impressoras',
    l10n.loginTradeImpressoras,
    l10n.loginSampleImpressoras,
    380,
  ),
  _Trade('automacao', l10n.loginTradeAutomacao, l10n.loginSampleAutomacao, 520),
  _Trade(
    'dedetizacao',
    l10n.loginTradeDedetizacao,
    l10n.loginSampleDedetizacao,
    450,
  ),
  _Trade(
    'elevadores',
    l10n.loginTradeElevadores,
    l10n.loginSampleElevadores,
    900,
  ),
  _Trade(
    'manutencao-predial',
    l10n.loginTradeManutencaoPredial,
    l10n.loginSampleManutencaoPredial,
    600,
  ),
  _Trade('moveis', l10n.loginTradeMoveis, l10n.loginSampleMoveis, 300),
  _Trade(
    'manutencao-ativos',
    l10n.loginTradeManutencaoAtivos,
    l10n.loginSampleManutencaoAtivos,
    750,
  ),
  _Trade(
    'obras-publicas',
    l10n.loginTradeObrasPublicas,
    l10n.loginSampleObrasPublicas,
    8500,
  ),
];

/// Illustration of the login screen, from the home of the site: a reel with the
/// photos of every trade and the spoken order below the people. The card
/// follows the photo at the center of the reel. What was said turns into a
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
  static const _margin = 30.0;
  static const _cardMaxWidth = 340.0;
  static const _radius = BorderRadius.all(Radius.circular(10));
  static const _swapDuration = Duration(milliseconds: 500);

  late final AnimationController _controller;
  final _activeTrade = ValueNotifier<int>(0);
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
    _activeTrade.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trades = _tradesOf(context.l10n);
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
                    child: _TradeReel(trades: trades, active: _activeTrade),
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
                        child: ValueListenableBuilder<int>(
                          valueListenable: _activeTrade,
                          builder: (context, active, _) =>
                              _buildCard(context, trades[active]),
                        ),
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

  /// Fades out the [child] of the previous trade, then fades this one in, so
  /// the two texts never overlap. At once with Reduce Motion.
  Widget _swap(
    BuildContext context,
    Object value,
    Alignment alignment,
    Widget child,
  ) {
    return AnimatedSwitcher(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : _swapDuration,
      switchInCurve: const Interval(0.5, 1),
      switchOutCurve: const Interval(0.5, 1),
      layoutBuilder: (current, previous) =>
          Stack(alignment: alignment, children: [...previous, ?current]),
      child: KeyedSubtree(key: ValueKey(value), child: child),
    );
  }

  Widget _buildCard(BuildContext context, _Trade trade) {
    final l10n = context.l10n;
    final text = AppColors.text.resolveFrom(context);
    final success = AppColors.success.resolveFrom(context);
    final lineStyle = AppTypography.bodyStrong.copyWith(
      color: text,
      height: 1.25,
    );
    final format = FormatService()..setLocale(l10n.localeName);

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
                          child: _swap(
                            context,
                            trade.slug,
                            Alignment.centerLeft,
                            Text(
                              '${l10n.loginSampleSaid} · ${trade.label}',
                              style: AppTypography.label.copyWith(
                                color: AppColors.textSecondary.resolveFrom(
                                  context,
                                ),
                              ),
                            ),
                          ),
                        ),
                        _buildVoiceBars(context),
                      ],
                    ),
                    const SizedBox(height: 2),
                    // At least two lines tall, so the card holds still between trades.
                    Stack(
                      children: [
                        Text('\n', style: lineStyle),
                        _swap(
                          context,
                          trade.slug,
                          Alignment.topLeft,
                          Text(trade.line, style: lineStyle),
                        ),
                      ],
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
                        _swap(
                          context,
                          trade.slug,
                          Alignment.centerRight,
                          Text(
                            format.formatCurrency(trade.total),
                            style: AppTypography.label.copyWith(
                              color: text,
                              fontWeight: FontWeight.w700,
                              fontFeatures: AppTypography.tabular,
                            ),
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
/// Motion they stand still and only the drag is left. [active] holds the trade
/// at the center of the reel, which starts on the first one.
class _TradeReel extends StatefulWidget {
  const _TradeReel({required this.trades, required this.active});

  final List<_Trade> trades;
  final ValueNotifier<int> active;

  @override
  State<_TradeReel> createState() => _TradeReelState();
}

class _TradeReelState extends State<_TradeReel>
    with SingleTickerProviderStateMixin {
  /// Points per second: the pace of the site's reels.
  static const _speed = 20.0;
  static const _gap = 10.0;
  static const _leftPadding = 20.0;
  static const _photoRatio = 800 / 993;

  /// The list starts one item early, so the first trade can open at the center.
  static const _firstTradeItem = 1;

  ScrollController? _controller;
  ScrollController get _scroll => _controller!;
  double _itemExtent = 0;
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
    _controller?.dispose();
    super.dispose();
  }

  /// Opens with the first trade centered, as the card opens with its order.
  ScrollController _controllerFor(double viewport) {
    final centered =
        _leftPadding +
        _firstTradeItem * _itemExtent +
        (_itemExtent - _gap) / 2 -
        viewport / 2;
    return ScrollController(initialScrollOffset: centered < 0 ? 0 : centered)
      ..addListener(_updateActive);
  }

  void _updateActive() {
    final center = _scroll.offset + _scroll.position.viewportDimension / 2;
    final item = ((center - _leftPadding) / _itemExtent).floor();
    widget.active.value = (item - _firstTradeItem) % widget.trades.length;
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
    if (_controller?.hasClients != true) return;
    // The finger wins while it drags or flings the reel.
    if (_scroll.position.isScrollingNotifier.value) return;
    _scroll.jumpTo(_scroll.offset + _speed * seconds);
  }

  void _togglePause() {
    _paused = !_paused;
    _syncTicker();
  }

  @override
  Widget build(BuildContext context) {
    final trades = widget.trades;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _togglePause,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxHeight * _photoRatio;
          _itemExtent = width + _gap;
          _controller ??= _controllerFor(constraints.maxWidth);
          return ListView.builder(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: _leftPadding),
            itemExtent: _itemExtent,
            itemBuilder: (context, index) {
              final trade = trades[(index - _firstTradeItem) % trades.length];
              return Padding(
                padding: const EdgeInsets.only(right: _gap),
                child: _buildPhoto(trade.slug, trade.label),
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
