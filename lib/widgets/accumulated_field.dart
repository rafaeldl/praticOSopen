import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show Autocomplete, Colors, Material, Offset, BoxShadow;
import '../models/accumulated_value.dart';
import '../repositories/accumulated_value_repository.dart';

/// A reusable autocomplete field that accumulates values over time.
///
/// Values are stored per company and field type, with optional grouping
/// for hierarchical relationships (e.g., models grouped by brand).
///
/// Example usage:
/// ```dart
/// // Independent field (no grouping)
/// AccumulatedField(
///   companyId: companyId,
///   fieldType: 'deviceBrand',
///   label: 'Marca',
///   onSelected: (value, valueId) {
///     device.brand = value;
///     device.brandId = valueId;
///   },
/// )
///
/// // Dependent field (filtered by group)
/// AccumulatedField(
///   companyId: companyId,
///   fieldType: 'deviceModel',
///   label: 'Modelo',
///   groupId: device.brandId,
///   groupValue: device.brand,
///   onSelected: (value, valueId) {
///     device.model = value;
///   },
/// )
/// ```
class AccumulatedField extends StatefulWidget {
  /// The company ID for multi-tenant isolation
  final String companyId;

  /// The field type identifier (e.g., 'deviceBrand', 'deviceModel', 'serviceCategory')
  final String fieldType;

  /// The label displayed above the field
  final String label;

  /// The initial value to display
  final String? initialValue;

  /// The initial value ID (if editing existing data)
  final String? initialValueId;

  /// Callback when a value is selected or created.
  /// Returns the value string and its ID.
  final Function(String value, String? valueId) onSelected;

  /// Optional group ID for hierarchical filtering.
  /// When set, only shows values that belong to this group.
  final String? groupId;

  /// Optional group value (parent's display value).
  /// Used when creating new values to store the parent reference.
  final String? groupValue;

  /// Placeholder text for the input field
  final String? placeholder;

  /// Whether to allow removing values from the list
  final bool allowRemove;

  /// Text alignment in the field
  final TextAlign textAlign;

  const AccumulatedField({
    super.key,
    required this.companyId,
    required this.fieldType,
    required this.label,
    this.initialValue,
    this.initialValueId,
    required this.onSelected,
    this.groupId,
    this.groupValue,
    this.placeholder,
    this.allowRemove = true,
    this.textAlign = TextAlign.right,
  });

  @override
  State<AccumulatedField> createState() => _AccumulatedFieldState();
}

class _AccumulatedFieldState extends State<AccumulatedField> {
  final _repo = AccumulatedValueRepository();
  final _controller = TextEditingController();
  List<AccumulatedValue> _cachedValues = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null) {
      _controller.text = widget.initialValue!;
    }
    _loadInitialValues();
  }

  @override
  void didUpdateWidget(AccumulatedField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload if groupId changes
    if (oldWidget.groupId != widget.groupId) {
      _loadInitialValues();
    }
  }

  Future<void> _loadInitialValues() async {
    setState(() => _isLoading = true);
    try {
      _cachedValues = await _repo.getAll(
        widget.companyId,
        widget.fieldType,
        groupId: widget.groupId,
      );
    } catch (e) {
      debugPrint('Error loading accumulated values: $e');
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<List<AccumulatedValue>> _getSuggestions(String query) async {
    final q = query.toLowerCase().trim();

    // Filter from cached values for better performance
    if (q.isEmpty) {
      return _cachedValues.take(20).toList();
    }

    return _cachedValues
        .where((v) => v.searchKey.contains(q))
        .take(20)
        .toList();
  }

  Future<void> _handleSelection(String value) async {
    // Find if this value exists in cache
    final existing = _cachedValues.firstWhere(
      (v) => v.value.toLowerCase() == value.toLowerCase(),
      orElse: () => AccumulatedValue(value: value),
    );

    // Add or increment in repository
    final valueId = await _repo.addOrIncrement(
      widget.companyId,
      widget.fieldType,
      value,
      groupId: widget.groupId,
      groupValue: widget.groupValue,
    );

    // Refresh cache
    await _loadInitialValues();

    // Notify parent
    widget.onSelected(value, existing.id ?? valueId);
  }

  Future<void> _removeValue(AccumulatedValue value) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Remover valor'),
        content: Text('Deseja remover "${value.value}" da lista de sugestões?'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );

    if (confirmed == true && value.id != null) {
      await _repo.remove(widget.companyId, widget.fieldType, value.id!);
      await _loadInitialValues();

      // Clear field if the removed value was selected
      if (_controller.text == value.value) {
        _controller.clear();
        widget.onSelected('', null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<AccumulatedValue>(
      initialValue: TextEditingValue(text: widget.initialValue ?? ''),
      displayStringForOption: (option) => option.value,
      optionsBuilder: (textEditingValue) async {
        return await _getSuggestions(textEditingValue.text);
      },
      onSelected: (option) => _handleSelection(option.value),
      fieldViewBuilder: (context, controller, focusNode, onSubmit) {
        // Sync with local controller
        if (controller.text != _controller.text) {
          _controller.text = controller.text;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.label.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: Text(
                  widget.label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ),
            ],
            CupertinoTextField(
              controller: controller,
              focusNode: focusNode,
              placeholder: widget.placeholder ?? 'Selecione ou digite...',
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              textAlign: widget.textAlign,
              decoration: BoxDecoration(
                color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
                borderRadius: BorderRadius.circular(8),
              ),
              suffix: Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: _isLoading
                    ? const CupertinoActivityIndicator(radius: 8)
                    : Icon(
                        CupertinoIcons.chevron_down,
                        size: 16,
                        color: CupertinoColors.systemGrey.resolveFrom(context),
                      ),
              ),
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  _handleSelection(value);
                }
              },
            ),
          ],
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final optionsList = options.toList();

        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 300,
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: CupertinoColors.systemBackground.resolveFrom(context),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: CupertinoColors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: optionsList.length,
                    separatorBuilder: (context, index) => Container(
                      height: 1,
                      color: CupertinoColors.separator.resolveFrom(context),
                      margin: const EdgeInsets.only(left: 16),
                    ),
                    itemBuilder: (context, index) {
                      final option = optionsList[index];
                      return _buildOptionTile(context, option, onSelected);
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOptionTile(
    BuildContext context,
    AccumulatedValue option,
    void Function(AccumulatedValue) onSelected,
  ) {
    return GestureDetector(
      onTap: () => onSelected(option),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: Colors.transparent,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.value,
                    style: TextStyle(
                      fontSize: 16,
                      color: CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
                  if (option.groupValue != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      option.groupValue!,
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            CupertinoColors.secondaryLabel.resolveFrom(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (option.usageCount > 1)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color:
                      CupertinoColors.tertiarySystemFill.resolveFrom(context),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${option.usageCount}',
                  style: TextStyle(
                    fontSize: 11,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ),
            if (widget.allowRemove && option.id != null)
              GestureDetector(
                onTap: () => _removeValue(option),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    CupertinoIcons.xmark_circle_fill,
                    size: 18,
                    color: CupertinoColors.systemGrey.resolveFrom(context),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
