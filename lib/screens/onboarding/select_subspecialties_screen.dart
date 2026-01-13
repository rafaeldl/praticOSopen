import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/mobx/auth_store.dart';
import 'package:praticos/screens/onboarding/confirm_bootstrap_screen.dart';

class SelectSubspecialtiesScreen extends StatefulWidget {
  final AuthStore authStore;
  final String? companyId;
  final String companyName;
  final String address;
  final String phone;
  final String email;
  final String? site;
  final XFile? logoFile;
  final String segmentId;
  final String segmentName;
  final List<Map<String, dynamic>> subspecialties;

  const SelectSubspecialtiesScreen({
    super.key,
    required this.authStore,
    this.companyId,
    required this.companyName,
    required this.address,
    required this.phone,
    required this.email,
    this.site,
    this.logoFile,
    required this.segmentId,
    required this.segmentName,
    required this.subspecialties,
  });

  @override
  State<SelectSubspecialtiesScreen> createState() =>
      _SelectSubspecialtiesScreenState();
}

class _SelectSubspecialtiesScreenState
    extends State<SelectSubspecialtiesScreen> {
  final Set<String> _selectedIds = {};

  /// Extrai string localizada de um valor que pode ser String ou Map
  String _localized(dynamic value, String locale) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is Map) {
      return value[locale] as String? ??
          value['pt-BR'] as String? ??
          (value.values.isNotEmpty ? value.values.first.toString() : '');
    }
    return value.toString();
  }

  /// Obtém o locale atual do dispositivo
  String get _currentLocale {
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    final languageTag = '${locale.languageCode}-${locale.countryCode ?? ''}';
    // Mapeia para os locales suportados
    if (languageTag.startsWith('pt')) return 'pt-BR';
    if (languageTag.startsWith('es')) return 'es-ES';
    return 'en-US';
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _continue() {
    if (_selectedIds.isEmpty) {
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: Text(context.l10n.selectAtLeastOne),
          content: Text(context.l10n.pleaseSelectAtLeastOneSpecialty),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.l10n.ok),
            ),
          ],
        ),
      );
      return;
    }

    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => ConfirmBootstrapScreen(
          authStore: widget.authStore,
          companyId: widget.companyId,
          companyName: widget.companyName,
          address: widget.address,
          phone: widget.phone,
          email: widget.email,
          site: widget.site,
          logoFile: widget.logoFile,
          segmentId: widget.segmentId,
          subspecialties: _selectedIds.toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text(context.l10n.specialties),
      ),
      child: SafeArea(
        child: DefaultTextStyle(
          style: CupertinoTheme.of(context).textTheme.textStyle,
          child: Column(
            children: [
              // Cabeçalho explicativo
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(
                      CupertinoIcons.checkmark_seal,
                      size: 48,
                      color: CupertinoColors.activeBlue,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.segmentName,
                      style: CupertinoTheme.of(context)
                          .textTheme
                          .navLargeTitleTextStyle,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.selectSpecialtiesDescription,
                      textAlign: TextAlign.center,
                      style:
                          CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                                color: CupertinoColors.secondaryLabel
                                    .resolveFrom(context),
                                fontSize: 16,
                              ),
                    ),
                  ],
                ),
              ),

              // Lista de subspecialties com checkboxes
              Expanded(
                child: SingleChildScrollView(
                  child: CupertinoListSection.insetGrouped(
                    header: Text(context.l10n.availableSpecialties),
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    children: widget.subspecialties.map((subspecialty) {
                      final locale = _currentLocale;
                      final id = subspecialty['id'] as String;
                      final name = _localized(subspecialty['name'], locale);
                      final icon = subspecialty['icon'] as String? ?? '🔧';
                      final description =
                          _localized(subspecialty['description'], locale);
                      final isSelected = _selectedIds.contains(id);

                      return CupertinoListTile.notched(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        leading: Text(
                          icon,
                          style: CupertinoTheme.of(context)
                              .textTheme
                              .textStyle
                              .copyWith(fontSize: 24),
                        ),
                        title: Text(
                          name.isEmpty ? context.l10n.noName : name,
                          style: CupertinoTheme.of(context)
                              .textTheme
                              .textStyle
                              .copyWith(fontWeight: FontWeight.w500),
                        ),
                        subtitle: description.isNotEmpty
                            ? Text(
                                description,
                                style: CupertinoTheme.of(context)
                                    .textTheme
                                    .textStyle
                                    .copyWith(
                                      fontSize: 13,
                                      color: CupertinoColors.secondaryLabel
                                          .resolveFrom(context),
                                    ),
                              )
                            : null,
                        trailing: Icon(
                          isSelected
                              ? CupertinoIcons.checkmark_circle_fill
                              : CupertinoIcons.circle,
                          color: isSelected
                              ? CupertinoColors.activeBlue
                              : CupertinoColors.systemGrey3,
                          size: 24,
                        ),
                        onTap: () => _toggleSelection(id),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // Botão continuar
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: CupertinoButton.filled(
                    onPressed: _selectedIds.isNotEmpty ? _continue : null,
                    child: Text(
                      _selectedIds.isEmpty
                          ? context.l10n.selectAtLeastOneOption
                          : context.l10n.continueWithCount(_selectedIds.length),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
