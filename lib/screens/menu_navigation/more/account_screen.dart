import 'package:flutter/cupertino.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/global.dart';
import 'package:praticos/mobx/auth_store.dart';
import 'package:praticos/mobx/user_store.dart';
import 'package:praticos/screens/menu_navigation/more/account_deletion.dart';
import 'package:praticos/screens/menu_navigation/more/more_page.dart';
import 'package:praticos/screens/onboarding/accept_invite_screen.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/screens/widgets/picker_screen.dart';
import 'package:praticos/services/authorization_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';
import 'package:praticos/widgets/cached_image.dart';

/// Company the user belongs to, for the switcher.
class AccountCompany {
  const AccountCompany({required this.id, required this.name});

  final String id;
  final String name;
}

/// Presentation of "Sua conta": profile, company switcher (only with more
/// than one), join with an invite code, sign out (link color, it does not
/// erase data) and "Apagar minha conta" (danger).
class AccountView extends StatelessWidget {
  const AccountView({
    super.key,
    required this.name,
    required this.deletion,
    required this.onSignOut,
    this.email,
    this.photoUrl,
    this.companyName,
    this.currentCompanyId,
    this.roleLabel,
    this.companies = const [],
    this.onEditProfile,
    this.onSwitchCompany,
    this.onJoinWithCode,
  });

  final String name;
  final String? email;
  final String? photoUrl;
  final String? companyName;

  /// Marked with ✓ in the company switcher.
  final String? currentCompanyId;
  final String? roleLabel;
  final List<AccountCompany> companies;
  final AccountDeletionFlow deletion;
  final Future<void> Function() onSignOut;
  final VoidCallback? onEditProfile;
  final ValueChanged<String>? onSwitchCompany;
  final VoidCallback? onJoinWithCode;

  void _confirmSignOut(BuildContext context) {
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(dialogContext.l10n.logout),
        content: Text(dialogContext.l10n.logoutConfirm),
        actions: [
          CupertinoDialogAction(
            child: Text(dialogContext.l10n.cancel),
            onPressed: () => Navigator.pop(dialogContext),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(dialogContext);
              onSignOut();
            },
            child: Text(dialogContext.l10n.logout),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCompany(BuildContext context) async {
    final id = await pickOne<String>(
      context,
      title: context.l10n.selectCompany,
      selected: currentCompanyId,
      options: [
        for (final company in companies)
          PickerItem(value: company.id, title: company.name),
      ],
    );
    if (id != null && id != currentCompanyId) onSwitchCompany?.call(id);
  }

  Widget _avatar(BuildContext context) {
    // The person icon shows while the photo loads and when it fails, never
    // a spinner that may not stop.
    final fallback = Container(
      key: const ValueKey('account_avatar_fallback'),
      width: 56,
      height: 56,
      color: AppColors.secondaryFill.resolveFrom(context),
      child: Icon(
        CupertinoIcons.person_solid,
        color: AppColors.textSecondary.resolveFrom(context),
      ),
    );
    return ClipOval(
      child: photoUrl != null && photoUrl!.isNotEmpty
          ? CachedImage(
              imageUrl: photoUrl!,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              placeholder: fallback,
              errorWidget: fallback,
            )
          : fallback,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final accent = AppColors.accentText.resolveFrom(context);
    final subtitleParts = [
      if (email != null && email!.isNotEmpty) email!,
      if (companyName != null)
        [companyName!, if (roleLabel != null) roleLabel!].join(' · '),
    ];

    return MorePage(
      title: l10n.yourAccount,
      children: [
        MoreRows(
          rows: [
            AppListRow(
              key: const ValueKey('account_profile'),
              leading: _avatar(context),
              title: name,
              subtitle: subtitleParts.isEmpty ? null : subtitleParts.join('\n'),
              onTap: onEditProfile,
            ),
            if (companies.length > 1)
              AppListRow(
                key: const ValueKey('account_switch_company'),
                title: l10n.switchCompany,
                onTap: () => _pickCompany(context),
              ),
            AppListRow(
              key: const ValueKey('account_join_code'),
              title: l10n.joinWithInviteCode,
              onTap: onJoinWithCode,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        MoreRows(
          rows: [
            _ActionRow(
              key: const ValueKey('account_sign_out'),
              label: l10n.logout,
              color: accent,
              onTap: () => _confirmSignOut(context),
            ),
            _ActionRow(
              key: const ValueKey('account_delete'),
              label: l10n.deleteMyAccount,
              color: AppColors.danger.resolveFrom(context),
              onTap: () => deletion.start(context),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.minTouchTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pageMargin,
              vertical: AppSpacing.md,
            ),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                label,
                style: AppTypography.body.copyWith(color: color),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Wires [AccountView] to the stores.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final UserStore _userStore = UserStore();

  @override
  Widget build(BuildContext context) {
    _userStore.findCurrentUser();
    final authStore = context.read<AuthStore>();
    return Observer(
      builder: (_) {
        final user = _userStore.user?.value;
        final companies = [
          for (final role in user?.companies ?? const [])
            if (role.company?.id != null)
              AccountCompany(
                id: role.company!.id!,
                name: role.company!.name ?? context.l10n.companyNoName,
              ),
        ];
        return AccountView(
          name: user?.name ?? Global.currentUser?.displayName ?? '',
          email: user?.email ?? Global.currentUser?.email,
          photoUrl: user?.photo ?? Global.currentUser?.photoURL,
          companyName: authStore.companyAggr?.name,
          currentCompanyId: authStore.companyAggr?.id,
          roleLabel: AuthorizationService.instance.getRoleLabelLocalized(
            context.l10n,
          ),
          companies: companies,
          deletion: AccountDeletionFlow(
            deleteAccount: authStore.deleteAccount,
            reauthenticate: authStore.reauthenticate,
          ),
          onSignOut: () async => authStore.signOutGoogle(),
          onEditProfile: () =>
              Navigator.pushNamed(context, '/user_profile_edit'),
          onSwitchCompany: (id) async {
            await authStore.switchCompany(id);
            if (context.mounted) {
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
            }
          },
          onJoinWithCode: () => Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (_) => AcceptInviteScreen(
                onInviteAccepted: () => Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/',
                  (route) => false,
                ),
                onCancel: () => Navigator.pop(context),
              ),
            ),
          ),
        );
      },
    );
  }
}
