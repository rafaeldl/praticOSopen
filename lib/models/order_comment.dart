import 'package:json_annotation/json_annotation.dart';
import 'package:praticos/models/membership.dart' show TimestampConverter;

part 'order_comment.g.dart';

/// Type of comment author
enum CommentAuthorType {
  customer,
  internal,
}

/// Source of the comment
enum CommentSource {
  app,
  magicLink,
  bot,
}

/// Author information for a comment
@JsonSerializable(explicitToJson: true)
class CommentAuthor {
  String? name;
  String? email;
  String? phone;
  String? userId;

  CommentAuthor();

  factory CommentAuthor.fromJson(Map<String, dynamic> json) =>
      _$CommentAuthorFromJson(json);
  Map<String, dynamic> toJson() => _$CommentAuthorToJson(this);
}

/// Order comment for customer communication
@JsonSerializable(explicitToJson: true)
class OrderComment {
  String? id;
  String? text;
  String? authorType; // 'customer' or 'internal'
  CommentAuthor? author;
  String? source; // 'app', 'magicLink', or 'bot'
  String? shareToken;
  bool? isInternal;
  @TimestampConverter()
  DateTime? createdAt;
  @TimestampConverter()
  DateTime? updatedAt;
  bool? deleted;

  /// Check if this is a customer comment
  bool get isCustomerComment => authorType == 'customer';

  /// Check if this is an internal comment
  bool get isInternalComment => authorType == 'internal';

  OrderComment();

  factory OrderComment.fromJson(Map<String, dynamic> json) =>
      _$OrderCommentFromJson(json);
  Map<String, dynamic> toJson() => _$OrderCommentToJson(this);
}
