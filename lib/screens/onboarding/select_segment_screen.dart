import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/screens/menu_navigation/more/more_page.dart';
import 'package:praticos/screens/onboarding/onboarding_flow.dart';
import 'package:praticos/screens/onboarding/select_subspecialties_screen.dart';
import 'package:praticos/screens/onboarding/your_business_screen.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/screens/widgets/list_states.dart';
import 'package:praticos/screens/widgets/text_link.dart';
import 'package:praticos/services/onboarding_service.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';

/// First step of the first access: "Qual é o seu ramo?". Same rows as the
/// segment picker of Ajustes (emoji + name), but tapping a segment picks it
/// (✓) and goes on to the next step (chevron); there is no button on this
/// screen.
class SelectSegmentScreen extends StatefulWidget {
  const SelectSegmentScreen({super.key, required this.session});

  final OnboardingSession session;

  @override
  State<SelectSegmentScreen> createState() => _SelectSegmentScreenState();
}

class _SelectSegmentScreenState extends State<SelectSegmentScreen> {
  late Stream<List<OnboardingSegment>> _segments =
      widget.session.deps.segments();
  String? _selectedId;

  void _retry() {
    setState(() => _segments = widget.session.deps.segments());
  }

  void _pick(OnboardingSegment segment) {
    widget.session.markStarted();
    setState(() => _selectedId = segment.id);
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => segment.hasSubspecialties
            ? SelectSubspecialtiesScreen(
                session: widget.session,
                segment: segment,
              )
            : YourBusinessScreen(
                session: widget.session,
                segment: segment,
                subspecialties: const [],
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);

    return OnboardingPage(
      title: l10n.pickSegmentTitle,
      subtitle: l10n.onboardingSegmentHint,
      leading: OnboardingTopButton(
        key: const ValueKey('onboarding_sign_out'),
        label: l10n.logout,
        onPressed: () => widget.session.deps.onSignOut(context),
      ),
      slivers: [
        StreamBuilder<List<OnboardingSegment>>(
          stream: _segments,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              debugPrint('Onboarding: segments failed: ${snapshot.error}');
              return SliverFillRemaining(
                hasScrollBody: false,
                child: ErrorState(
                  message: l10n.onboardingSegmentsError,
                  onRetry: _retry,
                ),
              );
            }
            final segments = snapshot.data;
            if (segments == null) {
              return const SliverFillRemaining(
                hasScrollBody: false,
                child: LoadingState(),
              );
            }
            if (segments.isEmpty) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  title: l10n.noSegmentsAvailable,
                  actionLabel: l10n.tryAgain,
                  onAction: _retry,
                ),
              );
            }
            return SliverToBoxAdapter(
              child: MoreRows(rows: [
                for (final segment in segments)
                  AppListRow(
                    key: ValueKey('segment_${segment.id}'),
                    leading: _Emoji(segment.icon ?? '🔧'),
                    title: segment.nameFor(locale),
                    selected: segment.id == _selectedId,
                    onTap: () => _pick(segment),
                  ),
              ]),
            );
          },
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xl),
            child: Center(
              child: TextLink(
                key: const ValueKey('onboarding_invite_code'),
                label: l10n.onboardingInviteCode,
                onPressed: () => widget.session.deps.onInviteCode(context),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Segment / specialty emoji as the leading of a row.
class _Emoji extends StatelessWidget {
  const _Emoji(this.emoji);

  final String emoji;

  @override
  Widget build(BuildContext context) =>
      ExcludeSemantics(child: Text(emoji, style: AppTypography.body));
}
