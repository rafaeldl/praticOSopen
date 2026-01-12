import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'package:praticos/mobx/auth_store.dart';
import 'package:praticos/widgets/cached_image.dart';
import 'company_contact_screen.dart';

class CompanyInfoScreen extends StatefulWidget {
  final AuthStore authStore;
  final String? companyId; // ID da empresa existente (se houver)
  final String? initialName;
  final String? initialAddress;
  final String? initialPhone;
  final String? initialEmail;
  final String? initialSite;
  final String? initialLogoUrl;

  const CompanyInfoScreen({
    super.key,
    required this.authStore,
    this.companyId,
    this.initialName,
    this.initialAddress,
    this.initialPhone,
    this.initialEmail,
    this.initialSite,
    this.initialLogoUrl,
  });

  @override
  State<CompanyInfoScreen> createState() => _CompanyInfoScreenState();
}

class _CompanyInfoScreenState extends State<CompanyInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  XFile? _logoFile;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _addressController = TextEditingController(text: widget.initialAddress);
  }

  Future<void> _pickImage() async {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: const Text('Logo da Empresa'),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            child: const Text('Tirar Foto'),
            onPressed: () async {
              Navigator.pop(context);
              final file = await _picker.pickImage(source: ImageSource.camera);
              if (file != null) setState(() => _logoFile = file);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('Escolher da Galeria'),
            onPressed: () async {
              Navigator.pop(context);
              final file = await _picker.pickImage(source: ImageSource.gallery);
              if (file != null) setState(() => _logoFile = file);
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

  void _next() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (context) => CompanyContactScreen(
            authStore: widget.authStore,
            companyId: widget.companyId,
            companyName: _nameController.text,
            address: _addressController.text,
            logoFile: _logoFile,
            initialPhone: widget.initialPhone,
            initialEmail: widget.initialEmail,
            initialSite: widget.initialSite,
          ),
        ),
      );
    }
  }

  Widget _buildLogoContent() {
    if (_logoFile != null) {
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          image: DecorationImage(
            image: FileImage(File(_logoFile!.path)),
            fit: BoxFit.cover,
          ),
        ),
      );
    } else if (widget.initialLogoUrl != null && widget.initialLogoUrl!.isNotEmpty) {
      return ClipOval(
        child: CachedImage(
          imageUrl: widget.initialLogoUrl!,
          width: 100,
          height: 100,
          fit: BoxFit.cover,
        ),
      );
    } else {
      return const Center(
        child: Icon(
          CupertinoIcons.photo_camera,
          size: 40,
          color: CupertinoColors.systemGrey,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Dados Básicos'),
      ),
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 20),
              
              // Logo Selection
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: const BoxDecoration(
                          color: CupertinoColors.systemGrey5,
                          shape: BoxShape.circle,
                        ),
                        child: _buildLogoContent(),
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
                            CupertinoIcons.pencil,
                            size: 14,
                            color: CupertinoColors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),

              // Formulário
              CupertinoListSection.insetGrouped(
                header: const Text('INFORMAÇÕES'),
                children: [
                  CupertinoTextFormFieldRow(
                    controller: _nameController,
                    prefix: const Text('Nome'),
                    placeholder: 'Nome da Empresa',
                    textCapitalization: TextCapitalization.words,
                    textAlign: TextAlign.right,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Obrigatório';
                      }
                      return null;
                    },
                  ),
                  CupertinoTextFormFieldRow(
                    controller: _addressController,
                    prefix: const Text('Endereço'),
                    placeholder: 'Opcional',
                    textCapitalization: TextCapitalization.sentences,
                    textAlign: TextAlign.right,
                    maxLines: 2,
                  ),
                ],
              ),

              const Spacer(),

              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  child: CupertinoButton.filled(
                    onPressed: _next,
                    child: const Text('Próximo'),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }
}
