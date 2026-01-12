import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialType, Divider, InkWell;
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/models/form_definition.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/repositories/segment/segment_form_template_repository.dart';
import 'package:praticos/services/forms_service.dart';
import 'package:provider/provider.dart';

class FormSelectionScreen extends StatefulWidget {
  final String companyId;

  const FormSelectionScreen({
    super.key,
    required this.companyId,
  });

  @override
  _FormSelectionScreenState createState() => _FormSelectionScreenState();
}

class _FormSelectionScreenState extends State<FormSelectionScreen> {
  final FormsService _formsService = FormsService();
  final SegmentFormTemplateRepository _segmentRepository = SegmentFormTemplateRepository();
  final TextEditingController _searchController = TextEditingController();

  List<FormDefinition>? _companyTemplates;
  List<FormDefinition>? _globalTemplates;
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTemplates() async {
    try {
      // Carrega templates da empresa
      final companyTemplates = await _formsService.getCompanyTemplates(widget.companyId);

      // Carrega templates globais do segmento
      List<FormDefinition> globalTemplates = [];
      final segmentProvider = context.read<SegmentConfigProvider>();
      final segmentId = segmentProvider.segmentId;

      if (segmentId != null && segmentId.isNotEmpty) {
        try {
          globalTemplates = await _segmentRepository.getActiveTemplates(segmentId);
        } catch (e) {
          // Ignora erro ao carregar globais - continua sem eles
        }
      }

      if (mounted) {
        setState(() {
          _companyTemplates = companyTemplates;
          _globalTemplates = globalTemplates;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<FormDefinition> _filterTemplates(List<FormDefinition> templates) {
    if (_searchQuery.isEmpty) return templates;
    return templates.where((template) {
      final title = template.title.toLowerCase();
      final description = template.description?.toLowerCase() ?? '';
      return title.contains(_searchQuery) || description.contains(_searchQuery);
    }).toList();
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
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                child: const Icon(CupertinoIcons.add),
                onPressed: () {
                  Navigator.pushNamed(context, '/form_template_form').then((_) {
                    _loadTemplates();
                  });
                },
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: CupertinoSearchTextField(
                  controller: _searchController,
                  placeholder: context.l10n.searchProcedure,
                  onChanged: (value) {
                    setState(() => _searchQuery = value.toLowerCase());
                  },
                ),
              ),
            ),
            _buildBody(),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const SliverFillRemaining(
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    final filteredCompanyTemplates = _companyTemplates != null
        ? _filterTemplates(_companyTemplates!)
        : <FormDefinition>[];
    final filteredGlobalTemplates = _globalTemplates != null
        ? _filterTemplates(_globalTemplates!)
        : <FormDefinition>[];

    final hasCompanyTemplates = filteredCompanyTemplates.isNotEmpty;
    final hasGlobalTemplates = filteredGlobalTemplates.isNotEmpty;

    if (!hasCompanyTemplates && !hasGlobalTemplates) {
      return SliverFillRemaining(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.doc_text_search,
                  size: 64,
                  color: CupertinoColors.systemGrey.resolveFrom(context),
                ),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isEmpty
                      ? context.l10n.noProceduresAvailable
                      : context.l10n.noResultsFound,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
                ),
                if (_searchQuery.isEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.tapPlusToCreateFirst,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: CupertinoColors.secondaryLabel.resolveFrom(context),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildListDelegate([
        // Seção: Templates da Empresa
        if (hasCompanyTemplates) ...[
          _buildSectionHeader(context.l10n.fromCompany),
          ..._buildTemplateList(filteredCompanyTemplates),
        ],

        // Seção: Templates Globais
        if (hasGlobalTemplates) ...[
          _buildSectionHeader(context.l10n.global),
          ..._buildTemplateList(filteredGlobalTemplates, isGlobal: true),
        ],
      ]),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 24, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
        ),
      ),
    );
  }

  List<Widget> _buildTemplateList(List<FormDefinition> templates, {bool isGlobal = false}) {
    return templates.asMap().entries.map((entry) {
      final index = entry.key;
      final template = entry.value;
      final isLast = index == templates.length - 1;
      return _buildTemplateItem(template, isLast, isGlobal: isGlobal);
    }).toList();
  }

  Widget _buildTemplateItem(FormDefinition template, bool isLast, {bool isGlobal = false}) {
    return Container(
      color: CupertinoColors.systemBackground.resolveFrom(context),
      child: InkWell(
        onTap: () {
          Navigator.of(context).pop(template);
        },
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  // Avatar
                  _buildTemplateAvatar(template, isGlobal: isGlobal),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          template.title,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: CupertinoColors.label.resolveFrom(context),
                          ),
                        ),
                        if (template.description != null &&
                            template.description!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            template.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              color: CupertinoColors.secondaryLabel.resolveFrom(context),
                            ),
                          ),
                        ],
                        const SizedBox(height: 2),
                        Text(
                          context.l10n.itemCount(template.items.length),
                          style: TextStyle(
                            fontSize: 13,
                            color: CupertinoColors.systemGrey.resolveFrom(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    CupertinoIcons.chevron_right,
                    size: 16,
                    color: CupertinoColors.systemGrey3.resolveFrom(context),
                  ),
                ],
              ),
            ),
            if (!isLast)
              Divider(
                height: 1,
                indent: 76, // Avatar (48) + Padding (16+12)
                color: CupertinoColors.systemGrey5.resolveFrom(context),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateAvatar(FormDefinition template, {bool isGlobal = false}) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: isGlobal
            ? CupertinoColors.systemBlue.withValues(alpha: 0.15)
            : CupertinoColors.systemTeal.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Icon(
        isGlobal ? CupertinoIcons.globe : CupertinoIcons.doc_text_fill,
        size: 24,
        color: isGlobal
            ? CupertinoColors.systemBlue
            : CupertinoColors.systemTeal,
      ),
    );
  }
}
