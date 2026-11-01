import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/mobx/auth_store.dart';
import 'package:praticos/screens/email_login_screen.dart';
import 'package:praticos/screens/widgets/login_sample_order.dart';
import 'package:praticos/screens/widgets/text_link.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_typography.dart';
import 'package:provider/provider.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:url_launcher/url_launcher.dart';

/// Login screen: brand-blue "order form" background with ruler lines, the app
/// icon, a phrase saying what the app does and a sample service order on top,
/// and a rounded panel at the bottom with the native Apple button, the Google
/// button and the e-mail link.
///
/// UI only: authentication goes through [AuthStore] untouched.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late AuthStore _auth;
  bool _isLoading = false;
  String? _error;

  static const _buttonHeight = 58.0;
  static const _buttonRadius = BorderRadius.all(Radius.circular(14));
  static const _heroMaxWidth = 480.0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _auth = context.read<AuthStore>();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final background = (isDark ? AppColors.accentSoft : AppColors.accent)
        .resolveFrom(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: CupertinoPageScaffold(
        backgroundColor: background,
        child: DefaultTextStyle(
          style: CupertinoTheme.of(context).textTheme.textStyle,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: FormRulerPainter(
                    color: (isDark ? AppColors.accentText : AppColors.onAccent)
                        .resolveFrom(context)
                        .withValues(alpha: isDark ? 0.12 : 0.08),
                  ),
                ),
              ),
              SafeArea(
                bottom: false,
                child: CustomScrollView(
                  slivers: [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Column(
                        children: [
                          Expanded(
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: _heroMaxWidth,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _buildHeader(context),
                                    const Expanded(child: _SampleOrderArea()),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          _buildPanel(context),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            label: 'PraticOS',
            image: true,
            child: ExcludeSemantics(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Image.asset(
                  'assets/images/icon.png',
                  width: 54,
                  height: 54,
                  cacheWidth: 162,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.loginTitle,
            style: AppTypography.title.copyWith(
              color: AppColors.onAccent.resolveFrom(context),
              height: 1.14,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanel(BuildContext context) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Container(
      key: const Key('login_panel'),
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, 28, 24, bottom + 16),
      decoration: BoxDecoration(
        color: AppColors.surface.resolveFrom(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            _buildError(context, _error!),
            const SizedBox(height: 12),
          ],
          Semantics(
            identifier: 'apple_login_button',
            child: SignInWithAppleButton(
              text: context.l10n.continueWithApple,
              height: _buttonHeight,
              borderRadius: _buttonRadius,
              style: isDark
                  ? SignInWithAppleButtonStyle.white
                  : SignInWithAppleButtonStyle.black,
              onPressed: _isLoading ? () {} : _handleAppleSignIn,
            ),
          ),
          const SizedBox(height: 12),
          _buildGoogleButton(context),
          const SizedBox(height: 4),
          Semantics(
            identifier: 'email_login_link',
            child: Center(
              child: TextLink(
                key: const Key('login_email_link'),
                label: context.l10n.loginWithEmailLink,
                onPressed: _isLoading ? null : _navigateToEmailLogin,
              ),
            ),
          ),
          const SizedBox(height: 4),
          _buildTerms(context),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, String message) {
    final danger = AppColors.danger.resolveFrom(context);
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(CupertinoIcons.exclamationmark_circle, size: 20, color: danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              key: const Key('login_error'),
              style: AppTypography.label.copyWith(color: danger),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleButton(BuildContext context) {
    return Semantics(
      identifier: 'google_login_button',
      button: true,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size.fromHeight(_buttonHeight),
        color: AppColors.secondaryFill.resolveFrom(context),
        borderRadius: _buttonRadius,
        onPressed: _isLoading ? null : _handleGoogleSignIn,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/google_logo.png', height: 22, width: 22),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                context.l10n.continueWithGoogle,
                style: AppTypography.bodyStrong.copyWith(
                  color: AppColors.onSecondaryFill.resolveFrom(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTerms(BuildContext context) {
    final linkColor = AppColors.accentText.resolveFrom(context);
    return Text.rich(
      TextSpan(
        style: AppTypography.label.copyWith(
          color: AppColors.textSecondary.resolveFrom(context),
        ),
        children: [
          TextSpan(text: '${context.l10n.byContinuingYouAgree} '),
          TextSpan(
            text: context.l10n.privacyPolicy,
            style: TextStyle(
              color: linkColor,
              decoration: TextDecoration.underline,
              decorationColor: linkColor,
            ),
            recognizer: TapGestureRecognizer()..onTap = _openPrivacyPolicy,
          ),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }

  void _navigateToEmailLogin() {
    Navigator.of(context).push(
      CupertinoPageRoute(builder: (context) => const EmailLoginScreen()),
    );
  }

  Future<void> _openPrivacyPolicy() async {
    final uri = Uri.parse('https://praticos.web.app/privacy.html');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// True when the user just closed the provider sheet: not an error.
  bool _isCancellation(Object e) {
    if (e is SignInWithAppleAuthorizationException &&
        e.code == AuthorizationErrorCode.canceled) {
      return true;
    }
    final text = e.toString().toLowerCase();
    return text.contains('cancel') || text.contains('popup-closed');
  }

  Future<void> _signIn(
    Future<dynamic> Function() action,
    String friendlyError,
  ) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      debugPrint('Sign-in failed: $e');
      if (mounted && !_isCancellation(e)) {
        setState(() => _error = friendlyError);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleAppleSignIn() =>
      _signIn(_auth.signInWithApple, context.l10n.errorSignInAppleFriendly);

  Future<void> _handleGoogleSignIn() async => _signIn(
        () async => _auth.signInWithGoogle(),
        context.l10n.errorSignInGoogleFriendly,
      );
}

/// Takes what is left between the header and the panel.
///
/// The order goes in a [Positioned] so it never adds to the scroll height: on
/// short screens or with large text the buttons push it away instead.
class _SampleOrderArea extends StatelessWidget {
  const _SampleOrderArea();

  @override
  Widget build(BuildContext context) {
    return const ClipRect(
      child: Stack(
        children: [
          SizedBox.expand(),
          Positioned.fill(child: LoginSampleOrder()),
        ],
      ),
    );
  }
}

/// Draws subtle horizontal rules, like the lines of a service-order form.
class FormRulerPainter extends CustomPainter {
  const FormRulerPainter({required this.color, this.spacing = 36});

  final Color color;
  final double spacing;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (double y = spacing; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(FormRulerPainter old) =>
      old.color != color || old.spacing != spacing;
}
