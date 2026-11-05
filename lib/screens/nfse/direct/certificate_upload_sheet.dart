import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/screens/nfse/direct/nfse_direct_texts.dart';
import 'package:praticos/screens/order/new_order_form.dart';
import 'package:praticos/screens/widgets/app_form_field.dart';
import 'package:praticos/screens/widgets/form_sheet.dart';
import 'package:praticos/screens/widgets/text_link.dart';
import 'package:praticos/services/nfse_direct_api_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';
import 'package:url_launcher/url_launcher.dart';

/// A file the user picked: its name and bytes (kept only in memory).
class PickedCertificate {
  const PickedCertificate(this.name, this.bytes);

  final String name;
  final List<int> bytes;
}

/// A .pfx is a few KB; the server takes up to ~64 KB.
const _maxCertificateBytes = 64 * 1024;

/// Opens Arquivos (iPhone) / the file chooser for a .pfx or .p12.
Future<PickedCertificate?> pickCertificateFile() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['pfx', 'p12'],
    withData: true,
  );
  final file = result?.files.firstOrNull;
  final bytes = file?.bytes;
  if (file == null || bytes == null) return null;
  return PickedCertificate(file.name, bytes);
}

/// Where the certificate terms live.
const nfseCertificateTermsUrl = 'https://praticos.app/privacy.html';

/// "Adicionar CNPJ" / "Trocar certificado" (spec §4.2): the A1 file, its
/// password and the terms. The "✓" turns blue with a file and a password;
/// the server checks the certificate and answers with a plain sentence when
/// something is wrong. The password goes only in the request: it is never
/// saved on the device. Pops with true when the server took it.
class CertificateUploadSheet extends StatefulWidget {
  const CertificateUploadSheet({
    super.key,
    this.emitterId,
    this.legalName,
    this.service,
    this.pickFile,
  });

  /// Replaces the certificate of this emitter; null adds a new CNPJ.
  final String? emitterId;
  final String? legalName;

  /// Test seams.
  final NfseDirectApiService? service;
  final Future<PickedCertificate?> Function()? pickFile;

  static Future<bool?> show(
    BuildContext context, {
    String? emitterId,
    String? legalName,
    NfseDirectApiService? service,
    Future<PickedCertificate?> Function()? pickFile,
  }) => FormSheet.show<bool>(
    context,
    (_) => CertificateUploadSheet(
      emitterId: emitterId,
      legalName: legalName,
      service: service,
      pickFile: pickFile,
    ),
  );

  @override
  State<CertificateUploadSheet> createState() => _CertificateUploadSheetState();
}

class _CertificateUploadSheetState extends State<CertificateUploadSheet> {
  final _password = TextEditingController();
  PickedCertificate? _file;
  String? _error;
  bool _busy = false;

  bool get _replace => widget.emitterId != null;

  bool get _ready => _file != null && _password.text.isNotEmpty;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final PickedCertificate? picked;
    try {
      picked = await (widget.pickFile ?? pickCertificateFile)();
    } catch (_) {
      if (mounted) {
        setState(() => _error = context.l10n.nfseDirectErrorInvalidFile);
      }
      return;
    }
    if (picked == null || !mounted) return;
    final tooBig = picked.bytes.length > _maxCertificateBytes;
    setState(() {
      _file = tooBig ? null : picked;
      _error = tooBig ? context.l10n.nfseDirectErrorInvalidFile : null;
    });
  }

  Future<void> _send() async {
    final file = _file;
    if (_busy || file == null || _password.text.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final service = widget.service ?? NfseDirectApiService.instance;
    try {
      if (_replace) {
        await service.replaceCertificate(
          widget.emitterId!,
          file.bytes,
          _password.text,
        );
      } else {
        await service.addCertificate(file.bytes, _password.text);
      }
      _password.clear();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = nfseDirectErrorText(context.l10n, e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final secondary = AppColors.textSecondary.resolveFrom(context);
    final file = _file;
    return FormSheet(
      key: const Key('certificateUploadSheet'),
      title: _replace
          ? l10n.nfseDirectReplaceTitle
          : l10n.nfseDirectAddCnpjTitle,
      canSave: _ready && !_busy,
      missingHint: _ready ? null : l10n.nfseDirectUploadMissing,
      dirty: file != null || _password.text.isNotEmpty,
      busy: _busy,
      onSave: _send,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageMargin,
            0,
            AppSpacing.pageMargin,
            AppSpacing.md,
          ),
          child: Text(
            _replace
                ? l10n.nfseDirectReplaceIntro(widget.legalName ?? '')
                : l10n.nfseDirectAddCnpjIntro,
            style: AppTypography.body.copyWith(
              color: AppColors.text.resolveFrom(context),
            ),
          ),
        ),
        FormCard(
          children: [
            FormRow(
              key: const Key('certificatePickFile'),
              title: l10n.nfseDirectCertificateFile,
              subtitle: file?.name,
              value: file == null ? l10n.nfseDirectPickFile : null,
              onTap: _busy ? null : _pick,
            ),
          ],
        ),
        FormFieldsCard(
          children: [
            AppFormField(
              key: const Key('certificatePassword'),
              label: l10n.nfseDirectCertificatePassword,
              controller: _password,
              obscureText: true,
              hint: l10n.nfseDirectCertificatePasswordHint,
              onChanged: (_) => setState(() => _error = null),
            ),
          ],
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageMargin,
              0,
              AppSpacing.pageMargin,
              AppSpacing.md,
            ),
            child: Text(
              _error!,
              key: const Key('certificateError'),
              style: AppTypography.body.copyWith(
                color: AppColors.danger.resolveFrom(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pageMargin,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.nfseDirectTerms,
                style: AppTypography.callout.copyWith(color: secondary),
              ),
              TextLink(
                key: const Key('certificateTermsLink'),
                label: l10n.nfseDirectTermsLink,
                onPressed: () => launchUrl(
                  Uri.parse(nfseCertificateTermsUrl),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
