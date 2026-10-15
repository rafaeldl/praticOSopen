import 'package:flutter/cupertino.dart';
import 'package:praticos/theme/app_colors.dart';

/// Full-screen receipt image viewer
class ReceiptImageViewer extends StatelessWidget {
  final String url;
  final String title;

  const ReceiptImageViewer({super.key, required this.url, required this.title});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.black.withValues(alpha: 0.8),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.back, color: CupertinoColors.white),
          onPressed: () => Navigator.pop(context),
        ),
        middle: Text(
          title,
          style: const TextStyle(color: CupertinoColors.white),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      child: SafeArea(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 3.0,
          child: Center(
            child: Image.network(
              url,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const CupertinoActivityIndicator();
              },
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  CupertinoIcons.exclamationmark_triangle,
                  color: AppColors.textSecondary.resolveFrom(context),
                  size: 48,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
