import 'package:flutter/cupertino.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';

/// Progressive disclosure for forms: a "+ Mais dados (…)" link that reveals
/// the rarely used [children]. In edit mode pass [initiallyExpanded] when any
/// of those fields already has a value, so the user sees it right away.
class MoreFieldsLink extends StatefulWidget {
  const MoreFieldsLink({
    super.key,
    required this.label,
    required this.children,
    this.initiallyExpanded = false,
  });

  /// Text of the link, without the leading "+".
  final String label;
  final List<Widget> children;
  final bool initiallyExpanded;

  @override
  State<MoreFieldsLink> createState() => _MoreFieldsLinkState();
}

class _MoreFieldsLinkState extends State<MoreFieldsLink> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    if (_expanded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widget.children,
      );
    }
    return Semantics(
      button: true,
      expanded: false,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _expanded = true),
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(minHeight: AppSizes.minTouchTarget),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pageMargin,
              ),
              child: Text(
                '+ ${widget.label}',
                style: AppTypography.callout.copyWith(
                  color: AppColors.accentText.resolveFrom(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
