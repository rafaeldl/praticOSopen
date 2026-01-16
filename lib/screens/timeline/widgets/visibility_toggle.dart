import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';

class VisibilityToggle extends StatelessWidget {
  final bool isPublic;
  final ValueChanged<bool> onChanged;

  const VisibilityToggle({
    super.key,
    required this.isPublic,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Internal Option
        _buildOption(
          context: context,
          icon: CupertinoIcons.lock_fill,
          label: context.l10n.internalOnly,
          isSelected: !isPublic,
          onTap: () => onChanged(false),
          color: CupertinoColors.activeBlue,
        ),
        const SizedBox(width: 8),
        // Public Option
        _buildOption(
          context: context,
          icon: CupertinoIcons.globe,
          label: context.l10n.customerCanSee,
          isSelected: isPublic,
          onTap: () => onChanged(true),
          color: CupertinoColors.systemGreen,
        ),
      ],
    );
  }

  Widget _buildOption({
    required BuildContext context,
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : null,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? color
                : CupertinoColors.separator.resolveFrom(context),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected
                  ? color
                  : CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? color
                    : CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
