import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:praticos/models/form/form_definition.dart';
import 'package:praticos/mobx/form_store.dart';
import 'package:praticos/theme/app_theme.dart';

class FormTemplateListScreen extends StatefulWidget {
  final FormStore formStore;
  final String orderId;

  const FormTemplateListScreen({
    Key? key,
    required this.formStore,
    required this.orderId,
  }) : super(key: key);

  @override
  _FormTemplateListScreenState createState() => _FormTemplateListScreenState();
}

class _FormTemplateListScreenState extends State<FormTemplateListScreen> {
  @override
  void initState() {
    super.initState();
    widget.formStore.loadAvailableForms();
  }

  @override
  Widget build(BuildContext context) {
    // Determine colors for dark mode support
    final brightness = MediaQuery.of(context).platformBrightness;
    final isDarkMode = brightness == Brightness.dark;

    return CupertinoPageScaffold(
      backgroundColor: isDarkMode ? CupertinoColors.systemGroupedBackground.darkColor : CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text('Adicionar Formulário'),
        previousPageTitle: 'Voltar',
      ),
      child: SafeArea(
        child: Observer(
          builder: (_) {
            if (widget.formStore.isLoading && widget.formStore.availableForms.isEmpty) {
              return Center(child: CupertinoActivityIndicator());
            }

            if (widget.formStore.availableForms.isEmpty) {
              return Center(
                child: Text(
                  'Nenhum modelo de formulário disponível.',
                  style: TextStyle(
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              );
            }

            return ListView(
              children: [
                CupertinoListSection.insetGrouped(
                  header: Text('MODELOS DISPONÍVEIS'),
                  children: widget.formStore.availableForms.map((template) {
                    return CupertinoListTile(
                      title: Text(template.title ?? 'Sem título'),
                      subtitle: template.description != null ? Text(template.description!) : null,
                      trailing: Icon(CupertinoIcons.add_circled),
                      onTap: () async {
                        await widget.formStore.addFormToOrder(widget.orderId, template);
                        Navigator.of(context).pop();
                      },
                    );
                  }).toList(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
