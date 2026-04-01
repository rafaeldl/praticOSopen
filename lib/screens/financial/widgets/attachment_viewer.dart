import 'package:flutter/cupertino.dart';

/// Fullscreen image viewer shown in-app to avoid Firebase Storage 403 errors
/// that occur when opening download URLs in an external browser.
class AttachmentImageViewer extends StatelessWidget {
  final String url;

  const AttachmentImageViewer({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context),
          child: const Text('Fechar'),
        ),
      ),
      child: Center(
        child: InteractiveViewer(
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (_, child, progress) => progress == null
                ? child
                : const CupertinoActivityIndicator(),
            errorBuilder: (_, __, ___) => const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.photo, size: 48, color: CupertinoColors.systemGrey),
                SizedBox(height: 8),
                Text('Não foi possível carregar a imagem',
                    style: TextStyle(color: CupertinoColors.systemGrey)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
