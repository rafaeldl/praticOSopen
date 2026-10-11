import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';

/// Empty list: one sentence saying what is missing, optional hint and one
/// optional action (link style, not a second filled button).
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.icon,
  });

  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return _CenteredState(
      icon: icon,
      title: title,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }
}

/// Failed load, with a retry action. [message] defaults to a localized
/// generic text.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, this.message, required this.onRetry});

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _CenteredState(
      icon: CupertinoIcons.exclamationmark_circle,
      title: message ?? context.l10n.listLoadError,
      actionLabel: context.l10n.tryAgain,
      onAction: onRetry,
    );
  }
}

/// Loading indicator, with an optional [label] (defaults to nothing visible
/// but announces "Loading..." to screen readers).
class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        label: label ?? context.l10n.loading,
        liveRegion: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CupertinoActivityIndicator(radius: 14),
            if (label != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                label!,
                textAlign: TextAlign.center,
                style: AppTypography.callout.copyWith(
                  color: AppColors.textSecondary.resolveFrom(context),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CenteredState extends StatelessWidget {
  const _CenteredState({
    required this.title,
    this.message,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? message;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.pageMargin),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 40,
                color: AppColors.textSecondary.resolveFrom(context),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.bodyStrong.copyWith(
                color: AppColors.text.resolveFrom(context),
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: AppTypography.callout.copyWith(
                  color: AppColors.textSecondary.resolveFrom(context),
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.lg),
              CupertinoButton(
                minimumSize: const Size(
                  AppSizes.minTouchTarget,
                  AppSizes.minTouchTarget,
                ),
                onPressed: onAction,
                child: Text(
                  actionLabel!,
                  style: AppTypography.callout.copyWith(
                    color: AppColors.accentText.resolveFrom(context),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
