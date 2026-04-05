import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';

class SegmentationOnboardingScreen extends StatefulWidget {
  final VoidCallback onCompleted;

  const SegmentationOnboardingScreen({
    super.key,
    required this.onCompleted,
  });

  @override
  State<SegmentationOnboardingScreen> createState() =>
      _SegmentationOnboardingScreenState();
}

class _SegmentationOnboardingScreenState
    extends State<SegmentationOnboardingScreen> {
  int _step = 0;
  bool _isSaving = false;

  String? _serviceType;
  String? _monthlyVolume;
  String? _teamSize;

  Future<void> _saveAndFinish({required bool skipped}) async {
    if (_isSaving) return;

    setState(() => _isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        widget.onCompleted();
        return;
      }

      final payload = <String, dynamic>{
        'completedAt': DateTime.now().toUtc().toIso8601String(),
        'skipped': skipped,
      };

      if (!skipped) {
        payload['serviceType'] = _serviceType;
        payload['monthlyVolume'] = _monthlyVolume;
        payload['teamSize'] = _teamSize;
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'onboardingSegment': payload,
      }, SetOptions(merge: true));

      if (!mounted) return;
      widget.onCompleted();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);

      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: Text(context.l10n.error),
          content: Text(e.toString()),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(context.l10n.ok),
            ),
          ],
        ),
      );
    }
  }

  bool get _canProceed {
    if (_step == 0) return _serviceType != null;
    if (_step == 1) return _monthlyVolume != null;
    return _teamSize != null;
  }

  List<_OptionItem> _serviceTypeOptions() => [
    _OptionItem('technical_assistance', context.l10n.serviceTypeTechnicalAssistance),
    _OptionItem('hvac', context.l10n.serviceTypeHvac),
    _OptionItem('electrical_plumbing', context.l10n.serviceTypeElectricalPlumbing),
    _OptionItem('automotive', context.l10n.serviceTypeAutomotive),
    _OptionItem('other', context.l10n.other),
  ];

  List<_OptionItem> _monthlyVolumeOptions() => [
    _OptionItem('lt10', context.l10n.monthlyVolumeLt10),
    _OptionItem('10-30', context.l10n.monthlyVolume10To30),
    _OptionItem('30-60', context.l10n.monthlyVolume30To60),
    _OptionItem('gt60', context.l10n.monthlyVolumeGt60),
  ];

  List<_OptionItem> _teamSizeOptions() => [
    _OptionItem('solo', context.l10n.teamSizeSolo),
    _OptionItem('1-3', context.l10n.teamSize1To3),
    _OptionItem('4-10', context.l10n.teamSize4To10),
    _OptionItem('gt10', context.l10n.teamSizeGt10),
  ];

  @override
  Widget build(BuildContext context) {
    final isLastStep = _step == 2;
    final question = _step == 0
        ? context.l10n.segmentationServiceTypeQuestion
        : _step == 1
            ? context.l10n.segmentationMonthlyVolumeQuestion
            : context.l10n.segmentationTeamSizeQuestion;

    final options = _step == 0
        ? _serviceTypeOptions()
        : _step == 1
            ? _monthlyVolumeOptions()
            : _teamSizeOptions();

    final selected = _step == 0
        ? _serviceType
        : _step == 1
            ? _monthlyVolume
            : _teamSize;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(context.l10n.segmentationOnboardingTitle),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _isSaving ? null : () => _saveAndFinish(skipped: true),
          child: Text(context.l10n.skip),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Text(
                context.l10n.segmentationOnboardingSubtitle,
                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                '${_step + 1}/3',
                textAlign: TextAlign.center,
                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                  color: CupertinoColors.tertiaryLabel.resolveFrom(context),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                question,
                style: CupertinoTheme.of(context).textTheme.navTitleTextStyle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.separated(
                  itemCount: options.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = options[index];
                    final isSelected = selected == item.value;
                    return CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _isSaving
                          ? null
                          : () {
                              setState(() {
                                if (_step == 0) _serviceType = item.value;
                                if (_step == 1) _monthlyVolume = item.value;
                                if (_step == 2) _teamSize = item.value;
                              });
                            },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? CupertinoColors.activeBlue.withValues(alpha: 0.12)
                              : CupertinoColors.secondarySystemGroupedBackground
                                  .resolveFrom(context),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? CupertinoColors.activeBlue
                                : CupertinoColors.systemGrey4.resolveFrom(context),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.label,
                                style: CupertinoTheme.of(context).textTheme.textStyle,
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                CupertinoIcons.check_mark_circled_solid,
                                color: CupertinoColors.activeBlue,
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  onPressed: !_canProceed || _isSaving
                      ? null
                      : () {
                          if (isLastStep) {
                            _saveAndFinish(skipped: false);
                            return;
                          }
                          setState(() => _step += 1);
                        },
                  child: _isSaving
                      ? const CupertinoActivityIndicator()
                      : Text(isLastStep ? context.l10n.finish : context.l10n.next),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionItem {
  final String value;
  final String label;

  _OptionItem(this.value, this.label);
}
