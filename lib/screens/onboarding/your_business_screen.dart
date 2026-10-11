import 'package:easy_mask/easy_mask.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/screens/menu_navigation/more/more_page.dart';
import 'package:praticos/screens/onboarding/onboarding_flow.dart';
import 'package:praticos/screens/widgets/app_form_field.dart';
import 'package:praticos/screens/widgets/list_states.dart';
import 'package:praticos/screens/widgets/next_step_block.dart';
import 'package:praticos/screens/widgets/primary_button.dart';
import 'package:praticos/screens/widgets/section_label.dart';
import 'package:praticos/screens/widgets/text_link.dart';
import 'package:praticos/services/onboarding_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';

/// Last step of the first access: "Seu negócio". Name (required), phone
/// (optional), "Como você trabalha" with "Valores e cobrança"
/// (`Company.useFinancial`, segment default), then creates the company and
/// goes straight to Início. Replaces Welcome, Contatos and "Quase lá".
class YourBusinessScreen extends StatefulWidget {
  const YourBusinessScreen({
    super.key,
    required this.session,
    required this.segment,
    required this.subspecialties,
  });

  final OnboardingSession session;
  final OnboardingSegment segment;
  final List<String> subspecialties;

  @override
  State<YourBusinessScreen> createState() => _YourBusinessScreenState();
}

enum _Status { editing, saving, failed }

class _YourBusinessScreenState extends State<YourBusinessScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name =
      TextEditingController(text: widget.session.initialName);
  late final TextEditingController _phone =
      TextEditingController(text: widget.session.initialPhone);
  late bool _useFinancial = widget.segment.useFinancialDefault;
  List<String> _phoneMasks = const [];
  _Status _status = _Status.editing;
  bool _lastWithSamples = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMasks());
  }

  Future<void> _loadMasks() async {
    final load = widget.session.deps.loadPhoneMasks;
    if (load == null || !mounted) return;
    try {
      final masks = await load(context);
      if (mounted) setState(() => _phoneMasks = masks);
    } catch (e) {
      // No mask: the field still works.
      debugPrint('Onboarding: phone masks failed: $e');
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  OnboardingBusiness get _business => OnboardingBusiness(
        segment: widget.segment,
        subspecialties: widget.subspecialties,
        name: _name.text.trim(),
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        useFinancial: _useFinancial,
      );

  Future<void> _create({required bool withSamples}) async {
    if (_status == _Status.saving) return;
    if (_status == _Status.editing &&
        !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    FocusScope.of(context).unfocus();
    _lastWithSamples = withSamples;
    setState(() => _status = _Status.saving);

    final session = widget.session;
    final setup = session.deps.setup;
    final data = _business;
    try {
      final companyId = await setup.saveCompany(
        data,
        companyId: session.savedCompanyId ?? session.companyId,
      );
      session.savedCompanyId = companyId;
      await setup.seedCompany(companyId, data, withSamples: withSamples);
      await setup.finish();
      if (!mounted) return;
      session.deps.onFinished(context);
    } catch (e, stack) {
      debugPrint('Onboarding: company setup failed: $e\n$stack');
      if (mounted) setState(() => _status = _Status.failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    if (_status != _Status.editing) {
      final saving = _status == _Status.saving;
      return PopScope(
        // Back from the error goes to the form, not to the previous step.
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _status == _Status.failed) {
            setState(() => _status = _Status.editing);
          }
        },
        child: CupertinoPageScaffold(
          backgroundColor: AppColors.background.resolveFrom(context),
          navigationBar: saving
              ? null
              : CupertinoNavigationBar(
                  backgroundColor: AppColors.background.resolveFrom(context),
                  border: null,
                ),
          child: Material(
            type: MaterialType.transparency,
            child: saving
                ? LoadingState(label: l10n.onboardingPreparing)
                : ErrorState(
                    message: l10n.onboardingCreateError,
                    onRetry: () => _create(withSamples: _lastWithSamples),
                  ),
          ),
        ),
      );
    }

    return Form(
      key: _formKey,
      child: OnboardingPage(
        title: l10n.onboardingBusinessTitle,
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppFormField(
                  key: const ValueKey('business_name'),
                  label: l10n.onboardingBusinessName,
                  controller: _name,
                  placeholder: l10n.onboardingBusinessNamePlaceholder,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  validator: (text) => text.trim().isEmpty
                      ? l10n.onboardingBusinessNameRequired
                      : null,
                ),
                AppFormField(
                  key: ValueKey('business_phone_${_phoneMasks.length}'),
                  label: l10n.onboardingPhoneLabel,
                  controller: _phone,
                  hint: l10n.onboardingPhoneHint,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  inputFormatters: _phoneMasks.isEmpty
                      ? null
                      : [
                          TextInputMask(
                            mask: _phoneMasks.length == 1
                                ? _phoneMasks.first
                                : _phoneMasks,
                          ),
                        ],
                ),
                SectionLabel(l10n.howYouWork),
                MoreSwitchRow(
                  key: const ValueKey('business_use_financial'),
                  title: l10n.valuesAndBilling,
                  subtitle: l10n.valuesAndBillingHint,
                  value: _useFinancial,
                  onChanged: (value) => setState(() => _useFinancial = value),
                ),
                const SizedBox(height: AppSpacing.xl),
                NextStepBlock(text: l10n.onboardingSamplesInfo),
              ],
            ),
          ),
        ],
        bottom: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PrimaryButton(
              key: const ValueKey('business_create'),
              label: l10n.onboardingCreate,
              floating: true,
              onPressed: () => _create(withSamples: true),
            ),
            Center(
              child: TextLink(
                key: const ValueKey('business_no_samples'),
                label: l10n.onboardingStartWithoutSamples,
                onPressed: () => _create(withSamples: false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
