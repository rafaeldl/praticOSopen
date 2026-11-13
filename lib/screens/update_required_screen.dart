import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/screens/widgets/primary_button.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';

/// Shown instead of the whole app when the installed version is below the
/// minimum in `config/appVersion`. One question ("what do I do now?"), one
/// yellow button that opens the store. No way around it: the app comes back
/// by itself when it returns from the store already updated.
class UpdateRequiredScreen extends StatelessWidget {
  const UpdateRequiredScreen({super.key, required this.onUpdate});

  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return CupertinoPageScaffold(
      key: const ValueKey('app_update_required_screen'),
      backgroundColor: AppColors.background.resolveFrom(context),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pageMargin,
            vertical: AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppSpacing.xxl),
                      Icon(
                        CupertinoIcons.arrow_down_circle,
                        size: 56,
                        color: AppColors.accentText.resolveFrom(context),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Semantics(
                        header: true,
                        child: Text(
                          l10n.appUpdateRequiredTitle,
                          style: AppTypography.title.copyWith(
                            color: AppColors.text.resolveFrom(context),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        l10n.appUpdateRequiredMessage,
                        style: AppTypography.body.copyWith(
                          color: AppColors.textSecondary.resolveFrom(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                key: const ValueKey('app_update_button'),
                label: l10n.appUpdateButton,
                onPressed: onUpdate,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
