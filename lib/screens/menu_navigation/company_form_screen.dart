import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';
import 'package:praticos/global.dart';
import 'package:praticos/mobx/company_store.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/widgets/cached_image.dart';
import 'package:praticos/widgets/dynamic_text_field.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/extensions/context_extensions.dart';

class CompanyFormScreen extends StatefulWidget {
  const CompanyFormScreen({super.key});

  @override
  State<CompanyFormScreen> createState() => _CompanyFormScreenState();
}

class _CompanyFormScreenState extends State<CompanyFormScreen> {
  final CompanyStore _companyStore = CompanyStore();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isLoading = true;
  Company? _company;
  Map<String, dynamic>? _selectedSegment;

  String _currentLocaleTag(BuildContext context) {
    final locale = Localizations.localeOf(context);
    if (locale.languageCode == 'pt') return 'pt-BR';
    if (locale.languageCode == 'es') return 'es-ES';
    return 'en-US';
  }

  String _localizedValue(dynamic value, String locale) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is Map) {
      return value[locale] as String? ??
          value['pt-BR'] as String? ??
          (value.values.isNotEmpty ? value.values.first.toString() : '');
    }
    return value.toString();
  }

  String _segmentDisplayName(Map<String, dynamic> segment) {
    final locale = _currentLocaleTag(context);
    return _localizedValue(segment['nameI18n'] ?? segment['name'], locale);
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    if (Global.companyAggr?.id != null) {
      _company = await _companyStore.retrieveCompany(Global.companyAggr!.id);

      if (mounted) {
        final provider = context.read<SegmentConfigProvider>();

        // 1. Carrega o segmento primeiro
        if (_company?.segment != null) {
          await _loadSegment(_company!.segment!);
          await provider.initialize(_company!.segment!);
        }

        // 2. Depois seta o país (após segmento carregado)
        // Se não tem país definido, usa BR como padrão
        provider.setCountry(_company?.country ?? 'BR');
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _loadSegment(String segmentId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('segments')
          .doc(segmentId)
          .get();
      if (doc.exists) {
        setState(() {
          _selectedSegment = {'id': segmentId, ...doc.data()!};
        });
      }
    } catch (e) {
      // Ignorar erro silenciosamente
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_company == null) return;

    _formKey.currentState!.save();
    setState(() => _isLoading = true);

    try {
      _company!
        ..updatedAt = DateTime.now()
        ..updatedBy = Global.userAggr;

      await _companyStore.updateCompany(_company!);

      if (Global.companyAggr != null && _company!.id == Global.companyAggr!.id) {
        Global.companyAggr!.name = _company!.name;
        Global.companyAggr!.country = _company!.country;

        final provider = context.read<SegmentConfigProvider>();

        // Atualiza segmento se mudou
        if (_company!.segment != null && mounted && provider.segmentId != _company!.segment) {
          provider.initialize(_company!.segment!);
        }

        // Atualiza país no provider
        if (mounted && _company!.country != null) {
          provider.setCountry(_company!.country!);
        }
      }
      
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      // Handle error quietly or show simple alert if needed, adhering to UX guidelines implies avoiding snackbars if possible or using CupertinoDialog
      // For now, simple return or print
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickSegment() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('segments')
          .where('active', isEqualTo: true)
          .orderBy('name')
          .get();

      final segments = snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();

      if (segments.isEmpty) return;

      if (!mounted) return;

      showCupertinoModalPopup(
        context: context,
        builder: (BuildContext context) => CupertinoActionSheet(
          title: Text(context.l10n.selectSegment),
          message: Text(context.l10n.chooseCompanySegment),
          actions: segments.map((segment) {
            final segmentName = _segmentDisplayName(segment);
            return CupertinoActionSheetAction(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    segment['icon'] ?? '🔧',
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 8),
                  Text(segmentName.isEmpty ? context.l10n.noName : segmentName),
                ],
              ),
              onPressed: () {
                setState(() {
                  _selectedSegment = segment;
                  _company?.segment = segment['id'];
                });
                Navigator.pop(context);
              },
            );
          }).toList(),
          cancelButton: CupertinoActionSheetAction(
            child: Text(context.l10n.cancel),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      );
    } catch (e) {
      // Ignorar erro silenciosamente
    }
  }

  Future<void> _pickCountry() async {
    // Usa IsoCode.values da phone_numbers_parser
    // Lista apenas os países mais comuns primeiro
    final priorityCountries = ['BR', 'US', 'PT', 'ES', 'MX'];
    final allIsoCodes = IsoCode.values.toList();

    // Separa em prioridade e resto
    final priority = allIsoCodes.where((iso) => priorityCountries.contains(iso.name)).toList();
    final others = allIsoCodes.where((iso) => !priorityCountries.contains(iso.name)).toList();

    // Ordena prioridade pela lista priorityCountries
    priority.sort((a, b) => priorityCountries.indexOf(a.name).compareTo(priorityCountries.indexOf(b.name)));
    // Ordena o resto alfabeticamente
    others.sort((a, b) => a.name.compareTo(b.name));

    final sortedIsoCodes = [...priority, ...others];

    if (!mounted) return;

    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: Text(context.l10n.selectCountry),
        message: const Text('Selecione o país da empresa'),
        actions: sortedIsoCodes.take(50).map((isoCode) {
          return CupertinoActionSheetAction(
            child: Text('${_getCountryFlag(isoCode.name)} ${_getCountryName(isoCode.name)}'),
            onPressed: () {
              setState(() {
                _company?.country = isoCode.name;
              });

              // Atualiza o país no provider imediatamente
              if (mounted) {
                final provider = context.read<SegmentConfigProvider>();
                provider.setCountry(isoCode.name);
              }

              Navigator.pop(context);
            },
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          child: Text(context.l10n.cancel),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  String _getCountryFlag(String countryCode) {
    // Retorna emoji da bandeira baseado no código ISO
    final int firstLetter = countryCode.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final int secondLetter = countryCode.codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(firstLetter) + String.fromCharCode(secondLetter);
  }

  String _getCountryName(String countryCode) {
    // Nomes em português dos países mais comuns
    switch (countryCode) {
      case 'BR':
        return 'Brasil';
      case 'US':
        return 'Estados Unidos';
      case 'PT':
        return 'Portugal';
      case 'ES':
        return 'Espanha';
      case 'MX':
        return 'México';
      case 'AR':
        return 'Argentina';
      case 'CL':
        return 'Chile';
      case 'CO':
        return 'Colômbia';
      case 'PE':
        return 'Peru';
      case 'UY':
        return 'Uruguai';
      case 'FR':
        return 'França';
      case 'IT':
        return 'Itália';
      case 'DE':
        return 'Alemanha';
      case 'GB':
        return 'Reino Unido';
      case 'CA':
        return 'Canadá';
      default:
        // Para outros, retorna o código ISO
        return countryCode;
    }
  }

  Future<void> _pickImage() async {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: Text(context.l10n.changeLogo),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            child: Text(context.l10n.takePhoto),
            onPressed: () async {
              Navigator.pop(context);
              final file = await _companyStore.photoService.takePhoto();
              if (file != null && _company != null) {
                await _companyStore.uploadCompanyLogo(file, _company!);
                setState(() {});
              }
            },
          ),
          CupertinoActionSheetAction(
            child: Text(context.l10n.chooseFromGallery),
            onPressed: () async {
              Navigator.pop(context);
              final file = await _companyStore.photoService.pickImageFromGallery();
              if (file != null && _company != null) {
                await _companyStore.uploadCompanyLogo(file, _company!);
                setState(() {});
              }
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: Text(context.l10n.cancel),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<SegmentConfigProvider>();

    // Mostra loading enquanto carrega empresa OU segmento
    if (_isLoading || (_company != null && config.isLoading)) {
      return const CupertinoPageScaffold(
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    if (_company == null) {
      return CupertinoPageScaffold(
        child: Center(child: Text(context.l10n.companyNotFound)),
      );
    }

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text(context.l10n.companyData),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const CupertinoActivityIndicator()
              : Text(context.l10n.save, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const SizedBox(height: 20),

              // Logo Section
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Observer(
                    builder: (_) => Stack(
                      children: [
                        if (_company?.logo != null && _company!.logo!.isNotEmpty)
                          ClipOval(
                            child: CachedImage(
                              imageUrl: _company!.logo!,
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                          )
                        else
                          Container(
                            width: 100,
                            height: 100,
                            decoration: const BoxDecoration(
                              color: CupertinoColors.systemGrey5,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.business,
                              size: 50,
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                        if (_companyStore.isUploading)
                          Positioned.fill(
                            child: Container(
                              decoration: const BoxDecoration(
                                color: CupertinoColors.black,
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: CupertinoActivityIndicator(color: CupertinoColors.white),
                              ),
                            ),
                          ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: CupertinoColors.activeBlue,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              CupertinoIcons.camera_fill,
                              size: 16,
                              color: CupertinoColors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Form Fields
              CupertinoListSection.insetGrouped(
                children: [
                  CupertinoTextFormFieldRow(
                    prefix: Text(context.l10n.name),
                    initialValue: _company?.name,
                    placeholder: context.l10n.companyNamePlaceholder,
                    textCapitalization: TextCapitalization.words,
                    textAlign: TextAlign.right,
                    onSaved: (val) => _company?.name = val,
                    validator: (val) => val == null || val.isEmpty ? context.l10n.required : null,
                  ),
                  GestureDetector(
                    onTap: _pickSegment,
                    child: CupertinoFormRow(
                      prefix: Text(context.l10n.segment),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16.0), // Respiro entre label e valor
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Text(
                                _selectedSegment != null
                                    ? (_segmentDisplayName(_selectedSegment!).isEmpty
                                        ? context.l10n.select
                                        : _segmentDisplayName(_selectedSegment!))
                                    : context.l10n.select,
                                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                                  color: _selectedSegment != null
                                      ? CupertinoColors.label.resolveFrom(context)
                                      : CupertinoColors.placeholderText.resolveFrom(context),
                                ),
                                textAlign: TextAlign.right,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              CupertinoIcons.chevron_forward,
                              size: 20,
                              color: CupertinoColors.systemGrey2.resolveFrom(context),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _pickCountry,
                    child: CupertinoFormRow(
                      prefix: Text(context.l10n.country),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Text(
                                _company?.country != null
                                    ? _getCountryName(_company!.country!)
                                    : context.l10n.select,
                                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                                  color: _company?.country != null
                                      ? CupertinoColors.label.resolveFrom(context)
                                      : CupertinoColors.placeholderText.resolveFrom(context),
                                ),
                                textAlign: TextAlign.right,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              CupertinoIcons.chevron_forward,
                              size: 20,
                              color: CupertinoColors.systemGrey2.resolveFrom(context),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  CupertinoTextFormFieldRow(
                    prefix: Text(context.l10n.email),
                    initialValue: _company?.email,
                    placeholder: context.l10n.companyEmailPlaceholder,
                    keyboardType: TextInputType.emailAddress,
                    textAlign: TextAlign.right,
                    onSaved: (val) => _company?.email = val,
                  ),
                  DynamicTextField(
                    fieldKey: 'company.phone',
                    initialValue: _company?.phone,
                    onSaved: (val) => _company?.phone = val,
                  ),
                  CupertinoTextFormFieldRow(
                    prefix: Text(context.l10n.address),
                    initialValue: _company?.address,
                    placeholder: context.l10n.fullAddress,
                    textCapitalization: TextCapitalization.sentences,
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    onSaved: (val) => _company?.address = val,
                  ),
                  CupertinoTextFormFieldRow(
                    prefix: Text(context.l10n.website),
                    initialValue: _company?.site,
                    placeholder: context.l10n.websitePlaceholder,
                    keyboardType: TextInputType.url,
                    textAlign: TextAlign.right,
                    onSaved: (val) => _company?.site = val,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
