import 'package:praticos/mobx/auth_store.dart';
import 'package:praticos/screens/email_login_screen.dart';
import 'package:praticos/theme/app_theme.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late AuthStore _auth;
  bool _isLoading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _auth = context.read<AuthStore>();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: isDark
            ? AppTheme.backgroundDark
            : AppTheme.backgroundColor,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                // Espaço flexível superior
                const Spacer(flex: 2),

                // Logo e título
                _buildHeader(isDark),

                const Spacer(flex: 3),

                // Botões de login
                _buildLoginButtons(isDark),

                const SizedBox(height: 32),

                // Termos e privacidade
                _buildTermsText(isDark),

                SizedBox(height: bottomPadding + 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo do app
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.2),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Image.asset(
              'assets/images/icon.png',
              fit: BoxFit.cover,
            ),
          ),
        ),

        const SizedBox(height: 32),

        // Título
        Text(
          context.l10n.welcomeToApp,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
            letterSpacing: -0.5,
          ),
        ),

        const SizedBox(height: 12),

        // Subtítulo
        Text(
          context.l10n.appSubtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w400,
            color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButtons(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Sign in with Apple (primário seguindo HIG)
        _buildAppleSignInButton(isDark),

        const SizedBox(height: 12),

        // Sign in with Google
        _buildGoogleSignInButton(isDark),

        const SizedBox(height: 24),

        // Link para login com email (para revisão da Apple)
        Semantics(
          identifier: 'email_login_link',
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => _navigateToEmailLogin(context),
            child: Text(
              context.l10n.signInWithEmail,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _navigateToEmailLogin(BuildContext context) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => const EmailLoginScreen(),
      ),
    );
  }

  Widget _buildAppleSignInButton(bool isDark) {
    // Seguindo Apple HIG: altura mínima 44pt, corner radius configurável
    return SizedBox(
      width: double.infinity,
      height: 50, // 44pt mínimo + padding
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleAppleSignIn,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? Colors.white : Colors.black,
          foregroundColor: isDark ? Colors.black : Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              FontAwesomeIcons.apple,
              size: 20,
              color: isDark ? Colors.black : Colors.white,
            ),
            const SizedBox(width: 12),
            Text(
              context.l10n.continueWithApple,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.black : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleSignInButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: _isLoading ? null : _handleGoogleSignIn,
        style: OutlinedButton.styleFrom(
          backgroundColor: isDark ? AppTheme.surfaceDark : Colors.white,
          side: BorderSide(
            color: isDark ? AppTheme.borderColorDark : AppTheme.borderColor,
            width: 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/google_logo.png',
              height: 20,
              width: 20,
            ),
            const SizedBox(width: 12),
            Text(
              context.l10n.continueWithGoogle,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermsText(bool isDark) {
    final textColor = isDark ? AppTheme.textTertiaryDark : AppTheme.textTertiary;
    final linkColor = isDark ? AppTheme.primaryLight : AppTheme.primaryColor;

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: TextStyle(
          fontSize: 13,
          color: textColor,
          height: 1.4,
        ),
        children: [
          TextSpan(text: '${context.l10n.byContinuingYouAgree}\n'),
          TextSpan(
            text: context.l10n.privacyPolicy,
            style: TextStyle(
              color: linkColor,
              decoration: TextDecoration.underline,
              decorationColor: linkColor,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () => _openPrivacyPolicy(),
          ),
        ],
      ),
    );
  }

  Future<void> _openPrivacyPolicy() async {
    final uri = Uri.parse('https://praticos.web.app/privacy.html');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _handleAppleSignIn() async {
    setState(() => _isLoading = true);
    try {
      await _auth.signInWithApple();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.l10n.errorSignInApple}: $e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      await _auth.signInWithGoogle();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.l10n.errorSignInGoogle}: $e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
