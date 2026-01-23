import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';

class UploadingPhotoPlaceholder extends StatelessWidget {
  const UploadingPhotoPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CupertinoIcons.camera_fill,
                  size: 12,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
                const SizedBox(width: 4),
                Text(
                  context.l10n.uploadingPhoto,
                  style: TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey5.resolveFrom(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: CupertinoActivityIndicator(),
            ),
          ),
        ],
      ),
    );
  }
}
