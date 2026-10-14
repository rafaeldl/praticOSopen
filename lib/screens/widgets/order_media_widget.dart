import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/order_document.dart';
import 'package:praticos/models/order_photo.dart';
import 'package:praticos/models/permission.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/screens/widgets/order_media_actions.dart';
import 'package:praticos/screens/widgets/pull_down_menu.dart';
import 'package:praticos/services/authorization_service.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/services/storage_url_resolver.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';
import 'package:praticos/widgets/cached_image.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

/// Photos and documents of an order (legacy order screen): the cover photo,
/// then a row with "add", the documents count and the photo thumbnails.
class OrderMediaWidget extends StatelessWidget {
  final OrderStore store;

  const OrderMediaWidget({super.key, required this.store});

  static const double _thumbSize = 56;

  @override
  Widget build(BuildContext context) {
    final config = context.watch<SegmentConfigProvider>();
    return Observer(
      builder: (_) {
        if (store.isUploadingPhoto || store.isUploadingDocument) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Column(
              children: [
                const CupertinoActivityIndicator(),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  store.isUploadingDocument
                      ? context.l10n.uploadingDocument
                      : context.l10n.orderPhotoUploading,
                  textAlign: TextAlign.center,
                  style: AppTypography.label.copyWith(
                    color: AppColors.textSecondary.resolveFrom(context),
                  ),
                ),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.blockMargin,
          ),
          child: Column(
            children: [
              if (store.photos.isNotEmpty) ...[
                _buildCoverPhoto(context, config),
                const SizedBox(height: AppSpacing.md),
              ],
              _buildThumbnailRow(context, config),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThumbnailRow(
    BuildContext context,
    SegmentConfigProvider config,
  ) {
    const spacing = AppSpacing.sm;
    final photoCount = store.photos.length;
    final docCount = store.documents.length;
    final hasDocThumb = docCount > 0;
    final totalCount = 1 + (hasDocThumb ? 1 : 0) + photoCount;
    final accent = AppColors.accent.resolveFrom(context);

    return SizedBox(
      height: _thumbSize,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: totalCount,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(right: spacing),
              child: _Tile(
                key: const ValueKey('order_media_add'),
                label: context.l10n.orderAddMedia,
                onTap: () => showAddOrderMediaSheet(context, store),
                child: Icon(
                  CupertinoIcons.paperclip,
                  size: 22,
                  color: AppColors.accentText.resolveFrom(context),
                ),
              ),
            );
          }

          if (hasDocThumb && index == 1) {
            return Padding(
              padding: EdgeInsets.only(right: photoCount > 0 ? spacing : 0),
              child: _Tile(
                key: const ValueKey('order_media_documents'),
                label: '${context.l10n.documents}: $docCount',
                onTap: () => _showDocumentsSheet(context),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.doc_on_doc,
                      size: 20,
                      color: AppColors.textSecondary.resolveFrom(context),
                    ),
                    Text(
                      '$docCount',
                      style: AppTypography.label.copyWith(
                        fontWeight: FontWeight.w600,
                        fontFeatures: AppTypography.tabular,
                        color: AppColors.textSecondary.resolveFrom(context),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final photoIndex = index - 1 - (hasDocThumb ? 1 : 0);
          final photo = store.photos[photoIndex];
          final isCover = photoIndex == 0;
          final isLast = photoIndex == photoCount - 1;

          return Padding(
            padding: EdgeInsets.only(right: isLast ? 0 : spacing),
            child: Semantics(
              button: true,
              image: true,
              label: context.l10n.checklistPhotoPosition(
                photoIndex + 1,
                photoCount,
              ),
              child: GestureDetector(
                onTap: () => _showPhotoViewer(context, photoIndex, config),
                child: Container(
                  width: _thumbSize,
                  height: _thumbSize,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadii.field),
                    border: isCover ? Border.all(color: accent, width: 2) : null,
                  ),
                  child: CachedImage.cover(
                    imageUrl: photo.url!,
                    height: _thumbSize,
                    borderRadius: BorderRadius.circular(
                      isCover ? AppRadii.field - 2 : AppRadii.field,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // --- Documents sheet ---

  void _showDocumentsSheet(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetCtx) => Observer(
        builder: (_) {
          final docs = store.documents;
          if (docs.isEmpty) {
            Navigator.pop(sheetCtx);
            return const SizedBox.shrink();
          }
          return _DocumentsSheet(
            docs: docs,
            onOpen: (doc) {
              Navigator.pop(sheetCtx);
              openOrderDocument(context, doc);
            },
            onConfirmDelete: (index) async {
              final confirmed = await confirmDeleteOrderDocument(context);
              if (!confirmed) return false;
              final success = await store.deleteDocument(index);
              if (context.mounted) {
                showOrderMediaFeedback(
                  context,
                  success
                      ? context.l10n.documentDeleted
                      : context.l10n.errorUploadingDocument,
                  isError: !success,
                );
              }
              // Close sheet if no more docs
              if (success && docs.length <= 1 && sheetCtx.mounted) {
                Navigator.pop(sheetCtx);
              }
              return success;
            },
          );
        },
      ),
    );
  }

  Widget _buildCoverPhoto(BuildContext context, SegmentConfigProvider config) {
    final OrderPhoto coverPhoto = store.photos.first;
    final mediaCount = store.photos.length + store.documents.length;
    const height = 200.0;
    final radius = BorderRadius.circular(AppRadii.block);

    return Stack(
      children: [
        Semantics(
          button: true,
          image: true,
          label: context.l10n.checklistPhotoPosition(1, store.photos.length),
          child: GestureDetector(
            onTap: () => _showPhotoViewer(context, 0, config),
            child: CachedImage.cover(
              imageUrl: coverPhoto.url!,
              height: height,
              borderRadius: radius,
            ),
          ),
        ),
        Positioned(
          top: AppSpacing.sm,
          left: AppSpacing.sm,
          child: ExcludeSemantics(
            child: _OnPhotoChip(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    CupertinoIcons.photo_on_rectangle,
                    color: _OnPhotoChip.foreground,
                    size: 14,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    '$mediaCount',
                    style: AppTypography.label.copyWith(
                      color: _OnPhotoChip.foreground,
                      fontWeight: FontWeight.w600,
                      fontFeatures: AppTypography.tabular,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: Semantics(
            button: true,
            label: context.l10n.orderMoreActions,
            excludeSemantics: true,
            child: CupertinoButton(
              key: const ValueKey('order_media_cover_more'),
              padding: EdgeInsets.zero,
              minimumSize: const Size(
                AppSizes.minTouchTarget,
                AppSizes.minTouchTarget,
              ),
              onPressed: () => _showPhotoActions(context, 0),
              child: const _OnPhotoChip(
                round: true,
                child: Icon(
                  CupertinoIcons.ellipsis,
                  color: _OnPhotoChip.foreground,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- Photo actions ---

  Future<void> _showPhotoActions(BuildContext context, int index) async {
    final choice = await showPullDownMenu(
      context,
      groups: [
        PullDownGroup([
          if (index > 0)
            PullDownItem(
              value: 'cover',
              label: context.l10n.setAsCover,
              icon: CupertinoIcons.star,
            ),
          PullDownItem(
            value: 'delete',
            label: context.l10n.orderPhotoDelete,
            icon: CupertinoIcons.trash,
            destructive: true,
          ),
        ]),
      ],
    );
    if (!context.mounted) return;
    switch (choice) {
      case 'cover':
        store.setPhotoCover(index);
        showOrderMediaFeedback(context, context.l10n.orderPhotoCoverSet);
      case 'delete':
        if (!await confirmDeleteOrderPhoto(context)) return;
        final success = await store.deletePhoto(index);
        if (!context.mounted) return;
        showOrderMediaFeedback(
          context,
          success
              ? context.l10n.orderPhotoDeleted
              : context.l10n.orderPhotoDeleteError,
          isError: !success,
        );
    }
  }

  void _showPhotoViewer(
    BuildContext context,
    int initialIndex,
    SegmentConfigProvider config,
  ) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => PhotoViewerScreen(
          photos: store.photos.toList(),
          initialIndex: initialIndex,
          onDelete: (index) async {
            final success = await store.deletePhoto(index);
            return success;
          },
          onSetCover: (index) {
            store.setPhotoCover(index);
          },
          config: config,
        ),
      ),
    );
  }
}

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

/// Square tile (56) of the media row: "add" and the documents count. The
/// tap area is the tile itself, at least 44.
class _Tile extends StatelessWidget {
  const _Tile({
    super.key,
    required this.label,
    required this.onTap,
    required this.child,
  });

  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: OrderMediaWidget._thumbSize,
          height: OrderMediaWidget._thumbSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.secondaryFill.resolveFrom(context),
            borderRadius: BorderRadius.circular(AppRadii.field),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Dark chip drawn over a photo (count, "…"). Over a photo the colors do
/// not follow the theme: always white on translucent black, like the
/// iPhone's photo viewer.
class _OnPhotoChip extends StatelessWidget {
  const _OnPhotoChip({required this.child, this.round = false});

  final Widget child;
  final bool round;

  static const foreground = Color(0xFFFFFFFF);
  static const background = Color(0x99000000);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: round ? 6 : AppSpacing.sm,
        vertical: round ? 6 : AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.field),
      ),
      child: child,
    );
  }
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
        showOrderMediaFeedback(context, l10n.orderPhotoShareError, isError: true);
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
    if (!mounted || !success) return;
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

/// Sheet with the documents of the order: tap opens, swipe deletes.
class _DocumentsSheet extends StatelessWidget {
  final List<OrderDocument> docs;
  final void Function(OrderDocument doc) onOpen;
  final Future<bool> Function(int index) onConfirmDelete;

  const _DocumentsSheet({
    required this.docs,
    required this.onOpen,
    required this.onConfirmDelete,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      decoration: BoxDecoration(
        color: AppColors.groupedBackground.resolveFrom(context),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadii.block),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageMargin,
              AppSpacing.lg,
              AppSpacing.pageMargin,
              AppSpacing.md,
            ),
            child: Text(
              '${context.l10n.documents} (${docs.length})',
              style: AppTypography.bodyStrong.copyWith(
                color: AppColors.text.resolveFrom(context),
              ),
            ),
          ),
          Flexible(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.blockMargin,
                0,
                AppSpacing.blockMargin,
                bottomPadding + AppSpacing.lg,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.block),
                child: ColoredBox(
                  color: AppColors.surface.resolveFrom(context),
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: docs.length,
                    itemBuilder: (context, index) => _buildRow(
                      context,
                      docs[index],
                      index,
                      isLast: index == docs.length - 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(
    BuildContext context,
    OrderDocument doc,
    int index, {
    required bool isLast,
  }) {
    final secondary = AppColors.textSecondary.resolveFrom(context);
    final iconData = doc.isPdf
        ? CupertinoIcons.doc_text
        : doc.isImage
        ? CupertinoIcons.photo
        : CupertinoIcons.doc;

    final subtitleParts = <String>[doc.typeLabel(context.l10n)];
    if (doc.fileSizeFormatted.isNotEmpty) {
      subtitleParts.add(doc.fileSizeFormatted);
    }
    if (doc.createdAt != null) {
      subtitleParts.add(FormatService().formatDayMonth(doc.createdAt!));
    }

    final canDelete = AuthorizationService.instance.hasPermission(
      PermissionType.attachPhotos,
    );
    final isLinkedReceipt = doc.linkedTransactionId != null;

    return Dismissible(
      key: ValueKey(doc.id ?? index),
      direction: canDelete
          ? DismissDirection.endToStart
          : DismissDirection.none,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.xl),
        color: AppColors.danger.resolveFrom(context),
        child: Icon(
          CupertinoIcons.delete,
          color: AppColors.onAccent.resolveFrom(context),
        ),
      ),
      confirmDismiss: (_) => onConfirmDelete(index),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onOpen(doc),
        child: Column(
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: Row(
                  children: [
                    Icon(iconData, color: secondary, size: 24),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doc.fileName ?? context.l10n.document,
                            style: AppTypography.body.copyWith(
                              color: AppColors.text.resolveFrom(context),
                            ),
                          ),
                          Text.rich(
                            TextSpan(
                              children: [
                                if (isLinkedReceipt)
                                  WidgetSpan(
                                    alignment: PlaceholderAlignment.middle,
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        right: AppSpacing.xs,
                                      ),
                                      child: Icon(
                                        CupertinoIcons.link,
                                        size: 14,
                                        color: AppColors.success.resolveFrom(
                                          context,
                                        ),
                                      ),
                                    ),
                                  ),
                                TextSpan(text: subtitleParts.join(' · ')),
                              ],
                            ),
                            style: AppTypography.label.copyWith(
                              color: secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Icon(
                      CupertinoIcons.chevron_right,
                      size: 16,
                      color: AppColors.separator.resolveFrom(context),
                    ),
                  ],
                ),
              ),
            ),
            if (!isLast)
              Padding(
                padding: const EdgeInsets.only(left: 52),
                child: Container(
                  height: 0.5,
                  color: AppColors.separator.resolveFrom(context),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
