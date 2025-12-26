import 'package:json_annotation/json_annotation.dart';
import 'package:praticos/models/user.dart';

part 'order_photo.g.dart';

@JsonSerializable(explicitToJson: true)
class OrderPhoto {
  String? id;
  String? itemId;
  String? url;
  String? storagePath;
  DateTime? createdAt;
  UserAggr? createdBy;

  OrderPhoto();

  factory OrderPhoto.fromJson(Map<String, dynamic> json) =>
      _$OrderPhotoFromJson(json);
  Map<String, dynamic> toJson() => _$OrderPhotoToJson(this);
}
