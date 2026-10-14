import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/screens/menu_navigation/more/more_page.dart';
import 'package:praticos/screens/onboarding/onboarding_flow.dart';
import 'package:praticos/screens/onboarding/your_business_screen.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/screens/widgets/primary_button.dart';
import 'package:praticos/services/onboarding_service.dart';
import 'package:praticos/theme/app_typography.dart';

/// Optional step, only for segments with specialties. All of them start
/// checked (reasonable default, HIG onboarding), so "Continuar" is enough;
/// unchecking all is allowed.
class SelectSubspecialtiesScreen extends StatefulWidget {
  const SelectSubspecialtiesScreen({
    super.key,
    required this.session,
    required this.segment,
  });

  final OnboardingSession session;
  final OnboardingSegment segment;

  @override
  State<SelectSubspecialtiesScreen> createState() =>
      _SelectSubspecialtiesScreenState();
}

class _SelectSubspecialtiesScreenState
    extends State<SelectSubspecialtiesScreen> {
  late final Set<String> _selected = {
    for (final s in widget.segment.subspecialties) s.id,
  };

  void _toggle(String id) {
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
    });
  }

  void _continue() {
    // Keep the segment order.
    final picked = [
      for (final s in widget.segment.subspecialties)
        if (_selected.contains(s.id)) s.id,
    ];
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => YourBusinessScreen(
          session: widget.session,
          segment: widget.segment,
          subspecialties: picked,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);

    return OnboardingPage(
      title: l10n.pickSpecialtiesTitle,
      subtitle: l10n.onboardingSpecialtiesHint,
      previousTitle: l10n.onboardingSegmentTitle,
      slivers: [
        SliverToBoxAdapter(
          child: MoreRows(rows: [
            for (final sub in widget.segment.subspecialties)
              AppListRow(
                key: ValueKey('subspecialty_${sub.id}'),
                leading: sub.icon == null
                    ? null
                    : ExcludeSemantics(
                        child: Text(sub.icon!, style: AppTypography.body),
                      ),
                title: sub.nameFor(locale),
                selected: _selected.contains(sub.id),
                // Toggles here: no chevron.
                showChevron: false,
                onTap: () => _toggle(sub.id),
              ),
          ]),
        ),
      ],
      bottom: PrimaryButton(
        key: const ValueKey('subspecialties_continue'),
        label: l10n.onboardingContinue,
        floating: true,
        onPressed: _continue,
      ),
    );
  }
}
