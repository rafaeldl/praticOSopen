import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:praticos/mobx/auth_store.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/screens/widgets/app_form_field.dart';
import 'package:praticos/screens/widgets/glass_bar_button.dart';
import 'package:praticos/screens/widgets/primary_button.dart';
import 'package:praticos/screens/widgets/text_link.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';

/// "Entrar com e-mail": rare path (App Review, old accounts). Glass back,
/// e-mail and password fields, one blue "Entrar" and the "Esqueceu a senha?"
/// link. A failed sign-in shows a fixed sentence above the button (never the
/// exception) and keeps the form, so the user can fix it or reset the
/// password.
///
/// UI only: authentication goes through [AuthStore] untouched.
class EmailLoginScreen extends StatefulWidget {
  const EmailLoginScreen({super.key});

  @override
  State<EmailLoginScreen> createState() => _EmailLoginScreenState();
}

class _EmailLoginScreenState extends State<EmailLoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late AuthStore _auth;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _auth = context.read<AuthStore>();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await _auth.signInWithEmailPassword(email, password);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint('Email sign-in failed: $e');
      if (mounted) {
        setState(() => _error = emailLoginErrorMessage(context, e));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background.resolveFrom(context),
      child: Form(
        key: _formKey,
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            AppNavBar(largeTitle: Text(l10n.emailLoginTitle)),
            SliverSafeArea(
              top: false,
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      identifier: 'email_field',
                      child: AppFormField(
                        key: const ValueKey('email_login_email'),
                        label: l10n.email,
                        controller: _emailController,
                        placeholder: l10n.emailPlaceholder,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: (val) {
                          final text = val.trim();
                          if (text.isEmpty) {
                            return l10n.emailLoginEmailRequired;
                          }
                          if (!text.contains('@') || !text.contains('.')) {
                            return l10n.emailLoginEmailInvalid;
                          }
                          return null;
                        },
                      ),
                    ),
                    Semantics(
                      identifier: 'password_field',
                      child: _PasswordField(
                        key: const ValueKey('email_login_password'),
                        controller: _passwordController,
                        onSubmitted: _handleSignIn,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.pageMargin,
                          0,
                          AppSpacing.pageMargin,
                          AppSpacing.lg,
                        ),
                        child: _ErrorLine(message: _error!),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.blockMargin,
                      ),
                      child: Semantics(
                        identifier: 'email_login_button',
                        child: PrimaryButton(
                          key: const ValueKey('email_login_submit'),
                          label: _isLoading
                              ? l10n.emailLoginSigningIn
                              : l10n.login,
                          onPressed: _isLoading ? null : _handleSignIn,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Center(
                      child: TextLink(
                        key: const ValueKey('email_login_forgot'),
                        label: l10n.forgotPasswordQuestion,
                        onPressed:
                            _isLoading ? null : _showForgotPasswordDialog,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final l10n = context.l10n;
    final resetEmailController =
        TextEditingController(text: _emailController.text.trim());

    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(l10n.resetPasswordTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.resetPasswordMessage),
            const SizedBox(height: AppSpacing.md),
            CupertinoTextField(
              controller: resetEmailController,
              placeholder: l10n.emailPlaceholder,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textCapitalization: TextCapitalization.none,
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            child: Text(l10n.cancel),
            onPressed: () => Navigator.pop(dialogContext),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: Text(l10n.send),
            onPressed: () async {
              final email = resetEmailController.text.trim();
              if (email.isEmpty || !email.contains('@')) {
                return;
              }
              Navigator.pop(dialogContext);
              try {
                await _auth.sendPasswordResetEmail(email);
                if (mounted) {
                  _showMessage(l10n.emailSent, l10n.checkInboxResetPassword);
                }
              } catch (e) {
                debugPrint('Password reset failed: $e');
                if (mounted) {
                  _showMessage(null, l10n.resetPasswordError);
                }
              }
            },
          ),
        ],
      ),
    );
  }

  void _showMessage(String? title, String message) {
    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: title == null ? null : Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: Text(context.l10n.ok),
            onPressed: () => Navigator.pop(dialogContext),
          ),
        ],
      ),
    );
  }
}

/// Fixed sentence for a failed e-mail sign-in, from the Firebase error code.
/// Wrong e-mail, wrong password and unknown user share one sentence (plain
/// language, and it does not tell whether an account exists).
@visibleForTesting
String emailLoginErrorMessage(BuildContext context, Object error) {
  final l10n = context.l10n;
  final code = error.toString();
  if (code.contains('user-not-found') ||
      code.contains('wrong-password') ||
      code.contains('invalid-credential')) {
    return l10n.emailLoginWrongCredentials;
  }
  if (code.contains('invalid-email')) return l10n.emailLoginEmailInvalid;
  if (code.contains('too-many-requests')) return l10n.emailLoginTooManyAttempts;
  if (code.contains('network-request-failed')) return l10n.emailLoginNoInternet;
  return l10n.emailLoginGenericError;
}

/// Error line above the button: icon + text in `danger`, announced by
/// screen readers.
class _ErrorLine extends StatelessWidget {
  const _ErrorLine({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final danger = AppColors.danger.resolveFrom(context);
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(CupertinoIcons.exclamationmark_circle, size: 20, color: danger),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              key: const Key('email_login_error'),
              style: AppTypography.label.copyWith(color: danger),
            ),
          ),
        ],
      ),
    );
  }
}

/// Password field in the [AppFormField] style (label above, `secondaryFill`
/// field, error below) with a 44pt show/hide button that has a spoken label.
class _PasswordField extends StatefulWidget {
  const _PasswordField({
    super.key,
    required this.controller,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final VoidCallback onSubmitted;

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = AppColors.text.resolveFrom(context);
    final secondary = AppColors.textSecondary.resolveFrom(context);
    final danger = AppColors.danger.resolveFrom(context);

    return FormField<String>(
      validator: (_) => widget.controller.text.isEmpty
          ? l10n.emailLoginPasswordRequired
          : null,
      builder: (state) {
        final error = state.errorText;
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pageMargin,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text(
                  l10n.password,
                  style: AppTypography.label.copyWith(color: secondary),
                ),
              ),
              CupertinoTextField(
                controller: widget.controller,
                obscureText: _obscure,
                autocorrect: false,
                enableSuggestions: false,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                style: AppTypography.body.copyWith(color: text),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md + 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.secondaryFill.resolveFrom(context),
                  borderRadius: BorderRadius.circular(AppRadii.field),
                  border: error == null
                      ? null
                      : Border.all(color: danger, width: 1.5),
                ),
                suffix: Semantics(
                  // Own node: VoiceOver reaches the eye apart from the field.
                  container: true,
                  button: true,
                  label: _obscure ? l10n.showPassword : l10n.hidePassword,
                  excludeSemantics: true,
                  child: CupertinoButton(
                    key: const ValueKey('email_login_toggle_password'),
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(
                      AppSizes.minTouchTarget,
                      AppSizes.minTouchTarget,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                    child: Icon(
                      _obscure ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
                      size: 22,
                      color: secondary,
                    ),
                  ),
                ),
                onChanged: (value) {
                  state.didChange(value);
                  if (state.hasError) state.validate();
                },
                onSubmitted: (_) => widget.onSubmitted(),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    error,
                    style: AppTypography.label.copyWith(color: danger),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
