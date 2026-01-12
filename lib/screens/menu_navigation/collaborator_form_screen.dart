import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:praticos/mobx/collaborator_store.dart';
import 'package:praticos/models/permission.dart';
import 'package:praticos/models/user_role.dart';
import 'package:praticos/extensions/context_extensions.dart';

class CollaboratorFormScreen extends StatefulWidget {
  @override
  _CollaboratorFormScreenState createState() => _CollaboratorFormScreenState();
}

class _CollaboratorFormScreenState extends State<CollaboratorFormScreen> {
  // Usa singleton para compartilhar estado com a tela de listagem
  final CollaboratorStore _collaboratorStore = CollaboratorStore.instance;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  RolesType _selectedRole = RolesType.technician; // Default para técnico
  bool _isLoading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final wasAddedDirectly = await _collaboratorStore.addCollaborator(
        _emailController.text.trim(),
        _selectedRole,
      );
      if (mounted) {
        if (wasAddedDirectly) {
          // Usuário já existia e foi adicionado diretamente
          _showSuccessDialog(
            context.l10n.collaboratorAdded,
            context.l10n.collaboratorAddedSuccess,
          );
        } else {
          // Usuário não existia, convite foi criado
          _showSuccessDialog(
            context.l10n.inviteSent,
            context.l10n.inviteCreatedMessage,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSuccessDialog(String title, String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: Text(context.l10n.ok),
            onPressed: () {
              Navigator.pop(context); // Fecha o dialog
              Navigator.pop(this.context, true); // Volta para a lista
            },
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(context.l10n.error),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: Text(context.l10n.ok),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showRolePicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: Text(context.l10n.selectProfile),
        message: Text(context.l10n.chooseCollaboratorRole),
        actions: RolePermissions.availableRoles.map((role) {
          final isSelected = _selectedRole == role;
          return CupertinoActionSheetAction(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${RolePermissions.getRoleIcon(role)} ${RolePermissions.getRoleLabel(role, context.l10n)}',
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 8),
                      const Icon(CupertinoIcons.checkmark, size: 16),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  RolePermissions.getRoleDescription(role, context.l10n),
                  style: TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ],
            ),
            onPressed: () {
              setState(() => _selectedRole = role);
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

  String _getRoleLabel(RolesType role) {
    return RolePermissions.getRoleLabel(role, context.l10n);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text(context.l10n.newCollaborator),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const CupertinoActivityIndicator()
              : Text(context.l10n.add, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                const SizedBox(height: 20),
                
                // Header Icon
                Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: const BoxDecoration(
                      color: CupertinoColors.systemGrey5,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      CupertinoIcons.person_add_solid,
                      size: 50,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                CupertinoListSection.insetGrouped(
                  header: Text(context.l10n.userInformation.toUpperCase()),
                  footer: Text(context.l10n.userWillReceiveInviteByEmail),
                  children: [
                    CupertinoTextFormFieldRow(
                      controller: _emailController,
                      prefix: Text(context.l10n.email, style: const TextStyle(fontSize: 16)),
                      placeholder: context.l10n.emailPlaceholder,
                      keyboardType: TextInputType.emailAddress,
                      textAlign: TextAlign.right,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return context.l10n.required;
                        }
                        if (!value.contains('@')) {
                          return context.l10n.invalidEmail;
                        }
                        return null;
                      },
                    ),
                    CupertinoListTile(
                      title: Text(context.l10n.profile),
                      subtitle: Text(
                        RolePermissions.getRoleDescription(_selectedRole, context.l10n),
                        style: TextStyle(
                          fontSize: 13,
                          color: CupertinoColors.secondaryLabel.resolveFrom(context),
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${RolePermissions.getRoleIcon(_selectedRole)} ${_getRoleLabel(_selectedRole)}',
                            style: const TextStyle(color: CupertinoColors.secondaryLabel),
                          ),
                          const SizedBox(width: 6),
                          const Icon(CupertinoIcons.chevron_right, size: 16, color: CupertinoColors.systemGrey3),
                        ],
                      ),
                      onTap: _showRolePicker,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
