import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/services/account_deletion_api_service.dart';
import 'package:praticos/services/subscription_service.dart';
import 'package:praticos/utils/store_subscription.dart';

/// "Apagar minha conta" (App Store guideline 5.1.1(v)): two confirmations,
/// a warning about the store subscription and re-authentication when Firebase
/// asks for a recent login.
///
/// The deletion itself stays in `AuthStore.deleteAccount` (callbacks injected
/// so the flow is testable); this class only drives the dialogs.
class AccountDeletionFlow {
  AccountDeletionFlow({
    required this.deleteAccount,
    required this.reauthenticate,
    this.needsPassword,
    this.reauthenticateWithPassword,
    bool? paidPlansEnabled,
    Future<void> Function()? openStoreSettings,
  })  : paidPlansEnabled =
            paidPlansEnabled ?? SubscriptionService.paidPlansEnabled,
        openStoreSettings = openStoreSettings ?? openStoreSubscriptionSettings;

  final Future<void> Function() deleteAccount;
  final Future<void> Function() reauthenticate;

  /// True for e-mail accounts: the flow asks for the password and calls
  /// [reauthenticateWithPassword] instead of [reauthenticate].
  final bool Function()? needsPassword;
  final Future<void> Function(String password)? reauthenticateWithPassword;
  final bool paidPlansEnabled;
  final Future<void> Function() openStoreSettings;

  /// First confirmation. Call from the "Apagar minha conta" row.
  void start(BuildContext context) {
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(dialogContext.l10n.deleteMyAccount),
        content: Text(
          deleteAccountDialogMessage(
            dialogContext.l10n,
            paidPlansEnabled: paidPlansEnabled,
          ),
        ),
        actions: [
          if (paidPlansEnabled)
            CupertinoDialogAction(
              child: Text(dialogContext.l10n.manageInStore),
              onPressed: () {
                Navigator.pop(dialogContext);
                openStoreSettings();
              },
            ),
          CupertinoDialogAction(
            child: Text(dialogContext.l10n.cancel),
            onPressed: () => Navigator.pop(dialogContext),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(dialogContext);
              _confirmFinal(context);
            },
            child: Text(dialogContext.l10n.continue_),
          ),
        ],
      ),
    );
  }

  void _confirmFinal(BuildContext context) {
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(dialogContext.l10n.finalConfirmation),
        content: Text(dialogContext.l10n.lastChanceCancel),
        actions: [
          CupertinoDialogAction(
            child: Text(dialogContext.l10n.cancel),
            onPressed: () => Navigator.pop(dialogContext),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(dialogContext);
              _delete(context);
            },
            child: Text(dialogContext.l10n.permanentlyDelete),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final navigator = _showLoading(context);
    try {
      await deleteAccount();
      _closeLoading(navigator);
      // The auth state change sends the user back to the login screen.
    } catch (e) {
      _closeLoading(navigator);
      if (!context.mounted) return;
      if (e.toString().contains('REQUIRES_RECENT_LOGIN')) {
        _askReauthentication(context);
        return;
      }
      _showMessage(
        context,
        title: context.l10n.errorDeletingAccount,
        message: '${context.l10n.couldNotDeleteAccount}\n\n'
            '${formatError(context, e.toString())}',
      );
    }
  }

  void _askReauthentication(BuildContext context) {
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(dialogContext.l10n.reauthenticationRequired),
        content: Text(dialogContext.l10n.pleaseSignInAgainToDelete),
        actions: [
          CupertinoDialogAction(
            child: Text(dialogContext.l10n.cancel),
            onPressed: () => Navigator.pop(dialogContext),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(dialogContext);
              _reauthenticate(context);
            },
            child: Text(dialogContext.l10n.signInAgain),
          ),
        ],
      ),
    );
  }

  Future<void> _reauthenticate(BuildContext context) async {
    String? password;
    if (needsPassword?.call() ?? false) {
      password = await showCupertinoDialog<String>(
        context: context,
        builder: (_) => const _PasswordDialog(),
      );
      if (password == null || !context.mounted) return;
    }

    final navigator = _showLoading(context);
    try {
      if (password == null) {
        await reauthenticate();
      } else {
        await reauthenticateWithPassword!(password);
      }
      _closeLoading(navigator);
      if (context.mounted) _confirmFinal(context);
    } catch (e) {
      _closeLoading(navigator);
      if (!context.mounted) return;
      _showMessage(
        context,
        title: context.l10n.reauthenticationFailed,
        message: '${context.l10n.couldNotReauthenticate}\n\n'
            '${formatError(context, e.toString())}',
      );
    }
  }

  /// Returns the navigator holding the spinner, the one to close it on: the
  /// dialog goes on the root navigator, and this screen sits on a tab's.
  NavigatorState _showLoading(BuildContext context) {
    final navigator = Navigator.of(context, rootNavigator: true);
    showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CupertinoActivityIndicator(radius: 20)),
    );
    return navigator;
  }

  void _closeLoading(NavigatorState navigator) {
    try {
      navigator.pop();
    } catch (_) {
      // The widget may be gone already; nothing to close.
    }
  }

  void _showMessage(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: Text(dialogContext.l10n.ok),
            onPressed: () => Navigator.pop(dialogContext),
          ),
        ],
      ),
    );
  }

  /// Turns raw errors into a short user-facing sentence.
  @visibleForTesting
  static String formatError(BuildContext context, String error) {
    if (error.contains('proprietário de uma empresa com outros membros') ||
        error.contains('Fale com o suporte')) {
      return error.replaceAll('Exception: ', '');
    }
    if (error.contains(AccountDeletionApiService.timeoutCode)) {
      return context.l10n.accountDeletionTakingLong;
    }
    if (error.contains('requires-recent-login')) {
      return context.l10n.requiresRecentLogin;
    }
    if (error.contains('permission-denied')) {
      return context.l10n.noPermissionDelete;
    }
    if (error.contains('invalid-credential') ||
        error.contains('wrong-password')) {
      return context.l10n.emailLoginWrongCredentials;
    }
    if (error.contains('too-many-requests')) {
      return context.l10n.emailLoginTooManyAttempts;
    }
    if (error.contains('network')) {
      return context.l10n.networkError;
    }
    return '${context.l10n.error}: ${error.replaceAll('[firebase_auth/', '').replaceAll('Exception: ', '').replaceAll(']', '')}';
  }
}

/// Asks the password of an e-mail account; pops with it, or null on cancel.
class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_controller.text.isEmpty) return;
    Navigator.pop(context, _controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return CupertinoAlertDialog(
      title: Text(l10n.reauthenticationRequired),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.emailLoginPasswordRequired),
          const SizedBox(height: 12),
          CupertinoTextField(
            key: const ValueKey('account_deletion_password'),
            controller: _controller,
            placeholder: l10n.password,
            obscureText: true,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        CupertinoDialogAction(
          child: Text(l10n.cancel),
          onPressed: () => Navigator.pop(context),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: _submit,
          child: Text(l10n.signInAgain),
        ),
      ],
    );
  }
}
