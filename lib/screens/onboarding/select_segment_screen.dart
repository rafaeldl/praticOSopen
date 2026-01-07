import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/mobx/user_store.dart';
import 'package:praticos/mobx/company_store.dart';

class SelectSegmentScreen extends StatefulWidget {
  final String? companyId;
  final String companyName;
  final String address;
  final String phone;
  final String email;
  final String? site;
  final XFile? logoFile;

  const SelectSegmentScreen({
    super.key,
    this.companyId,
    required this.companyName,
    required this.address,
    required this.phone,
    required this.email,
    this.site,
    this.logoFile,
  });

  @override
  State<SelectSegmentScreen> createState() => _SelectSegmentScreenState();
}

class _SelectSegmentScreenState extends State<SelectSegmentScreen> {
  bool _isCreating = false;

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

  Future<void> _saveCompany(
    String segmentId,
    Map<String, dynamic> segmentData,
  ) async {
    if (_isCreating) return;

    setState(() => _isCreating = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Usuário não autenticado');

      final db = FirebaseFirestore.instance;
      final String targetCompanyId = widget.companyId ?? db.collection('companies').doc().id;

      // Upload da logo primeiro (se existir)
      String? logoUrl;
      if (widget.logoFile != null) {
        logoUrl = await _uploadLogo(targetCompanyId);
      }

      if (widget.companyId != null) {
        // ATUALIZAR empresa existente usando CompanyStore
        final companyStore = CompanyStore();
        final userStore = UserStore();

        final existingCompany = await companyStore.retrieveCompany(widget.companyId);
        final dbUser = await userStore.findUserById(user.uid);

        if (dbUser == null) {
          throw Exception('Usuário não encontrado no Firestore');
        }

        // Atualiza os campos
        existingCompany.name = widget.companyName;
        existingCompany.phone = widget.phone;
        existingCompany.address = widget.address;
        existingCompany.email = widget.email;
        existingCompany.site = widget.site;
        existingCompany.segment = segmentId;
        existingCompany.updatedAt = DateTime.now();
        existingCompany.updatedBy = dbUser.toAggr();
        if (logoUrl != null) {
          existingCompany.logo = logoUrl;
        }

        // Usa o store para salvar
        await companyStore.updateCompany(existingCompany);
      } else {
        // CRIAR nova empresa usando UserStore (forma correta)
        final userStore = UserStore();
        final dbUser = await userStore.findUserById(user.uid);

        if (dbUser == null) {
          throw Exception('Usuário não encontrado no Firestore');
        }

        final userAggr = dbUser.toAggr();

        // Cria o objeto Company completo com TODOS os campos de auditoria
        final company = Company()
          ..id = targetCompanyId
          ..name = widget.companyName
          ..phone = widget.phone
          ..address = widget.address
          ..email = widget.email
          ..site = widget.site
          ..segment = segmentId
          ..logo = logoUrl
          ..owner = userAggr
          ..createdAt = DateTime.now()
          ..createdBy = userAggr
          ..updatedAt = DateTime.now()
          ..updatedBy = userAggr;

        // Usa o UserStore que cria empresa + vínculo usuário + membership corretamente
        await userStore.createCompanyForUser(company);
      }

      if (mounted) {
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
            title: const Text('Erro'),
            content: Text(e.toString()),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
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
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Escolha o Ramo'),
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
                        widget.companyId != null
                            ? 'Atualizando...'
                            : 'Configurando sua empresa...',
                        style: const TextStyle(color: CupertinoColors.secondaryLabel),
                      ),
                    ],
                  ),
                )
              : StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('segments')
                    .where('active', isEqualTo: true)
                    .orderBy('name')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Erro ao carregar segmentos: ${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: CupertinoColors.systemRed),
                        ),
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CupertinoActivityIndicator());
                  }

                  final segments = snapshot.data?.docs ?? [];

                  if (segments.isEmpty) {
                    return const Center(
                      child: Text('Nenhum segmento disponível'),
                    );
                  }

                  return Column(
                    children: [
                      // Cabeçalho explicativo
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            const Icon(
                              CupertinoIcons.briefcase,
                              size: 48,
                              color: CupertinoColors.activeBlue,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              widget.companyName,
                              style: CupertinoTheme.of(context).textTheme.navLargeTitleTextStyle,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Selecione o ramo de atuação para personalizar o sistema para você.',
                              textAlign: TextAlign.center,
                              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                                color: CupertinoColors.secondaryLabel.resolveFrom(context),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Lista de Segmentos estilo iOS
                      Expanded(
                        child: SingleChildScrollView(
                          child: CupertinoListSection.insetGrouped(
                            header: const Text('SEGMENTOS DISPONÍVEIS'),
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            children: segments.map((doc) {
                              final segment = doc.data() as Map<String, dynamic>;
                              final segmentId = doc.id;

                              return CupertinoListTile.notched(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12, // Aumenta a altura interna
                                ),
                                leading: Text(
                                  segment['icon'] ?? '🔧',
                                  style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                                    fontSize: 24,
                                  ),
                                ),
                                title: Text(
                                  segment['name'] ?? 'Sem nome',
                                  style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                trailing: const Icon(
                                  CupertinoIcons.chevron_forward,
                                  color: CupertinoColors.systemGrey3,
                                  size: 18,
                                ),
                                onTap: () => _saveCompany(segmentId, segment),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
        ),
      ),
    );
  }
}
