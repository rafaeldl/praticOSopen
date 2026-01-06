import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Cache manager customizado para imagens do PraticOS
/// Configura limites de cache para melhor performance
class PraticOSCacheManager {
  static const key = 'praticos_image_cache';

  static CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 7), // Cache válido por 7 dias
      maxNrOfCacheObjects: 200, // Máximo de 200 imagens em cache
      repo: JsonCacheInfoRepository(databaseName: key),
      fileService: HttpFileService(),
    ),
  );
}

/// Widget de imagem com cache para exibir fotos do Firebase Storage
/// Otimizado para diferentes contextos: thumbnails, covers e tela cheia
class CachedImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Color? placeholderColor;

  /// Tamanho sugerido para cache (reduz uso de memória)
  /// Se null, usa o tamanho original da imagem
  final int? memCacheWidth;
  final int? memCacheHeight;

  const CachedImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.placeholderColor,
    this.memCacheWidth,
    this.memCacheHeight,
  });

  /// Factory para thumbnails pequenos (lista de OSs)
  factory CachedImage.thumbnail({
    Key? key,
    required String imageUrl,
    double size = 76,
    BorderRadius? borderRadius,
  }) {
    return CachedImage(
      key: key,
      imageUrl: imageUrl,
      width: size,
      height: size,
      borderRadius: borderRadius,
      memCacheWidth: (size * 2).toInt(), // 2x para telas retina
      // Removido memCacheHeight para manter o aspect ratio e evitar distorção
      // O BoxFit.cover cuidará do preenchimento visual
    );
  }

  /// Factory para imagens de capa (tamanho médio)
  factory CachedImage.cover({
    Key? key,
    required String imageUrl,
    double? height = 200,
    BorderRadius? borderRadius,
  }) {
    return CachedImage(
      key: key,
      imageUrl: imageUrl,
      height: height,
      borderRadius: borderRadius,
      memCacheWidth: 800, // Limita para economizar memória
      // Removido memCacheHeight para manter o aspect ratio
    );
  }

  /// Factory para visualização em tela cheia
  factory CachedImage.fullScreen({
    Key? key,
    required String imageUrl,
  }) {
    return CachedImage(
      key: key,
      imageUrl: imageUrl,
      fit: BoxFit.contain,
      // Sem limite de cache para tela cheia - melhor qualidade
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget image = CachedNetworkImage(
      imageUrl: imageUrl,
      cacheManager: PraticOSCacheManager.instance,
      fit: fit,
      width: width,
      height: height,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      placeholder: (context, url) => placeholder ?? _buildPlaceholder(),
      errorWidget: (context, url, error) => errorWidget ?? _buildErrorWidget(),
      fadeInDuration: const Duration(milliseconds: 200),
      fadeOutDuration: const Duration(milliseconds: 200),
    );

    if (borderRadius != null) {
      image = ClipRRect(
        borderRadius: borderRadius!,
        child: image,
      );
    }

    return image;
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: placeholderColor ?? Colors.grey[200],
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.grey[400],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.broken_image,
              size: (height != null && height! < 100) ? 24 : 48,
              color: Colors.grey[400],
            ),
            if (height == null || height! >= 100) ...[
              SizedBox(height: 8),
              Text(
                'Falha ao carregar',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Utilitários para pré-cache de imagens
class ImageCacheUtils {
  /// Pré-carrega uma lista de URLs para o cache
  /// Útil para fazer prefetch ao abrir tela de detalhes
  static Future<void> precacheImages(List<String> urls) async {
    for (final url in urls) {
      try {
        await PraticOSCacheManager.instance.downloadFile(url);
      } catch (e) {
        // Ignora erros silenciosamente - é apenas prefetch
        print('Prefetch falhou para: $url');
      }
    }
  }

  /// Limpa todo o cache de imagens
  static Future<void> clearCache() async {
    await PraticOSCacheManager.instance.emptyCache();
  }

  /// Remove uma imagem específica do cache
  static Future<void> removeFromCache(String url) async {
    await PraticOSCacheManager.instance.removeFile(url);
  }
}
