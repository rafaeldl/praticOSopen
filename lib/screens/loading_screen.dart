import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Usamos Scaffold para garantir que preencha a tela corretamente em todos os casos
    // mas com estilo visual alinhado ao Cupertino
    return Scaffold(
      backgroundColor: CupertinoColors.systemBackground, 
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/icon.png',
              width: 100,
              height: 100,
              // Se a imagem não existir ou falhar, mantém o layout estável
              errorBuilder: (_, __, ___) => const SizedBox(height: 100),
            ),
            const SizedBox(height: 24),
            const CupertinoActivityIndicator(radius: 12),
          ],
        ),
      ),
    );
  }
}
