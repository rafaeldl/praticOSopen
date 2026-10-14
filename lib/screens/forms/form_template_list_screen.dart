import 'package:flutter/cupertino.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/mobx/form_template_store.dart';
import 'package:praticos/models/form_definition.dart';
import 'package:praticos/screens/forms/checklists_view.dart';
import 'package:praticos/screens/forms/form_template_form_screen.dart';
import 'package:praticos/screens/widgets/form_sheet.dart';
import 'package:praticos/services/feature_gate_service.dart';
import 'package:praticos/widgets/photo_limit_dialog.dart';

class FormTemplateListScreen extends StatefulWidget {
  @override
  _FormTemplateListScreenState createState() => _FormTemplateListScreenState();
}

class _FormTemplateListScreenState extends State<FormTemplateListScreen> {
  FormTemplateStore templateStore = FormTemplateStore();

  /// Gets the current locale code for i18n (e.g., 'pt', 'en', 'es')
  String? get _localeCode => context.l10n.localeName;

  @override
  void initState() {
    super.initState();
    templateStore.retrieveTemplates();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (_) {
        final companyStream = templateStore.templateList;
        final globalList = templateStore.globalTemplateList?.value;
        return ChecklistsView(
          templates:
              companyStream?.value?.whereType<FormDefinition>().toList() ??
              const [],
          readyTemplates: globalList ?? const [],
          localeCode: _localeCode,
          loading:
              companyStream == null ||
              (!companyStream.hasError && companyStream.value == null),
          error: companyStream?.hasError ?? false,
          onRetry: templateStore.retrieveTemplates,
          // Editing is a focused task: it covers the tab bar, so the screen's
          // one blue button ("Salvar checklist") is the only one.
          onOpen: (template) => Navigator.of(context, rootNavigator: true)
              .pushNamed(
                '/form_template_form',
                arguments: {'template': template},
              )
              .then((_) => templateStore.retrieveTemplates()),
          onDelete: _confirmDelete,
          onPreviewReady: _showGlobalTemplateDetails,
          onUseReady: _importGlobalTemplate,
          onNew: () => FormSheet.show<FormDefinition>(
            context,
            (_) => const FormTemplateFormScreen(asSheet: true),
          ).then((_) => templateStore.retrieveTemplates()),
        );
      },
    );
  }

  Future<bool> _confirmDelete(FormDefinition template) async {
    final title = template.getLocalizedTitle(_localeCode);
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(context.l10n.confirmDelete),
        content: Text('${context.l10n.discard} "$title"?'),
        actions: [
          CupertinoDialogAction(
            child: Text(context.l10n.cancel),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: Text(context.l10n.delete),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;
    await templateStore.deleteTemplate(template);
    return true;
  }

  void _showGlobalTemplateDetails(FormDefinition template) {
    final localizedTitle = template.getLocalizedTitle(_localeCode);
    final localizedDescription = template.getLocalizedDescription(_localeCode);

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(localizedTitle),
        message: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (localizedDescription != null &&
                localizedDescription.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(localizedDescription, style: const TextStyle(fontSize: 14)),
            ],
            const SizedBox(height: 12),
            Text(
              context.l10n.itemCount(template.items.length),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            ...template.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• ${item.getLocalizedLabel(_localeCode)}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          ],
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _importGlobalTemplate(template);
            },
            child: Text(context.l10n.importForMyCompany),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: Text(context.l10n.closeDialog),
        ),
      ),
    );
  }

  Future<void> _importGlobalTemplate(FormDefinition template) async {
    final localizedTitle = template.getLocalizedTitle(_localeCode);

    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(context.l10n.importProcedure),
        content: Text(context.l10n.importConfirmationMessage(localizedTitle)),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.cancel),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.import),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await templateStore.importGlobalTemplate(template);

      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: Text(context.l10n.confirmAction),
            content: Text(context.l10n.procedureImportedSuccessfully),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(ctx),
                child: Text(context.l10n.ok),
              ),
            ],
          ),
        );
      }
    } on FeatureGateLimitException catch (e) {
      if (mounted) showFeatureLimitDialog(context, e.result);
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: Text(context.l10n.error),
            content: Text(context.l10n.couldNotImportProcedure),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(ctx),
                child: Text(context.l10n.ok),
              ),
            ],
          ),
        );
      }
    }
  }
}
