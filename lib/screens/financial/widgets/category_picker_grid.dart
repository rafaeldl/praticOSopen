import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/models/accumulated_value.dart';
import 'package:praticos/repositories/accumulated_value_repository.dart';

/// Grid of category chips for selecting financial category.
///
/// Streams categories from AccumulatedValueRepository, displays them
/// as selectable chips ordered by usage count, and allows creating
/// new categories inline via a dialog.
class CategoryPickerGrid extends StatelessWidget {
  final String fieldType;
  final String? selectedCategory;
  final String companyId;
  final ValueChanged<String> onCategorySelected;

  const CategoryPickerGrid({
    super.key,
    required this.fieldType,
    required this.selectedCategory,
    required this.companyId,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AccumulatedValue>>(
      stream: AccumulatedValueRepository().streamAll(companyId, fieldType),
      builder: (context, snapshot) {
        final categories = snapshot.data ?? [];
        return _buildGrid(context, categories);
      },
    );
  }

  Widget _buildGrid(BuildContext context, List<AccumulatedValue> categories) {
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final fillColor =
        CupertinoColors.systemGrey5.resolveFrom(context);
    final selectedBgColor = CupertinoColors.activeBlue;
    final selectedTextColor = CupertinoColors.white;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        // Category chips
        ...categories.map((category) {
          final isSelected = category.value == selectedCategory;
          return GestureDetector(
            onTap: () => onCategorySelected(category.value),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? selectedBgColor : fillColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                category.value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? selectedTextColor : labelColor,
                ),
              ),
            ),
          );
        }),

        // "+ Nova" button
        GestureDetector(
          onTap: () => _showNewCategoryDialog(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(
                color: CupertinoColors.activeBlue,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  CupertinoIcons.add,
                  size: 14,
                  color: CupertinoColors.activeBlue,
                ),
                const SizedBox(width: 4),
                Text(
                  context.l10n.newCategory,
                  style: const TextStyle(
                    fontSize: 14,
                    color: CupertinoColors.activeBlue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showNewCategoryDialog(BuildContext context) {
    final controller = TextEditingController();

    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(context.l10n.newCategory),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            autofocus: true,
            placeholder: context.l10n.category,
            textCapitalization: TextCapitalization.sentences,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: false,
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.l10n.cancel),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () async {
              final value = controller.text.trim();
              if (value.isNotEmpty) {
                await AccumulatedValueRepository().use(
                  companyId,
                  fieldType,
                  value,
                );
                onCategorySelected(value);
              }
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: Text(context.l10n.confirm),
          ),
        ],
      ),
    );
  }
}
