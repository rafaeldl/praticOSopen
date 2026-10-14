import 'package:easy_mask/easy_mask.dart';
import 'package:flutter/cupertino.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/mobx/company_store.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/screens/widgets/app_form_field.dart';
import 'package:praticos/screens/widgets/more_fields_link.dart';
import 'package:praticos/screens/widgets/picker_screen.dart';
import 'package:praticos/screens/widgets/text_link.dart';
import 'package:praticos/services/onboarding_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';
import 'package:praticos/widgets/cached_image.dart';

/// Saves the whole company document (defaults to
/// [CompanyStore.updateCompany]). Throws when the write fails.
typedef CompanySaver = Future<void> Function(Company company);

/// Picks a photo (camera or gallery) and uploads it as the company logo,
/// returning its URL (null when the user gave up).
typedef CompanyLogoUploader =
    Future<String?> Function(Company company, {required bool fromCamera});

/// Independent copy of [company], so an editor can change it and leave the
/// original untouched until the save works.
Company copyCompany(Company company) =>
    Company.fromJson(company.toJson())..subscription = company.subscription;

Future<String?> _uploadLogoWithStore(
  Company company, {
  required bool fromCamera,
}) async {
  final store = CompanyStore();
  final file = fromCamera
      ? await store.photoService.takePhoto()
      : await store.photoService.pickImageFromGallery();
  if (file == null) return null;
  return store.uploadCompanyLogo(file, company);
}

Future<void> _showSaveError(BuildContext context) {
  final l10n = context.l10n;
  return showCupertinoDialog<void>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      content: Text(l10n.companySettingSaveError),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(l10n.ok),
        ),
      ],
    ),
  );
}

/// "Salvar" of the pushed edit screens: text button in `accentText`
/// semibold, spinner while saving.
class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      key: const ValueKey('company_editor_save'),
      padding: EdgeInsets.zero,
      onPressed: busy ? null : onPressed,
      child: busy
          ? const CupertinoActivityIndicator()
          : Text(
              context.l10n.save,
              style: AppTypography.callout.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.accentText.resolveFrom(context),
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Country
// ---------------------------------------------------------------------------

const _priorityCountries = ['BR', 'US', 'PT', 'ES', 'MX'];

/// Countries offered for the company: the common ones first, then the rest
/// alphabetically (the first 50, as the previous company form did).
List<String> companyCountryOptions() {
  final all = IsoCode.values.map((iso) => iso.name).toList();
  final priority = [
    for (final code in _priorityCountries)
      if (all.contains(code)) code,
  ];
  final others = all.where((c) => !_priorityCountries.contains(c)).toList()
    ..sort();
  return [...priority, ...others].take(50).toList();
}

/// Flag emoji of an ISO 3166-1 alpha-2 code.
String countryFlag(String countryCode) {
  final first = countryCode.codeUnitAt(0) - 0x41 + 0x1F1E6;
  final second = countryCode.codeUnitAt(1) - 0x41 + 0x1F1E6;
  return String.fromCharCode(first) + String.fromCharCode(second);
}

/// Name of the common countries (in Portuguese, as before); the ISO code for
/// the others.
String countryName(String countryCode) {
  const names = {
    'BR': 'Brasil',
    'US': 'Estados Unidos',
    'PT': 'Portugal',
    'ES': 'Espanha',
    'MX': 'México',
    'AR': 'Argentina',
    'CL': 'Chile',
    'CO': 'Colômbia',
    'PE': 'Peru',
    'UY': 'Uruguai',
    'FR': 'França',
    'IT': 'Itália',
    'DE': 'Alemanha',
    'GB': 'Reino Unido',
    'CA': 'Canadá',
  };
  return names[countryCode] ?? countryCode;
}

/// A form field that opens a picker: label above, the value on
/// `secondaryFill` with a chevron (same look as [AppFormField]).
class _ChoiceField extends StatelessWidget {
  const _ChoiceField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final secondary = AppColors.textSecondary.resolveFrom(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageMargin,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(
              label,
              style: AppTypography.label.copyWith(color: secondary),
            ),
          ),
          Semantics(
            button: true,
            label: label,
            value: value,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Container(
                constraints: const BoxConstraints(minHeight: 52),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: AppColors.secondaryFill.resolveFrom(context),
                  borderRadius: BorderRadius.circular(AppRadii.field),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        value ?? '',
                        style: AppTypography.body.copyWith(
                          color: AppColors.text.resolveFrom(context),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Icon(
                      CupertinoIcons.chevron_forward,
                      size: 18,
                      color: secondary,
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

// ---------------------------------------------------------------------------
// Nome, logo e contato
// ---------------------------------------------------------------------------

/// "Nome, logo e contato" of Sua empresa: pushed edit screen with the logo
/// (whole, never cropped), name, phone and address; e-mail, site and country
/// behind "Mais dados" (open right away when any of them is filled).
///
/// "Salvar" applies the fields to a copy of [company], calls [onSave] and
/// pops with that copy. When [onSave] throws, an alert shows and the screen
/// stays.
class CompanyDataScreen extends StatefulWidget {
  const CompanyDataScreen({
    super.key,
    required this.company,
    required this.onSave,
    this.phoneMasks = const [],
    this.uploadLogo,
    this.onLogoChanged,
  });

  final Company company;
  final CompanySaver onSave;

  /// Phone masks of the company country (`company.phone`).
  final List<String> phoneMasks;

  /// Defaults to the camera/gallery pick and upload of [CompanyStore].
  final CompanyLogoUploader? uploadLogo;

  /// The logo was uploaded (and already saved) with this URL.
  final ValueChanged<String>? onLogoChanged;

  @override
  State<CompanyDataScreen> createState() => _CompanyDataScreenState();
}

class _CompanyDataScreenState extends State<CompanyDataScreen> {
  final _formKey = GlobalKey<FormState>();
  late final Company _company = copyCompany(widget.company);
  late final _name = TextEditingController(text: _company.name);
  late final _phone = TextEditingController(text: _company.phone);
  late final _address = TextEditingController(text: _company.address);
  late final _email = TextEditingController(text: _company.email);
  late final _site = TextEditingController(text: _company.site);
  late String? _country = _company.country;
  bool _busy = false;
  bool _uploading = false;

  @override
  void dispose() {
    for (final c in [_name, _phone, _address, _email, _site]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _hasMoreData {
    bool filled(String? v) => v != null && v.trim().isNotEmpty;
    return filled(_company.email) ||
        filled(_company.site) ||
        filled(_company.country);
  }

  String? _clean(String text) => text.trim().isEmpty ? null : text.trim();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _company
      ..name = _name.text.trim()
      ..phone = _clean(_phone.text)
      ..address = _clean(_address.text)
      ..email = _clean(_email.text)
      ..site = _clean(_site.text)
      ..country = _country;
    setState(() => _busy = true);
    try {
      await widget.onSave(_company);
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        await _showSaveError(context);
      }
      return;
    }
    if (mounted) Navigator.pop(context, _company);
  }

  Future<void> _pickCountry() async {
    final picked = await pickOne<String>(
      context,
      title: context.l10n.pickCountryTitle,
      selected: _country,
      options: [
        for (final code in companyCountryOptions())
          PickerItem(
            key: ValueKey('country_$code'),
            value: code,
            title: '${countryFlag(code)} ${countryName(code)}',
          ),
      ],
    );
    if (picked != null && mounted) setState(() => _country = picked);
  }

  void _changeLogo() {
    final l10n = context.l10n;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text(l10n.changeLogo),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              _uploadLogo(fromCamera: true);
            },
            child: Text(l10n.takePhoto),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              _uploadLogo(fromCamera: false);
            },
            child: Text(l10n.chooseFromGallery),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: Text(l10n.cancel),
        ),
      ),
    );
  }

  Future<void> _uploadLogo({required bool fromCamera}) async {
    final upload = widget.uploadLogo ?? _uploadLogoWithStore;
    setState(() => _uploading = true);
    try {
      final url = await upload(_company, fromCamera: fromCamera);
      if (url != null) {
        _company.logo = url;
        widget.onLogoChanged?.call(url);
      }
    } catch (_) {
      if (mounted) await _showSaveError(context);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Widget _logo() {
    final l10n = context.l10n;
    final logo = _company.logo;
    final hasLogo = logo != null && logo.isNotEmpty;
    const size = 112.0;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageMargin,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Container(
            key: const ValueKey('company_logo'),
            width: size,
            height: size,
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.secondaryFill.resolveFrom(context),
              borderRadius: BorderRadius.circular(AppRadii.block),
            ),
            child: _uploading
                ? const Center(child: CupertinoActivityIndicator())
                : hasLogo
                ? CachedImage(
                    imageUrl: logo,
                    width: size,
                    height: size,
                    fit: BoxFit.contain,
                  )
                : Icon(
                    CupertinoIcons.building_2_fill,
                    size: 44,
                    color: AppColors.textSecondary.resolveFrom(context),
                  ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Flexible(
            child: TextLink(
              key: const ValueKey('company_change_logo'),
              label: hasLogo ? l10n.changeLogoLink : l10n.addLogo,
              onPressed: _uploading ? null : _changeLogo,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final masks = widget.phoneMasks;
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background.resolveFrom(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text(l10n.companyNameLogoContact),
        trailing: _SaveButton(busy: _busy, onPressed: _save),
      ),
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.only(
              top: AppSpacing.sm,
              bottom: AppSpacing.xxl,
            ),
            children: [
              _logo(),
              AppFormField(
                key: const ValueKey('company_name_field'),
                label: l10n.name,
                controller: _name,
                placeholder: l10n.companyNamePlaceholder,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    v.trim().isEmpty ? l10n.companyNameRequired : null,
              ),
              AppFormField(
                key: const ValueKey('company_phone_field'),
                label: l10n.phone,
                controller: _phone,
                keyboardType: TextInputType.phone,
                inputFormatters: masks.isEmpty
                    ? null
                    : [
                        TextInputMask(
                          mask: masks.length == 1 ? masks.first : masks,
                        ),
                      ],
              ),
              AppFormField(
                key: const ValueKey('company_address_field'),
                label: l10n.address,
                controller: _address,
                placeholder: l10n.fullAddress,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
              ),
              MoreFieldsLink(
                label: l10n.moreCompanyData,
                initiallyExpanded: _hasMoreData,
                children: [
                  AppFormField(
                    key: const ValueKey('company_email_field'),
                    label: l10n.email,
                    controller: _email,
                    placeholder: l10n.companyEmailPlaceholder,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  AppFormField(
                    key: const ValueKey('company_site_field'),
                    label: l10n.website,
                    controller: _site,
                    placeholder: l10n.websitePlaceholder,
                    keyboardType: TextInputType.url,
                  ),
                  _ChoiceField(
                    key: const ValueKey('company_country_field'),
                    label: l10n.country,
                    value: _country == null
                        ? null
                        : '${countryFlag(_country!)} ${countryName(_country!)}',
                    onTap: _pickCountry,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Termos para o cliente
// ---------------------------------------------------------------------------

/// "Termos para o cliente" of Sua empresa: one multiline field with the
/// terms shown on the customer's order (`Company.termsOfService`). While it
/// is empty, a link fills in the segment default ([defaultTerms]).
class CompanyTermsScreen extends StatefulWidget {
  const CompanyTermsScreen({
    super.key,
    required this.company,
    required this.onSave,
    this.defaultTerms,
  });

  final Company company;
  final CompanySaver onSave;
  final String? defaultTerms;

  @override
  State<CompanyTermsScreen> createState() => _CompanyTermsScreenState();
}

class _CompanyTermsScreenState extends State<CompanyTermsScreen> {
  late final Company _company = copyCompany(widget.company);
  late final _terms = TextEditingController(text: _company.termsOfService);
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _terms.addListener(_onEdit);
  }

  @override
  void dispose() {
    _terms.dispose();
    super.dispose();
  }

  void _onEdit() {
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    final text = _terms.text.trim();
    _company.termsOfService = text.isEmpty ? null : text;
    setState(() => _busy = true);
    try {
      await widget.onSave(_company);
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        await _showSaveError(context);
      }
      return;
    }
    if (mounted) Navigator.pop(context, _company);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final defaultTerms = widget.defaultTerms;
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background.resolveFrom(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text(l10n.customerTerms),
        trailing: _SaveButton(busy: _busy, onPressed: _save),
      ),
      child: SafeArea(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.only(
            top: AppSpacing.lg,
            bottom: AppSpacing.xxl,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pageMargin,
              ),
              child: Text(
                l10n.companyShownOnOrder,
                style: AppTypography.callout.copyWith(
                  color: AppColors.textSecondary.resolveFrom(context),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppFormField(
              key: const ValueKey('company_terms_field'),
              label: l10n.customerTermsHint,
              controller: _terms,
              placeholder: l10n.termsOfServicePlaceholder,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 14,
            ),
            if (_terms.text.trim().isEmpty &&
                defaultTerms != null &&
                defaultTerms.isNotEmpty)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.pageMargin,
                  ),
                  child: TextLink(
                    key: const ValueKey('company_terms_default'),
                    label: l10n.useDefaultTerms,
                    onPressed: () => _terms.text = defaultTerms,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ramo e especialidades
// ---------------------------------------------------------------------------

/// "Qual é o seu ramo?": returns the picked segment id.
Future<String?> pickCompanySegment(
  BuildContext context, {
  required List<OnboardingSegment> segments,
  String? selectedId,
}) {
  final locale = Localizations.localeOf(context);
  return pickOne<String>(
    context,
    title: context.l10n.pickSegmentTitle,
    selected: selectedId,
    options: [
      for (final segment in segments)
        PickerItem(
          key: ValueKey('segment_${segment.id}'),
          value: segment.id,
          title: segment.nameFor(locale),
          leading: Text(segment.icon ?? '🔧', style: AppTypography.body),
        ),
    ],
  );
}

/// "O que você atende?": multiple choice of the [segment] specialties.
/// Returns the checked ids in the segment order (empty when none), or null
/// when the user went back.
Future<List<String>?> pickCompanySpecialties(
  BuildContext context, {
  required OnboardingSegment segment,
  List<String> selected = const [],
}) {
  return Navigator.of(context).push<List<String>>(
    CupertinoPageRoute<List<String>>(
      builder: (_) => _SpecialtiesPicker(segment: segment, selected: selected),
    ),
  );
}

class _SpecialtiesPicker extends StatefulWidget {
  const _SpecialtiesPicker({required this.segment, required this.selected});

  final OnboardingSegment segment;
  final List<String> selected;

  @override
  State<_SpecialtiesPicker> createState() => _SpecialtiesPickerState();
}

class _SpecialtiesPickerState extends State<_SpecialtiesPicker> {
  late final Set<String> _selected = {...widget.selected};

  void _confirm() {
    Navigator.pop(context, [
      for (final s in widget.segment.subspecialties)
        if (_selected.contains(s.id)) s.id,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final subs = widget.segment.subspecialties;
    return PickerScaffold<String>(
      title: context.l10n.pickSpecialtiesTitle,
      itemCount: subs.length,
      multiple: true,
      strongTitles: false,
      onConfirm: _confirm,
      onSelect: (id) => setState(() {
        if (!_selected.remove(id)) _selected.add(id);
      }),
      sections: (query) => [
        PickerSection<String>(
          items: [
            for (final sub in subs)
              if (pickerMatches(sub.nameFor(locale), query))
                PickerItem(
                  key: ValueKey('specialty_${sub.id}'),
                  value: sub.id,
                  title: sub.nameFor(locale),
                  leading: sub.icon == null
                      ? null
                      : Text(sub.icon!, style: AppTypography.body),
                  selected: _selected.contains(sub.id),
                ),
          ],
        ),
      ],
    );
  }
}
