import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/models/order_photo.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/screens/widgets/order_media_actions.dart';
import 'package:praticos/screens/widgets/pull_down_menu.dart';
import 'package:praticos/services/storage_url_resolver.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';
import 'package:praticos/widgets/cached_image.dart';
import 'package:share_plus/share_plus.dart';

/// "Apagar esta foto?" Resolves true when confirmed.
Future<bool> confirmDeleteOrderPhoto(BuildContext context) async {
  final l10n = context.l10n;
  final confirmed = await showCupertinoDialog<bool>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(l10n.orderPhotoDeleteTitle),
      content: Text(l10n.cannotUndo),
      actions: [
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l10n.cancel),
        ),
        CupertinoDialogAction(
          key: const ValueKey('order_photo_delete_confirm'),
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l10n.orderPhotoDelete),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// Photos of the order in full screen (black, like the iPhone's photo
/// viewer): swipe between them, share, and "…" with cover and delete.
class PhotoViewerScreen extends StatefulWidget {
  final List<OrderPhoto> photos;
  final int initialIndex;
  final Future<bool> Function(int index) onDelete;
  final void Function(int index) onSetCover;
  final SegmentConfigProvider config;

  /// Downloads and shares the photo; defaults to [sharePhotoUrl] (tests).
  final Future<void> Function(BuildContext context, String url)? onShare;

  const PhotoViewerScreen({
    super.key,
    required this.photos,
    required this.initialIndex,
    required this.onDelete,
    required this.onSetCover,
    required this.config,
    this.onShare,
  });

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

/// Downloads [url] to a temp file and opens the share sheet with it.
Future<void> sharePhotoUrl(
  BuildContext context,
  String url, {
  String? text,
}) async {
  final response = await http.get(Uri.parse(url));
  if (response.statusCode != 200) {
    throw Exception('Photo download failed (${response.statusCode})');
  }
  final tempDir = await getTemporaryDirectory();
  final fileName = 'foto_os_${DateTime.now().millisecondsSinceEpoch}.jpg';
  final file = await File('${tempDir.path}/$fileName').create();
  await file.writeAsBytes(response.bodyBytes);

  if (!context.mounted) return;
  final box = context.findRenderObject() as RenderBox?;
  final size = MediaQuery.of(context).size;
  // ignore: deprecated_member_use
  await Share.shareXFiles(
    [XFile(file.path)],
    text: text,
    sharePositionOrigin: box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : Rect.fromLTWH(0, 0, size.width, size.height / 2),
  );
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;
  bool _isSharing = false;

  // Over the photo the colors do not follow the theme (iPhone viewer).
  static const _black = Color(0xFF000000);
  static const _white = Color(0xFFFFFFFF);

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _sharePhoto() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    final l10n = context.l10n;
    try {
      final photo = widget.photos[_currentIndex];
      final url = photo.url == null
          ? null
          : await StorageUrlResolver.resolve(photo.url!);
      if (url == null || url.isEmpty) {
        throw Exception('Invalid photo URL');
      }
      if (!mounted) return;
      final share = widget.onShare;
      if (share != null) {
        await share(context, url);
      } else {
        await sharePhotoUrl(
          context,
          url,
          text: l10n.orderPhotoShareText(widget.config.serviceOrder),
        );
      }
    } catch (e) {
      debugPrint('Photo share failed: $e');
      if (mounted) {
        showOrderMediaFeedback(
          context,
          l10n.orderPhotoShareError,
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<void> _showMore() async {
    final l10n = context.l10n;
    final index = _currentIndex;
    final choice = await showPullDownMenu(
      context,
      groups: [
        PullDownGroup([
          if (index > 0)
            PullDownItem(
              value: 'cover',
              label: l10n.setAsCover,
              icon: CupertinoIcons.star,
            ),
          PullDownItem(
            value: 'delete',
            label: l10n.orderPhotoDelete,
            icon: CupertinoIcons.trash,
            destructive: true,
          ),
        ]),
      ],
    );
    if (!mounted) return;
    switch (choice) {
      case 'cover':
        widget.onSetCover(index);
        showOrderMediaFeedback(context, l10n.orderPhotoCoverSet);
      case 'delete':
        await _confirmDelete();
    }
  }

  Future<void> _confirmDelete() async {
    if (!await confirmDeleteOrderPhoto(context)) return;
    final success = await widget.onDelete(_currentIndex);
    if (!mounted) return;
    final l10n = context.l10n;
    showOrderMediaFeedback(
      context,
      success ? l10n.orderPhotoDeleted : l10n.orderPhotoDeleteError,
      isError: !success,
    );
    if (!success) return;
    if (widget.photos.length <= 1) {
      Navigator.pop(context); // Close viewer if no photos left
    } else {
      setState(() {
        if (_currentIndex >= widget.photos.length - 1) {
          _currentIndex = widget.photos.length - 2;
          _pageController.jumpToPage(_currentIndex);
        }
      });
    }
  }

  Widget _barButton({
    required Key key,
    required String label,
    required VoidCallback? onPressed,
    required Widget child,
  }) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: CupertinoButton(
        key: key,
        padding: EdgeInsets.zero,
        minimumSize: const Size(
          AppSizes.minTouchTarget,
          AppSizes.minTouchTarget,
        ),
        onPressed: onPressed,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return CupertinoPageScaffold(
      backgroundColor: _black,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: _black.withValues(alpha: 0.8),
        border: null,
        leading: _barButton(
          key: const ValueKey('photo_viewer_back'),
          label: l10n.back,
          onPressed: () => Navigator.pop(context),
          child: const Icon(CupertinoIcons.back, color: _white),
        ),
        middle: Text(
          l10n.checklistPhotoPosition(_currentIndex + 1, widget.photos.length),
          style: AppTypography.callout.copyWith(
            color: _white,
            fontWeight: FontWeight.w600,
            fontFeatures: AppTypography.tabular,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _barButton(
              key: const ValueKey('photo_viewer_share'),
              label: l10n.share,
              onPressed: _isSharing ? null : _sharePhoto,
              child: _isSharing
                  ? const CupertinoActivityIndicator(color: _white)
                  : const Icon(CupertinoIcons.share, color: _white),
            ),
            _barButton(
              key: const ValueKey('photo_viewer_more'),
              label: l10n.orderMoreActions,
              onPressed: _showMore,
              child: const Icon(CupertinoIcons.ellipsis_circle, color: _white),
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: PageView.builder(
          controller: _pageController,
          itemCount: widget.photos.length,
          onPageChanged: (index) => setState(() => _currentIndex = index),
          itemBuilder: (context, index) {
            final photo = widget.photos[index];
            return InteractiveViewer(
              minScale: 0.5,
              maxScale: 3.0,
              child: Center(
                child: CachedImage.fullScreen(imageUrl: photo.url!),
              ),
            );
          },
        ),
      ),
    );
  }
}
