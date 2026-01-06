import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialType, Divider, InkWell;
import 'package:praticos/models/form_definition.dart';
import 'package:praticos/services/forms_service.dart';

class FormSelectionScreen extends StatefulWidget {
  final String segmentId;
  final String? companyId;

  const FormSelectionScreen({
    super.key,
    required this.segmentId,
    this.companyId,
  });

  @override
  _FormSelectionScreenState createState() => _FormSelectionScreenState();
}

class _FormSelectionScreenState extends State<FormSelectionScreen> {
  final FormsService _formsService = FormsService();
  List<FormDefinition>? _templates;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    try {
      final templates = await _formsService.getAvailableTemplates(
        widget.segmentId,
        widget.companyId,
      );
      if (mounted) {
        setState(() {
          _templates = templates;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      print('Erro ao carregar templates: $e');
    }
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
              largeTitle: const Text('Modelos'),
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                child: const Icon(CupertinoIcons.add),
                onPressed: () {
                  // TODO: Navegar para tela de criação de template
                  // Navigator.push(...)
                },
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

    if (_templates == null || _templates!.isEmpty) {
      return SliverFillRemaining(
        child: Center(
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
                'Nenhum modelo disponível',
                style: TextStyle(
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index >= _templates!.length) return null;
          final template = _templates![index];
          final isLast = index == _templates!.length - 1;
          return _buildTemplateItem(template, isLast);
        },
        childCount: _templates!.length,
      ),
    );
  }

  Widget _buildTemplateItem(FormDefinition template, bool isLast) {
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
                  _buildTemplateAvatar(template),
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

  Widget _buildTemplateAvatar(FormDefinition template) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: CupertinoColors.activeBlue.resolveFrom(context).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Icon(
        CupertinoIcons.doc_text,
        size: 24,
        color: CupertinoColors.activeBlue.resolveFrom(context),
      ),
    );
  }
}
