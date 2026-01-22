import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show Colors, Material, MaterialType, Divider, InkWell;
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/mobx/form_template_store.dart';
import 'package:praticos/models/form_definition.dart';

class FormTemplateListScreen extends StatefulWidget {
  @override
  _FormTemplateListScreenState createState() => _FormTemplateListScreenState();
}

class _FormTemplateListScreenState extends State<FormTemplateListScreen> {
  FormTemplateStore templateStore = FormTemplateStore();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  /// Gets the current locale code for i18n (e.g., 'pt', 'en', 'es')
  String? get _localeCode => context.l10n.localeName;

  @override
  void initState() {
    super.initState();
    templateStore.retrieveTemplates();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: Material(
        type: MaterialType.transparency,
        child: CustomScrollView(
          slivers: [
            CupertinoSliverNavigationBar(
              largeTitle: Text(context.l10n.procedures),
              trailing: Semantics(
                identifier: 'form_list_add_button',
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: const Icon(CupertinoIcons.add),
                  onPressed: () {
                    Navigator.pushNamed(context, '/form_template_form')
                        .then((_) => templateStore.retrieveTemplates());
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Semantics(
                  identifier: 'form_list_search_field',
                  child: CupertinoSearchTextField(
                    controller: _searchController,
                    placeholder: context.l10n.searchProcedure,
                    onChanged: (value) {
                      setState(() => _searchQuery = value.toLowerCase());
                    },
                  ),
                ),
              ),
            ),

            // Company Templates
            Observer(
              builder: (_) => _buildCompanyTemplates(),
            ),

            // Global Templates
            Observer(
              builder: (_) => _buildGlobalTemplates(),
            ),

            // Bottom padding
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanyTemplates() {
    if (templateStore.templateList == null) {
      return const SliverToBoxAdapter(
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    if (templateStore.templateList!.hasError) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.exclamationmark_circle,
                    size: 48, color: CupertinoColors.systemRed),
                const SizedBox(height: 16),
                Text(context.l10n.errorLoadingProcedures),
                const SizedBox(height: 16),
                CupertinoButton(
                  child: Text(context.l10n.tryAgain),
                  onPressed: () => templateStore.retrieveTemplates(),
                )
              ],
            ),
          ),
        ),
      );
    }

    List<FormDefinition?>? templateList = templateStore.templateList!.value;

    if (templateList == null) {
      return const SliverToBoxAdapter(
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    // Filter list based on search query
    final filteredList = _searchQuery.isEmpty
        ? templateList.whereType<FormDefinition>().toList()
        : templateList.whereType<FormDefinition>().where((template) {
            final title = template.getLocalizedTitle(_localeCode).toLowerCase();
            final description = template.getLocalizedDescription(_localeCode)?.toLowerCase() ?? '';
            return title.contains(_searchQuery) ||
                description.contains(_searchQuery);
          }).toList();

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          // Header
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(32, 16, 16, 8),
              child: Text(
                context.l10n.myProcedures.toUpperCase(),
                style: TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }

          // Empty state
          if (filteredList.isEmpty && index == 1) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    Icon(CupertinoIcons.doc_text,
                        size: 48,
                        color: CupertinoColors.systemGrey.resolveFrom(context)),
                    const SizedBox(height: 12),
                    Text(
                      _searchQuery.isEmpty
                          ? context.l10n.noProceduresRegistered
                          : context.l10n.noResultsFound,
                      style: TextStyle(
                          color:
                              CupertinoColors.secondaryLabel.resolveFrom(context)),
                    ),
                  ],
                ),
              ),
            );
          }

          if (filteredList.isEmpty) return null;

          final templateIndex = index - 1;
          if (templateIndex >= filteredList.length) return null;

          final template = filteredList[templateIndex];
          return _buildTemplateItem(
              template, templateIndex == filteredList.length - 1);
        },
        childCount: filteredList.isEmpty ? 2 : filteredList.length + 1,
      ),
    );
  }

  Widget _buildGlobalTemplates() {
    if (templateStore.globalTemplateList == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    if (templateStore.globalTemplateList!.value == null) {
      return const SliverToBoxAdapter(
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    final globalList = templateStore.globalTemplateList!.value!;

    // Filter based on search query
    final filteredGlobalList = _searchQuery.isEmpty
        ? globalList
        : globalList.where((template) {
            final title = template.getLocalizedTitle(_localeCode).toLowerCase();
            final description = template.getLocalizedDescription(_localeCode)?.toLowerCase() ?? '';
            return title.contains(_searchQuery) ||
                description.contains(_searchQuery);
          }).toList();

    if (filteredGlobalList.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          // Header
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(32, 24, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.globalProcedures.toUpperCase(),
                      style: TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.secondaryLabel.resolveFrom(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    CupertinoIcons.globe,
                    size: 14,
                    color: CupertinoColors.systemGrey.resolveFrom(context),
                  ),
                ],
              ),
            );
          }

          final templateIndex = index - 1;
          if (templateIndex >= filteredGlobalList.length) return null;

          final template = filteredGlobalList[templateIndex];
          return _buildGlobalTemplateItem(
              template, templateIndex == filteredGlobalList.length - 1);
        },
        childCount: filteredGlobalList.length + 1,
      ),
    );
  }

  Widget _buildTemplateItem(FormDefinition template, bool isLast) {
    final localizedTitle = template.getLocalizedTitle(_localeCode);
    final localizedDescription = template.getLocalizedDescription(_localeCode);

    return Semantics(
      identifier: 'form_item_${template.id}',
      child: Dismissible(
      key: Key(template.id!),
      direction: DismissDirection.horizontal,
      background: Container(
        color: CupertinoColors.systemBlue,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(CupertinoIcons.pencil, color: Colors.white),
      ),
      secondaryBackground: Container(
        color: CupertinoColors.systemRed,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(CupertinoIcons.trash, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Swipe Right -> Edit
          Navigator.pushNamed(
            context,
            '/form_template_form',
            arguments: {'template': template},
          ).then((_) => templateStore.retrieveTemplates());
          return false;
        } else {
          // Swipe Left -> Delete
          return await showCupertinoDialog<bool>(
                context: context,
                builder: (context) => CupertinoAlertDialog(
                  title: Text(context.l10n.confirmDelete),
                  content: Text(
                      '${context.l10n.discard} "$localizedTitle"?'),
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
              ) ??
              false;
        }
      },
      onDismissed: (_) {
        templateStore.deleteTemplate(template);
      },
      child: Container(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: InkWell(
          onTap: () {
            Navigator.pushNamed(
              context,
              '/form_template_form',
              arguments: {'template': template},
            ).then((_) => templateStore.retrieveTemplates());
          },
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    // Icon
                    _buildTemplateIcon(template),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  localizedTitle,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: CupertinoColors.label
                                        .resolveFrom(context),
                                  ),
                                ),
                              ),
                              if (!template.isActive)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: CupertinoColors.systemGrey4
                                        .resolveFrom(context),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    context.l10n.inactive,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: CupertinoColors.secondaryLabel
                                          .resolveFrom(context),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (localizedDescription != null &&
                              localizedDescription.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              localizedDescription,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                color: CupertinoColors.secondaryLabel
                                    .resolveFrom(context),
                              ),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            context.l10n.itemCount(template.items.length),
                            style: TextStyle(
                              fontSize: 13,
                              color: CupertinoColors.systemGrey
                                  .resolveFrom(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(CupertinoIcons.chevron_right,
                        size: 16,
                        color: CupertinoColors.systemGrey3.resolveFrom(context)),
                  ],
                ),
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  indent: 76, // Icon (48) + Padding (16+12)
                  color: CupertinoColors.systemGrey5.resolveFrom(context),
                ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildGlobalTemplateItem(FormDefinition template, bool isLast) {
    final localizedTitle = template.getLocalizedTitle(_localeCode);
    final localizedDescription = template.getLocalizedDescription(_localeCode);

    return Container(
      color: CupertinoColors.systemBackground.resolveFrom(context),
      child: InkWell(
        onTap: () => _showGlobalTemplateDetails(template),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemBlue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      CupertinoIcons.globe,
                      color: CupertinoColors.systemBlue,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localizedTitle,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: CupertinoColors.label.resolveFrom(context),
                          ),
                        ),
                        if (localizedDescription != null &&
                            localizedDescription.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            localizedDescription,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              color: CupertinoColors.secondaryLabel
                                  .resolveFrom(context),
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          context.l10n.itemCount(template.items.length),
                          style: TextStyle(
                            fontSize: 13,
                            color:
                                CupertinoColors.systemGrey.resolveFrom(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => _importGlobalTemplate(template),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: CupertinoColors.activeBlue,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        context.l10n.import,
                        style: const TextStyle(
                          color: CupertinoColors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!isLast)
              Divider(
                height: 1,
                indent: 76, // Icon (48) + Padding (16+12)
                color: CupertinoColors.systemGrey5.resolveFrom(context),
              ),
          ],
        ),
      ),
    );
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
              Text(
                localizedDescription,
                style: const TextStyle(fontSize: 14),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              context.l10n.itemCount(template.items.length),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            ...template.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• ${item.getLocalizedLabel(_localeCode)}',
                    style: const TextStyle(fontSize: 13),
                  ),
                )),
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
        content: Text(
            context.l10n.importConfirmationMessage(localizedTitle)),
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

  Widget _buildTemplateIcon(FormDefinition template) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: template.isActive
            ? CupertinoColors.systemTeal.withValues(alpha: 0.15)
            : CupertinoColors.systemGrey5.resolveFrom(context),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Icon(
        CupertinoIcons.doc_text_fill,
        color: template.isActive
            ? CupertinoColors.systemTeal
            : CupertinoColors.systemGrey.resolveFrom(context),
        size: 24,
      ),
    );
  }
}
