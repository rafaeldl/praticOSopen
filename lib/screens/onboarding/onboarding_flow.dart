import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:praticos/config/feature_flags.dart';
import 'package:praticos/mobx/auth_store.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/screens/onboarding/accept_invite_screen.dart';
import 'package:praticos/screens/onboarding/select_segment_screen.dart';
import 'package:praticos/screens/onboarding/whatsapp_onboarding_screen.dart';
import 'package:praticos/screens/widgets/glass_bar_button.dart';
import 'package:praticos/services/onboarding_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_glass.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';
import 'package:provider/provider.dart';

/// Everything the first-access screens need from outside, so the flow can be
/// tested with fakes. [OnboardingDeps.firebase] wires the real app.
class OnboardingDeps {
  const OnboardingDeps({
    required this.segments,
    required this.setup,
    required this.onSignOut,
    required this.onInviteCode,
    required this.onFinished,
    this.loadPhoneMasks,
  });

  /// Active segments ("ramos").
  final Stream<List<OnboardingSegment>> Function() segments;
  final OnboardingSetup setup;

  /// "Sair": for whoever signed in with the wrong account.
  final void Function(BuildContext context) onSignOut;

  /// "Recebi um código de convite".
  final void Function(BuildContext context) onInviteCode;

  /// The company is ready: enter the app (Início).
  final void Function(BuildContext context) onFinished;

  /// Phone masks of the device country; null or empty means no mask.
  final Future<List<String>> Function(BuildContext context)? loadPhoneMasks;

  factory OnboardingDeps.firebase(AuthStore authStore) {
    return OnboardingDeps(
      segments: firestoreOnboardingSegments,
      setup: FirebaseOnboardingSetup(authStore: authStore),
      onSignOut: (context) {
        // The flow may sit on a pushed route (from the invites screen).
        Navigator.of(context).popUntil((route) => route.isFirst);
        authStore.signOutGoogle();
      },
      onInviteCode: (context) {
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (_) => AcceptInviteScreen(
              onInviteAccepted: () async {
                await authStore.reloadUserAndCompany();
                if (context.mounted) {
                  Navigator.of(context)
                      .pushNamedAndRemoveUntil('/', (route) => false);
                }
              },
              onCancel: () => Navigator.of(context).pop(),
            ),
          ),
        );
      },
      onFinished: (context) {
        if (kWhatsAppBotEnabled) {
          Navigator.of(context).pushAndRemoveUntil(
            CupertinoPageRoute(builder: (_) => const WhatsAppOnboardingScreen()),
            (route) => false,
          );
        } else {
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        }
      },
      loadPhoneMasks: _globalPhoneMasks,
    );
  }
}

/// Phone masks from the "global" segment config and the device country, as
/// the old contacts screen did.
Future<List<String>> _globalPhoneMasks(BuildContext context) async {
  final provider = context.read<SegmentConfigProvider>();
  if (!provider.isLoaded) {
    final country = Localizations.localeOf(context).countryCode ?? 'BR';
    await provider.initialize('global');
    provider.setCountry(country);
  }
  return provider.getMasks('company.phone');
}

/// State shared by the steps of one first access.
class OnboardingSession {
  OnboardingSession({
    required this.deps,
    this.companyId,
    this.initialName,
    this.initialPhone,
  });

  final OnboardingDeps deps;

  /// Company that exists without a segment (created by an older version).
  final String? companyId;
  final String? initialName;
  final String? initialPhone;

  /// Company saved by a previous attempt that failed later: a retry completes
  /// it instead of creating a second one.
  String? savedCompanyId;

  bool _started = false;

  /// Logs the start of the setup once.
  void markStarted() {
    if (_started) return;
    _started = true;
    deps.setup.started();
  }
}

/// First access of an owner without a company: Ramo -> [Especialidades] ->
/// Seu negócio -> Início.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({
    super.key,
    required this.deps,
    this.companyId,
    this.initialName,
    this.initialPhone,
  });

  final OnboardingDeps deps;
  final String? companyId;
  final String? initialName;
  final String? initialPhone;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  late final OnboardingSession _session = OnboardingSession(
    deps: widget.deps,
    companyId: widget.companyId,
    initialName: widget.initialName,
    initialPhone: widget.initialPhone,
  );

  @override
  Widget build(BuildContext context) => SelectSegmentScreen(session: _session);
}

/// Page of the first access: [AppNavBar] (large title that collapses on
/// scroll, glass back button named [previousTitle]), an optional sentence
/// under the title, [slivers], and optional [bottom] actions that float over
/// the content (which fades at the edge).
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.previousTitle,
    required this.slivers,
    this.bottom,
  });

  final String title;
  final String? subtitle;

  /// Replaces the automatic back button (e.g. "Sair" on the first step).
  final Widget? leading;

  /// Name of the previous step on the back button ("‹ Seu ramo").
  final String? previousTitle;
  final List<Widget> slivers;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final background = AppColors.background.resolveFrom(context);
    final scroll = CustomScrollView(
      slivers: [
        AppNavBar(
          largeTitle: Text(title),
          leading: leading,
          previousTitle: previousTitle,
        ),
        if (subtitle != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageMargin,
                0,
                AppSpacing.pageMargin,
                AppSpacing.sm,
              ),
              child: Text(
                subtitle!,
                style: AppTypography.callout.copyWith(
                  color: AppColors.textSecondary.resolveFrom(context),
                ),
              ),
            ),
          ),
        ...slivers,
        SliverSafeArea(
          top: false,
          sliver: SliverToBoxAdapter(
            child: SizedBox(height: bottom == null ? AppSpacing.xxl : 200),
          ),
        ),
      ],
    );

    return CupertinoPageScaffold(
      backgroundColor: background,
      child: Material(
        type: MaterialType.transparency,
        child: bottom == null
            ? scroll
            : Stack(
                children: [
                  Positioned.fill(child: scroll),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            background.withValues(alpha: 0),
                            background,
                            background,
                          ],
                          stops: const [0, 0.3, 1],
                        ),
                      ),
                      child: SafeArea(
                        top: false,
                        minimum: const EdgeInsets.only(bottom: AppSpacing.lg),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.blockMargin,
                            AppSpacing.xxl,
                            AppSpacing.blockMargin,
                            0,
                          ),
                          child: bottom,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Text button for the top bar, on glass ("Sair"): same capsule as
/// [GlassBackButton], 44pt touch target.
class OnboardingTopButton extends StatelessWidget {
  const OnboardingTopButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.text.resolveFrom(context);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(
          AppSizes.minTouchTarget,
          AppSizes.minTouchTarget,
        ),
        onPressed: onPressed,
        child: AppGlass(
          elevated: true,
          borderRadius: BorderRadius.circular(AppSizes.glassBarButton / 2),
          child: Container(
            constraints: const BoxConstraints(
              minHeight: AppSizes.glassBarButton,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
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
