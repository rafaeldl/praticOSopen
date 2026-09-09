import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;

/// Assinatura da funcao usada para buscar uma imagem por HTTP
typedef PdfHttpGet = Future<http.Response> Function(Uri url);

/// Utilitario para download e cache de imagens para PDF
class PdfImageLoader {
  /// Numero maximo de downloads simultaneos
  static const int maxConcurrentDownloads = 5;

  /// Funcao de download (injetavel em testes)
  final PdfHttpGet _httpGet;

  PdfImageLoader({PdfHttpGet? httpGet}) : _httpGet = httpGet ?? http.get;

  /// Cache de imagens em memoria
  final Map<String, pw.MemoryImage> _cache = {};

  /// Downloads em andamento, para nao baixar a mesma URL duas vezes
  final Map<String, Future<pw.MemoryImage?>> _inFlight = {};

  /// Carrega o logo do PraticOS dos assets locais
  Future<pw.MemoryImage?> loadPraticosLogo() async {
    return _loadAssetImage('assets/images/icon.png', 'praticos_logo');
  }

  /// Carrega o badge da App Store
  Future<pw.MemoryImage?> loadAppStoreBadge() async {
    return _loadAssetImage('assets/images/appstore_badge.png', 'appstore_badge');
  }

  /// Carrega o badge da Play Store
  Future<pw.MemoryImage?> loadPlayStoreBadge() async {
    return _loadAssetImage('assets/images/playstore_badge.png', 'playstore_badge');
  }

  /// Carrega uma imagem dos assets locais
  Future<pw.MemoryImage?> _loadAssetImage(String assetPath, String cacheKey) async {
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }

    try {
      final data = await rootBundle.load(assetPath);
      final image = pw.MemoryImage(data.buffer.asUint8List());
      _cache[cacheKey] = image;
      return image;
    } catch (e) {
      // Falha silenciosa - imagem e opcional
    }
    return null;
  }

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
  /// Os downloads sao feitos em paralelo, em lotes de [maxConcurrentDownloads],
  /// preservando a ordem original das URLs no resultado.
  ///
  /// [urls] Lista de URLs das fotos
  /// [limit] Numero maximo de fotos a baixar (default: 10)
  ///
  /// Retorna lista de imagens baixadas com sucesso
  Future<List<pw.MemoryImage>> loadPhotos(List<String> urls, {int limit = 10}) async {
    final urlsToLoad =
        urls.where((url) => url.isNotEmpty).take(limit).toList();
    if (urlsToLoad.isEmpty) return [];

    final List<pw.MemoryImage> images = [];

    for (var i = 0; i < urlsToLoad.length; i += maxConcurrentDownloads) {
      final batch = urlsToLoad.skip(i).take(maxConcurrentDownloads);
      final results = await Future.wait(
        batch.map((url) => _loadImage(url, url)),
      );
      images.addAll(results.whereType<pw.MemoryImage>());
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
  ///
  /// Downloads simultaneos da mesma URL compartilham a mesma requisicao.
  Future<pw.MemoryImage?> _loadImage(String url, String cacheKey) async {
    // Verifica cache primeiro
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }

    // Reaproveita um download ja em andamento para a mesma imagem
    final inFlight = _inFlight[cacheKey];
    if (inFlight != null) {
      return inFlight;
    }

    final future = _download(url, cacheKey);
    _inFlight[cacheKey] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(cacheKey);
    }
  }

  /// Executa o download efetivo e popula o cache
  Future<pw.MemoryImage?> _download(String url, String cacheKey) async {
    try {
      final response = await _httpGet(Uri.parse(url));
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
