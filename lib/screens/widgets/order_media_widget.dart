import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Divider, ScaffoldMessenger, SnackBar, showModalBottomSheet;
import 'package:provider/provider.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/order_document.dart';
import 'package:praticos/models/order_photo.dart';
import 'package:praticos/services/photo_service.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/widgets/cached_image.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/constants/label_keys.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class OrderMediaWidget extends StatelessWidget {
  final OrderStore store;

  const OrderMediaWidget({
    super.key,
    required this.store,
  });

  @override
  Widget build(BuildContext context) {
    final config = context.watch<SegmentConfigProvider>();
    return Observer(
      builder: (_) {
        // Show loading indicator while uploading
        if (store.isUploadingPhoto || store.isUploadingDocument) {
          return Container(
            height: 120,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CupertinoActivityIndicator(),
                const SizedBox(height: 8),
                Text(
                  store.isUploadingDocument
                      ? context.l10n.uploadingDocument
                      : context.l10n.uploadingDocument,
                  style: TextStyle(
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          );
        }

        // Show media grid
        return _buildMediaGrid(context, config);
      },
    );
  }

  Widget _buildMediaGrid(BuildContext context, SegmentConfigProvider config) {
    final hasPhotos = store.photos.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          if (hasPhotos) ...[
            _buildCoverPhoto(context, config),
            const SizedBox(height: 12),
          ],
          _buildThumbnailRow(context, config),
        ],
      ),
    );
  }

  Widget _buildThumbnailRow(BuildContext context, SegmentConfigProvider config) {
    const double thumbSize = 56;
    const double spacing = 8;
    final photoCount = store.photos.length;
    final docCount = store.documents.length;
    final hasDocThumb = docCount > 0;
    final totalCount = 1 + (hasDocThumb ? 1 : 0) + photoCount;

    return SizedBox(
      height: thumbSize,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: totalCount,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(right: spacing),
              child: _buildAddButton(context, thumbSize),
            );
          }

          if (hasDocThumb && index == 1) {
            return Padding(
              padding: EdgeInsets.only(right: photoCount > 0 ? spacing : 0),
              child: _buildDocumentCountThumb(context, thumbSize, docCount),
            );
          }

          final photoIndex = index - 1 - (hasDocThumb ? 1 : 0);
          final photo = store.photos[photoIndex];
          final isSelected = photoIndex == 0; // First photo is cover
          final isLast = photoIndex == photoCount - 1;

          return Padding(
            padding: EdgeInsets.only(right: isLast ? 0 : spacing),
            child: GestureDetector(
              onTap: () => _showPhotoViewer(context, photoIndex, config),
              child: Container(
                width: thumbSize,
                height: thumbSize,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: isSelected
                      ? Border.all(
                          color: CupertinoColors.activeBlue,
                          width: 2,
                        )
                      : null,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(isSelected ? 6 : 8),
                  child: CachedImage.cover(
                    imageUrl: photo.url!,
                    height: thumbSize,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDocumentCountThumb(BuildContext context, double size, int count) {
    return GestureDetector(
      onTap: () => _showDocumentsSheet(context),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey6.resolveFrom(context),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: CupertinoColors.systemGrey4.resolveFrom(context),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.doc_on_doc_fill,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
              size: 20,
            ),
            const SizedBox(height: 2),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton(BuildContext context, double size) {
    return GestureDetector(
      onTap: () => _showAddMediaOptions(context),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey6.resolveFrom(context),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: CupertinoColors.systemGrey4.resolveFrom(context),
            width: 1,
          ),
        ),
        child: Icon(
          CupertinoIcons.paperclip,
          color: CupertinoColors.systemGrey.resolveFrom(context),
          size: 22,
        ),
      ),
    );
  }

  // --- Documents bottom sheet ---

  void _showDocumentsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
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
              _openDocument(context, doc);
            },
            onConfirmDelete: (index) async {
              final confirmed = await _showDeleteConfirmation(context);
              if (!confirmed) return false;
              final success = await store.deleteDocument(index);
              if (context.mounted) {
                _showFeedback(
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
            store: store,
          );
        },
      ),
    );
  }

  Future<bool> _showDeleteConfirmation(BuildContext context) async {
    bool confirmed = false;
    await showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(context.l10n.deleteDocument),
        content: Text(context.l10n.confirmDeleteDocument),
        actions: [
          CupertinoDialogAction(
            child: Text(context.l10n.cancel),
            onPressed: () {
              confirmed = false;
              Navigator.pop(ctx);
            },
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: Text(context.l10n.delete),
            onPressed: () {
              confirmed = true;
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
    return confirmed;
  }

  Widget _buildCoverPhoto(BuildContext context, SegmentConfigProvider config) {
    final OrderPhoto coverPhoto = store.photos.first;
    final mediaCount = store.photos.length + store.documents.length;

    return GestureDetector(
      onTap: () => _showPhotoViewer(context, 0, config),
      child: Stack(
        children: [
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: CupertinoColors.systemGrey.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedImage.cover(
                imageUrl: coverPhoto.url!,
                height: 200,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: CupertinoColors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    CupertinoIcons.photo_on_rectangle,
                    color: CupertinoColors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$mediaCount',
                    style: const TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: _buildPhotoActionButton(context, 0, config),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoActionButton(
      BuildContext context, int index, SegmentConfigProvider config,
      {bool small = false}) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () => _showPhotoActionSheet(context, index, config),
      minimumSize: Size.zero,
      child: Container(
        padding: EdgeInsets.all(small ? 4 : 6),
        decoration: BoxDecoration(
          color: CupertinoColors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
        child: Icon(
          CupertinoIcons.ellipsis,
          color: CupertinoColors.white,
          size: small ? 16 : 20,
        ),
      ),
    );
  }

  // --- Photo actions ---

  void _showPhotoActionSheet(
      BuildContext context, int index, SegmentConfigProvider config) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          if (index > 0)
            CupertinoActionSheetAction(
              child: Text(config.label(LabelKeys.setAsCover)),
              onPressed: () {
                Navigator.pop(context);
                store.setPhotoCover(index);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Foto definida como capa')),
                );
              },
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          child: Text(config.label(LabelKeys.deletePhoto)),
          onPressed: () {
            Navigator.pop(context);
            _confirmDeletePhoto(context, index, config);
          },
        ),
      ),
    );
  }

  void _confirmDeletePhoto(
      BuildContext context, int index, SegmentConfigProvider config) {
    showCupertinoDialog(
      context: context,
      builder: (dialogContext) {
        return CupertinoAlertDialog(
          title: Text('${config.label(LabelKeys.delete)}?'),
          content: const Text('Esta ação não pode ser desfeita.'),
          actions: [
            CupertinoDialogAction(
              child: Text(config.label(LabelKeys.cancel)),
              onPressed: () => Navigator.pop(dialogContext),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () async {
                Navigator.pop(dialogContext);
                final success = await store.deletePhoto(index);
                if (context.mounted) {
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  if (success) {
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(content: Text('Foto excluída')),
                    );
                  } else {
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(content: Text('Erro ao excluir foto')),
                    );
                  }
                }
              },
              child: Text(config.label(LabelKeys.delete)),
            ),
          ],
        );
      },
    );
  }

  void _showPhotoViewer(
      BuildContext context, int initialIndex, SegmentConfigProvider config) {
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

  // --- Add media (unified action sheet) ---

  void _showAddMediaOptions(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          // Add photo (camera)
          CupertinoActionSheetAction(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.camera, size: 20),
                const SizedBox(width: 8),
                Text(context.l10n.takePhoto),
              ],
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await store.addPhotoFromCamera();
            },
          ),
          // Add photo (gallery)
          CupertinoActionSheetAction(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.photo, size: 20),
                const SizedBox(width: 8),
                Text(context.l10n.gallery),
              ],
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await store.addPhotoFromGallery();
            },
          ),
          // Add as document (file picker)
          CupertinoActionSheetAction(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.doc, size: 20),
                const SizedBox(width: 8),
                Text(context.l10n.fromFiles),
              ],
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final photoService = PhotoService();
              final platformFile = await photoService.pickDocument();
              if (platformFile != null &&
                  platformFile.path != null &&
                  context.mounted) {
                final file = File(platformFile.path!);
                final contentType =
                    _getContentType(platformFile.extension ?? '');
                _selectDocumentType(
                  context,
                  file,
                  contentType,
                  platformFile.name,
                  fileSize: platformFile.size,
                );
              }
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: Text(context.l10n.cancel),
          onPressed: () => Navigator.pop(ctx),
        ),
      ),
    );
  }

  void _selectDocumentType(
    BuildContext context,
    File file,
    String contentType,
    String fileName, {
    int? fileSize,
  }) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(context.l10n.selectDocumentType),
        actions: [
          _buildDocTypeAction(ctx, context, file, contentType, fileName,
              OrderDocumentType.receipt, context.l10n.receipt,
              fileSize: fileSize),
          _buildDocTypeAction(ctx, context, file, contentType, fileName,
              OrderDocumentType.invoice, context.l10n.invoice,
              fileSize: fileSize),
          _buildDocTypeAction(ctx, context, file, contentType, fileName,
              OrderDocumentType.contract, context.l10n.contract,
              fileSize: fileSize),
          _buildDocTypeAction(ctx, context, file, contentType, fileName,
              OrderDocumentType.warranty, context.l10n.warranty,
              fileSize: fileSize),
          _buildDocTypeAction(ctx, context, file, contentType, fileName,
              OrderDocumentType.other, context.l10n.other,
              fileSize: fileSize),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: Text(context.l10n.cancel),
          onPressed: () => Navigator.pop(ctx),
        ),
      ),
    );
  }

  CupertinoActionSheetAction _buildDocTypeAction(
    BuildContext sheetCtx,
    BuildContext parentCtx,
    File file,
    String contentType,
    String fileName,
    OrderDocumentType type,
    String label, {
    int? fileSize,
  }) {
    return CupertinoActionSheetAction(
      child: Text(label),
      onPressed: () async {
        Navigator.pop(sheetCtx);
        final success = await store.addDocument(
          file, type, contentType, fileName,
          fileSize: fileSize,
        );
        if (parentCtx.mounted) {
          if (success) {
            _showFeedback(parentCtx, parentCtx.l10n.documentAdded);
          } else {
            _showFeedback(parentCtx, parentCtx.l10n.errorUploadingDocument,
                isError: true);
          }
        }
      },
    );
  }

  void _openDocument(BuildContext context, OrderDocument doc) {
    if (doc.url == null) return;

    if (doc.isImage) {
      Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (context) => _DocumentImageViewer(
            url: doc.url!,
            title: doc.fileName ?? context.l10n.documents,
          ),
        ),
      );
    } else {
      launchUrl(Uri.parse(doc.url!), mode: LaunchMode.externalApplication);
    }
  }

  void _showFeedback(BuildContext context, String message,
      {bool isError = false}) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        content: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isError
                  ? CupertinoIcons.xmark_circle_fill
                  : CupertinoIcons.checkmark_circle_fill,
              color: isError
                  ? CupertinoColors.systemRed
                  : CupertinoColors.systemGreen,
              size: 24,
            ),
            const SizedBox(width: 8),
            Flexible(child: Text(message)),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: Text(context.l10n.ok),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  String _getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }
}

/// Tela de visualização de fotos em tela cheia (Cupertino style)
class PhotoViewerScreen extends StatefulWidget {
  final List<OrderPhoto> photos;
  final int initialIndex;
  final Future<bool> Function(int index) onDelete;
  final void Function(int index) onSetCover;
  final SegmentConfigProvider config;

  const PhotoViewerScreen({
    super.key,
    required this.photos,
    required this.initialIndex,
    required this.onDelete,
    required this.onSetCover,
    required this.config,
  });

  @override
  _PhotoViewerScreenState createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;
  bool _isSharing = false;

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

    setState(() {
      _isSharing = true;
    });

    try {
      final photo = widget.photos[_currentIndex];
      final url = photo.url;

      if (url == null || url.isEmpty) {
        throw Exception('URL da imagem inválida');
      }

      // Baixa a imagem
      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        throw Exception('Falha ao baixar imagem');
      }

      // Prepara o arquivo temporário
      final tempDir = await getTemporaryDirectory();
      final fileName = 'foto_os_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = await File('${tempDir.path}/$fileName').create();
      await file.writeAsBytes(response.bodyBytes);

      // Compartilha
      final box = context.findRenderObject() as RenderBox?;
      final size = MediaQuery.of(context).size;

      // ignore: deprecated_member_use
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Foto da ${widget.config.serviceOrder}',
        sharePositionOrigin: box != null
            ? box.localToGlobal(Offset.zero) & box.size
            : Rect.fromLTWH(0, 0, size.width, size.height / 2),
      );
    } catch (e) {
      print('Erro no compartilhamento: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao compartilhar: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSharing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.black.withValues(alpha: 0.8),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child:
              const Icon(CupertinoIcons.back, color: CupertinoColors.white),
          onPressed: () => Navigator.pop(context),
        ),
        middle: Text(
          '${_currentIndex + 1} de ${widget.photos.length}',
          style: const TextStyle(color: CupertinoColors.white),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _sharePhoto,
              child: _isSharing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CupertinoActivityIndicator(
                          color: CupertinoColors.white))
                  : const Icon(CupertinoIcons.share,
                      color: CupertinoColors.white),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Icon(CupertinoIcons.trash,
                  color: CupertinoColors.white),
              onPressed: () => _confirmDelete(),
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: PageView.builder(
          controller: _pageController,
          itemCount: widget.photos.length,
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          itemBuilder: (context, index) {
            final photo = widget.photos[index];
            return InteractiveViewer(
              minScale: 0.5,
              maxScale: 3.0,
              child: Center(
                child: CachedImage.fullScreen(
                  imageUrl: photo.url!,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _confirmDelete() {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: Text('${widget.config.label(LabelKeys.delete)}?'),
          content: const Text('Esta ação não pode ser desfeita.'),
          actions: [
            CupertinoDialogAction(
              child: Text(widget.config.label(LabelKeys.cancel)),
              onPressed: () => Navigator.pop(context),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () async {
                Navigator.pop(context); // Close dialog
                final success = await widget.onDelete(_currentIndex);
                if (mounted) {
                  if (success) {
                    if (widget.photos.length <= 1) {
                      Navigator.pop(
                          context); // Close viewer if no photos left
                    } else {
                      setState(() {
                        if (_currentIndex >= widget.photos.length - 1) {
                          _currentIndex = widget.photos.length - 2;
                          _pageController.jumpToPage(_currentIndex);
                        }
                      });
                    }
                  }
                }
              },
              child: Text(widget.config.label(LabelKeys.delete)),
            ),
          ],
        );
      },
    );
  }
}

/// Full-screen image viewer for document images
class _DocumentImageViewer extends StatelessWidget {
  final String url;
  final String title;

  const _DocumentImageViewer({
    required this.url,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.black.withValues(alpha: 0.8),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child:
              const Icon(CupertinoIcons.back, color: CupertinoColors.white),
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
                return const Icon(
                  CupertinoIcons.exclamationmark_triangle,
                  color: CupertinoColors.systemGrey,
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

/// Bottom sheet that lists attached documents with swipe-to-delete
class _DocumentsSheet extends StatelessWidget {
  final List<OrderDocument> docs;
  final void Function(OrderDocument doc) onOpen;
  final Future<bool> Function(int index) onConfirmDelete;
  final OrderStore store;

  const _DocumentsSheet({
    required this.docs,
    required this.onOpen,
    required this.onConfirmDelete,
    required this.store,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey3.resolveFrom(context),
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              children: [
                Text(
                  context.l10n.documents,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey5.resolveFrom(context),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${docs.length}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.secondaryLabel.resolveFrom(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Document list
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: bottomPadding + 16,
              ),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                return _buildRow(context, docs[index], index, isLast: index == docs.length - 1);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, OrderDocument doc, int index, {required bool isLast}) {
    final iconData = doc.isPdf
        ? CupertinoIcons.doc_text_fill
        : doc.isImage
            ? CupertinoIcons.photo_fill
            : CupertinoIcons.doc_fill;
    final iconColor = doc.isPdf
        ? CupertinoColors.systemRed
        : doc.isImage
            ? CupertinoColors.activeBlue
            : CupertinoColors.systemGrey;
    final bgColor = iconColor.withValues(alpha: 0.15);

    final subtitleParts = <String>[];
    if (doc.fileSizeFormatted.isNotEmpty) subtitleParts.add(doc.fileSizeFormatted);
    if (doc.createdAt != null) {
      subtitleParts.add(FormatService().formatDayMonth(doc.createdAt!));
    }

    // Wrap in ClipRRect for first/last items rounded corners
    final isFirst = index == 0;
    final borderRadius = BorderRadius.only(
      topLeft: isFirst ? const Radius.circular(10) : Radius.zero,
      topRight: isFirst ? const Radius.circular(10) : Radius.zero,
      bottomLeft: isLast ? const Radius.circular(10) : Radius.zero,
      bottomRight: isLast ? const Radius.circular(10) : Radius.zero,
    );

    return ClipRRect(
      borderRadius: borderRadius,
      child: Dismissible(
        key: ValueKey(doc.id ?? index),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          color: CupertinoColors.systemRed,
          child: const Icon(
            CupertinoIcons.delete,
            color: CupertinoColors.white,
          ),
        ),
        confirmDismiss: (_) => onConfirmDelete(index),
        child: GestureDetector(
          onTap: () => onOpen(doc),
          child: Container(
            color: CupertinoColors.systemBackground.resolveFrom(context),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      // Leading icon
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(iconData, color: iconColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      // Title + subtitle
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              doc.fileName ?? context.l10n.document,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w500,
                                color: CupertinoColors.label.resolveFrom(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: CupertinoColors.systemGrey5.resolveFrom(context),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    doc.typeLabel(context.l10n),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: CupertinoColors.secondaryLabel.resolveFrom(context),
                                    ),
                                  ),
                                ),
                                if (subtitleParts.isNotEmpty)
                                  Text(
                                    '  ·  ${subtitleParts.join('  ·  ')}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: CupertinoColors.secondaryLabel.resolveFrom(context),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        CupertinoIcons.chevron_right,
                        size: 16,
                        color: CupertinoColors.systemGrey3.resolveFrom(context),
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Padding(
                    padding: const EdgeInsets.only(left: 68),
                    child: Divider(
                      height: 1,
                      thickness: 0.5,
                      color: CupertinoColors.systemGrey5.resolveFrom(context),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
