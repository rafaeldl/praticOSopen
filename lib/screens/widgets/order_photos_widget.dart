import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/order_photo.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:io';

class OrderPhotosWidget extends StatelessWidget {
  final OrderStore store;

  const OrderPhotosWidget({Key? key, required this.store}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Fotos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              icon: Icon(Icons.add_a_photo),
              onPressed: () => _showAddPhotoOptions(context),
            ),
          ],
        ),
        SizedBox(height: 8),
        Observer(
          builder: (_) {
            if (store.isUploadingPhoto) {
              return Container(
                height: 120,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 8),
                      Text('Enviando foto...'),
                    ],
                  ),
                ),
              );
            }

            if (store.photos.isEmpty) {
              return GestureDetector(
                onTap: () => _showAddPhotoOptions(context),
                child: Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Adicionar fotos',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return _buildPhotosGrid(context);
          },
        ),
      ],
    );
  }

  Widget _buildPhotosGrid(BuildContext context) {
    return Column(
      children: [
        // Foto de capa (primeira foto)
        if (store.photos.isNotEmpty) _buildCoverPhoto(context),
        SizedBox(height: 8),
        // Grid das outras fotos
        if (store.photos.length > 1) _buildThumbnailGrid(context),
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
                  color: Colors.grey[300]!,
                  blurRadius: 6.0,
                  spreadRadius: 2.0,
                  offset: Offset(3.0, 3.0),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                coverPhoto.url!,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[200],
                    child: Center(
                      child: Icon(Icons.broken_image, size: 48),
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Capa',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
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
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
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
                child: Image.network(
                  photo.url!,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: Colors.grey[200],
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[200],
                      child: Icon(Icons.broken_image),
                    );
                  },
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
    return PopupMenuButton<String>(
      icon: Container(
        padding: EdgeInsets.all(small ? 2 : 4),
        decoration: BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.more_vert,
          color: Colors.white,
          size: small ? 16 : 20,
        ),
      ),
      onSelected: (value) async {
        if (value == 'delete') {
          _confirmDeletePhoto(context, index);
        } else if (value == 'cover') {
          store.setPhotoCover(index);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Foto definida como capa')),
            );
          }
        }
      },
      itemBuilder: (context) => [
        if (index > 0)
          PopupMenuItem(
            value: 'cover',
            child: Row(
              children: [
                Icon(Icons.star, size: 20),
                SizedBox(width: 8),
                Text('Definir como capa'),
              ],
            ),
          ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, size: 20, color: Colors.red),
              SizedBox(width: 8),
              Text('Excluir', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    );
  }

  void _showAddPhotoOptions(BuildContext context) {
    // Salva o contexto do Scaffold pai antes de abrir o modal
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (modalContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.camera_alt, color: Theme.of(context).primaryColor),
                  title: Text('Tirar foto'),
                  onTap: () async {
                    Navigator.pop(modalContext);
                    final success = await store.addPhotoFromCamera();
                    if (!success && context.mounted) {
                      scaffoldMessenger.showSnackBar(
                        SnackBar(content: Text('Erro ao adicionar foto')),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: Icon(Icons.photo_library, color: Theme.of(context).primaryColor),
                  title: Text('Escolher da galeria'),
                  onTap: () async {
                    Navigator.pop(modalContext);
                    final success = await store.addPhotoFromGallery();
                    if (!success && context.mounted) {
                      scaffoldMessenger.showSnackBar(
                        SnackBar(content: Text('Erro ao adicionar foto')),
                      );
                    }
                  },
                ),
                SizedBox(height: 8),
                ListTile(
                  leading: Icon(Icons.close, color: Colors.grey),
                  title: Text('Cancelar'),
                  onTap: () => Navigator.pop(modalContext),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmDeletePhoto(BuildContext context, int index) {
    // Salva o contexto do Scaffold antes de abrir o dialog
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Excluir foto?'),
          content: Text('Esta ação não pode ser desfeita.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                final success = await store.deletePhoto(index);
                if (context.mounted) {
                  if (success) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(content: Text('Foto excluída')),
                    );
                  } else {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(content: Text('Erro ao excluir foto')),
                    );
                  }
                }
              },
              child: Text('Excluir', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _showPhotoViewer(BuildContext context, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
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

/// Tela de visualização de fotos em tela cheia
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
      // Define uma origem para o popover no iPad/iOS
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.white),
        title: Text(
          'Foto ${_currentIndex + 1} de ${widget.photos.length}',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: _isSharing 
                ? SizedBox(
                    width: 20, 
                    height: 20, 
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                  )
                : Icon(Icons.share),
            tooltip: 'Compartilhar',
            onPressed: _sharePhoto,
          ),
          if (_currentIndex > 0)
            IconButton(
              icon: Icon(Icons.star_border),
              tooltip: 'Definir como capa',
              onPressed: () {
                widget.onSetCover(_currentIndex);
                Navigator.pop(context);
                // Usa o contexto do Scaffold pai se disponível
                if (mounted) {
                  final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
                  scaffoldMessenger?.showSnackBar(
                    SnackBar(content: Text('Foto definida como capa')),
                  );
                }
              },
            ),
          IconButton(
            icon: Icon(Icons.delete),
            tooltip: 'Excluir',
            onPressed: () => _confirmDelete(),
          ),
        ],
      ),
      body: PageView.builder(
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
              child: Image.network(
                photo.url!,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image, size: 64, color: Colors.white54),
                        SizedBox(height: 16),
                        Text(
                          'Erro ao carregar imagem',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Excluir foto?'),
          content: Text('Esta ação não pode ser desfeita.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                final success = await widget.onDelete(_currentIndex);
                if (mounted) {
                  if (success) {
                    if (widget.photos.length <= 1) {
                      Navigator.pop(context);
                    } else {
                      setState(() {
                        if (_currentIndex >= widget.photos.length - 1) {
                          _currentIndex = widget.photos.length - 2;
                          _pageController.jumpToPage(_currentIndex);
                        }
                      });
                    }
                    final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
                    scaffoldMessenger?.showSnackBar(
                      SnackBar(content: Text('Foto excluída')),
                    );
                  } else {
                    final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
                    scaffoldMessenger?.showSnackBar(
                      SnackBar(content: Text('Erro ao excluir foto')),
                    );
                  }
                }
              },
              child: Text('Excluir', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}
