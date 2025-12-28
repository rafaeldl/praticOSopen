import 'package:flutter/material.dart';

class GroupedRow extends StatelessWidget {
  final String label;
  final Widget child;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool showArrow;

  const GroupedRow({
    super.key,
    required this.label,
    required this.child,
    this.icon,
    this.onPressed,
    this.showArrow = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Typography 17pt
    final labelStyle = theme.textTheme.bodyLarge?.copyWith(
      fontSize: 17,
      fontWeight: FontWeight.normal,
      color: theme.colorScheme.onSurface,
    ) ?? const TextStyle(fontSize: 17);

    final contentStyle = theme.textTheme.bodyMedium?.copyWith(
      fontSize: 17,
      color: theme.colorScheme.onSurface.withOpacity(0.6),
    ) ?? const TextStyle(fontSize: 17);

    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 22, color: theme.primaryColor),
              const SizedBox(width: 12),
            ],
            Text(label, style: labelStyle),
            const SizedBox(width: 16),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: DefaultTextStyle(
                  style: contentStyle,
                  textAlign: TextAlign.right,
                  child: child,
                ),
              ),
            ),
            if (showArrow || (onPressed != null && showArrow)) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: theme.disabledColor,
              ),
            ]
          ],
        ),
      ),
    );
  }
}
