import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/screens/widgets/add_row.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/screens/widgets/glass_bar_button.dart';
import 'package:praticos/screens/widgets/list_states.dart';
import 'package:praticos/screens/widgets/section_label.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_glass.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';
import 'package:praticos/utils/search_utils.dart';

/// The search field shows only when the list has more than this many items
/// (or when the user already typed something). Product decision.
const int kPickerSearchThreshold = 10;

/// True when [text] contains [query], ignoring case and accents.
bool pickerMatches(String? text, String query) {
  if (query.isEmpty) return true;
  return removeAccents(text ?? '').toLowerCase().contains(
    removeAccents(query).toLowerCase(),
  );
}

/// True when [text] is [query], ignoring case, accents and outer spaces.
bool pickerSameText(String? text, String query) =>
    removeAccents((text ?? '').trim()).toLowerCase() ==
    removeAccents(query.trim()).toLowerCase();

/// One row of a [PickerScaffold].
class PickerItem<T> {
  const PickerItem({
    required this.value,
    required this.title,
    this.subtitle,
    this.subtitleWidget,
    this.leading,
    this.trailing,
    this.selected = false,
    this.key,
    this.wrap,
  });

  /// What the picker returns when the row is tapped.
  final T value;
  final String title;
  final String? subtitle;
  final Widget? subtitleWidget;

  /// E.g. a [StatusDot] for a status or a photo for a vehicle.
  final Widget? leading;

  /// Value at the end of the row (a price). The ✓ comes after it.
  final String? trailing;

  /// Current choice: blue ✓ at the end of the row.
  final bool selected;
  final Key? key;

  /// Wraps the built row, e.g. in a `Dismissible` for swipe to delete.
  final Widget Function(Widget row)? wrap;
}

/// A group of rows, with an optional [SectionLabel] ("Recentes", "Todos",
/// "Mais usados", "Do cliente", "Outros").
class PickerSection<T> {
  const PickerSection({this.label, required this.items});

  final String? label;
  final List<PickerItem<T>> items;
}

/// The single pattern of the "Escolher" screens (choose a customer, a
/// vehicle, a service, a checklist, a status, ...). See
/// `docs/APP_DESIGN_SYSTEM.md`, "Telas de escolher".
///
/// - Pushed screen, glass back button; the large title is the question
///   ([title], "Qual cliente?") with an optional [subtitle] ("de Paulo").
/// - The search ([AppSearchField]) shows under the title only when
///   [itemCount] is above [kPickerSearchThreshold], or once the user typed
///   something, or when [alwaysShowSearch] is set.
/// - First row: "+ Novo …" ([addLabel]/[onAdd]). With a query that matches
///   nothing exactly and [onCreate] set, it becomes "+ Cadastrar “texto”"
///   ([createLabel]) and, when nothing matched at all, a short
///   [noMatchText] sentence follows.
/// - Flat rows, no chevron. Single choice: tapping pops with the value
///   ([onSelect] overrides). Multiple choice ([multiple]): tapping calls
///   [onSelect] (the caller toggles `selected`), and the round ✓ in the top
///   bar ([onConfirm]; gray while null, blue when set) confirms.
/// - Loading, error and empty ([emptyTitle], with the add action) states.
///
/// The caller keeps the data (static list, stream or store) and builds the
/// [sections] for the current query; this widget only keeps the query.
class PickerScaffold<T> extends StatefulWidget {
  const PickerScaffold({
    super.key,
    required this.title,
    required this.sections,
    required this.itemCount,
    this.subtitle,
    this.previousTitle,
    this.searchPlaceholder,
    this.alwaysShowSearch = false,
    this.autofocusSearch = false,
    this.onQueryChanged,
    this.headerRows,
    this.loading = false,
    this.hasError = false,
    this.errorMessage,
    this.onRetry,
    this.addLabel,
    this.onAdd,
    this.onCreate,
    this.createLabel,
    this.canCreate,
    this.noMatchText,
    this.emptyTitle,
    this.emptyMessage,
    this.emptyIcon,
    this.onSelect,
    this.multiple = false,
    this.onConfirm,
    this.strongTitles = true,
    this.enabled = true,
  });

  /// The question, shown as the large title.
  final String title;
  final String? subtitle;
  final String? previousTitle;

  /// Rows for the (trimmed) query. The caller filters.
  final List<PickerSection<T>> Function(String query) sections;

  /// Size of the whole list (before filtering): decides the search.
  final int itemCount;
  final String? searchPlaceholder;
  final bool alwaysShowSearch;
  final bool autofocusSearch;
  final ValueChanged<String>? onQueryChanged;

  /// Extra rows between the add row and the sections (e.g. "Deixar em
  /// branco").
  final List<Widget> Function(String query)? headerRows;

  final bool loading;
  final bool hasError;
  final String? errorMessage;
  final VoidCallback? onRetry;

  /// "+ Novo …" on top. Without [onAdd] the row focuses the search (and
  /// shows it), so the user types the name and gets "Cadastrar “x”".
  final String? addLabel;
  final VoidCallback? onAdd;

  /// Creates from the typed text ("Cadastrar “x”").
  final void Function(String query)? onCreate;

  /// Label of the create row. Defaults to "Cadastrar “x”".
  final String Function(String query)? createLabel;

  /// Whether the create row shows for a query. Defaults to "no row has
  /// exactly that title".
  final bool Function(String query)? canCreate;

  /// Sentence when the query matches nothing. Defaults to "Nada com “x”.".
  final String Function(String query)? noMatchText;

  final String? emptyTitle;
  final String? emptyMessage;
  final IconData? emptyIcon;

  /// Tapping a row. Defaults to popping with the value (single choice).
  final ValueChanged<T>? onSelect;

  /// Multiple choice: shows the ✓ in the top bar.
  final bool multiple;

  /// Confirms a multiple choice. Gray (disabled) while null.
  final VoidCallback? onConfirm;

  /// Titles in semibold (names); off for short options such as a status.
  final bool strongTitles;

  /// False while saving: rows and actions ignore taps.
  final bool enabled;

  @override
  State<PickerScaffold<T>> createState() => _PickerScaffoldState<T>();
}

class _PickerScaffoldState<T> extends State<PickerScaffold<T>> {
  final TextEditingController _search = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _query = '';
  bool _revealed = false;

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  bool get _showSearch =>
      widget.alwaysShowSearch ||
      _revealed ||
      _search.text.isNotEmpty ||
      widget.itemCount > kPickerSearchThreshold;

  void _onChanged(String value) {
    setState(() => _query = value);
    widget.onQueryChanged?.call(value);
  }

  void _focusSearch() {
    setState(() => _revealed = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  void _select(T value) {
    if (!widget.enabled) return;
    if (widget.onSelect != null) {
      widget.onSelect!(value);
    } else {
      Navigator.of(context).pop(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final secondary = AppColors.textSecondary.resolveFrom(context);
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background.resolveFrom(context),
      child: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          AppNavBar(
            largeTitle: Text(widget.title),
            previousTitle: widget.previousTitle,
            trailing: widget.multiple
                ? PickerConfirmButton(
                    onPressed: widget.enabled ? widget.onConfirm : null,
                  )
                : _addButton(),
          ),
          if (widget.subtitle != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageMargin,
                  0,
                  AppSpacing.pageMargin,
                  AppSpacing.xs,
                ),
                child: Text(
                  widget.subtitle!,
                  style: AppTypography.callout.copyWith(color: secondary),
                ),
              ),
            ),
          if (_showSearch)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.blockMargin,
                  AppSpacing.sm,
                  AppSpacing.blockMargin,
                  AppSpacing.xs,
                ),
                child: AppSearchField(
                  controller: _search,
                  focusNode: _searchFocus,
                  autofocus: widget.autofocusSearch,
                  placeholder:
                      widget.searchPlaceholder ?? context.l10n.pickerSearch,
                  onChanged: _onChanged,
                ),
              ),
            ),
          ..._body(),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  /// "+" in the bar for "Novo …" (HIG: adding lives in the top bar).
  Widget? _addButton() {
    final addLabel = widget.addLabel;
    if (addLabel == null) return null;
    final onAdd = widget.onAdd ?? _focusSearch;
    return GlassBarButton(
      key: const ValueKey('picker-add'),
      icon: CupertinoIcons.add,
      label: addLabel,
      onPressed: widget.enabled ? onAdd : null,
    );
  }

  List<Widget> _body() {
    final l10n = context.l10n;
    if (widget.hasError) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ErrorState(
            message: widget.errorMessage,
            onRetry: widget.onRetry ?? () {},
          ),
        ),
      ];
    }
    if (widget.loading) {
      return const [
        SliverFillRemaining(hasScrollBody: false, child: LoadingState()),
      ];
    }

    final query = _query.trim();
    final sections = widget
        .sections(query)
        .where((s) => s.items.isNotEmpty)
        .toList();
    final header = widget.headerRows?.call(query) ?? const <Widget>[];
    final items = [for (final s in sections) ...s.items];
    final addLabel = widget.addLabel;
    final onAdd = widget.onAdd ?? (addLabel == null ? null : _focusSearch);

    if (query.isEmpty &&
        widget.itemCount == 0 &&
        items.isEmpty &&
        header.isEmpty &&
        widget.emptyTitle != null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: widget.emptyIcon,
            title: widget.emptyTitle!,
            message: widget.emptyMessage,
            actionLabel: addLabel,
            onAction: widget.enabled ? onAdd : null,
          ),
        ),
      ];
    }

    final children = <Widget>[];
    final createAllowed =
        query.isNotEmpty &&
        widget.onCreate != null &&
        (widget.canCreate?.call(query) ??
            !items.any((i) => pickerSameText(i.title, query)));
    if (createAllowed) {
      children.add(
        AddRow(
          plain: true,
          label: widget.createLabel?.call(query) ?? l10n.pickerRegister(query),
          onTap: () {
            if (widget.enabled) widget.onCreate!(query);
          },
        ),
      );
      children.add(const PickerSeparator());
    }
    children.addAll(header);

    if (query.isNotEmpty && items.isEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageMargin,
            AppSpacing.md,
            AppSpacing.pageMargin,
            AppSpacing.md,
          ),
          child: Text(
            widget.noMatchText?.call(query) ?? l10n.pickerNoMatch(query),
            style: AppTypography.callout.copyWith(
              color: AppColors.textSecondary.resolveFrom(context),
            ),
          ),
        ),
      );
    }

    for (final section in sections) {
      if (section.label != null) children.add(SectionLabel(section.label!));
      for (var i = 0; i < section.items.length; i++) {
        children.add(_row(section.items[i]));
        if (i < section.items.length - 1) {
          children.add(const PickerSeparator());
        }
      }
    }

    return [SliverList(delegate: SliverChildListDelegate(children))];
  }

  Widget _row(PickerItem<T> item) {
    final row = Container(
      color: AppColors.background.resolveFrom(context),
      child: AppListRow(
        key: item.key,
        leading: item.leading,
        title: item.title,
        subtitle: item.subtitle,
        subtitleWidget: item.subtitleWidget,
        trailing: item.trailing,
        selected: item.selected,
        showChevron: false,
        titleStyle: widget.strongTitles ? AppTypography.bodyStrong : null,
        onTap: () => _select(item.value),
      ),
    );
    return item.wrap?.call(row) ?? row;
  }
}

/// Hairline between picker rows, inset like the text.
class PickerSeparator extends StatelessWidget {
  const PickerSeparator({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageMargin),
      child: Container(
        height: 1,
        color: AppColors.separator.resolveFrom(context),
      ),
    );
  }
}

/// The app's search field: [CupertinoSearchTextField] with the design system
/// colors and body text. Use it instead of styling the field again.
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    this.controller,
    this.focusNode,
    this.placeholder,
    this.onChanged,
    this.autofocus = false,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? placeholder;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final secondary = AppColors.textSecondary.resolveFrom(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSizes.minTouchTarget),
      child: CupertinoSearchTextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: autofocus,
        placeholder: placeholder,
        onChanged: onChanged,
        backgroundColor: AppColors.secondaryFill.resolveFrom(context),
        borderRadius: BorderRadius.circular(AppRadii.field),
        style: AppTypography.callout.copyWith(
          color: AppColors.text.resolveFrom(context),
        ),
        placeholderStyle: AppTypography.callout.copyWith(color: secondary),
        itemColor: secondary,
      ),
    );
  }
}

/// Round ✓ of the top bar that confirms a multiple choice (same as the ✓ of
/// the Nova OS): gray glass while [onPressed] is null, blue when it is set.
class PickerConfirmButton extends StatelessWidget {
  const PickerConfirmButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final icon = Icon(
      CupertinoIcons.checkmark_alt,
      color: enabled
          ? AppColors.onAccent.resolveFrom(context)
          : AppColors.textSecondary.resolveFrom(context),
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: context.l10n.confirm,
      excludeSemantics: true,
      child: CupertinoButton(
        key: const ValueKey('picker_confirm'),
        padding: EdgeInsets.zero,
        minimumSize: const Size(
          AppSizes.minTouchTarget,
          AppSizes.minTouchTarget,
        ),
        onPressed: onPressed,
        child: enabled
            // The one blue action of the screen: opaque, not glass.
            ? Container(
                width: AppSizes.minTouchTarget,
                height: AppSizes.minTouchTarget,
                decoration: BoxDecoration(
                  color: AppColors.accent.resolveFrom(context),
                  shape: BoxShape.circle,
                ),
                child: icon,
              )
            : AppGlass(
                elevated: true,
                borderRadius: BorderRadius.circular(
                  AppSizes.minTouchTarget / 2,
                ),
                child: SizedBox(
                  width: AppSizes.minTouchTarget,
                  height: AppSizes.minTouchTarget,
                  child: icon,
                ),
              ),
      ),
    );
  }
}

/// Pushes a single-choice [PickerScaffold] for a short, fixed list (status,
/// responsible, ...) and returns the tapped value, or null when the user
/// goes back. The option equal to [selected] (or with `selected: true`) gets
/// the ✓. Titles are regular weight; the search shows only above
/// [kPickerSearchThreshold] options and filters by title.
///
/// ```dart
/// final status = await pickOne<String>(
///   context,
///   title: context.l10n.pickerStatusTitle,
///   selected: order.status,
///   options: [
///     for (final s in ['quote', 'approved', 'progress', 'done', 'canceled'])
///       PickerItem(
///         value: s,
///         title: OrderStatusStyle.label(context.l10n, s),
///         leading: StatusDot(color: OrderStatusStyle.dotColor(s)),
///       ),
///   ],
/// );
/// ```
Future<T?> pickOne<T>(
  BuildContext context, {
  required String title,
  required List<PickerItem<T>> options,
  T? selected,
  String? subtitle,
  String? previousTitle,
  bool strongTitles = false,
}) {
  final marked = [
    for (final o in options)
      PickerItem<T>(
        value: o.value,
        title: o.title,
        subtitle: o.subtitle,
        subtitleWidget: o.subtitleWidget,
        leading: o.leading,
        trailing: o.trailing,
        key: o.key,
        wrap: o.wrap,
        selected: o.selected || (selected != null && o.value == selected),
      ),
  ];
  return Navigator.of(context).push<T>(
    CupertinoPageRoute<T>(
      builder: (_) => PickerScaffold<T>(
        title: title,
        subtitle: subtitle,
        previousTitle: previousTitle,
        itemCount: marked.length,
        strongTitles: strongTitles,
        sections: (query) => [
          PickerSection<T>(
            items: [
              for (final o in marked)
                if (pickerMatches(o.title, query)) o,
            ],
          ),
        ],
      ),
    ),
  );
}
