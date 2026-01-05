import 'package:flutter/material.dart';
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
    BuildContext context,
    String segmentId,
    Map<String, dynamic> segmentData,
  ) async {
    if (_isCreating) return;

    setState(() => _isCreating = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Usuário não autenticado');

      final db = FirebaseFirestore.instance;

      if (widget.companyId != null) {
        // Atualiza empresa existente
        await db.collection('companies').doc(widget.companyId).update({
          'name': widget.companyName,
          'phone': widget.phone,
          'address': widget.address,
          'segment': segmentId,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Empresa atualizada com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );

          // Redireciona para home
          Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
        }
      } else {
        // Cria nova empresa
        final companyRef = await db.collection('companies').add({
          'name': widget.companyName,
          'phone': widget.phone,
          'address': widget.address,
          'segment': segmentId,
          'owner': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Adiciona o usuário como membro da empresa
        await db.collection('users').doc(user.uid).set({
          'email': user.email,
          'name': user.displayName ?? user.email?.split('@')[0],
          'companies': FieldValue.arrayUnion([companyRef.id]),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Empresa criada com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );

          // Redireciona para home
          Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
        }
      }
    } catch (e) {
      setState(() => _isCreating = false);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar empresa: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Qual o ramo do seu negócio?'),
        centerTitle: true,
      ),
      body: _isCreating
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(widget.companyId != null
                      ? 'Atualizando empresa...'
                      : 'Criando empresa...'),
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
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        const Text('Erro ao carregar segmentos'),
                        const SizedBox(height: 8),
                        Text(
                          snapshot.error.toString(),
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final segments = snapshot.data?.docs ?? [];

                if (segments.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.inbox, size: 48, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('Nenhum segmento disponível'),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    // Cabeçalho
                    Container(
                      padding: const EdgeInsets.all(24),
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                      child: Column(
                        children: [
                          Icon(
                            Icons.business_center,
                            size: 48,
                            color: Theme.of(context).primaryColor,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            widget.companyName,
                            style: Theme.of(context).textTheme.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Selecione o ramo de atuação para personalizar o sistema',
                            style: TextStyle(color: Colors.grey[600]),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    // Lista de segmentos
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: segments.length,
                        itemBuilder: (context, index) {
                          final segment = segments[index].data() as Map<String, dynamic>;
                          final segmentId = segments[index].id;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              leading: Text(
                                segment['icon'] ?? '🔧',
                                style: const TextStyle(fontSize: 32),
                              ),
                              title: Text(
                                segment['name'] ?? 'Sem nome',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                              onTap: () => _saveCompany(context, segmentId, segment),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
