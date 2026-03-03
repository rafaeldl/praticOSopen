import 'package:json_annotation/json_annotation.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/user.dart';

part 'order_document.g.dart';

/// Document type classification for order attachments
enum OrderDocumentType {
  @JsonValue('receipt')
  receipt,
  @JsonValue('invoice')
  invoice,
  @JsonValue('contract')
  contract,
  @JsonValue('warranty')
  warranty,
  @JsonValue('other')
  other,
}

/// Represents a document attached to an order (receipts, invoices, contracts, etc.)
@JsonSerializable(explicitToJson: true)
class OrderDocument {
  String? id;
  String? url;
  String? storagePath;
  String? fileName;
  String? contentType;
  int? fileSize;
  OrderDocumentType? type;
  String? description;
  DateTime? createdAt;
  UserAggr? createdBy;

  /// If this document is a receipt linked to a payment transaction
  String? linkedTransactionId;

  OrderDocument();

  factory OrderDocument.fromJson(Map<String, dynamic> json) =>
      _$OrderDocumentFromJson(json);
  Map<String, dynamic> toJson() => _$OrderDocumentToJson(this);

  /// Whether this document is an image
  bool get isImage => contentType?.startsWith('image/') == true;

  /// Whether this document is a PDF
  bool get isPdf => contentType == 'application/pdf';

  /// Human-readable file size
  String get fileSizeFormatted {
    if (fileSize == null) return '';
    if (fileSize! < 1024) return '${fileSize}B';
    if (fileSize! < 1024 * 1024) {
      return '${(fileSize! / 1024).toStringAsFixed(0)}KB';
    }
    return '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  /// Returns localized label for the document type
  String typeLabel(AppLocalizations l10n) {
    switch (type) {
      case OrderDocumentType.receipt:
        return l10n.receipt;
      case OrderDocumentType.invoice:
        return l10n.invoice;
      case OrderDocumentType.contract:
        return l10n.contract;
      case OrderDocumentType.warranty:
        return l10n.warranty;
      case OrderDocumentType.other:
      case null:
        return l10n.other;
    }
  }
}
