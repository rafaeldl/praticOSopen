import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_glass.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';

/// One action of a [showPullDownMenu]: label on the left, icon on the right
/// (like the iOS pull-down menus). [submenu] adds a "›" (it opens another
/// choice); [destructive] draws it in red.
class PullDownItem {
  const PullDownItem({
    required this.value,
    required this.label,
    required this.icon,
    this.destructive = false,
    this.submenu = false,
  });

  final String value;
  final String label;
  final IconData icon;
  final bool destructive;
  final bool submenu;
}

/// A group of [PullDownItem]s, with an optional small title above them.
/// Groups are split by a wider gap, as in the iOS menus.
class PullDownGroup {
  const PullDownGroup(this.items, {this.title});

  final String? title;
  final List<PullDownItem> items;
}

/// Pull-down menu of the "…" top button: a glass panel (navigation layer)
/// under the top right corner, with the actions in groups. Resolves with the
/// [PullDownItem.value] picked, or null when dismissed.
Future<String?> showPullDownMenu(
  BuildContext context, {
  required List<PullDownGroup> groups,
}) {
  final visible = [
    for (final g in groups)
      if (g.items.isNotEmpty) g,
  ];
  if (visible.isEmpty) return Future.value();
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: context.l10n.close,
    barrierColor: AppColors.text.resolveFrom(context).withValues(alpha: 0.06),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (ctx, _, _) => _PullDownPanel(groups: visible),
    transitionBuilder: (ctx, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          alignment: Alignment.topRight,
          scale: Tween<double>(begin: 0.9, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _PullDownPanel extends StatelessWidget {
  const _PullDownPanel({required this.groups});

  final List<PullDownGroup> groups;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = (media.size.width - 2 * AppSpacing.blockMargin).clamp(
      0.0,
      300.0,
    );
    final top = media.padding.top + AppSizes.minTouchTarget + AppSpacing.sm;
    final separator = AppColors.separator.resolveFrom(context);
    final gap = AppColors.groupedBackground.resolveFrom(context);

    final children = <Widget>[];
    for (var g = 0; g < groups.length; g++) {
      final group = groups[g];
      if (g > 0) children.add(Container(height: AppSpacing.sm, color: gap));
      if (group.title != null) {
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xs,
            ),
            child: Semantics(
              header: true,
              child: Text(
                group.title!,
                style: AppTypography.label.copyWith(
                  color: AppColors.textSecondary.resolveFrom(context),
                ),
              ),
            ),
          ),
        );
      }
      for (var i = 0; i < group.items.length; i++) {
        if (i > 0 || group.title != null) {
          children.add(Container(height: 0.5, color: separator));
        }
        children.add(_PullDownRow(item: group.items[i]));
      }
    }

    return Stack(
      children: [
        Positioned(
          top: top,
          right: AppSpacing.blockMargin,
          width: width,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight:
                  media.size.height -
                  top -
                  media.padding.bottom -
                  AppSpacing.lg,
            ),
            child: AppGlass(
              elevated: true,
              borderRadius: BorderRadius.circular(AppRadii.block),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PullDownRow extends StatelessWidget {
  const _PullDownRow({required this.item});

  final PullDownItem item;

  @override
  Widget build(BuildContext context) {
    final color = item.destructive
        ? AppColors.danger.resolveFrom(context)
        : AppColors.text.resolveFrom(context);
    return Semantics(
      button: true,
      child: GestureDetector(
        key: ValueKey('pull_down_${item.value}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(item.value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.minTouchTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item.label,
                    style: AppTypography.body.copyWith(color: color),
                  ),
                ),
                if (item.submenu)
                  Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.sm),
                    child: Icon(
                      CupertinoIcons.chevron_forward,
                      size: 16,
                      color: AppColors.textSecondary.resolveFrom(context),
                    ),
                  ),
                const SizedBox(width: AppSpacing.md),
                Icon(item.icon, size: 22, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
