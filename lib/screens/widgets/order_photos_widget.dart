import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show ScaffoldMessenger, SnackBar; 
import 'package:provider/provider.dart';
// Keeping Material for ScaffoldMessenger/SnackBar reliance or specific Icons if needed, 
// but preferring Cupertino.

import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/order_photo.dart';
import 'package:praticos/widgets/cached_image.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/constants/label_keys.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:io';

class OrderPhotosWidget extends StatelessWidget {
  final OrderStore store;
  final VoidCallback? onAddPhoto;

  const OrderPhotosWidget({
    super.key,
    required this.store,
    this.onAddPhoto,
  });

  @override
  Widget build(BuildContext context) {
    final config = context.watch<SegmentConfigProvider>();
    return Observer(
      builder: (_) {
        // Show loading indicator while uploading
        if (store.isUploadingPhoto) {
          return Container(
            height: 120,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CupertinoActivityIndicator(),
                const SizedBox(height: 8),
                Text(
                  'Enviando foto...',
                  style: const TextStyle(
                    color: CupertinoColors.secondaryLabel,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          );
        }

        // Show photos grid (or just add button if no photos)
        return _buildPhotosGrid(context, config);
      },
    );
  }

  Widget _buildPhotosGrid(BuildContext context, SegmentConfigProvider config) {
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

    return SizedBox(
      height: thumbSize,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: store.photos.length + 1, // +1 for add button
        separatorBuilder: (_, __) => const SizedBox(width: spacing),
        itemBuilder: (context, index) {
          // First item is the add photo button
          if (index == 0) {
            return _buildAddPhotoButton(context, thumbSize);
          }

          // Photo thumbnails (index - 1 because first item is add button)
          final photoIndex = index - 1;
          final photo = store.photos[photoIndex];
          final isSelected = photoIndex == 0; // First photo is cover

          return GestureDetector(
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
          );
        },
      ),
    );
  }

  Widget _buildAddPhotoButton(BuildContext context, double size) {
    return GestureDetector(
      onTap: onAddPhoto,
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
          CupertinoIcons.camera_fill,
          color: CupertinoColors.systemGrey.resolveFrom(context),
          size: 24,
        ),
      ),
    );
  }

  Widget _buildCoverPhoto(BuildContext context, SegmentConfigProvider config) {
    final OrderPhoto coverPhoto = store.photos.first;
    
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
                    '${store.photos.length}',
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

  Widget _buildPhotoActionButton(BuildContext context, int index, SegmentConfigProvider config, {bool small = false}) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () => _showActionSheet(context, index, config), minimumSize: Size(0, 0),
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

  void _showActionSheet(BuildContext context, int index, SegmentConfigProvider config) {
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

  void _confirmDeletePhoto(BuildContext context, int index, SegmentConfigProvider config) {
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

  void _showPhotoViewer(BuildContext context, int initialIndex, SegmentConfigProvider config) {
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
          child: const Icon(CupertinoIcons.back, color: CupertinoColors.white),
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
                    child: CupertinoActivityIndicator(color: CupertinoColors.white)
                  )
                : const Icon(CupertinoIcons.share, color: CupertinoColors.white),
            ),
             CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Icon(CupertinoIcons.trash, color: CupertinoColors.white),
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
                      Navigator.pop(context); // Close viewer if no photos left
                    } else {
                      setState(() {
                        if (_currentIndex >= widget.photos.length - 1) {
                          _currentIndex = widget.photos.length - 2;
                          _pageController.jumpToPage(_currentIndex);
                        }
                      });
                    }
                    // Optional: Provide feedback?
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