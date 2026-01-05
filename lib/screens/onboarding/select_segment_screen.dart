import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SelectSegmentScreen extends StatefulWidget {
  final String? companyId; // ID da empresa existente (se houver)
  final String companyName;
  final String phone;
  final String address;

  const SelectSegmentScreen({
    Key? key,
    this.companyId,
    required this.companyName,
    required this.phone,
    required this.address,
  }) : super(key: key);

  @override
  State<SelectSegmentScreen> createState() => _SelectSegmentScreenState();
}

class _SelectSegmentScreenState extends State<SelectSegmentScreen> {
  bool _isCreating = false;

  Future<void> _saveCompany(
    String segmentId,
    Map<String, dynamic> segmentData,
  ) async {
    if (_isCreating) return;

    setState(() => _isCreating = true);
    debugPrint('🚀 _saveCompany started');

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Usuário não autenticado');

      final db = FirebaseFirestore.instance;

      if (widget.companyId != null) {
        debugPrint('🔄 Updating company ${widget.companyId}...');
        // Atualiza empresa existente
        await db.collection('companies').doc(widget.companyId).update({
          'name': widget.companyName,
          'phone': widget.phone,
          'address': widget.address,
          'segment': segmentId,
          'updatedAt': DateTime.now().toIso8601String(),
        });
        debugPrint('✅ Company updated successfully');

        if (context.mounted) {
          debugPrint('➡ Navigating to /');
          // Redireciona para home
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        }
      } else {
        debugPrint('✨ Creating new company...');
        // Cria nova empresa
        final companyRef = await db.collection('companies').add({
          'name': widget.companyName,
          'phone': widget.phone,
          'address': widget.address,
          'segment': segmentId,
          'owner': user.uid,
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        });
        debugPrint('✅ Company created: ${companyRef.id}');

        debugPrint('👤 Updating user profile...');
        // Adiciona o usuário como membro da empresa
        await db.collection('users').doc(user.uid).set({
          'email': user.email,
          'name': user.displayName ?? user.email?.split('@')[0],
          'companies': FieldValue.arrayUnion([companyRef.id]),
          'updatedAt': DateTime.now().toIso8601String(),
        }, SetOptions(merge: true));
        debugPrint('✅ User profile updated');

        if (context.mounted) {
          debugPrint('➡ Navigating to /');
          // Redireciona para home imediatamente
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        }
      }
    } catch (e, stack) {
      debugPrint('❌ Error in _saveCompany: $e');
      debugPrint(stack.toString());
      setState(() => _isCreating = false);

      if (context.mounted) {
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
