import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/screens/widgets/primary_button.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';

/// Modal sheet for creating a record (new customer, vehicle, service).
///
/// HIG: "Cancelar" on the leading edge, title in the middle. A record form
/// (new customer, vehicle, service) confirms with the big button at the
/// bottom ([primaryLabel], design system rule 9, "Salvar cliente"); small
/// sheets confirm on the trailing edge ([actionLabel]). Never both. Editing an
/// existing record stays a pushed screen. Open it with [AppSheet.show] and put an [AppSheet] as the
/// root of the builder.
class AppSheet extends StatelessWidget {
  const AppSheet({
    super.key,
    required this.title,
    required this.child,
    this.actionLabel,
    this.primaryLabel,
    this.onAction,
    this.busy = false,
    this.onCancel,
  });

  final String title;
  final Widget child;

  /// Label of the trailing action (e.g. "Salvar"). No action when null.
  final String? actionLabel;

  /// Label of the big confirming button at the bottom (e.g. "Salvar
  /// cliente"). Takes the place of [actionLabel].
  final String? primaryLabel;

  /// Disabled while null or [busy].
  final VoidCallback? onAction;

  /// Shows a spinner instead of the action label.
  final bool busy;

  /// Defaults to popping the sheet with no result.
  final VoidCallback? onCancel;

  /// Presents [builder] as a Cupertino sheet and resolves with what the sheet
  /// pops (null when cancelled).
  static Future<T?> show<T>(BuildContext context, WidgetBuilder builder) {
    return showCupertinoSheet<T>(context: context, builder: builder);
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentText.resolveFrom(context);
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background.resolveFrom(context),
      navigationBar: CupertinoNavigationBar(
        automaticallyImplyLeading: false,
        automaticallyImplyMiddle: false,
        backgroundColor: AppColors.background.resolveFrom(context),
        border: null,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(44, 44),
          onPressed: onCancel ?? () => Navigator.of(context).maybePop(),
          child: Text(
            context.l10n.cancel,
            style: AppTypography.callout.copyWith(color: accent),
          ),
        ),
        middle: Text(
          title,
          style: AppTypography.bodyStrong.copyWith(
            color: AppColors.text.resolveFrom(context),
          ),
        ),
        trailing: actionLabel == null || primaryLabel != null
            ? null
            : CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(44, 44),
                onPressed: busy ? null : onAction,
                child: busy
                    ? const CupertinoActivityIndicator()
                    : Text(
                        actionLabel!,
                        style: AppTypography.callout.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
      ),
      child: SafeArea(
        child: primaryLabel == null
            ? child
            : Column(
                children: [
                  Expanded(child: child),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.blockMargin,
                      AppSpacing.sm,
                      AppSpacing.blockMargin,
                      AppSpacing.lg,
                    ),
                    child: busy
                        ? const SizedBox(
                            height: AppSizes.primaryButtonHeight,
                            child: CupertinoActivityIndicator(),
                          )
                        : PrimaryButton(
                            label: primaryLabel!,
                            onPressed: onAction,
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}
