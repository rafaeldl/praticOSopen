import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show Colors, Material, MaterialType, Divider, InkWell;
import 'package:flutter_mobx/flutter_mobx.dart';
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
              largeTitle: const Text('Formulários'),
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                child: const Icon(CupertinoIcons.add),
                onPressed: () {
                  Navigator.pushNamed(context, '/form_template_form')
                      .then((_) => templateStore.retrieveTemplates());
                },
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: CupertinoSearchTextField(
                  controller: _searchController,
                  placeholder: 'Buscar formulário',
                  onChanged: (value) {
                    setState(() => _searchQuery = value.toLowerCase());
                  },
                ),
              ),
            ),

            // List (as Sliver)
            Observer(
              builder: (_) => _buildBody(),
            ),

            // Bottom padding
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (templateStore.templateList == null) {
      return const SliverFillRemaining(
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    if (templateStore.templateList!.hasError) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(CupertinoIcons.exclamationmark_circle,
                  size: 48, color: CupertinoColors.systemRed),
              const SizedBox(height: 16),
              const Text('Erro ao carregar formulários'),
              const SizedBox(height: 16),
              CupertinoButton(
                child: const Text('Tentar novamente'),
                onPressed: () => templateStore.retrieveTemplates(),
              )
            ],
          ),
        ),
      );
    }

    List<FormDefinition?>? templateList = templateStore.templateList!.value;

    if (templateList == null) {
      return const SliverFillRemaining(
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    if (templateList.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(CupertinoIcons.doc_text,
                  size: 64,
                  color: CupertinoColors.systemGrey.resolveFrom(context)),
              const SizedBox(height: 16),
              Text(
                'Nenhum formulário cadastrado',
                style: TextStyle(
                    color: CupertinoColors.secondaryLabel.resolveFrom(context)),
              ),
            ],
          ),
        ),
      );
    }

    // Filter list based on search query
    final filteredList = _searchQuery.isEmpty
        ? templateList.whereType<FormDefinition>().toList()
        : templateList.whereType<FormDefinition>().where((template) {
            final title = template.title.toLowerCase();
            final description = template.description?.toLowerCase() ?? '';
            return title.contains(_searchQuery) ||
                description.contains(_searchQuery);
          }).toList();

    if (filteredList.isEmpty) {
      return const SliverFillRemaining(
        child: Center(
          child: Text('Nenhum resultado encontrado'),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index >= filteredList.length) return null;
          final template = filteredList[index];
          return _buildTemplateItem(
              template, index == filteredList.length - 1);
        },
        childCount: filteredList.length,
      ),
    );
  }

  Widget _buildTemplateItem(FormDefinition template, bool isLast) {
    return Dismissible(
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
                  title: const Text('Confirmar exclusão'),
                  content: Text(
                      'Deseja remover o formulário "${template.title}"?'),
                  actions: [
                    CupertinoDialogAction(
                      child: const Text('Cancelar'),
                      onPressed: () => Navigator.pop(context, false),
                    ),
                    CupertinoDialogAction(
                      isDestructiveAction: true,
                      child: const Text('Remover'),
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
                                  template.title,
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
                                    'Inativo',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: CupertinoColors.secondaryLabel
                                          .resolveFrom(context),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (template.description != null &&
                              template.description!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              template.description!,
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
                            '${template.items.length} ${template.items.length == 1 ? 'item' : 'itens'}',
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
    );
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
