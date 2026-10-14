import 'package:flutter/cupertino.dart';
import 'package:praticos/screens/widgets/app_toast.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:praticos/mobx/invite_store.dart';
import 'package:praticos/models/invite.dart';
import 'package:praticos/models/permission.dart';
import 'package:praticos/models/user_role.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/screens/onboarding/accept_invite_screen.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/screens/widgets/glass_bar_button.dart';
import 'package:praticos/screens/widgets/list_states.dart';
import 'package:praticos/screens/widgets/primary_button.dart';
import 'package:praticos/screens/widgets/text_link.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';
import 'package:praticos/utils/invite_error.dart';

/// Tela de convites pendentes.
///
/// Mostrada quando o usuário tem convites pendentes para entrar em empresas.
/// Um único botão primário ("Entrar na equipe"); recusar é um link de texto
/// com confirmação. Com vários convites, tocar na linha abre o convite numa
/// tela própria, com o mesmo botão e link.
class PendingInvitesScreen extends StatefulWidget {
  final VoidCallback? onCreateCompany;
  final VoidCallback? onInviteAccepted;

  /// Tests pre-populate [InviteStore] and skip the Firestore load.
  final bool loadOnInit;

  /// Tests replace the accept call (the store talks to the API).
  final Future<void> Function(Invite invite)? acceptInviteOverride;

  const PendingInvitesScreen({
    super.key,
    this.onCreateCompany,
    this.onInviteAccepted,
    @visibleForTesting this.loadOnInit = true,
    @visibleForTesting this.acceptInviteOverride,
  });

  @override
  State<PendingInvitesScreen> createState() => _PendingInvitesScreenState();
}

class _PendingInvitesScreenState extends State<PendingInvitesScreen> {
  final InviteStore _inviteStore = InviteStore.instance;

  @override
  void initState() {
    super.initState();
    if (widget.loadOnInit) _inviteStore.loadPendingInvites();
  }

  String _getRoleLabel(RolesType? role) {
    if (role == null) return context.l10n.roleTechnician;
    // Use RolePermissions helper instead of manual switch
    return RolePermissions.getRoleLabel(role, context.l10n);
  }

  Future<void> _acceptInvite(Invite invite) async {
    try {
      final accept = widget.acceptInviteOverride ?? _inviteStore.acceptInvite;
      await accept(invite);
      if (mounted) {
        showAppToast(
          context,
          context.l10n.youAreNowPartOf(invite.company?.name ?? ''),
        );
        widget.onInviteAccepted?.call();
      }
    } catch (e) {
      debugPrint('[PendingInvites] accept failed: $e');
      if (mounted) {
        _showErrorDialog(friendlyInviteError(e, context.l10n));
      }
    }
  }

  Future<void> _rejectInvite(Invite invite) async {
    try {
      await _inviteStore.rejectInvite(invite);
    } catch (e) {
      debugPrint('[PendingInvites] reject failed: $e');
      if (mounted) {
        _showErrorDialog(friendlyInviteError(e, context.l10n));
      }
    }
  }

  void _showErrorDialog(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(context.l10n.error),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: Text(context.l10n.ok),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _openAcceptInviteScreen() {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => AcceptInviteScreen(
          onInviteAccepted: () {
            Navigator.pop(context); // Fecha a tela de código
            widget.onInviteAccepted?.call();
          },
          onCancel: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _showRejectConfirmation(Invite invite, {VoidCallback? onRejected}) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(context.l10n.inviteDecline),
        content: Text(
          context.l10n.areYouSureReject(invite.company?.name ?? ''),
        ),
        actions: [
          CupertinoDialogAction(
            child: Text(context.l10n.back),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              onRejected?.call();
              _rejectInvite(invite);
            },
            child: Text(context.l10n.reject),
          ),
        ],
      ),
    );
  }

  /// With several invites, tapping a row opens that invite on its own
  /// screen (same layout as a single invite), never an action sheet.
  void _openInvite(Invite invite) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (detailContext) => _InviteDetailScreen(
          invite: invite,
          subtitle: _subtitle(invite),
          onJoin: () => _acceptInvite(invite),
          onDecline: () => _showRejectConfirmation(
            invite,
            onRejected: () => Navigator.of(detailContext).pop(),
          ),
        ),
      ),
    );
  }

  String _subtitle(Invite invite) {
    final role = _getRoleLabel(invite.role);
    final name = invite.invitedBy?.name;
    return name == null
        ? context.l10n.inviteEntersAs(role)
        : context.l10n.inviteInvitedByAs(name, role);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background.resolveFrom(context),
      child: SafeArea(
        child: Observer(
          builder: (_) {
            if (_inviteStore.isLoading) {
              return const LoadingState();
            }
            if (_inviteStore.errorMessage != null &&
                _inviteStore.pendingInvites.isEmpty) {
              return ErrorState(
                message: context.l10n.inviteLoadError,
                onRetry: _inviteStore.loadPendingInvites,
              );
            }

            final invites = _inviteStore.pendingInvites.toList();
            final single = invites.length == 1 ? invites.first : null;

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageMargin,
                AppSpacing.xxl,
                AppSpacing.pageMargin,
                AppSpacing.xl,
              ),
              children: [
                Text(
                  single != null
                      ? context.l10n.inviteTitleOne(single.company?.name ?? '')
                      : context.l10n.inviteTitleMany,
                  style: AppTypography.title.copyWith(
                    color: AppColors.text.resolveFrom(context),
                  ),
                ),
                if (invites.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text(
                      context.l10n.inviteManyHint,
                      style: AppTypography.callout.copyWith(
                        color: AppColors.textSecondary.resolveFrom(context),
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
                if (invites.isEmpty)
                  Text(
                    context.l10n.noPendingInvites,
                    style: AppTypography.callout.copyWith(
                      color: AppColors.textSecondary.resolveFrom(context),
                    ),
                  ),
                if (single != null) ...[
                  AppListRow(
                    title: single.company?.name ?? '',
                    subtitle: _subtitle(single),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  PrimaryButton(
                    label: context.l10n.inviteJoinTeam,
                    onPressed: () => _acceptInvite(single),
                  ),
                  Center(
                    child: TextLink(
                      label: context.l10n.inviteDecline,
                      onPressed: () => _showRejectConfirmation(single),
                    ),
                  ),
                ] else
                  for (final invite in invites)
                    AppListRow(
                      title: invite.company?.name ?? '',
                      subtitle: _subtitle(invite),
                      onTap: () => _openInvite(invite),
                    ),
                const SizedBox(height: AppSpacing.lg),
                Center(
                  child: TextLink(
                    label: context.l10n.inviteHaveAnotherCode,
                    onPressed: _openAcceptInviteScreen,
                  ),
                ),
                if (widget.onCreateCompany != null)
                  Center(
                    child: TextLink(
                      label: context.l10n.inviteCreateOwnCompany,
                      onPressed: widget.onCreateCompany,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// One invite among several: who invited, the single blue "Entrar na equipe"
/// and the "Recusar convite" link.
class _InviteDetailScreen extends StatelessWidget {
  const _InviteDetailScreen({
    required this.invite,
    required this.subtitle,
    required this.onJoin,
    required this.onDecline,
  });

  final Invite invite;
  final String subtitle;
  final VoidCallback onJoin;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final company = invite.company?.name ?? '';
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background.resolveFrom(context),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageMargin,
            0,
            AppSpacing.pageMargin,
            AppSpacing.xl,
          ),
          children: [
            const Align(
              alignment: AlignmentDirectional.centerStart,
              child: GlassBackButton(),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Same layout as a single invite.
            Text(
              context.l10n.inviteTitleOne(company),
              style: AppTypography.title.copyWith(
                color: AppColors.text.resolveFrom(context),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppListRow(title: company, subtitle: subtitle),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              key: const ValueKey('invite_detail_join'),
              label: context.l10n.inviteJoinTeam,
              onPressed: onJoin,
            ),
            Center(
              child: TextLink(
                key: const ValueKey('invite_detail_decline'),
                label: context.l10n.inviteDecline,
                onPressed: onDecline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
