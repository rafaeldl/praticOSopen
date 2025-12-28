import 'package:flutter/material.dart';

class GroupedSection extends StatelessWidget {
  final List<Widget> children;
  final Widget? header;
  final Widget? footer;

  const GroupedSection({
    super.key,
    required this.children,
    this.header,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (header != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 16, 32, 8),
            child: DefaultTextStyle(
              style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color,
                  ) ??
                  TextStyle(color: theme.colorScheme.onSurfaceVariant),
              child: header!,
            ),
          ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: theme.cardTheme.color ?? theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1)
                  Divider(
                    height: 1,
                    thickness: 1,
                    indent: 16,
                    color: theme.dividerColor,
                  ),
              ],
            ],
          ),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 8, 32, 16),
            child: DefaultTextStyle(
              style: theme.textTheme.bodySmall ??
                  TextStyle(color: theme.colorScheme.onSurfaceVariant),
              child: footer!,
            ),
          ),
      ],
    );
  }
}
