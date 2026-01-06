import 'package:flutter/cupertino.dart';
import 'package:praticos/mobx/auth_store.dart';

class EmailLoginScreen extends StatefulWidget {
  const EmailLoginScreen({super.key});

  @override
  State<EmailLoginScreen> createState() => _EmailLoginScreenState();
}

class _EmailLoginScreenState extends State<EmailLoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final AuthStore _auth = AuthStore();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

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
        _showError(_getErrorMessage(e.toString()));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getErrorMessage(String error) {
    if (error.contains('user-not-found')) {
      return 'Usuário não encontrado';
    } else if (error.contains('wrong-password')) {
      return 'Senha incorreta';
    } else if (error.contains('invalid-email')) {
      return 'Email inválido';
    } else if (error.contains('invalid-credential')) {
      return 'Credenciais inválidas';
    }
    return 'Erro ao entrar. Tente novamente.';
  }

  void _showError(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Erro'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Entrar com Email'),
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
                  'Digite seu email e senha para acessar sua conta',
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
                header: const Text('CREDENCIAIS'),
                children: [
                  Semantics(
                    identifier: 'email_field',
                    child: CupertinoTextFormFieldRow(
                      controller: _emailController,
                      prefix: const SizedBox(
                        width: 80,
                        child: Text('Email', style: TextStyle(fontSize: 16)),
                      ),
                      placeholder: 'seu@email.com',
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      textCapitalization: TextCapitalization.none,
                      textInputAction: TextInputAction.next,
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'Obrigatório';
                        }
                        if (!val.contains('@') || !val.contains('.')) {
                          return 'Email inválido';
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
                            prefix: const SizedBox(
                              width: 80,
                              child: Text('Senha', style: TextStyle(fontSize: 16)),
                            ),
                            placeholder: 'Digite sua senha',
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _handleSignIn(),
                            validator: (val) {
                              if (val == null || val.isEmpty) {
                                return 'Obrigatório';
                              }
                              if (val.length < 6) {
                                return 'Mínimo 6 caracteres';
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
                        : const Text(
                            'Entrar',
                            style: TextStyle(
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
                    'Esqueceu sua senha?',
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
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Recuperar Senha'),
        content: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: CupertinoTextField(
            controller: resetEmailController,
            placeholder: 'Digite seu email',
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textCapitalization: TextCapitalization.none,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Cancelar'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            child: const Text('Enviar'),
            onPressed: () async {
              final email = resetEmailController.text.trim();
              if (email.isEmpty || !email.contains('@')) {
                return;
              }
              Navigator.pop(context);
              try {
                await _auth.sendPasswordResetEmail(email);
                if (mounted) {
                  showCupertinoDialog(
                    context: context,
                    builder: (context) => CupertinoAlertDialog(
                      title: const Text('Email Enviado'),
                      content: const Text(
                        'Verifique sua caixa de entrada para redefinir sua senha.',
                      ),
                      actions: [
                        CupertinoDialogAction(
                          child: const Text('OK'),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  _showError('Erro ao enviar email de recuperação');
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
