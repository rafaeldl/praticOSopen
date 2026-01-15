import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/mobx/auth_store.dart';
import 'package:praticos/mobx/user_store.dart';
import 'package:praticos/mobx/company_store.dart';
import 'package:praticos/services/bootstrap_service.dart';

class ConfirmBootstrapScreen extends StatefulWidget {
  final AuthStore authStore;
  final String? companyId;
  final String companyName;
  final String address;
  final String phone;
  final String email;
  final String? site;
  final XFile? logoFile;
  final String segmentId;
  final List<String> subspecialties;

  const ConfirmBootstrapScreen({
    super.key,
    required this.authStore,
    this.companyId,
    required this.companyName,
    required this.address,
    required this.phone,
    required this.email,
    this.site,
    this.logoFile,
    required this.segmentId,
    required this.subspecialties,
  });

  @override
  State<ConfirmBootstrapScreen> createState() => _ConfirmBootstrapScreenState();
}

class _ConfirmBootstrapScreenState extends State<ConfirmBootstrapScreen> {
  bool _isCreating = false;
  String _statusMessage = '';

  /// Obtém o locale atual do dispositivo
  String get _currentLocale {
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    final languageTag = '${locale.languageCode}-${locale.countryCode ?? ''}';
    // Mapeia para os locales suportados
    if (languageTag.startsWith('pt')) return 'pt-BR';
    if (languageTag.startsWith('es')) return 'es-ES';
    return 'en-US';
  }

  Future<String?> _uploadLogo(String companyId) async {
    if (widget.logoFile == null) return null;
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('companies')
          .child(companyId)
          .child('logo.jpg');

      await ref.putFile(File(widget.logoFile!.path));
      return await ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  Future<void> _saveCompany({required bool runBootstrap}) async {
    if (_isCreating) return;

    setState(() {
      _isCreating = true;
      _statusMessage = context.l10n.preparing;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Usuário não autenticado');

      final db = FirebaseFirestore.instance;
      final String targetCompanyId =
          widget.companyId ?? db.collection('companies').doc().id;

      // Upload da logo
      setState(() => _statusMessage = context.l10n.uploadingLogo);
      String? logoUrl;
      if (widget.logoFile != null) {
        logoUrl = await _uploadLogo(targetCompanyId);
      }

      setState(() => _statusMessage = context.l10n.creatingCompany);

      if (widget.companyId != null) {
        // ATUALIZAR empresa existente
        final companyStore = CompanyStore();
        final userStore = UserStore();

        final existingCompany =
            await companyStore.retrieveCompany(widget.companyId);
        final dbUser = await userStore.findUserById(user.uid);

        if (dbUser == null) {
          throw Exception('Usuário não encontrado no Firestore');
        }

        existingCompany.name = widget.companyName;
        existingCompany.phone = widget.phone;
        existingCompany.address = widget.address;
        existingCompany.email = widget.email;
        existingCompany.site = widget.site;
        existingCompany.segment = widget.segmentId;
        existingCompany.subspecialties =
            widget.subspecialties.isEmpty ? null : widget.subspecialties;
        existingCompany.updatedAt = DateTime.now();
        existingCompany.updatedBy = dbUser.toAggr();
        if (logoUrl != null) {
          existingCompany.logo = logoUrl;
        }

        await companyStore.updateCompany(existingCompany);

        setState(() => _statusMessage = context.l10n.importingForms);
        final bootstrapService = BootstrapService();
        await bootstrapService.syncCompanyFormsFromSegment(
          companyId: targetCompanyId,
          segmentId: widget.segmentId,
          subspecialties: widget.subspecialties,
          userAggr: dbUser.toAggr(),
          locale: _currentLocale,
        );

        // Bootstrap se solicitado
        if (runBootstrap) {
          setState(() => _statusMessage = context.l10n.creatingSampleData);
          await bootstrapService.executeBootstrap(
            companyId: targetCompanyId,
            segmentId: widget.segmentId,
            subspecialties: widget.subspecialties,
            userAggr: dbUser.toAggr(),
            companyAggr: existingCompany.toAggr(),
            locale: _currentLocale,
          );
        }
      } else {
        // CRIAR nova empresa
        final userStore = UserStore();
        final dbUser = await userStore.findUserById(user.uid);

        if (dbUser == null) {
          throw Exception('Usuário não encontrado no Firestore');
        }

        final userAggr = dbUser.toAggr();

        final company = Company()
          ..id = targetCompanyId
          ..name = widget.companyName
          ..phone = widget.phone
          ..address = widget.address
          ..email = widget.email
          ..site = widget.site
          ..segment = widget.segmentId
          ..subspecialties =
              widget.subspecialties.isEmpty ? null : widget.subspecialties
          ..logo = logoUrl
          ..owner = userAggr
          ..createdAt = DateTime.now()
        ..createdBy = userAggr
        ..updatedAt = DateTime.now()
        ..updatedBy = userAggr;

        await userStore.createCompanyForUser(company);

        setState(() => _statusMessage = context.l10n.importingForms);
        final bootstrapService = BootstrapService();
        await bootstrapService.syncCompanyFormsFromSegment(
          companyId: targetCompanyId,
          segmentId: widget.segmentId,
          subspecialties: widget.subspecialties,
          userAggr: userAggr,
          locale: _currentLocale,
        );

        // Bootstrap se solicitado
        if (runBootstrap) {
          setState(() => _statusMessage = context.l10n.creatingSampleData);
          await bootstrapService.executeBootstrap(
            companyId: targetCompanyId,
            segmentId: widget.segmentId,
            subspecialties: widget.subspecialties,
            userAggr: userAggr,
            companyAggr: company.toAggr(),
            locale: _currentLocale,
          );
        }
      }

      if (mounted) {
        // Reload AuthStore BEFORE navigating to update companyAggr
        await widget.authStore.reloadUserAndCompany();

        // Navigate to home
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e, stack) {
      debugPrint('❌ Error in _saveCompany: $e');
      debugPrint(stack.toString());
      if (mounted) setState(() => _isCreating = false);

      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: Text(context.l10n.error),
            content: Text(e.toString()),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(ctx),
                child: Text(context.l10n.ok),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text(context.l10n.almostThere),
      ),
      child: SafeArea(
        child: DefaultTextStyle(
          style: CupertinoTheme.of(context).textTheme.textStyle,
          child: _isCreating
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CupertinoActivityIndicator(radius: 16),
                      const SizedBox(height: 16),
                      Text(
                        _statusMessage,
                        style: const TextStyle(
                            color: CupertinoColors.secondaryLabel),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Ícone e título
                      const Icon(
                        CupertinoIcons.sparkles,
                        size: 64,
                        color: CupertinoColors.systemYellow,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        context.l10n.createSampleDataQuestion,
                        style: CupertinoTheme.of(context)
                            .textTheme
                            .navLargeTitleTextStyle
                            .copyWith(fontSize: 24),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        context.l10n.sampleDataDescription,
                        textAlign: TextAlign.center,
                        style: CupertinoTheme.of(context)
                            .textTheme
                            .textStyle
                            .copyWith(
                              color: CupertinoColors.secondaryLabel
                                  .resolveFrom(context),
                              fontSize: 16,
                            ),
                      ),

                      const SizedBox(height: 32),

                      // Lista de benefícios
                      Container(
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemBackground
                              .resolveFrom(context),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _buildBenefitRow(
                              context,
                              CupertinoIcons.wrench,
                              context.l10n.commonServicesForSegment,
                            ),
                            const SizedBox(height: 12),
                            _buildBenefitRow(
                              context,
                              CupertinoIcons.cube_box,
                              context.l10n.mostUsedProducts,
                            ),
                            const SizedBox(height: 12),
                            _buildBenefitRow(
                              context,
                              CupertinoIcons.device_phone_portrait,
                              context.l10n.sampleEquipment,
                            ),
                            const SizedBox(height: 12),
                            _buildBenefitRow(
                              context,
                              CupertinoIcons.doc_text,
                              context.l10n.sampleForms,
                            ),
                            const SizedBox(height: 12),
                            _buildBenefitRow(
                              context,
                              CupertinoIcons.person,
                              context.l10n.demoCustomer,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      Text(
                        context.l10n.canEditOrDeleteAnytime,
                        textAlign: TextAlign.center,
                        style: CupertinoTheme.of(context)
                            .textTheme
                            .textStyle
                            .copyWith(
                              color: CupertinoColors.secondaryLabel
                                  .resolveFrom(context),
                              fontSize: 14,
                            ),
                      ),

                      const SizedBox(height: 32),

                      // Botão principal - Criar com exemplos
                      SizedBox(
                        width: double.infinity,
                        child: CupertinoButton.filled(
                          onPressed: () => _saveCompany(runBootstrap: true),
                          child: Text(context.l10n.yesCreateSampleData),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Botão secundário - Começar do zero
                      SizedBox(
                        width: double.infinity,
                        child: CupertinoButton(
                          onPressed: () => _saveCompany(runBootstrap: false),
                          child: Text(
                            context.l10n.noStartFromScratch,
                            style: TextStyle(
                              color: CupertinoColors.secondaryLabel
                                  .resolveFrom(context),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildBenefitRow(BuildContext context, IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: CupertinoColors.activeBlue,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                  fontSize: 15,
                ),
          ),
        ),
        const Icon(
          CupertinoIcons.checkmark,
          size: 18,
          color: CupertinoColors.systemGreen,
        ),
      ],
    );
  }
}
