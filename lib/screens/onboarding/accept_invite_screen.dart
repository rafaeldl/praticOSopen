import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:praticos/models/invite.dart';
import 'package:praticos/models/permission.dart';
import 'package:praticos/models/user_role.dart';
import 'package:praticos/services/invite_api_service.dart';
import 'package:praticos/extensions/context_extensions.dart';

/// Tela para aceitar convite por código.
///
/// O usuário digita o código INV_XXXXXXXX e aceita o convite.
class AcceptInviteScreen extends StatefulWidget {
  final VoidCallback? onInviteAccepted;
  final VoidCallback? onCancel;

  const AcceptInviteScreen({
    super.key,
    this.onInviteAccepted,
    this.onCancel,
  });

  @override
  State<AcceptInviteScreen> createState() => _AcceptInviteScreenState();
}

class _AcceptInviteScreenState extends State<AcceptInviteScreen> {
  final TextEditingController _codeController = TextEditingController();

  bool _isLoading = false;
  bool _isAccepting = false;
  Invite? _invite;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  String _getRoleLabel(RolesType? role) {
    if (role == null) return context.l10n.roleTechnician;
    return RolePermissions.getRoleLabel(role, context.l10n);
  }

  Future<void> _searchInvite() async {
    final code = _codeController.text.trim().toUpperCase();

    if (code.isEmpty) {
      setState(() => _errorMessage = context.l10n.enterInviteCode);
      return;
    }

    // Normaliza o código (adiciona prefixo se não tiver)
    final normalizedCode = code.startsWith('INV_') ? code : 'INV_$code';

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _invite = null;
    });

    try {
      // Use API to get invite details (bypasses Firestore security rules)
      final invite = await InviteApiService.instance.getInviteByToken(normalizedCode);

      if (invite == null) {
        setState(() {
          _errorMessage = context.l10n.inviteNotFound;
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _invite = invite;
        _isLoading = false;
      });
    } on InviteApiException catch (e) {
      setState(() {
        // Map API error messages to localized strings when possible
        if (e.message.contains('expired')) {
          _errorMessage = context.l10n.inviteExpired;
        } else if (e.message.contains('already used') || e.message.contains('no longer valid')) {
          _errorMessage = context.l10n.inviteAlreadyUsed;
        } else {
          _errorMessage = e.message;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _acceptInvite() async {
    if (_invite == null) return;

    setState(() => _isAccepting = true);

    try {
      final result = await InviteApiService.instance.acceptInvite(_invite!.token!);

      // Wait for updateUserClaims trigger to execute
      // The backend updated the user's companies array, which triggers the Cloud Function
      // We need to wait a moment for the trigger to update the Auth claims
      await Future.delayed(const Duration(seconds: 2));

      // Force token refresh to get updated claims
      await FirebaseAuth.instance.currentUser?.getIdToken(true);

      if (mounted) {
        _showSuccessDialog(
          context.l10n.inviteAccepted,
          context.l10n.youAreNowPartOf(result.companyName),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isAccepting = false;
        });
      }
    }
  }

  void _showSuccessDialog(String title, String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: Text(context.l10n.ok),
            onPressed: () {
              Navigator.pop(context);
              widget.onInviteAccepted?.call();
            },
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
        middle: Text(context.l10n.acceptInvite),
        leading: widget.onCancel != null
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: widget.onCancel,
                child: Text(context.l10n.cancel),
              )
            : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 20),

                // Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: CupertinoColors.activeBlue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.ticket,
                    size: 40,
                    color: CupertinoColors.activeBlue,
                  ),
                ),

                const SizedBox(height: 24),

                // Title
                Text(
                  context.l10n.enterInviteCode,
                  style: CupertinoTheme.of(context).textTheme.navLargeTitleTextStyle,
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 12),

                // Subtitle
                Text(
                  context.l10n.enterCodeReceived,
                  style: TextStyle(
                    fontSize: 17,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 32),

                // Code input
                CupertinoTextField(
                  controller: _codeController,
                  placeholder: 'INV_XXXXXXXX',
                  textCapitalization: TextCapitalization.characters,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontFamily: 'Menlo',
                    letterSpacing: 2,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemBackground.resolveFrom(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSubmitted: (_) => _searchInvite(),
                ),

                const SizedBox(height: 16),

                // Error message
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: CupertinoColors.systemRed,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // Search button (if no invite found yet)
                if (_invite == null)
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton.filled(
                      onPressed: _isLoading ? null : _searchInvite,
                      child: _isLoading
                          ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                          : Text(context.l10n.search),
                    ),
                  ),

                // Invite details card
                if (_invite != null) ...[
                  _buildInviteCard(),

                  const SizedBox(height: 24),

                  // Accept button
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton.filled(
                      onPressed: _isAccepting ? null : _acceptInvite,
                      child: _isAccepting
                          ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                          : Text(context.l10n.acceptInvite),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Cancel/search another
                  CupertinoButton(
                    onPressed: () {
                      setState(() {
                        _invite = null;
                        _errorMessage = null;
                      });
                    },
                    child: Text(context.l10n.searchAnotherCode),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInviteCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Company info
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: CupertinoColors.activeBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    (_invite!.company?.name?.substring(0, 1).toUpperCase()) ?? 'E',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: CupertinoColors.activeBlue,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _invite!.company?.name ?? 'Empresa',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.label.resolveFrom(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.roleLabel(_getRoleLabel(_invite!.role)),
                      style: TextStyle(
                        fontSize: 14,
                        color: CupertinoColors.secondaryLabel.resolveFrom(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (_invite!.invitedBy?.name != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  CupertinoIcons.person,
                  size: 16,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
                const SizedBox(width: 8),
                Text(
                  context.l10n.invitedBy(_invite!.invitedBy!.name!),
                  style: TextStyle(
                    fontSize: 14,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
