import 'package:flutter/cupertino.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';

/// First row of a "choose" list: a "+" circle and an `accentText` label
/// ("Cadastrar cliente novo"). Replaces the loose "+" in the top bar.
///
/// [plain] drops the gray circle: just the "+" and the label, as in the
/// "Escolher" screens (`PickerScaffold`).
class AddRow extends StatelessWidget {
  const AddRow({
    super.key,
    required this.label,
    required this.onTap,
    this.plain = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool plain;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: plain ? 52 : 60),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pageMargin,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                if (plain)
                  Icon(
                    CupertinoIcons.add,
                    size: 24,
                    color: AppColors.accentText.resolveFrom(context),
                  )
                else
                  Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.secondaryFill.resolveFrom(context),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    CupertinoIcons.add,
                    size: 20,
                    color: AppColors.accentText.resolveFrom(context),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    label,
                    style: AppTypography.bodyStrong.copyWith(
                      color: AppColors.accentText.resolveFrom(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
