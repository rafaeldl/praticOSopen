import 'package:flutter/cupertino.dart';
import 'package:praticos/screens/widgets/glass_bar_button.dart';
import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';

/// Page of the "Mais" area: native large title that collapses on scroll,
/// followed by [children] (rows, section labels, footnotes).
class MorePage extends StatelessWidget {
  const MorePage({
    super.key,
    required this.title,
    required this.children,
    this.previousPageTitle,
    this.subtitle,
    this.floatingButton,
    this.trailing,
    this.fitTitle = false,
  });

  final String title;

  /// The title is a record's name (e.g. a checklist), which can be long: it
  /// shrinks to fit the large title line instead of ending in "…".
  final bool fitTitle;

  /// Back button label; defaults to the title of the screen below.
  final String? previousPageTitle;

  /// One line under the large title.
  final String? subtitle;

  /// The screen's single blue button, floating over the bottom of the page
  /// (design system rule 11). The list gets room so nothing hides under it.
  final Widget? floatingButton;

  /// Top-right bar button, e.g. the "+" that adds a new record.
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background.resolveFrom(context),
      child: Material(
        type: MaterialType.transparency,
        child: _withFloatingButton(
          context,
          CustomScrollView(
            slivers: [
              AppNavBar(
                largeTitle: fitTitle
                    ? Padding(
                        padding: const EdgeInsetsDirectional.only(
                          end: AppSpacing.md,
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(title),
                        ),
                      )
                    : Text(title),
                previousTitle: previousPageTitle,
                trailing: trailing,
              ),
              SliverSafeArea(
                top: false,
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (subtitle != null)
                      Padding(
                        // Lined up with the large title (16 from the edge).
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.blockMargin,
                          0,
                          AppSpacing.pageMargin,
                          AppSpacing.sm,
                        ),
                        child: Text(
                          subtitle!,
                          key: const Key('morePageSubtitle'),
                          style: AppTypography.callout.copyWith(
                            color: AppColors.textSecondary.resolveFrom(context),
                          ),
                        ),
                      ),
                    ...children,
                    SizedBox(
                      height: floatingButton == null
                          ? AppSpacing.xxl
                          : AppSizes.primaryButtonHeight + AppSpacing.xxl * 2,
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _withFloatingButton(BuildContext context, Widget scroll) {
    final button = floatingButton;
    if (button == null) return scroll;
    return Stack(
      children: [
        Positioned.fill(child: scroll),
        Positioned(
          left: AppSpacing.blockMargin,
          right: AppSpacing.blockMargin,
          bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.md,
          child: button,
        ),
      ],
    );
  }
}

/// Stacks rows with a hairline separator between them.
class MoreRows extends StatelessWidget {
  const MoreRows({super.key, required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final separator = AppColors.separator.resolveFrom(context);
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0)
            Container(
              height: 0.5,
              margin: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pageMargin,
              ),
              color: separator,
            ),
          rows[i],
        ],
      ],
    );
  }
}

/// Row with a switch at the end (list-row switch style of the HIG, system
/// green). [onChanged] null renders it disabled.
class MoreSwitchRow extends StatelessWidget {
  const MoreSwitchRow({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.onChanged,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    final text = AppColors.text.resolveFrom(context);
    final secondary = AppColors.textSecondary.resolveFrom(context);
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.minTouchTarget),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pageMargin,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.body.copyWith(color: text),
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle!,
                          style: AppTypography.callout.copyWith(
                            color: secondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              CupertinoSwitch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small explanatory text under a list.
class MoreFootnote extends StatelessWidget {
  const MoreFootnote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageMargin,
        AppSpacing.sm,
        AppSpacing.pageMargin,
        0,
      ),
      child: Text(
        text,
        style: AppTypography.label.copyWith(
          color: AppColors.textSecondary.resolveFrom(context),
        ),
      ),
    );
  }
}
