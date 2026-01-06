import 'package:flutter/cupertino.dart';
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
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Selecionar Formulário'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      child: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CupertinoActivityIndicator());
    }

    if (_templates == null || _templates!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.doc_text_search,
              size: 64,
              color: CupertinoColors.systemGrey3.resolveFrom(context),
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhum formulário disponível',
              style: TextStyle(
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return CupertinoListSection.insetGrouped(
      header: const Text('MODELOS DISPONÍVEIS'),
      children: _templates!.map((template) {
        return CupertinoListTile(
          title: Text(template.title),
          subtitle: template.description != null && template.description!.isNotEmpty
              ? Text(
                  template.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                )
              : null,
          leading: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              // Usando withValues para evitar warning de depreciação do withOpacity
              color: CupertinoColors.activeBlue.resolveFrom(context).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(CupertinoIcons.doc_text, size: 20),
          ),
          trailing: const Icon(CupertinoIcons.add_circled, color: CupertinoColors.activeBlue),
          onTap: () {
            Navigator.of(context).pop(template);
          },
        );
      }).toList(),
    );
  }
}