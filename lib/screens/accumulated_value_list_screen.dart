import 'package:flutter/cupertino.dart';
import 'package:praticos/models/accumulated_value.dart';
import 'package:praticos/repositories/accumulated_value_repository.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/global.dart';
import 'package:praticos/models/permission.dart';
import 'package:praticos/screens/widgets/add_row.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/screens/widgets/list_states.dart';
import 'package:praticos/services/authorization_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';

/// Screen for selecting or creating accumulated values.
///
/// Displays a searchable list of previously used values sorted by usage count,
/// with "Usar “X”" on top for a new value, a check mark on the current choice
/// and "Deixar em branco" when clearing is allowed. Deleting (swipe) needs the
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
  final _searchController = TextEditingController();

  List<AccumulatedValue> _allValues = [];
  List<AccumulatedValue> _filteredValues = [];
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
  void initState() {
    super.initState();
    _searchController.addListener(_filterValues);
  }

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
      _filteredValues = _allValues;
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

  void _filterValues() {
    final query = _searchController.text.toLowerCase().trim();

    setState(() {
      if (query.isEmpty) {
        _filteredValues = _allValues;
      } else {
        _filteredValues = _allValues
            .where((v) => v.searchKey.contains(query))
            .toList();
      }
    });
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
    final background = AppColors.background.resolveFrom(context);
    return CupertinoPageScaffold(
      backgroundColor: background,
      navigationBar: CupertinoNavigationBar(
        middle: Text(_title ?? context.l10n.select),
        backgroundColor: background,
        trailing: _multiSelect
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _confirmSelection,
                child: Text(
                  context.l10n.done,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              )
            : null,
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.pageMargin),
              child: CupertinoSearchTextField(
                controller: _searchController,
                placeholder: context.l10n.searchOrAddNew,
              ),
            ),
            Expanded(child: _isLoading ? const LoadingState() : _buildList()),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    final l10n = context.l10n;
    final searchQuery = _searchController.text.trim();
    final hasSearchQuery = searchQuery.isNotEmpty;
    final current = _currentValue;
    final hasCurrent = current != null && current.isNotEmpty;

    bool inList(String v) =>
        _filteredValues.any((x) => x.value.toLowerCase() == v.toLowerCase());

    // New value to confirm: what was typed, or the current value when it is
    // not saved yet.
    final String? toAdd = hasSearchQuery
        ? (inList(searchQuery) ? null : searchQuery)
        : (hasCurrent && !inList(current) ? current : null);

    final showClear = _allowClear && !_multiSelect && hasCurrent;
    final children = <Widget>[
      if (showClear)
        AppListRow(title: l10n.accumulatedLeaveBlank, onTap: _clearSelection),
      if (toAdd != null)
        AddRow(
          label: l10n.accumulatedUse(toAdd),
          onTap: () => _selectValue(toAdd),
        ),
      for (final value in _filteredValues) _valueRow(value),
    ];

    if (children.isEmpty) {
      return EmptyState(
        icon: CupertinoIcons.square_list,
        title: l10n.noValuesRegistered,
        message: l10n.typeAboveToAdd,
      );
    }
    return ListView(children: children);
  }

  Widget _valueRow(AccumulatedValue value) {
    final isSelected = _multiSelect
        ? _selectedValues.contains(value.value)
        : value.value == _currentValue;
    final row = Container(
      color: AppColors.background.resolveFrom(context),
      child: AppListRow(
        key: ValueKey('value-${value.id ?? value.value}'),
        title: value.value,
        subtitle: value.group,
        trailing: isSelected ? '✓' : null,
        showChevron: false,
        titleStyle: isSelected
            ? const TextStyle(fontWeight: FontWeight.w600)
            : null,
        onTap: () => _selectValue(value.value),
      ),
    );
    if (!_mayDelete) return row;

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
            _filteredValues.removeWhere((v) => v.id == value.id);
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
    _searchController.dispose();
    super.dispose();
  }
}
