import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/models/form_definition.dart';
import 'package:praticos/models/permission.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/repositories/segment/segment_form_template_repository.dart';
import 'package:praticos/screens/forms/form_template_form_screen.dart';
import 'package:praticos/screens/widgets/form_sheet.dart';
import 'package:praticos/screens/widgets/picker_screen.dart';
import 'package:praticos/services/authorization_service.dart';
import 'package:praticos/services/forms_service.dart';
import 'package:provider/provider.dart';

/// "Qual checklist?": picks a form template for the order ([PickerScaffold]).
///
/// The company's templates come first ("Da empresa"), then the segment's
/// ("Globais"). "+ Novo checklist" opens the template form and reloads.
/// Tapping a row pops with the [FormDefinition].
class FormSelectionScreen extends StatefulWidget {
  final String companyId;

  /// Injected in tests; defaults to [FormsService] + the segment templates.
  final Future<(List<FormDefinition>, List<FormDefinition>)> Function()?
  loadTemplates;

  /// Whether "Novo checklist" shows (`manageForms`); injected in tests.
  final bool Function()? canCreateTemplate;

  const FormSelectionScreen({
    super.key,
    required this.companyId,
    this.loadTemplates,
    this.canCreateTemplate,
  });

  @override
  State<FormSelectionScreen> createState() => _FormSelectionScreenState();
}

class _FormSelectionScreenState extends State<FormSelectionScreen> {
  List<FormDefinition>? _companyTemplates;
  List<FormDefinition>? _globalTemplates;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<(List<FormDefinition>, List<FormDefinition>)> _defaultLoad() async {
    final companyTemplates = await FormsService().getCompanyTemplates(
      widget.companyId,
    );
    var globalTemplates = <FormDefinition>[];
    final segmentId = context.read<SegmentConfigProvider>().segmentId;
    if (segmentId != null && segmentId.isNotEmpty) {
      try {
        globalTemplates = await SegmentFormTemplateRepository()
            .getActiveTemplates(segmentId);
      } catch (_) {
        // Global templates are optional: go on without them.
      }
    }
    return (companyTemplates, globalTemplates);
  }

  Future<void> _loadTemplates() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final (company, global) = await (widget.loadTemplates ?? _defaultLoad)();
      if (!mounted) return;
      setState(() {
        _companyTemplates = company;
        _globalTemplates = global;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  bool get _canCreate =>
      widget.canCreateTemplate?.call() ??
      AuthorizationService.instance.hasPermission(PermissionType.manageForms);

  void _newTemplate() {
    FormSheet.show<FormDefinition>(
      context,
      (_) => const FormTemplateFormScreen(asSheet: true),
    ).then((_) => _loadTemplates());
  }

  PickerItem<FormDefinition> _item(FormDefinition template) {
    final l10n = context.l10n;
    final description = template.getLocalizedDescription(l10n.localeName);
    return PickerItem(
      value: template,
      title: template.getLocalizedTitle(l10n.localeName),
      subtitle: [
        l10n.itemCount(template.items.length),
        if (description != null && description.isNotEmpty) description,
      ].join(' · '),
    );
  }

  bool _matches(FormDefinition t, String query) {
    final locale = context.l10n.localeName;
    return pickerMatches(t.getLocalizedTitle(locale), query) ||
        pickerMatches(t.getLocalizedDescription(locale), query);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final company = _companyTemplates ?? const <FormDefinition>[];
    final global = _globalTemplates ?? const <FormDefinition>[];
    return PickerScaffold<FormDefinition>(
      title: l10n.pickerChecklistTitle,
      itemCount: company.length + global.length,
      searchPlaceholder: l10n.searchProcedure,
      loading: _isLoading,
      hasError: _hasError,
      onRetry: _loadTemplates,
      addLabel: _canCreate ? l10n.pickerNewChecklist : null,
      onAdd: _canCreate ? _newTemplate : null,
      emptyTitle: l10n.noProceduresAvailable,
      sections: (query) {
        final mine = company.where((t) => _matches(t, query));
        final theirs = global.where((t) => _matches(t, query));
        final both = mine.isNotEmpty && theirs.isNotEmpty;
        return [
          PickerSection(
            label: both ? l10n.fromCompany : null,
            items: mine.map(_item).toList(),
          ),
          PickerSection(
            label: both ? l10n.global : null,
            items: theirs.map(_item).toList(),
          ),
        ];
      },
    );
  }
}
