import 'package:praticos/mobx/auth_store.dart';
import 'package:praticos/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final AuthStore _auth = AuthStore();
  bool _isLoading = false;

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
          'Bem-vindo ao PraticOS',
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
          'Gerencie suas ordens de serviço\nde forma simples e eficiente',
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
      ],
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
              'Continuar com Apple',
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
              'Continuar com Google',
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
    return Text(
      'Ao continuar, você concorda com nossos\nTermos de Uso e Política de Privacidade',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 13,
        color: isDark ? AppTheme.textTertiaryDark : AppTheme.textTertiary,
        height: 1.4,
      ),
    );
  }

  Future<void> _handleAppleSignIn() async {
    setState(() => _isLoading = true);
    try {
      await _auth.signInWithApple();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao entrar com Apple: $e'),
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
            content: Text('Erro ao entrar com Google: $e'),
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
