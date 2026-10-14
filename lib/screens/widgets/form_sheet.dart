import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/screens/order/new_order_form.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';

/// Large sheet for creating a record (new customer, vehicle, service), the
/// same pattern as the "Nova OS" (design system rule 9): "X" and "✓" at the
/// top over a gray background, the fields in white cards.
///
/// - The "✓" is gray while [canSave] is false and blue once it is true; while
///   gray, [missingHint] says what is missing, under the first card.
/// - With something filled ([dirty]) the "X" asks before discarding, and
///   dragging the sheet down is locked (when opened with [FormSheet.show]).
/// - The "✓" calls [onSave]; the screen saves and pops with the record.
///   [busy] shows a spinner in its place.
///
/// Wrap it in a [Form] when the fields validate.
class FormSheet extends StatefulWidget {
  const FormSheet({
    super.key,
    required this.title,
    required this.canSave,
    required this.dirty,
    required this.onSave,
    required this.children,
    this.missingHint,
    this.busy = false,
  });

  final String title;
  final bool canSave;

  /// Something was filled: closing asks first.
  final bool dirty;
  final VoidCallback onSave;

  /// The cards ([FormFieldsCard], [FormMoreCard], [FormCard]).
  final List<Widget> children;

  /// What is missing to save ("Escreva o nome para salvar.").
  final String? missingHint;
  final bool busy;

  /// Opens [builder] (whose root is a [FormSheet]) as a large Cupertino sheet
  /// and resolves with what it pops (null when closed).
  static Future<T?> show<T>(BuildContext context, WidgetBuilder builder) {
    return Navigator.of(
      context,
      rootNavigator: true,
    ).push<T>(FormSheetRoute<T>(builder: builder));
  }

  @override
  State<FormSheet> createState() => _FormSheetState();
}

class _FormSheetState extends State<FormSheet> {
  bool _leaving = false;

  void _pop() => Navigator.of(context).pop();

  void _close() {
    if (widget.dirty) {
      _confirmDiscard();
    } else {
      setState(() => _leaving = true);
      _pop();
    }
  }

  Future<void> _confirmDiscard() async {
    final l10n = context.l10n;
    final leave = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(l10n.orderDiscardTitle),
        content: Text(l10n.orderDiscardMessage),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.orderKeepEditing),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.discard),
          ),
        ],
      ),
    );
    if (leave == true && mounted) {
      setState(() => _leaving = true);
      _pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    if (route is FormSheetRoute) {
      final lock = widget.dirty && !_leaving;
      WidgetsBinding.instance.addPostFrameCallback((_) => route.lockDrag(lock));
    }
    final children = [...widget.children];
    // The hint keeps its slot (empty once the form can be saved) so the
    // cards after it keep their state (an open "Mais dados").
    final showHint = !widget.canSave && widget.missingHint != null;
    children.insert(
      children.isEmpty ? 0 : 1,
      showHint
          ? Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.blockMargin + AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.blockMargin + AppSpacing.lg,
                0,
              ),
              child: Text(
                widget.missingHint!,
                key: const ValueKey('form_sheet_missing'),
                style: AppTypography.label.copyWith(
                  color: AppColors.textSecondary.resolveFrom(context),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
    return PopScope(
      canPop: !widget.dirty || _leaving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: CupertinoPageScaffold(
        backgroundColor: AppColors.groupedBackground.resolveFrom(context),
        child: SafeArea(
          child: Column(
            children: [
              NewOrderTopBar(
                title: widget.title,
                onClose: _close,
                onSave: widget.canSave && !widget.busy ? widget.onSave : null,
                busy: widget.busy,
              ),
              Expanded(
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                  children: children,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The sheet route of [FormSheet.show]: a [CupertinoSheetRoute] whose drag to
/// dismiss can be locked while the form has something filled (a
/// [PopScope] alone does not stop the sheet's drag).
class FormSheetRoute<T> extends CupertinoSheetRoute<T> {
  FormSheetRoute({required super.builder, super.settings});

  bool _dragLocked = false;

  @override
  bool get enableDrag => !_dragLocked;

  bool get dragLocked => _dragLocked;

  /// Locks (or unlocks) dragging the sheet down.
  void lockDrag(bool locked) {
    if (_dragLocked == locked || !isActive) return;
    _dragLocked = locked;
    // Rebuilds the transitions, which read [enableDrag].
    changedInternalState();
  }
}

/// White rounded card with text fields ([AppFormField]) stacked inside, no
/// separators (each field has its own label).
class FormFieldsCard extends StatelessWidget {
  const FormFieldsCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.blockMargin,
        AppSpacing.lg,
        AppSpacing.blockMargin,
        0,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kFormCardRadius),
        child: ColoredBox(
          color: AppColors.surface.resolveFrom(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

/// "Mais dados": a card with one line that opens the rarely used fields
/// right there, inside the card (like "Mais opções" of the Nova OS). Closed,
/// it shows [hint] under the title. The fields stay mounted while closed, so
/// what was typed is kept and the [Form] still validates and saves them.
class FormMoreCard extends StatefulWidget {
  const FormMoreCard({
    super.key,
    required this.title,
    required this.children,
    this.hint,
    this.initiallyOpen = false,
  });

  final String title;
  final String? hint;
  final bool initiallyOpen;
  final List<Widget> children;

  @override
  State<FormMoreCard> createState() => _FormMoreCardState();
}

class _FormMoreCardState extends State<FormMoreCard> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final secondary = AppColors.textSecondary.resolveFrom(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.blockMargin,
        AppSpacing.lg,
        AppSpacing.blockMargin,
        0,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kFormCardRadius),
        child: ColoredBox(
          color: AppColors.surface.resolveFrom(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                expanded: _open,
                child: FormRow(
                  key: const ValueKey('form_more'),
                  icon: CupertinoIcons.ellipsis_circle,
                  title: widget.title,
                  subtitle: _open ? null : widget.hint,
                  showChevron: false,
                  trailing: Icon(
                    _open
                        ? CupertinoIcons.chevron_up
                        : CupertinoIcons.chevron_down,
                    size: 18,
                    color: secondary,
                  ),
                  onTap: () => setState(() => _open = !_open),
                ),
              ),
              Visibility(
                visible: _open,
                maintainState: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      height: 0.5,
                      color: AppColors.separator.resolveFrom(context),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ...widget.children,
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
