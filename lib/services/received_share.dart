import 'dart:convert';
import 'dart:io';

import 'package:praticos/utils/vcard.dart';

/// What a file received from another app becomes.
enum ReceivedKind {
  /// Saved as an order photo (tenants/{companyId}/orders/{orderId}/photos/).
  photo,

  /// Saved as an `OrderDocument` (PDF).
  pdf,

  /// A contact card (`.vcf`): opens the new customer form, not "Em qual OS?".
  contact,

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

/// Routes a received file: images -> order photos, PDFs -> order documents,
/// contact cards -> new customer.
///
/// The MIME type wins; the extension is the fallback because some apps share
/// with a generic or missing type.
ReceivedKind classifyReceived(String path, String? mimeType) {
  final mime = mimeType?.toLowerCase().trim();
  if (mime != null && mime.isNotEmpty) {
    if (mime.startsWith('image/')) return ReceivedKind.photo;
    if (mime == 'application/pdf') return ReceivedKind.pdf;
    if (isContactMime(mime)) return ReceivedKind.contact;
  }
  final dot = path.lastIndexOf('.');
  final ext = dot == -1 ? '' : path.substring(dot + 1).toLowerCase();
  const imageExt = {'jpg', 'jpeg', 'png', 'webp', 'heic', 'heif', 'gif'};
  if (imageExt.contains(ext)) return ReceivedKind.photo;
  if (ext == 'pdf') return ReceivedKind.pdf;
  if (ext == 'vcf' || ext == 'vcard') return ReceivedKind.contact;
  return ReceivedKind.unsupported;
}

/// MIME types of a contact card. Android apps share them as text.
bool isContactMime(String? mimeType) => const {
      'text/x-vcard',
      'text/vcard',
      'text/directory',
    }.contains(mimeType?.toLowerCase().trim());

/// Received files split by destination.
class ReceivedBatch {
  ReceivedBatch(Iterable<ReceivedFile> files)
      : photos = [],
        pdfs = [],
        contacts = [] {
    for (final f in files) {
      switch (f.kind) {
        case ReceivedKind.photo:
          photos.add(f);
        case ReceivedKind.pdf:
          pdfs.add(f);
        case ReceivedKind.contact:
          contacts.add(f);
        case ReceivedKind.unsupported:
          break;
      }
    }
  }

  final List<ReceivedFile> photos;
  final List<ReceivedFile> pdfs;
  final List<ReceivedFile> contacts;

  bool get isEmpty => photos.isEmpty && pdfs.isEmpty && contacts.isEmpty;

  /// Only contact cards: they become a customer. Shared together with photos
  /// or PDFs, the files win and go to "Em qual OS?" as always.
  bool get isOnlyContacts =>
      contacts.isNotEmpty && photos.isEmpty && pdfs.isEmpty;
}

/// Contacts in [files], in order. A file that cannot be read counts as empty.
Future<List<ContactCard>> readContactCards(List<ReceivedFile> files) async {
  final cards = <ContactCard>[];
  for (final f in files) {
    try {
      final bytes = await File(f.path).readAsBytes();
      cards.addAll(parseVCards(utf8.decode(bytes, allowMalformed: true)));
    } catch (_) {
      // Unreadable: the caller says so when no contact is left.
    }
  }
  return cards;
}


/// Whether receiving shares from other apps is wired on this platform:
/// Android (intent filters) and iOS (Share Extension). [operatingSystem] is
/// `Platform.operatingSystem`.
bool receiveShareSupported({
  required bool isWeb,
  required String operatingSystem,
}) =>
    !isWeb && (operatingSystem == 'android' || operatingSystem == 'ios');

/// Turns a path handed over by the share plugin into a plain file path.
///
/// The iOS plugin usually strips `file://`, but a `file://` URI (possibly
/// percent-encoded) is accepted too. Plain paths are returned unchanged.
String normalizeSharedPath(String path) {
  if (!path.startsWith('file://')) return path;
  try {
    return Uri.parse(path).toFilePath();
  } catch (_) {
    return path.substring('file://'.length);
  }
}

/// True for the copies the iOS Share Extension leaves in the App Group
/// container. They are ours to delete once handled; anything else (e.g. a
/// photo in the iPhone library) is never touched.
bool isShareExtensionCopy(String path) => path.contains('/Shared/AppGroup/');

/// True for the copy Android's share plugin leaves in the app's cache. Same
/// idea as [isShareExtensionCopy]; a `.vcf` in the phone's storage stays.
bool isAndroidCacheCopy(String path) =>
    path.contains('/br.com.rafsoft.praticos/cache/');
