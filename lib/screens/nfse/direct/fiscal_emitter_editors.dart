import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/models/fiscal_emitter.dart';
import 'package:praticos/screens/menu_navigation/more/more_page.dart';
import 'package:praticos/screens/nfse/direct/nfse_direct_texts.dart';
import 'package:praticos/screens/nfse/nfse_setup_screen.dart'
    show nfsePercentText, parseNfsePercent;
import 'package:praticos/screens/order/new_order_form.dart';
import 'package:praticos/screens/widgets/app_form_field.dart';
import 'package:praticos/screens/widgets/app_toast.dart';
import 'package:praticos/screens/widgets/form_sheet.dart';
import 'package:praticos/screens/widgets/picker_screen.dart';
import 'package:praticos/services/nfse_direct_api_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';

/// Separators the server accepts (DESCRIPTION_SEPARATORS in
/// emitter-settings.service.ts).
const descriptionSeparators = [', ', ' - ', ' / ', '; '];

/// Shared save flow of the editors: busy, call, pop with true or show the
/// error in a toast.
mixin _EditorSave<T extends StatefulWidget> on State<T> {
  bool busy = false;

  Future<void> save(Future<void> Function() call) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await call();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => busy = false);
      showAppToast(
        context,
        nfseDirectErrorText(context.l10n, e),
        icon: CupertinoIcons.exclamationmark_circle,
      );
    }
  }
}

/// "Serviço da nota": name, national code (cTribNac, 6 digits) and ISS.
class EmitterServiceSheet extends StatefulWidget {
  const EmitterServiceSheet({super.key, required this.emitter, this.service});

  final FiscalEmitter emitter;
  final NfseDirectApiService? service;

  @override
  State<EmitterServiceSheet> createState() => _EmitterServiceSheetState();
}

class _EmitterServiceSheetState extends State<EmitterServiceSheet>
    with _EditorSave {
  late final _name = TextEditingController(text: widget.emitter.service?.name);
  late final _code = TextEditingController(
    text: widget.emitter.service?.nationalCode,
  );
  late final _iss = TextEditingController(
    text: nfsePercentText(widget.emitter.service?.issRate ?? 0),
  );
  bool _dirty = false;

  bool get _valid =>
      _name.text.trim().isNotEmpty &&
      RegExp(r'^\d{6}$').hasMatch(_code.text.trim());

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _iss.dispose();
    super.dispose();
  }

  void _changed(String _) => setState(() => _dirty = true);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final current = widget.emitter.service;
    return FormSheet(
      key: const Key('emitterServiceSheet'),
      title: l10n.nfseDirectServiceRow,
      canSave: _valid,
      missingHint: _valid ? null : l10n.nfseDirectServiceMissing,
      dirty: _dirty,
      busy: busy,
      onSave: () => save(
        () => (widget.service ?? NfseDirectApiService.instance).updateService(
          widget.emitter.id!,
          FiscalEmitterService(
            name: _name.text.trim(),
            nationalCode: _code.text.trim(),
            municipalCode: current?.municipalCode,
            nbs: current?.nbs,
            issRate: parseNfsePercent(_iss.text),
          ),
        ),
      ),
      children: [
        FormFieldsCard(
          children: [
            AppFormField(
              key: const Key('emitterServiceName'),
              label: l10n.nfseDirectServiceName,
              controller: _name,
              placeholder: l10n.nfseDirectServiceNamePlaceholder,
              textCapitalization: TextCapitalization.sentences,
              onChanged: _changed,
            ),
            AppFormField(
              key: const Key('emitterServiceCode'),
              label: l10n.nfseDirectServiceCode,
              controller: _code,
              placeholder: l10n.nfseDirectServiceCodePlaceholder,
              hint: l10n.nfseDirectServiceCodeHint,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              onChanged: _changed,
            ),
            AppFormField(
              key: const Key('emitterServiceIss'),
              label: l10n.nfseIss,
              controller: _iss,
              placeholder: '0',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: _changed,
            ),
          ],
        ),
      ],
    );
  }
}

/// "Inscrição municipal": one field; empty removes it.
class EmitterRegistrationSheet extends StatefulWidget {
  const EmitterRegistrationSheet({
    super.key,
    required this.emitter,
    this.service,
  });

  final FiscalEmitter emitter;
  final NfseDirectApiService? service;

  @override
  State<EmitterRegistrationSheet> createState() =>
      _EmitterRegistrationSheetState();
}

class _EmitterRegistrationSheetState extends State<EmitterRegistrationSheet>
    with _EditorSave {
  late final _value = TextEditingController(
    text: widget.emitter.municipalRegistration,
  );
  bool _dirty = false;

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FormSheet(
      key: const Key('emitterRegistrationSheet'),
      title: l10n.nfseDirectRegistrationRow,
      canSave: _dirty,
      dirty: _dirty,
      busy: busy,
      onSave: () => save(
        () => (widget.service ?? NfseDirectApiService.instance)
            .updateMunicipalRegistration(
              widget.emitter.id!,
              _value.text.trim().isEmpty ? null : _value.text.trim(),
            ),
      ),
      children: [
        FormFieldsCard(
          children: [
            AppFormField(
              key: const Key('emitterRegistration'),
              label: l10n.nfseDirectRegistrationRow,
              controller: _value,
              hint: l10n.nfseDirectRegistrationHint,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9./-]')),
                LengthLimitingTextInputFormatter(20),
              ],
              onChanged: (_) => setState(() => _dirty = true),
            ),
          ],
        ),
      ],
    );
  }
}

/// Sample of how the description comes out with [style].
String descriptionStylePreview(
  FiscalDescriptionStyle style,
  List<String> services,
) {
  final text = services.join(style.separator);
  return style.uppercase ? text.toUpperCase() : text;
}

/// "Como escrever a descrição": all caps or not, and the separator of the
/// services of one OS, with a sample line.
class EmitterDescriptionStyleScreen extends StatefulWidget {
  const EmitterDescriptionStyleScreen({
    super.key,
    required this.emitter,
    this.service,
  });

  final FiscalEmitter emitter;
  final NfseDirectApiService? service;

  @override
  State<EmitterDescriptionStyleScreen> createState() =>
      _EmitterDescriptionStyleScreenState();
}

class _EmitterDescriptionStyleScreenState
    extends State<EmitterDescriptionStyleScreen> {
  late FiscalDescriptionStyle _style =
      widget.emitter.descriptionStyle ?? FiscalDescriptionStyle();
  bool _busy = false;

  Future<void> _apply(FiscalDescriptionStyle next) async {
    if (_busy) return;
    final before = _style;
    setState(() {
      _style = next;
      _busy = true;
    });
    try {
      await (widget.service ?? NfseDirectApiService.instance)
          .updateDescriptionStyle(widget.emitter.id!, next);
    } catch (e) {
      if (!mounted) return;
      setState(() => _style = before);
      showAppToast(
        context,
        nfseDirectErrorText(context.l10n, e),
        icon: CupertinoIcons.exclamationmark_circle,
      );
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _pickSeparator() async {
    final l10n = context.l10n;
    final picked = await pickOne<String>(
      context,
      title: l10n.nfseDirectSeparatorQuestion,
      selected: _style.separator,
      options: [
        for (final separator in descriptionSeparators)
          PickerItem(
            key: Key('separator_${descriptionSeparators.indexOf(separator)}'),
            value: separator,
            title: descriptionStylePreview(
              FiscalDescriptionStyle(
                uppercase: _style.uppercase,
                separator: separator,
              ),
              [l10n.nfseDirectSampleService1, l10n.nfseDirectSampleService2],
            ),
          ),
      ],
    );
    if (picked == null || picked == _style.separator || !mounted) return;
    _apply(
      FiscalDescriptionStyle(uppercase: _style.uppercase, separator: picked),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sample = descriptionStylePreview(_style, [
      l10n.nfseDirectSampleService1,
      l10n.nfseDirectSampleService2,
    ]);
    return MorePage(
      title: l10n.nfseDirectStyleRow,
      subtitle: l10n.nfseDirectStyleHead,
      children: [
        MoreRows(
          rows: [
            MoreSwitchRow(
              key: const Key('styleUppercase'),
              title: l10n.nfseDirectStyleUppercase,
              value: _style.uppercase,
              onChanged: _busy
                  ? null
                  : (value) => _apply(
                      FiscalDescriptionStyle(
                        uppercase: value,
                        separator: _style.separator,
                      ),
                    ),
            ),
            FormRow(
              key: const Key('styleSeparator'),
              title: l10n.nfseDirectStyleSeparator,
              value: '"${_style.separator.trim()}"',
              onTap: _busy ? null : _pickSeparator,
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pageMargin,
            vertical: AppSpacing.md,
          ),
          child: Text(
            l10n.nfseDirectStyleSample(sample),
            key: const Key('styleSample'),
            style: AppTypography.callout.copyWith(
              color: AppColors.textSecondary.resolveFrom(context),
            ),
          ),
        ),
      ],
    );
  }
}
