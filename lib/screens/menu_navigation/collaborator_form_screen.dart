import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:praticos/config/feature_flags.dart';
import 'package:praticos/global.dart';
import 'package:praticos/mobx/collaborator_store.dart';
import 'package:praticos/models/invite.dart';
import 'package:praticos/models/user_role.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/screens/menu_navigation/invite_form.dart';
import 'package:praticos/screens/widgets/invite_share_sheet.dart';
import 'package:praticos/services/feature_gate_service.dart';
import 'package:praticos/widgets/photo_limit_dialog.dart';

/// "Convidar pessoa" as a `FormSheet` (open it with `FormSheet.show`).
/// Optionally prefilled from an expired invite (see [prefill]) when the admin
/// chose "Cancelar e convidar de novo".
class CollaboratorFormScreen extends StatefulWidget {
  const CollaboratorFormScreen({super.key, this.prefill});

  final Invite? prefill;

  @override
  State<CollaboratorFormScreen> createState() => _CollaboratorFormScreenState();
}

class _CollaboratorFormScreenState extends State<CollaboratorFormScreen> {
  // Usa singleton para compartilhar estado com a tela de listagem
  final CollaboratorStore _collaboratorStore = CollaboratorStore.instance;
  String _phone = '';

  // Default invite expiration days
  static const int _inviteExpirationDays = 7;

  Future<void> _submit(InviteFormData data) async {
    final name = data.name ?? '';
    final email = data.email ?? '';
    final phone = data.phone ?? '';
    _phone = phone;

    // Check for existing pending invite with same email/phone
    final existingInvite = _collaboratorStore.findExistingPendingInvite(
      email: email.isNotEmpty ? email : null,
      phone: phone.isNotEmpty ? phone : null,
    );
    final expiresAt = existingInvite?.expiresAt;
    if (existingInvite != null &&
        expiresAt != null &&
        expiresAt.isBefore(DateTime.now())) {
      // Expired invite: resending the code is useless, so cancel it and
      // create a new one (no rules change needed).
      await _collaboratorStore.cancelInvite(existingInvite.id!);
    } else if (existingInvite != null) {
      final shouldResend = await _showDuplicateInviteDialog(existingInvite);
      if (shouldResend == true) {
        // Resend existing invite via share sheet
        await _showInviteShareSheet(existingInvite.token!);
        return;
      } else if (shouldResend == null) {
        // User cancelled
        return;
      }
      // shouldResend == false → cancel existing and create new (falls through)
      await _collaboratorStore.cancelInvite(existingInvite.id!);
    }

    try {
      final (wasAddedDirectly, inviteToken) = await _collaboratorStore.addCollaborator(
        name.isNotEmpty ? name : null,
        email.isNotEmpty ? email : null,
        phone.isNotEmpty ? phone : null,
        data.role,
      );
      if (mounted) {
        if (wasAddedDirectly) {
          // Usuário já existia e foi adicionado diretamente
          _showSuccessDialog(
            context.l10n.collaboratorAdded,
            context.l10n.collaboratorAddedSuccess,
          );
        } else if (kWhatsAppBotEnabled &&
            inviteToken != null &&
            phone.isNotEmpty) {
          // Invite created with phone → show WhatsApp bot success dialog
          await _showWhatsAppInviteSuccess(
            inviteToken,
            name.isNotEmpty ? name : phone,
            phone,
          );
        } else {
          // Invite created without the bot → share sheet (WhatsApp goes to
          // the typed phone when there is one). See [kWhatsAppBotEnabled].
          if (inviteToken != null) {
            await _showInviteShareSheet(inviteToken);
          }
        }
      }
    } on FeatureGateLimitException catch (e) {
      if (mounted) showFeatureLimitDialog(context, e.result);
    } catch (e) {
      if (mounted) {
        _showErrorDialog(e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  Future<void> _showInviteShareSheet(String token) async {
    final phone = _phone;
    await InviteShareSheet.show(
      context,
      token: token,
      whatsappPhone: phone.isNotEmpty ? phone : null,
      expirationDays: _inviteExpirationDays,
    );
    if (mounted) {
      Navigator.pop(context, true); // Volta para a lista após compartilhar
    }
  }

  Future<void> _showWhatsAppInviteSuccess(
    String token,
    String displayName,
    String phone,
  ) async {
    final companyName = Global.companyAggr?.name ?? '';
    await showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(ctx.l10n.inviteWhatsAppSuccessTitle),
        content: Text(ctx.l10n.inviteWhatsAppSuccessMessage(displayName)),
        actions: [
          CupertinoDialogAction(
            child: Text(ctx.l10n.sendWhatsApp),
            onPressed: () async {
              Navigator.pop(ctx);
              final message = Uri.encodeComponent(
                context.l10n.inviteWhatsAppBotMessage(companyName),
              );
              final cleanNumber = phone.replaceAll(RegExp(r'\D'), '');
              final url = Uri.parse('https://wa.me/$cleanNumber?text=$message');
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
          ),
          CupertinoDialogAction(
            child: Text(ctx.l10n.ok),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
    if (mounted) {
      Navigator.pop(context, true);
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

  /// Shows a dialog when a duplicate invite is found.
  /// Returns: true = resend existing, false = cancel and create new, null = cancelled
  Future<bool?> _showDuplicateInviteDialog(Invite existingInvite) {
    return showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(context.l10n.duplicateInviteTitle),
        content: Text(context.l10n.duplicateInviteMessage),
        actions: [
          CupertinoDialogAction(
            child: Text(context.l10n.resendExistingInvite),
            onPressed: () => Navigator.pop(context, true),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: Text(context.l10n.cancelAndCreateNew),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            child: Text(context.l10n.cancel),
            onPressed: () => Navigator.pop(context, null),
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

  @override
  Widget build(BuildContext context) {
    final prefill = widget.prefill;
    return InviteForm(
      onSubmit: _submit,
      initialName: prefill?.name,
      initialEmail: prefill?.email,
      initialPhone: prefill?.phone,
      initialRole: prefill?.role ?? RolesType.technician,
    );
  }
}
