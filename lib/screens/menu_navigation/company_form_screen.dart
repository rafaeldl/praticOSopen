import 'package:easy_mask/easy_mask.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:praticos/global.dart';
import 'package:praticos/mobx/company_store.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/widgets/cached_image.dart';

class CompanyFormScreen extends StatefulWidget {
  const CompanyFormScreen({Key? key}) : super(key: key);

  @override
  State<CompanyFormScreen> createState() => _CompanyFormScreenState();
}

class _CompanyFormScreenState extends State<CompanyFormScreen> {
  final CompanyStore _companyStore = CompanyStore();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isLoading = true;
  Company? _company;
  Map<String, dynamic>? _selectedSegment;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    if (Global.companyAggr?.id != null) {
      _company = await _companyStore.retrieveCompany(Global.companyAggr!.id);
      if (_company?.segment != null) {
        await _loadSegment(_company!.segment!);
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
          title: const Text('Selecionar Segmento'),
          message: const Text('Escolha o ramo de atuação da empresa'),
          actions: segments.map((segment) {
            return CupertinoActionSheetAction(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    segment['icon'] ?? '🔧',
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 8),
                  Text(segment['name'] ?? 'Sem nome'),
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
            child: const Text('Cancelar'),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      );
    } catch (e) {
      // Ignorar erro silenciosamente
    }
  }

  Future<void> _pickImage() async {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: const Text('Alterar Logo'),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            child: const Text('Tirar Foto'),
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
            child: const Text('Escolher da Galeria'),
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
          child: const Text('Cancelar'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _company == null) {
      return const CupertinoPageScaffold(
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    if (_company == null) {
      return const CupertinoPageScaffold(
        child: Center(child: Text("Empresa não encontrada")),
      );
    }

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: const Text("Dados da Empresa"),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const CupertinoActivityIndicator()
              : const Text("Salvar", style: TextStyle(fontWeight: FontWeight.bold)),
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
                    prefix: const Text("Nome"),
                    initialValue: _company?.name,
                    placeholder: "Nome da Empresa",
                    textCapitalization: TextCapitalization.words,
                    textAlign: TextAlign.right,
                    onSaved: (val) => _company?.name = val,
                    validator: (val) => val == null || val.isEmpty ? "Obrigatório" : null,
                  ),
                  GestureDetector(
                    onTap: _pickSegment,
                    child: CupertinoFormRow(
                      prefix: const Text("Segmento"),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16.0), // Respiro entre label e valor
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Text(
                                _selectedSegment?['name'] ?? "Selecionar",
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
                  CupertinoTextFormFieldRow(
                    prefix: const Text("Email"),
                    initialValue: _company?.email,
                    placeholder: "contato@empresa.com",
                    keyboardType: TextInputType.emailAddress,
                    textAlign: TextAlign.right,
                    onSaved: (val) => _company?.email = val,
                  ),
                  CupertinoTextFormFieldRow(
                    prefix: const Text("Telefone"),
                    initialValue: _company?.phone,
                    placeholder: "(00) 00000-0000",
                    keyboardType: TextInputType.phone,
                    textAlign: TextAlign.right,
                    inputFormatters: [TextInputMask(mask: ['(99) 9999-9999', '(99) 99999-9999'])],
                    onSaved: (val) => _company?.phone = val,
                  ),
                  CupertinoTextFormFieldRow(
                    prefix: const Text("Endereço"),
                    initialValue: _company?.address,
                    placeholder: "Endereço completo",
                    textCapitalization: TextCapitalization.sentences,
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    onSaved: (val) => _company?.address = val,
                  ),
                  CupertinoTextFormFieldRow(
                    prefix: const Text("Site"),
                    initialValue: _company?.site,
                    placeholder: "www.empresa.com.br",
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
