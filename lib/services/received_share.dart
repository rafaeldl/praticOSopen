/// What a file received from another app becomes inside an order.
enum ReceivedKind {
  /// Saved as an order photo (tenants/{companyId}/orders/{orderId}/photos/).
  photo,

  /// Saved as an `OrderDocument` (PDF).
  pdf,

  /// Not supported; ignored.
  unsupported,
}

/// A file handed to the app by the system share sheet.
class ReceivedFile {
  const ReceivedFile({required this.path, this.mimeType});

  final String path;
  final String? mimeType;

  String get fileName => path.split('/').last;

  ReceivedKind get kind => classifyReceived(path, mimeType);
}

/// Routes a received file: images -> order photos, PDFs -> order documents.
///
/// The MIME type wins; the extension is the fallback because some apps share
/// with a generic or missing type.
ReceivedKind classifyReceived(String path, String? mimeType) {
  final mime = mimeType?.toLowerCase().trim();
  if (mime != null && mime.isNotEmpty) {
    if (mime.startsWith('image/')) return ReceivedKind.photo;
    if (mime == 'application/pdf') return ReceivedKind.pdf;
  }
  final dot = path.lastIndexOf('.');
  final ext = dot == -1 ? '' : path.substring(dot + 1).toLowerCase();
  const imageExt = {'jpg', 'jpeg', 'png', 'webp', 'heic', 'heif', 'gif'};
  if (imageExt.contains(ext)) return ReceivedKind.photo;
  if (ext == 'pdf') return ReceivedKind.pdf;
  return ReceivedKind.unsupported;
}

/// Received files split by destination.
class ReceivedBatch {
  ReceivedBatch(Iterable<ReceivedFile> files)
      : photos = [],
        pdfs = [] {
    for (final f in files) {
      switch (f.kind) {
        case ReceivedKind.photo:
          photos.add(f);
        case ReceivedKind.pdf:
          pdfs.add(f);
        case ReceivedKind.unsupported:
          break;
      }
    }
  }

  final List<ReceivedFile> photos;
  final List<ReceivedFile> pdfs;

  bool get isEmpty => photos.isEmpty && pdfs.isEmpty;
}
