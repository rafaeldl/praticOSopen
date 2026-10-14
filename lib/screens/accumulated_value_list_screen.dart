import 'package:flutter/cupertino.dart';
import 'package:praticos/models/accumulated_value.dart';
import 'package:praticos/repositories/accumulated_value_repository.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/global.dart';
import 'package:praticos/models/permission.dart';
import 'package:praticos/screens/widgets/add_row.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/screens/widgets/picker_screen.dart';
import 'package:praticos/services/authorization_service.dart';
import 'package:praticos/theme/app_colors.dart';

/// Screen for selecting or creating accumulated values.
///
/// "Escolher" pattern ([PickerScaffold]): the field as the large title, the
/// search always on (typing adds), previously used values sorted by usage
/// count, "Usar “X”" on top for a new value, a ✓ on the current choice and
/// "Deixar em branco" when clearing is allowed. Multiple choice
/// (`multiSelect`) confirms with the ✓ in the top bar (blue once the choice
/// changed) and pops with the list. Deleting (swipe) needs the
/// permission of the field's area (`manageDevices` for device fields,
/// `manageServices` / `manageProducts` for catalog fields).
class AccumulatedValueListScreen extends StatefulWidget {
  const AccumulatedValueListScreen({
    super.key,
    this.repository,
    this.canDelete,
  });

  /// Injected in tests; defaults to [AccumulatedValueRepository].
  final AccumulatedValueRepository? repository;

  /// Injected in tests; defaults to the permission of the field type.
  final bool Function(String fieldType)? canDelete;

  @override
  State<AccumulatedValueListScreen> createState() =>
      _AccumulatedValueListScreenState();
}

class _AccumulatedValueListScreenState
    extends State<AccumulatedValueListScreen> {
  late final AccumulatedValueRepository _repo =
      widget.repository ?? AccumulatedValueRepository();

  List<AccumulatedValue> _allValues = [];
  bool _isLoading = false;

  String? _companyId;
  String? _fieldType;
  String? _title;
  String? _currentValue;
  List<String>? _currentValues; // For multi-select
  String? _group;
  bool _multiSelect = false;
  bool _allowClear = false; // Allow clearing the selection
  Set<String> _selectedValues =
      {}; // Track selected values in multi-select mode
  bool _argumentsLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    debugPrint(
      'AccumulatedValueListScreen.didChangeDependencies: _argumentsLoaded=$_argumentsLoaded',
    );

    // Get arguments once
    if (!_argumentsLoaded) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

      if (args != null) {
        _fieldType = args['fieldType'];
        _title = args['title'] ?? context.l10n.select;
        _multiSelect = args['multiSelect'] ?? false;
        _allowClear = args['allowClear'] ?? false;

        // Handle current value(s) for single or multi-select
        if (_multiSelect) {
          final currentValuesArg = args['currentValues'];
          if (currentValuesArg is List) {
            _currentValues = currentValuesArg.whereType<String>().toList();
            _selectedValues = Set.from(_currentValues ?? []);
          } else {
            _currentValues = [];
            _selectedValues = {};
          }
        } else {
          _currentValue = args['currentValue'];
        }

        // Handle group as String or List
        final groupArg = args['group'];
        if (groupArg is List) {
          // Filter out null values and join with '-'
          final nonNullValues = groupArg
              .whereType<String>()
              .where((s) => s.isNotEmpty)
              .toList();
          _group = nonNullValues.isNotEmpty ? nonNullValues.join('-') : null;
        } else if (groupArg is String) {
          _group = groupArg;
        } else {
          _group = null;
        }

        // Get companyId from Global automatically
        _companyId = Global.companyAggr?.id;

        debugPrint(
          'AccumulatedValueListScreen: Arguments loaded - companyId=$_companyId, fieldType=$_fieldType, group=$_group, multiSelect=$_multiSelect, currentValue=$_currentValue, selectedValues=$_selectedValues',
        );

        _argumentsLoaded = true;
      }
    }

    // Always reload values when screen is shown (if we have the required data)
    if (_companyId != null && _fieldType != null && !_isLoading) {
      debugPrint('AccumulatedValueListScreen: Triggering reload...');
      _loadValues();
    }
  }

  Future<void> _loadValues() async {
    if (_companyId == null || _fieldType == null) return;

    setState(() => _isLoading = true);

    try {
      _allValues = await _repo.getAll(_companyId!, _fieldType!, group: _group);
      debugPrint(
        'AccumulatedValueListScreen: Loaded ${_allValues.length} values',
      );
    } catch (e) {
      debugPrint('Error loading accumulated values: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectValue(String value) async {
    if (_companyId == null || _fieldType == null) return;

    debugPrint('AccumulatedValueListScreen: Adding/selecting value: $value');

    // Record usage (create or increment)
    final valueId = await _repo.use(
      _companyId!,
      _fieldType!,
      value,
      group: _group,
    );

    debugPrint('AccumulatedValueListScreen: Value saved with ID: $valueId');

    if (_multiSelect) {
      // Multi-select: toggle selection and update UI
      setState(() {
        if (_selectedValues.contains(value)) {
          _selectedValues.remove(value);
        } else {
          _selectedValues.add(value);
        }
      });
    } else {
      // Single select: close immediately
      if (mounted) {
        Navigator.pop(context, value);
      }
    }
  }

  void _confirmSelection() {
    if (mounted) {
      Navigator.pop(context, _selectedValues.toList());
    }
  }

  void _clearSelection() {
    if (mounted) {
      Navigator.pop(context, 'clear');
    }
  }

  bool get _mayDelete {
    final type = _fieldType ?? '';
    if (widget.canDelete != null) return widget.canDelete!(type);
    final PermissionType permission;
    if (type.startsWith('service')) {
      permission = PermissionType.manageServices;
    } else if (type.startsWith('product')) {
      permission = PermissionType.manageProducts;
    } else {
      permission = PermissionType.manageDevices;
    }
    return AuthorizationService.instance.hasPermission(permission);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final current = _currentValue;
    final hasCurrent = current != null && current.isNotEmpty;
    bool inList(String v) =>
        _allValues.any((x) => x.value.toLowerCase() == v.toLowerCase());
    final changed =
        _multiSelect &&
        (_selectedValues.length != (_currentValues ?? const []).length ||
            !_selectedValues.containsAll(_currentValues ?? const []));

    return PickerScaffold<String>(
      title: _title ?? l10n.select,
      itemCount: _allValues.length,
      // Typing is how a new value comes in, so the search is always there.
      alwaysShowSearch: true,
      searchPlaceholder: l10n.searchOrAddNew,
      loading: _isLoading && _allValues.isEmpty,
      strongTitles: false,
      multiple: _multiSelect,
      onConfirm: changed ? _confirmSelection : null,
      onSelect: _selectValue,
      onCreate: _selectValue,
      createLabel: l10n.accumulatedUse,
      canCreate: (query) => !inList(query),
      emptyIcon: CupertinoIcons.square_list,
      emptyTitle: l10n.noValuesRegistered,
      emptyMessage: l10n.typeAboveToAdd,
      headerRows: (query) => [
        if (_allowClear && !_multiSelect && hasCurrent && query.isEmpty)
          AppListRow(
            title: l10n.accumulatedLeaveBlank,
            showChevron: false,
            onTap: _clearSelection,
          ),
        // The current value when it is not saved yet.
        if (query.isEmpty && hasCurrent && !inList(current))
          AddRow(
            plain: true,
            label: l10n.accumulatedUse(current),
            onTap: () => _selectValue(current),
          ),
      ],
      sections: (query) => [
        PickerSection(
          items: [
            for (final value in _allValues)
              if (value.searchKey.contains(query.toLowerCase()))
                _valueItem(value),
          ],
        ),
      ],
    );
  }

  PickerItem<String> _valueItem(AccumulatedValue value) {
    final isSelected = _multiSelect
        ? _selectedValues.contains(value.value)
        : value.value == _currentValue;
    return PickerItem(
      key: ValueKey('value-${value.id ?? value.value}'),
      value: value.value,
      title: value.value,
      subtitle: value.group,
      selected: isSelected,
      wrap: _mayDelete ? (row) => _dismissible(value, row) : null,
    );
  }

  Widget _dismissible(AccumulatedValue value, Widget row) {
    return Dismissible(
      key: Key(value.id ?? value.value),
      direction: DismissDirection.endToStart,
      background: Container(
        color: AppColors.danger.resolveFrom(context),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(
          CupertinoIcons.delete,
          color: AppColors.onAccent.resolveFrom(context),
        ),
      ),
      confirmDismiss: (direction) async {
        final confirmed = await showCupertinoDialog<bool>(
          context: context,
          builder: (dialogContext) => CupertinoAlertDialog(
            title: Text(context.l10n.accumulatedDeleteConfirm(value.value)),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(context.l10n.cancel),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(context.l10n.delete),
              ),
            ],
          ),
        );
        if (confirmed != true || value.id == null) return false;
        try {
          await _repo.remove(_companyId!, _fieldType!, value.id!);
          setState(() {
            _allValues.removeWhere((v) => v.id == value.id);
          });
          return true;
        } catch (e) {
          debugPrint('Error deleting accumulated value: $e');
          return false;
        }
      },
      child: row,
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
