import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/screens/menu_navigation/more/account_deletion.dart';
import 'package:praticos/screens/widgets/primary_button.dart';
import 'package:praticos/screens/widgets/text_link.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';

/// Shown to a signed-in user without a company where the app must not
/// create one (iOS, App Store guideline 3.1.1; see `PlatformPolicy`).
///
/// The account is not linked to any company yet: the user joins one with an
/// invite code from the company administrator, signs out or deletes the
/// account. On purpose there is no mention of creating a company anywhere
/// else (website, other platforms): Apple treats that as steering.
class NoCompanyScreen extends StatelessWidget {
  const NoCompanyScreen({
    super.key,
    required this.onJoinWithCode,
    required this.onSignOut,
    required this.deletion,
    this.email,
  });

  final VoidCallback onJoinWithCode;
  final VoidCallback onSignOut;
  final AccountDeletionFlow deletion;

  /// Account the user is signed in with, so they can tell the administrator.
  final String? email;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background.resolveFrom(context),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageMargin,
            AppSpacing.xxl,
            AppSpacing.pageMargin,
            AppSpacing.xl,
          ),
          children: [
            Icon(
              CupertinoIcons.person_2,
              size: 48,
              color: AppColors.accentText.resolveFrom(context),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.noCompanyTitle,
              style: AppTypography.title.copyWith(
                color: AppColors.text.resolveFrom(context),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.noCompanyMessage,
              style: AppTypography.callout.copyWith(
                color: AppColors.textSecondary.resolveFrom(context),
              ),
            ),
            if (email != null && email!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.noCompanySignedInAs(email!),
                style: AppTypography.label.copyWith(
                  color: AppColors.textSecondary.resolveFrom(context),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: l10n.joinWithInviteCode,
              onPressed: onJoinWithCode,
            ),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: TextLink(label: l10n.logout, onPressed: onSignOut),
            ),
            Center(
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(
                  AppSizes.minTouchTarget,
                  AppSizes.minTouchTarget,
                ),
                onPressed: () => deletion.start(context),
                child: Text(
                  l10n.deleteMyAccount,
                  style: AppTypography.callout.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.danger.resolveFrom(context),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
