import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:praticos/mobx/invite_store.dart';
import 'package:praticos/models/invite.dart';
import 'package:praticos/models/permission.dart';
import 'package:praticos/models/user_role.dart';
import 'package:praticos/extensions/context_extensions.dart';

/// Tela de convites pendentes.
///
/// Mostrada quando o usuário tem convites pendentes para entrar em empresas.
/// Permite aceitar ou rejeitar os convites.
class PendingInvitesScreen extends StatefulWidget {
  final VoidCallback? onCreateCompany;
  final VoidCallback? onInviteAccepted;

  const PendingInvitesScreen({
    super.key,
    this.onCreateCompany,
    this.onInviteAccepted,
  });

  @override
  State<PendingInvitesScreen> createState() => _PendingInvitesScreenState();
}

class _PendingInvitesScreenState extends State<PendingInvitesScreen> {
  final InviteStore _inviteStore = InviteStore.instance;

  @override
  void initState() {
    super.initState();
    _inviteStore.loadPendingInvites();
  }

  String _getRoleLabel(RolesType? role) {
    if (role == null) return context.l10n.roleTechnician;
    // Use RolePermissions helper instead of manual switch
    return RolePermissions.getRoleLabel(role, context.l10n);
  }

  Future<void> _acceptInvite(Invite invite) async {
    try {
      await _inviteStore.acceptInvite(invite);
      if (mounted) {
        _showSuccessDialog(
          'Convite Aceito',
          'Agora voce faz parte de ${invite.company?.name ?? "a empresa"}!',
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  Future<void> _rejectInvite(Invite invite) async {
    try {
      await _inviteStore.rejectInvite(invite);
    } catch (e) {
      if (mounted) {
        _showErrorDialog(e.toString().replaceAll('Exception: ', ''));
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
            child: const Text('OK'),
            onPressed: () {
              Navigator.pop(context);
              widget.onInviteAccepted?.call();
            },
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
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

  void _showRejectConfirmation(Invite invite) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Recusar Convite'),
        content: Text(
          'Tem certeza que deseja recusar o convite de ${invite.company?.name ?? "a empresa"}?',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              _rejectInvite(invite);
            },
            child: const Text('Recusar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: Observer(
            builder: (_) {
              if (_inviteStore.isLoading) {
                return const Center(child: CupertinoActivityIndicator());
              }

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: CupertinoColors.activeBlue.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              CupertinoIcons.envelope_badge_fill,
                              size: 40,
                              color: CupertinoColors.activeBlue,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Convites Pendentes',
                            style: CupertinoTheme.of(context)
                                .textTheme
                                .navLargeTitleTextStyle,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Voce foi convidado para fazer parte de empresas no praticOS!',
                            style: CupertinoTheme.of(context)
                                .textTheme
                                .textStyle
                                .copyWith(
                                  fontSize: 17,
                                  color: CupertinoColors.secondaryLabel,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                  if (_inviteStore.pendingInvites.isEmpty)
                    const SliverFillRemaining(
                      child: Center(
                        child: Text('Nenhum convite pendente'),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final invite = _inviteStore.pendingInvites[index];
                          return _buildInviteCard(invite);
                        },
                        childCount: _inviteStore.pendingInvites.length,
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 1,
                                  color: CupertinoColors.systemGrey5,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'ou',
                                  style: TextStyle(
                                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  height: 1,
                                  color: CupertinoColors.systemGrey5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: CupertinoButton(
                              color: CupertinoColors.systemGrey5,
                              onPressed: widget.onCreateCompany,
                              child: Text(
                                'Criar Minha Empresa',
                                style: TextStyle(
                                  color: CupertinoColors.label.resolveFrom(context),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildInviteCard(Invite invite) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                      (invite.company?.name?.substring(0, 1).toUpperCase()) ?? 'E',
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
                        invite.company?.name ?? 'Empresa',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.label.resolveFrom(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Cargo: ${_getRoleLabel(invite.role)}',
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
            if (invite.invitedBy?.name != null) ...[
              const SizedBox(height: 12),
              Text(
                'Convidado por ${invite.invitedBy!.name}',
                style: TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    color: CupertinoColors.systemGrey5,
                    onPressed: () => _showRejectConfirmation(invite),
                    child: Text(
                      'Recusar',
                      style: TextStyle(
                        color: CupertinoColors.label.resolveFrom(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CupertinoButton.filled(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    onPressed: () => _acceptInvite(invite),
                    child: const Text(
                      'Aceitar',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
