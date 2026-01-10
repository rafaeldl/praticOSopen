import 'package:flutter/cupertino.dart';
import 'package:praticos/mobx/user_store.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/widgets/cached_image.dart';

class UserProfileEditScreen extends StatefulWidget {
  const UserProfileEditScreen({super.key});

  @override
  State<UserProfileEditScreen> createState() => _UserProfileEditScreenState();
}

class _UserProfileEditScreenState extends State<UserProfileEditScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  User? _user;
  final UserStore _userStore = UserStore();
  bool _isLoading = false;
  bool _isLoadingUser = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final user = await _userStore.getSingleUserById();
    if (mounted) {
      setState(() {
        _user = user;
        _isLoadingUser = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate() && _user != null) {
      setState(() => _isLoading = true);
      _formKey.currentState!.save();
      await _userStore.updateUserProfile(_user!);
      setState(() => _isLoading = false);
      if (mounted) {
        Navigator.pop(context, _user);
      }
    }
  }

  Future<void> _pickImage() async {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: const Text('Alterar Foto'),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            child: const Text('Tirar Foto'),
            onPressed: () async {
              Navigator.pop(context);
              final file = await _userStore.photoService.takePhoto();
              if (file != null && _user != null) {
                await _userStore.uploadUserPhoto(file, _user!);
                setState(() {});
              }
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('Escolher da Galeria'),
            onPressed: () async {
              Navigator.pop(context);
              final file = await _userStore.photoService.pickImageFromGallery();
              if (file != null && _user != null) {
                await _userStore.uploadUserPhoto(file, _user!);
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
    if (_isLoadingUser) {
      return CupertinoPageScaffold(
        backgroundColor: CupertinoColors.systemGroupedBackground,
        navigationBar: const CupertinoNavigationBar(
          middle: Text('Editar Perfil'),
        ),
        child: const Center(
          child: CupertinoActivityIndicator(),
        ),
      );
    }

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Editar Perfil'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _isLoading ? null : _saveProfile,
          child: _isLoading
              ? const CupertinoActivityIndicator()
              : const Text('Salvar', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const SizedBox(height: 20),

              // Photo Section
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      if (_user?.photo != null && _user!.photo!.isNotEmpty)
                        ClipOval(
                          child: CachedImage(
                            imageUrl: _user!.photo!,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemGrey5.resolveFrom(context),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            CupertinoIcons.person_fill,
                            size: 50,
                            color: CupertinoColors.systemGrey.resolveFrom(context),
                          ),
                        ),
                      if (_userStore.isUploading)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: CupertinoColors.black.withValues(alpha: 0.5),
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
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Toque para alterar',
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Form Fields
              CupertinoListSection.insetGrouped(
                header: Text(
                  'INFORMAÇÕES PESSOAIS',
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
                children: [
                  _buildCupertinoFormField(
                    label: 'Nome',
                    initialValue: _user?.name,
                    placeholder: 'Seu nome completo',
                    textCapitalization: TextCapitalization.words,
                    onSaved: (val) => _user?.name = val,
                    validator: (val) => val == null || val.isEmpty ? 'Obrigatório' : null,
                  ),
                ],
              ),

              CupertinoListSection.insetGrouped(
                header: Text(
                  'CONTA',
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
                children: [
                  CupertinoListTile(
                    title: const SizedBox(
                      width: 80,
                      child: Text('Email', style: TextStyle(fontSize: 16)),
                    ),
                    additionalInfo: Text(
                      _user?.email ?? '',
                      style: TextStyle(
                        color: CupertinoColors.secondaryLabel.resolveFrom(context),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCupertinoFormField({
    required String label,
    String? initialValue,
    String? placeholder,
    TextCapitalization textCapitalization = TextCapitalization.none,
    required FormFieldSetter<String> onSaved,
    required FormFieldValidator<String> validator,
  }) {
    return CupertinoListTile(
      title: SizedBox(
        width: 80,
        child: Text(label, style: const TextStyle(fontSize: 16)),
      ),
      additionalInfo: SizedBox(
        width: 200,
        child: CupertinoTextFormFieldRow(
          initialValue: initialValue,
          placeholder: placeholder,
          textCapitalization: textCapitalization,
          padding: EdgeInsets.zero,
          textAlign: TextAlign.right,
          decoration: null,
          style: TextStyle(color: CupertinoColors.label.resolveFrom(context)),
          validator: validator,
          onSaved: onSaved,
        ),
      ),
    );
  }
}
