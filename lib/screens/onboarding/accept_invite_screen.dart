import 'package:flutter/cupertino.dart';
import 'package:praticos/models/invite.dart';
import 'package:praticos/models/permission.dart';
import 'package:praticos/models/user_role.dart';
import 'package:praticos/services/claims_service.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/services/invite_api_service.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/screens/widgets/glass_bar_button.dart';
import 'package:praticos/screens/widgets/primary_button.dart';
import 'package:praticos/screens/widgets/text_link.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';
import 'package:praticos/utils/invite_error.dart';

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
    } catch (e) {
      debugPrint('[AcceptInvite] search failed: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = friendlyInviteError(e, context.l10n);
        _isLoading = false;
      });
    }
  }

  Future<void> _acceptInvite() async {
    if (_invite == null) return;

    setState(() => _isAccepting = true);

    try {
      final result = await InviteApiService.instance.acceptInvite(_invite!.token!);

      // Wait for Cloud Function to update custom claims (polls until ready)
      await ClaimsService.instance.waitForCompanyClaim(result.companyId);

      if (mounted) {
        _showSuccessDialog(
          context.l10n.inviteAccepted,
          context.l10n.youAreNowPartOf(result.companyName),
        );
      }
    } catch (e) {
      debugPrint('[AcceptInvite] accept failed: $e');
      if (mounted) {
        setState(() {
          _errorMessage = friendlyInviteError(e, context.l10n);
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
    final textColor = AppColors.text.resolveFrom(context);
    final secondary = AppColors.textSecondary.resolveFrom(context);
    final danger = AppColors.danger.resolveFrom(context);

    final canGoBack = widget.onCancel != null || Navigator.canPop(context);

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background.resolveFrom(context),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageMargin,
            0,
            AppSpacing.pageMargin,
            AppSpacing.pageMargin,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (canGoBack)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: GlassBackButton(
                    key: const ValueKey('invite_code_back'),
                    onPressed: widget.onCancel,
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                context.l10n.inviteCodeTitle,
                style: AppTypography.title.copyWith(color: textColor),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                context.l10n.enterCodeReceived,
                style: AppTypography.callout.copyWith(color: secondary),
              ),
              const SizedBox(height: AppSpacing.xl),
              CupertinoTextField(
                key: const Key('invite_code_field'),
                controller: _codeController,
                placeholder: context.l10n.inviteCodePlaceholder,
                textCapitalization: TextCapitalization.characters,
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(
                  color: textColor,
                  fontFamily: 'Menlo',
                  letterSpacing: 2,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.lg,
                ),
                decoration: BoxDecoration(
                  color: AppColors.secondaryFill.resolveFrom(context),
                  borderRadius: BorderRadius.circular(AppRadii.field),
                ),
                onSubmitted: (_) => _searchInvite(),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                  child: Semantics(
                    liveRegion: true,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          CupertinoIcons.exclamationmark_circle,
                          size: 20,
                          color: danger,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            key: const Key('invite_error'),
                            style: AppTypography.label.copyWith(color: danger),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_invite == null)
                PrimaryButton(
                  label: context.l10n.search,
                  onPressed: _isLoading ? null : _searchInvite,
                ),
              if (_invite != null) ...[
                _buildInviteCard(),
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: context.l10n.inviteJoinTeam,
                  onPressed: _isAccepting ? null : _acceptInvite,
                ),
                Center(
                  child: TextLink(
                    label: context.l10n.searchAnotherCode,
                    onPressed: () {
                      setState(() {
                        _invite = null;
                        _errorMessage = null;
                      });
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInviteCard() {
    final role = _getRoleLabel(_invite!.role);
    final name = _invite!.invitedBy?.name;
    return AppListRow(
      title: _invite!.company?.name ?? '',
      subtitle: name == null
          ? context.l10n.inviteEntersAs(role)
          : context.l10n.inviteInvitedByAs(name, role),
    );
  }
}
