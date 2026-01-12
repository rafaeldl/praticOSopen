import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:praticos/mobx/auth_store.dart';
import 'package:praticos/screens/onboarding/select_subspecialties_screen.dart';
import 'package:praticos/screens/onboarding/confirm_bootstrap_screen.dart';

class SelectSegmentScreen extends StatefulWidget {
  final AuthStore authStore;
  final String? companyId;
  final String companyName;
  final String address;
  final String phone;
  final String email;
  final String? site;
  final XFile? logoFile;

  const SelectSegmentScreen({
    super.key,
    required this.authStore,
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
  void _onSegmentTap(String segmentId, Map<String, dynamic> segmentData) {
    final subspecialties = segmentData['subspecialties'] as List?;
    final segmentName = segmentData['name'] as String? ?? 'Sem nome';

    if (subspecialties != null && subspecialties.isNotEmpty) {
      // Segmento tem subspecialties -> navegar para seleção de subspecialties
      Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (context) => SelectSubspecialtiesScreen(
            authStore: widget.authStore,
            companyId: widget.companyId,
            companyName: widget.companyName,
            address: widget.address,
            phone: widget.phone,
            email: widget.email,
            site: widget.site,
            logoFile: widget.logoFile,
            segmentId: segmentId,
            segmentName: segmentName,
            subspecialties: subspecialties
                .map((s) => Map<String, dynamic>.from(s as Map))
                .toList(),
          ),
        ),
      );
    } else {
      // Segmento não tem subspecialties -> ir direto para confirmação de bootstrap
      Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (context) => ConfirmBootstrapScreen(
            authStore: widget.authStore,
            companyId: widget.companyId,
            companyName: widget.companyName,
            address: widget.address,
            phone: widget.phone,
            email: widget.email,
            site: widget.site,
            logoFile: widget.logoFile,
            segmentId: segmentId,
            subspecialties: const [], // Sem subspecialties
          ),
        ),
      );
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
          child: StreamBuilder<QuerySnapshot>(
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
                          style: CupertinoTheme.of(context)
                              .textTheme
                              .navLargeTitleTextStyle,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Selecione o ramo de atuação para personalizar o sistema para você.',
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
                      ],
                    ),
                  ),

                  // Lista de Segmentos estilo iOS
                  Expanded(
                    child: SingleChildScrollView(
                      child: CupertinoListSection.insetGrouped(
                        header: const Text('SEGMENTOS DISPONÍVEIS'),
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        children: segments.map((doc) {
                          final segment = doc.data() as Map<String, dynamic>;
                          final segmentId = doc.id;
                          final subspecialties =
                              segment['subspecialties'] as List?;
                          final hasSubspecialties =
                              subspecialties != null && subspecialties.isNotEmpty;

                          return CupertinoListTile.notched(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            leading: Text(
                              segment['icon'] ?? '🔧',
                              style: CupertinoTheme.of(context)
                                  .textTheme
                                  .textStyle
                                  .copyWith(fontSize: 24),
                            ),
                            title: Text(
                              segment['name'] ?? 'Sem nome',
                              style: CupertinoTheme.of(context)
                                  .textTheme
                                  .textStyle
                                  .copyWith(fontWeight: FontWeight.w500),
                            ),
                            subtitle: hasSubspecialties
                                ? Text(
                                    '${subspecialties.length} especialidades',
                                    style: CupertinoTheme.of(context)
                                        .textTheme
                                        .textStyle
                                        .copyWith(
                                          fontSize: 13,
                                          color: CupertinoColors.secondaryLabel
                                              .resolveFrom(context),
                                        ),
                                  )
                                : null,
                            trailing: const Icon(
                              CupertinoIcons.chevron_forward,
                              color: CupertinoColors.systemGrey3,
                              size: 18,
                            ),
                            onTap: () => _onSegmentTap(segmentId, segment),
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
