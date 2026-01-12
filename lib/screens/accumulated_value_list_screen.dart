import 'package:flutter/cupertino.dart';
import 'package:praticos/models/accumulated_value.dart';
import 'package:praticos/repositories/accumulated_value_repository.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/global.dart';

/// Screen for selecting or creating accumulated values.
///
/// Displays a searchable list of previously used values sorted by usage count,
/// with an option to add new values.
class AccumulatedValueListScreen extends StatefulWidget {
  const AccumulatedValueListScreen({super.key});

  @override
  State<AccumulatedValueListScreen> createState() =>
      _AccumulatedValueListScreenState();
}

class _AccumulatedValueListScreenState
    extends State<AccumulatedValueListScreen> {
  final _repo = AccumulatedValueRepository();
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
  Set<String> _selectedValues = {}; // Track selected values in multi-select mode
  bool _argumentsLoaded = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterValues);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    debugPrint('AccumulatedValueListScreen.didChangeDependencies: _argumentsLoaded=$_argumentsLoaded');

    // Get arguments once
    if (!_argumentsLoaded) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

      if (args != null) {
        _fieldType = args['fieldType'];
        _title = args['title'] ?? context.l10n.select;
        _multiSelect = args['multiSelect'] ?? false;

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
          final nonNullValues = groupArg.whereType<String>().where((s) => s.isNotEmpty).toList();
          _group = nonNullValues.isNotEmpty ? nonNullValues.join('-') : null;
        } else if (groupArg is String) {
          _group = groupArg;
        } else {
          _group = null;
        }

        // Get companyId from Global automatically
        _companyId = Global.companyAggr?.id;

        debugPrint('AccumulatedValueListScreen: Arguments loaded - companyId=$_companyId, fieldType=$_fieldType, group=$_group, multiSelect=$_multiSelect, currentValue=$_currentValue, selectedValues=$_selectedValues');

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
      _allValues = await _repo.getAll(
        _companyId!,
        _fieldType!,
        group: _group,
      );
      _filteredValues = _allValues;
      debugPrint('AccumulatedValueListScreen: Loaded ${_allValues.length} values');
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

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text(_title ?? context.l10n.select),
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
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: CupertinoSearchTextField(
                controller: _searchController,
                placeholder: context.l10n.searchOrAddNew,
              ),
            ),

            // List
            Expanded(
              child: _isLoading
                  ? const Center(child: CupertinoActivityIndicator())
                  : _buildList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    final searchQuery = _searchController.text.trim();
    final hasSearchQuery = searchQuery.isNotEmpty;

    // If searching and no results, show "Add '{query}'" option
    if (_filteredValues.isEmpty && hasSearchQuery) {
      return ListView(
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => _selectValue(searchQuery),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              color: CupertinoColors.systemBackground.resolveFrom(context),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.add_circled_solid,
                    color: CupertinoTheme.of(context).primaryColor,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${context.l10n.add} "$searchQuery"',
                          style: TextStyle(
                            fontSize: 16,
                            color: CupertinoTheme.of(context).primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Adicionar novo valor',
                          style: TextStyle(
                            fontSize: 13,
                            color: CupertinoColors.secondaryLabel.resolveFrom(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // Empty state (no search query)
    if (_filteredValues.isEmpty) {
      // If there's a current value, show it as an option to add
      if (_currentValue != null && _currentValue!.isNotEmpty) {
        return ListView(
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _selectValue(_currentValue!),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                color: CupertinoColors.systemBackground.resolveFrom(context),
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.add_circled_solid,
                      color: CupertinoTheme.of(context).primaryColor,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${context.l10n.add} "$_currentValue"',
                            style: TextStyle(
                              fontSize: 16,
                              color: CupertinoTheme.of(context).primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Adicionar novo valor',
                            style: TextStyle(
                              fontSize: 13,
                              color: CupertinoColors.secondaryLabel.resolveFrom(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }

      // Otherwise show empty state message
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.square_list,
              size: 64,
              color: CupertinoColors.systemGrey.resolveFrom(context),
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhum valor cadastrado',
              style: TextStyle(
                fontSize: 17,
                color: CupertinoColors.label.resolveFrom(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Digite no campo acima para adicionar',
              style: TextStyle(
                fontSize: 15,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ],
        ),
      );
    }

    // Check if search query exactly matches any existing value
    final exactMatch = hasSearchQuery &&
        _filteredValues.any((v) => v.value.toLowerCase() == searchQuery.toLowerCase());

    // Check if current value is in the list
    final currentValueInList = _currentValue != null && _currentValue!.isNotEmpty &&
        _filteredValues.any((v) => v.value.toLowerCase() == _currentValue!.toLowerCase());

    // Show add option for search query OR current value if not in list
    final showAddOption = (hasSearchQuery && !exactMatch) ||
        (!hasSearchQuery && _currentValue != null && _currentValue!.isNotEmpty && !currentValueInList);

    final valueToAdd = hasSearchQuery ? searchQuery : _currentValue ?? '';

    return ListView.separated(
      itemCount: _filteredValues.length + (showAddOption ? 1 : 0),
      separatorBuilder: (context, index) => Container(
        height: 0.5,
        color: CupertinoColors.separator.resolveFrom(context),
        margin: const EdgeInsets.only(left: 16),
      ),
      itemBuilder: (context, index) {
        // Show "Add new" option at the bottom
        if (showAddOption && index == _filteredValues.length) {
          return CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => _selectValue(valueToAdd),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              color: CupertinoColors.systemBackground.resolveFrom(context),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.add_circled,
                    color: CupertinoTheme.of(context).primaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${context.l10n.add} "$valueToAdd"',
                      style: TextStyle(
                        fontSize: 16,
                        color: CupertinoTheme.of(context).primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final value = _filteredValues[index];
        final isSelected = _multiSelect
            ? _selectedValues.contains(value.value)
            : value.value == _currentValue;

        return Dismissible(
          key: Key(value.id ?? value.value),
          direction: DismissDirection.endToStart,
          background: Container(
            color: CupertinoColors.systemRed,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(
              CupertinoIcons.delete,
              color: CupertinoColors.white,
              size: 24,
            ),
          ),
          confirmDismiss: (direction) async {
            return await showCupertinoDialog<bool>(
              context: context,
              builder: (context) => CupertinoAlertDialog(
                title: Text(context.l10n.delete),
                content: Text('Deseja excluir "${value.value}"?'),
                actions: [
                  CupertinoDialogAction(
                    isDestructiveAction: true,
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(context.l10n.delete),
                  ),
                  CupertinoDialogAction(
                    isDefaultAction: true,
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(context.l10n.cancel),
                  ),
                ],
              ),
            );
          },
          onDismissed: (direction) async {
            if (value.id != null) {
              try {
                await _repo.remove(_companyId!, _fieldType!, value.id!);
                debugPrint('AccumulatedValueListScreen: Deleted value: ${value.value}');
                await _loadValues();
              } catch (e) {
                debugPrint('Error deleting accumulated value: $e');
              }
            }
          },
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => _selectValue(value.value),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: CupertinoColors.systemBackground.resolveFrom(context),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      Text(
                        value.value,
                        style: TextStyle(
                          fontSize: 16,
                          color: CupertinoColors.label.resolveFrom(context),
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      if (value.group != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          value.group!,
                          style: TextStyle(
                            fontSize: 13,
                            color: CupertinoColors.secondaryLabel
                                .resolveFrom(context),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (value.usageCount > 1) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: CupertinoColors.tertiarySystemFill
                          .resolveFrom(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${value.usageCount}',
                      style: TextStyle(
                        fontSize: 12,
                        color: CupertinoColors.secondaryLabel
                            .resolveFrom(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (isSelected)
                  Icon(
                    CupertinoIcons.check_mark,
                    color: CupertinoTheme.of(context).primaryColor,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
