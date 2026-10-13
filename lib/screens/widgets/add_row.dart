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
    this.icon = CupertinoIcons.add,
    this.destructive = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool plain;

  /// Leading symbol; "+" by default.
  final IconData icon;

  /// Red (`danger`) instead of blue, for "Tirar … da OS".
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = (destructive ? AppColors.danger : AppColors.accentText)
        .resolveFrom(context);
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
                  Icon(icon, size: 24, color: color)
                else
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.secondaryFill.resolveFrom(context),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 20, color: color),
                  ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    label,
                    style: AppTypography.bodyStrong.copyWith(color: color),
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
