import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;

/// Utilitario para download e cache de imagens para PDF
class PdfImageLoader {
  /// Cache de imagens em memoria
  final Map<String, pw.MemoryImage> _cache = {};

  /// Download do logo da empresa
  ///
  /// Retorna null se a URL for invalida ou o download falhar
  Future<pw.MemoryImage?> loadLogo(String? url) async {
    if (url == null || url.isEmpty) return null;
    return _loadImage(url, 'logo');
  }

  /// Download de uma foto unica
  ///
  /// Retorna null se o download falhar
  Future<pw.MemoryImage?> loadPhoto(String url) async {
    if (url.isEmpty) return null;
    return _loadImage(url, url);
  }

  /// Download de multiplas fotos com limite
  ///
  /// [urls] Lista de URLs das fotos
  /// [limit] Numero maximo de fotos a baixar (default: 10)
  ///
  /// Retorna lista de imagens baixadas com sucesso
  Future<List<pw.MemoryImage>> loadPhotos(List<String> urls, {int limit = 10}) async {
    final List<pw.MemoryImage> images = [];
    final urlsToLoad = urls.take(limit).toList();

    for (final url in urlsToLoad) {
      if (url.isEmpty) continue;
      final image = await _loadImage(url, url);
      if (image != null) {
        images.add(image);
      }
    }
    return images;
  }

  /// Download de fotos agrupadas por item de formulario
  ///
  /// [formPhotos] Map com itemId -> lista de URLs
  /// [maxPerItem] Numero maximo de fotos por item
  ///
  /// Retorna Map com itemId -> lista de imagens
  Future<Map<String, List<pw.MemoryImage>>> loadFormItemPhotos(
    Map<String, List<String>> formPhotos, {
    int maxPerItem = 6,
  }) async {
    final Map<String, List<pw.MemoryImage>> result = {};

    for (final entry in formPhotos.entries) {
      final itemId = entry.key;
      final urls = entry.value;
      final images = await loadPhotos(urls, limit: maxPerItem);
      if (images.isNotEmpty) {
        result[itemId] = images;
      }
    }

    return result;
  }

  /// Metodo interno para download de imagem com cache
  Future<pw.MemoryImage?> _loadImage(String url, String cacheKey) async {
    // Verifica cache primeiro
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final image = pw.MemoryImage(response.bodyBytes);
        _cache[cacheKey] = image;
        return image;
      }
    } catch (e) {
      // Falha silenciosa - imagem e opcional
    }
    return null;
  }

  /// Limpa o cache de imagens
  void clearCache() => _cache.clear();

  /// Retorna o numero de imagens em cache
  int get cacheSize => _cache.length;
}
