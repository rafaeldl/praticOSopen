import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:praticos/mobx/auth_store.dart';
import 'package:praticos/extensions/context_extensions.dart';

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
  bool _obscurePassword = true;

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
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() => _isLoading = true);
    try {
      await _auth.signInWithEmailPassword(email, password);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        _showError(context, _getErrorMessage(context, e.toString()));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getErrorMessage(BuildContext context, String error) {
    if (error.contains('user-not-found')) {
      return context.l10n.userNotFound;
    } else if (error.contains('wrong-password')) {
      return context.l10n.wrongPassword;
    } else if (error.contains('invalid-email')) {
      return context.l10n.invalidEmail;
    } else if (error.contains('invalid-credential')) {
      return context.l10n.invalidCredentials;
    }
    return context.l10n.errorSignIn;
  }

  void _showError(BuildContext context, String message) {
    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(context.l10n.error),
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

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text(context.l10n.signInWithEmail),
      ),
      child: SafeArea(
        child: DefaultTextStyle(
          style: CupertinoTheme.of(context).textTheme.textStyle,
          child: Form(
            key: _formKey,
            child: ListView(
            children: [
              const SizedBox(height: 20),

              // Header Icon
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey5.resolveFrom(context),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    CupertinoIcons.mail,
                    size: 40,
                    color: CupertinoColors.activeBlue.resolveFrom(context),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Description text
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  context.l10n.enterEmailPassword,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Form Fields
              CupertinoListSection.insetGrouped(
                header: Text(context.l10n.credentials.toUpperCase()),
                children: [
                  Semantics(
                    identifier: 'email_field',
                    child: CupertinoTextFormFieldRow(
                      controller: _emailController,
                      prefix: SizedBox(
                        width: 80,
                        child: Text(context.l10n.email, style: const TextStyle(fontSize: 16)),
                      ),
                      placeholder: context.l10n.emailPlaceholder,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      textCapitalization: TextCapitalization.none,
                      textInputAction: TextInputAction.next,
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return context.l10n.requiredField;
                        }
                        if (!val.contains('@') || !val.contains('.')) {
                          return context.l10n.invalidEmail;
                        }
                        return null;
                      },
                    ),
                  ),
                  Semantics(
                    identifier: 'password_field',
                    child: Row(
                      children: [
                        Expanded(
                          child: CupertinoTextFormFieldRow(
                            controller: _passwordController,
                            prefix: SizedBox(
                              width: 80,
                              child: Text(context.l10n.password, style: const TextStyle(fontSize: 16)),
                            ),
                            placeholder: context.l10n.enterYourPassword,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _handleSignIn(),
                            validator: (val) {
                              if (val == null || val.isEmpty) {
                                return context.l10n.requiredField;
                              }
                              if (val.length < 6) {
                                return context.l10n.minLength(6);
                              }
                              return null;
                            },
                          ),
                        ),
                        CupertinoButton(
                          padding: const EdgeInsets.only(right: 8),
                          onPressed: () {
                            setState(() => _obscurePassword = !_obscurePassword);
                          },
                          child: Icon(
                            _obscurePassword
                                ? CupertinoIcons.eye
                                : CupertinoIcons.eye_slash,
                            size: 22,
                            color: CupertinoColors.secondaryLabel.resolveFrom(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Sign In Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Semantics(
                  identifier: 'email_login_button',
                  child: CupertinoButton.filled(
                    onPressed: _isLoading ? null : _handleSignIn,
                    child: _isLoading
                        ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                        : Text(
                            context.l10n.login,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Forgot password link
              Center(
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => _showForgotPasswordDialog(),
                  child: Text(
                    '${context.l10n.forgotPassword}?',
                    style: TextStyle(
                      fontSize: 15,
                      color: CupertinoColors.activeBlue.resolveFrom(context),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
          ),
        ),
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController(text: _emailController.text);

    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(context.l10n.resetPassword),
        content: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: CupertinoTextField(
            controller: resetEmailController,
            placeholder: context.l10n.enterYourEmail,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textCapitalization: TextCapitalization.none,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: Text(context.l10n.cancel),
            onPressed: () => Navigator.pop(dialogContext),
          ),
          CupertinoDialogAction(
            child: Text(context.l10n.send),
            onPressed: () async {
              final email = resetEmailController.text.trim();
              if (email.isEmpty || !email.contains('@')) {
                return;
              }
              Navigator.pop(dialogContext);
              try {
                await _auth.sendPasswordResetEmail(email);
                if (mounted) {
                  showCupertinoDialog(
                    context: context,
                    builder: (successContext) => CupertinoAlertDialog(
                      title: Text(context.l10n.emailSent),
                      content: Text(context.l10n.checkInboxResetPassword),
                      actions: [
                        CupertinoDialogAction(
                          child: Text(context.l10n.ok),
                          onPressed: () => Navigator.pop(successContext),
                        ),
                      ],
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  _showError(context, context.l10n.errorSendingRecoveryEmail);
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
