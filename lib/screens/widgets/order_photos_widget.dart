import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show ScaffoldMessenger, SnackBar; 
// Keeping Material for ScaffoldMessenger/SnackBar reliance or specific Icons if needed, 
// but preferring Cupertino.

import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/order_photo.dart';
import 'package:praticos/widgets/cached_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:io';

class OrderPhotosWidget extends StatelessWidget {
  final OrderStore store;

  const OrderPhotosWidget({Key? key, required this.store}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (_) {
        // Show loading indicator while uploading
        if (store.isUploadingPhoto) {
          return Container(
            height: 120,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                CupertinoActivityIndicator(),
                SizedBox(height: 8),
                Text(
                  'Enviando foto...',
                  style: TextStyle(
                    color: CupertinoColors.secondaryLabel,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          );
        }

        // Don't show anything if no photos
        if (store.photos.isEmpty) {
          return const SizedBox.shrink();
        }

        // Show photos grid
        return _buildPhotosGrid(context);
      },
    );
  }

  Widget _buildPhotosGrid(BuildContext context) {
    return Column(
      children: [
        // Foto de capa (primeira foto)
        if (store.photos.isNotEmpty) 
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _buildCoverPhoto(context),
          ),
        const SizedBox(height: 8),
        // Grid das outras fotos
        if (store.photos.length > 1) 
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _buildThumbnailGrid(context),
          ),
      ],
    );
  }

  Widget _buildCoverPhoto(BuildContext context) {
    final OrderPhoto coverPhoto = store.photos.first;
    
    return GestureDetector(
      onTap: () => _showPhotoViewer(context, 0),
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
            child: _buildPhotoActionButton(context, 0),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnailGrid(BuildContext context) {
    final thumbnailPhotos = store.photos.skip(1).toList();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: thumbnailPhotos.length,
      itemBuilder: (context, index) {
        final photo = thumbnailPhotos[index];
        final actualIndex = index + 1; // +1 porque pulamos a primeira foto

        return GestureDetector(
          onTap: () => _showPhotoViewer(context, actualIndex),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedImage(
                  imageUrl: photo.url!,
                  fit: BoxFit.cover,
                  borderRadius: BorderRadius.circular(8),
                  memCacheWidth: 200, // Otimiza para thumbnails
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: _buildPhotoActionButton(context, actualIndex, small: true),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPhotoActionButton(BuildContext context, int index, {bool small = false}) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () => _showActionSheet(context, index),
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
      ), minimumSize: Size(0, 0),
    );
  }

  void _showActionSheet(BuildContext context, int index) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          if (index > 0)
            CupertinoActionSheetAction(
              child: const Text('Definir como Capa'),
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
          child: const Text('Excluir Foto'),
          onPressed: () {
            Navigator.pop(context);
            _confirmDeletePhoto(context, index);
          },
        ),
      ),
    );
  }

  void _confirmDeletePhoto(BuildContext context, int index) {
    showCupertinoDialog(
      context: context,
      builder: (dialogContext) {
        return CupertinoAlertDialog(
          title: const Text('Excluir foto?'),
          content: const Text('Esta ação não pode ser desfeita.'),
          actions: [
            CupertinoDialogAction(
              child: const Text('Cancelar'),
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
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );
  }

  void _showPhotoViewer(BuildContext context, int initialIndex) {
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

  const PhotoViewerScreen({
    Key? key,
    required this.photos,
    required this.initialIndex,
    required this.onDelete,
    required this.onSetCover,
  }) : super(key: key);

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

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Foto da Ordem de Serviço',
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
               child: _isSharing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CupertinoActivityIndicator(color: CupertinoColors.white)
                  )
                : const Icon(CupertinoIcons.share, color: CupertinoColors.white),
              onPressed: _sharePhoto,
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
          title: const Text('Excluir foto?'),
          content: const Text('Esta ação não pode ser desfeita.'),
          actions: [
            CupertinoDialogAction(
              child: const Text('Cancelar'),
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
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );
  }
}