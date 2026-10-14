import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/models/form_definition.dart';
import 'package:praticos/screens/menu_navigation/more/more_page.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/screens/widgets/list_states.dart';
import 'package:praticos/screens/widgets/glass_bar_button.dart';
import 'package:praticos/screens/widgets/section_label.dart';
import 'package:praticos/screens/widgets/status_dot.dart';
import 'package:praticos/screens/widgets/text_link.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';

/// "Checklists" (app-checklists): the company's checklists ("Seus
/// checklists", tap to edit, swipe to delete), the ready ones ("Prontos para
/// usar", "Usar" copies one) and "+" at the top for a new one.
///
/// Presentational: [FormTemplateListScreen] wires the store.
class ChecklistsView extends StatelessWidget {
  const ChecklistsView({
    super.key,
    required this.templates,
    this.readyTemplates = const [],
    this.localeCode,
    this.loading = false,
    this.error = false,
    this.onRetry,
    this.onOpen,
    this.onDelete,
    this.onPreviewReady,
    this.onUseReady,
    this.onNew,
  });

  final List<FormDefinition> templates;
  final List<FormDefinition> readyTemplates;
  final String? localeCode;
  final bool loading;
  final bool error;
  final VoidCallback? onRetry;
  final ValueChanged<FormDefinition>? onOpen;

  /// Asks and deletes; true when the row should go away.
  final Future<bool> Function(FormDefinition template)? onDelete;
  final ValueChanged<FormDefinition>? onPreviewReady;
  final ValueChanged<FormDefinition>? onUseReady;
  final VoidCallback? onNew;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return MorePage(
      title: l10n.checklistsTitle,
      subtitle: l10n.checklistsSubtitle,
      trailing: onNew == null
          ? null
          : GlassBarButton(
              key: const ValueKey('checklist_new'),
              label: l10n.checklistNew,
              icon: CupertinoIcons.add,
              onPressed: onNew,
            ),
      children: [
        if (loading)
          const SizedBox(height: 240, child: LoadingState())
        else if (error)
          SizedBox(
            height: 240,
            child: ErrorState(
              message: l10n.errorLoadingProcedures,
              onRetry: onRetry ?? () {},
            ),
          )
        else ...[
          if (templates.isEmpty && readyTemplates.isEmpty)
            SizedBox(
              height: 240,
              child: EmptyState(title: l10n.checklistsEmpty),
            ),
          if (templates.isNotEmpty) ...[
            SectionLabel(l10n.checklistsYours),
            MoreRows(rows: [
              for (final template in templates) _yourRow(context, template),
            ]),
          ],
          if (readyTemplates.isNotEmpty) ...[
            SectionLabel(l10n.checklistsReady),
            MoreRows(rows: [
              for (final template in readyTemplates)
                _readyRow(context, template),
            ]),
          ],
        ],
      ],
    );
  }

  /// "12 perguntas · com fotos"; "● Desligado · 20 perguntas" when off.
  Widget _yourRow(BuildContext context, FormDefinition template) {
    final l10n = context.l10n;
    final questions = l10n.checklistQuestions(template.items.length);
    final withPhotos =
        template.items.any((item) => item.type == FormItemType.photoOnly);
    final row = AppListRow(
      key: ValueKey('checklist_${template.id}'),
      title: template.getLocalizedTitle(localeCode),
      subtitle: template.isActive
          ? (withPhotos ? '$questions · ${l10n.checklistWithPhotos}' : questions)
          : null,
      subtitleWidget: template.isActive
          ? null
          : Row(
              children: [
                StatusDot(color: AppColors.textSecondary),
                const SizedBox(width: AppSpacing.xs + 2),
                Flexible(
                  child: Text(
                    '${l10n.checklistOff} · $questions',
                    style: AppTypography.callout.copyWith(
                      color: AppColors.textSecondary.resolveFrom(context),
                    ),
                  ),
                ),
              ],
            ),
      titleStyle: AppTypography.bodyStrong,
      onTap: onOpen == null ? null : () => onOpen!(template),
    );
    final delete = onDelete;
    if (delete == null || template.id == null) return row;
    return Dismissible(
      key: ValueKey('dismiss_${template.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: AppColors.danger.resolveFrom(context),
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsetsDirectional.only(end: AppSpacing.xl),
        child: Icon(
          CupertinoIcons.trash,
          color: AppColors.onAccent.resolveFrom(context),
        ),
      ),
      confirmDismiss: (_) => delete(template),
      child: row,
    );
  }

  /// "Vistoria de ar-condicionado · 8 perguntas" with "Usar" at the end.
  Widget _readyRow(BuildContext context, FormDefinition template) {
    final l10n = context.l10n;
    return Semantics(
      key: ValueKey('checklist_ready_${template.id}'),
      button: onPreviewReady != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPreviewReady == null ? null : () => onPreviewReady!(template),
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
                      template.getLocalizedTitle(localeCode),
                      style: AppTypography.bodyStrong.copyWith(
                        color: AppColors.text.resolveFrom(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.checklistQuestions(template.items.length),
                      style: AppTypography.callout.copyWith(
                        color: AppColors.textSecondary.resolveFrom(context),
                      ),
                    ),
                  ],
                ),
              ),
              if (onUseReady != null) ...[
                const SizedBox(width: AppSpacing.md),
                TextLink(
                  key: ValueKey('checklist_use_${template.id}'),
                  label: l10n.checklistUse,
                  onPressed: () => onUseReady!(template),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
