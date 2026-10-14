import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/mobx/user_store.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/screens/widgets/app_form_field.dart';
import 'package:praticos/screens/widgets/text_link.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';
import 'package:praticos/widgets/cached_image.dart';

/// "Seu perfil": the signed-in person's name and photo. Pushed edit screen
/// (Salvar at the top right); the e-mail is shown as a plain sentence because
/// it can't be changed here.
class UserProfileEditScreen extends StatefulWidget {
  const UserProfileEditScreen({
    super.key,
    this.loadUser,
    this.saveUser,
    this.uploadPhoto,
  });

  /// Test seams; default to [UserStore].
  final Future<User?> Function()? loadUser;
  final Future<void> Function(User user)? saveUser;
  final Future<String?> Function(File file, User user)? uploadPhoto;

  @override
  State<UserProfileEditScreen> createState() => _UserProfileEditScreenState();
}

class _UserProfileEditScreenState extends State<UserProfileEditScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  UserStore? _store;
  User? _user;
  bool _saving = false;
  bool _uploading = false;
  bool _loadingUser = true;

  UserStore get _userStore => _store ??= UserStore();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = await (widget.loadUser ?? _userStore.getSingleUserById)();
    if (!mounted) return;
    setState(() {
      _user = user;
      _name.text = user?.name ?? '';
      _loadingUser = false;
    });
  }

  Future<void> _save() async {
    if (_user == null || !_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => _saving = true);
    try {
      await (widget.saveUser ?? _userStore.updateUserProfile)(_user!);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (mounted) Navigator.pop(context, _user);
  }

  Future<void> _pickPhoto() async {
    final l10n = context.l10n;
    final fromCamera = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(sheetContext, true),
            child: Text(l10n.takePhoto),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(sheetContext, false),
            child: Text(l10n.chooseFromGallery),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: Text(l10n.cancel),
        ),
      ),
    );
    if (fromCamera == null || _user == null) return;
    final photos = _userStore.photoService;
    final file = fromCamera
        ? await photos.takePhoto()
        : await photos.pickImageFromGallery();
    if (file == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      await (widget.uploadPhoto ?? _userStore.uploadUserPhoto)(file, _user!);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background.resolveFrom(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text(l10n.profileEditTitle),
        trailing: _loadingUser
            ? null
            : CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const CupertinoActivityIndicator()
                    : Text(
                        l10n.save,
                        style: AppTypography.callout.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.accentText.resolveFrom(context),
                        ),
                      ),
              ),
      ),
      child: SafeArea(
        child: _loadingUser
            ? const Center(child: CupertinoActivityIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.only(
                    top: AppSpacing.lg,
                    bottom: AppSpacing.xxl,
                  ),
                  children: [
                    Center(child: _avatar(context)),
                    Center(
                      child: TextLink(
                        label: l10n.profileChangePhoto,
                        onPressed: _uploading ? null : _pickPhoto,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppFormField(
                      label: l10n.name,
                      controller: _name,
                      placeholder: l10n.profileNamePlaceholder,
                      textCapitalization: TextCapitalization.words,
                      onSaved: (v) => _user?.name = v.trim(),
                      validator: (v) =>
                          v.trim().isEmpty ? l10n.profileNameRequired : null,
                    ),
                    if ((_user?.email ?? '').isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.pageMargin,
                          AppSpacing.sm,
                          AppSpacing.pageMargin,
                          0,
                        ),
                        child: Text(
                          l10n.profileSignedInAs(_user!.email!),
                          style: AppTypography.label.copyWith(
                            color: AppColors.textSecondary.resolveFrom(context),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _avatar(BuildContext context) {
    const size = 96.0;
    final photo = _user?.photo;
    final Widget image = (photo != null && photo.isNotEmpty)
        ? CachedImage(
            imageUrl: photo,
            width: size,
            height: size,
            fit: BoxFit.cover,
          )
        : Container(
            width: size,
            height: size,
            color: AppColors.secondaryFill.resolveFrom(context),
            child: Icon(
              CupertinoIcons.person_fill,
              size: 48,
              color: AppColors.textSecondary.resolveFrom(context),
            ),
          );
    return GestureDetector(
      onTap: _uploading ? null : _pickPhoto,
      child: ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            fit: StackFit.expand,
            children: [
              image,
              if (_uploading)
                ColoredBox(
                  color: AppColors.text
                      .resolveFrom(context)
                      .withValues(alpha: 0.5),
                  child: const Center(
                    child: CupertinoActivityIndicator(
                      color: CupertinoColors.white,
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
