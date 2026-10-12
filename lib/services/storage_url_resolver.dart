import 'package:firebase_storage/firebase_storage.dart';

typedef DownloadUrlGetter =
    Future<String> Function(String bucket, String storagePath);

/// Turns photo URLs that the app cannot open into Firebase download URLs.
///
/// Older photos (saved by the WhatsApp bot) store a plain
/// `https://storage.googleapis.com/<bucket>/<path>` URL. The bucket is not
/// public, so those URLs fail to load. The file still exists at `<path>`,
/// so we ask Firebase Storage for a tokenized download URL instead.
class StorageUrlResolver {
  StorageUrlResolver._();

  static DownloadUrlGetter getDownloadUrl = (bucket, path) =>
      FirebaseStorage.instanceFor(
        bucket: 'gs://$bucket',
      ).ref(path).getDownloadURL();

  static final Map<String, Future<String?>> _cache = {};

  /// The storage path to resolve for [url], or null when [url] loads as is.
  static String? storagePathFromUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host != 'storage.googleapis.com') return null;
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    // First segment is the bucket.
    if (segments.length < 2) return null;
    return segments.skip(1).join('/');
  }

  static bool needsResolve(String url) => storagePathFromUrl(url) != null;

  /// A URL that loads, or [url] unchanged when it already does.
  static Future<String?> resolve(String url) {
    final path = storagePathFromUrl(url);
    if (path == null) return Future.value(url);
    final bucket = Uri.parse(url).pathSegments.firstWhere((s) => s.isNotEmpty);
    final key = '$bucket/$path';
    final cached = _cache[key];
    if (cached != null) return cached;
    final future = _load(bucket, path);
    _cache[key] = future;
    // Failures are not cached, so the photo is retried on the next build.
    future.then((value) {
      if (value == null) _cache.remove(key);
    });
    return future;
  }

  static Future<String?> _load(String bucket, String path) async {
    try {
      return await getDownloadUrl(bucket, path);
    } catch (_) {
      return null;
    }
  }

  static void clearCache() => _cache.clear();
}
