import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/models/permission.dart';
import 'package:praticos/models/user_role.dart';
import 'package:praticos/screens/widgets/app_form_field.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/screens/widgets/app_sheet.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';

/// What the invite form collects. [name] is optional; at least one of
/// [email] and [phone] is required (the invitee is found by e-mail when
/// signing in, so e-mail is the main way).
class InviteFormData {
  const InviteFormData({
    required this.role,
    this.name,
    this.email,
    this.phone,
  });

  final String? name;
  final String? email;
  final String? phone;
  final RolesType role;
}

/// "Convidar pessoa": a creation sheet (Cancelar on the left, "Criar convite"
/// on the right) with name (optional), e-mail, WhatsApp and the role.
class InviteForm extends StatefulWidget {
  const InviteForm({
    super.key,
    required this.onSubmit,
    this.initialName,
    this.initialEmail,
    this.initialPhone,
    this.initialRole = RolesType.technician,
  });

  /// Called with valid data. The sheet shows a spinner until it completes.
  final Future<void> Function(InviteFormData data) onSubmit;
  final String? initialName;
  final String? initialEmail;
  final String? initialPhone;
  final RolesType initialRole;

  @override
  State<InviteForm> createState() => _InviteFormState();
}

class _InviteFormState extends State<InviteForm> {
  late final TextEditingController _name =
      TextEditingController(text: widget.initialName);
  late final TextEditingController _email =
      TextEditingController(text: widget.initialEmail);
  late final TextEditingController _phone =
      TextEditingController(text: widget.initialPhone);
  late RolesType _role = widget.initialRole;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String? _contactError;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  /// Empty is fine (optional); otherwise 10 to 15 digits.
  static bool isValidPhone(String phone) {
    if (phone.isEmpty) return true;
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 10 && digits.length <= 15;
  }

  Future<void> _submit() async {
    final valid = _formKey.currentState!.validate();
    final email = _email.text.trim();
    final phone = _phone.text.trim();
    final missing = email.isEmpty && phone.isEmpty;
    setState(() => _contactError = missing ? context.l10n.emailOrPhone : null);
    if (!valid || missing) return;

    setState(() => _busy = true);
    try {
      final name = _name.text.trim();
      await widget.onSubmit(InviteFormData(
        name: name.isEmpty ? null : name,
        email: email.isEmpty ? null : email,
        phone: phone.isEmpty ? null : phone,
        role: _role,
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickRole() async {
    final picked = await RolePickerSheet.show(context, selected: _role);
    if (picked != null && mounted) setState(() => _role = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppSheet(
      title: l10n.invitePerson,
      actionLabel: l10n.createInvite,
      onAction: _submit,
      busy: _busy,
      child: Form(
        key: _formKey,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            const SizedBox(height: AppSpacing.sm),
            AppFormField(
              label: l10n.inviteWhoLabel,
              controller: _name,
              placeholder: l10n.inviteWhoPlaceholder,
              keyboardType: TextInputType.name,
              textCapitalization: TextCapitalization.words,
            ),
            AppFormField(
              label: l10n.inviteEmailLabel,
              controller: _email,
              placeholder: l10n.emailPlaceholder,
              hint: _contactError ?? l10n.inviteEmailHint,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                final text = value.trim();
                if (text.isEmpty) return null;
                return text.contains('@') ? null : l10n.invalidEmail;
              },
            ),
            AppFormField(
              label: l10n.inviteWhatsAppLabel,
              controller: _phone,
              placeholder: l10n.phonePlaceholder,
              hint: l10n.userWillReceiveInviteByWhatsAppHint,
              keyboardType: TextInputType.phone,
              validator: (value) =>
                  isValidPhone(value.trim()) ? null : l10n.invalidPhone,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppListRow(
              key: const ValueKey('invite_role'),
              title: l10n.inviteRoleLabel,
              subtitle: RolePermissions.getRoleDescription(_role, l10n),
              trailing: RolePermissions.getRoleLabel(_role, l10n),
              onTap: _pickRole,
            ),
          ],
        ),
      ),
    );
  }
}

/// Role choice with one sentence per role. The selected role shows a check
/// on the right (no radio buttons). All five roles are offered, Supervisor
/// included.
class RolePickerSheet extends StatelessWidget {
  const RolePickerSheet({super.key, required this.selected});

  final RolesType selected;

  static Future<RolesType?> show(
    BuildContext context, {
    required RolesType selected,
  }) {
    return AppSheet.show<RolesType>(
      context,
      (_) => RolePickerSheet(selected: selected),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppSheet(
      title: l10n.inviteRoleLabel,
      child: ListView(
        children: [
          for (final role in RolePermissions.availableRoles)
            GestureDetector(
              key: ValueKey('role_${role.name}'),
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(role),
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(minHeight: AppSizes.minTouchTarget),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.pageMargin,
                    vertical: AppSpacing.md,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              RolePermissions.getRoleLabel(role, l10n),
                              style: AppTypography.body.copyWith(
                                color: AppColors.text.resolveFrom(context),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                RolePermissions.getRoleDescription(role, l10n),
                                style: AppTypography.callout.copyWith(
                                  color: AppColors.textSecondary
                                      .resolveFrom(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (role == selected)
                        Icon(
                          CupertinoIcons.checkmark,
                          size: 20,
                          color: AppColors.accentText.resolveFrom(context),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
