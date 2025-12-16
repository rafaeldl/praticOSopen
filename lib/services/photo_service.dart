import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:praticos/models/order_photo.dart';
import 'package:praticos/global.dart';

class PhotoService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  /// Abre a galeria para selecionar uma imagem
  Future<File?> pickImageFromGallery() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1920,
      maxHeight: 1080,
    );
    if (image != null) {
      return File(image.path);
    }
    return null;
  }

  /// Abre a câmera para tirar uma foto
  Future<File?> takePhoto() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
      maxWidth: 1920,
      maxHeight: 1080,
    );
    if (image != null) {
      return File(image.path);
    }
    return null;
  }

  /// Faz upload de uma imagem para o Firebase Storage
  /// Retorna um OrderPhoto com a URL e o path do storage
  Future<OrderPhoto?> uploadPhoto({
    required File file,
    required String companyId,
    required String orderId,
  }) async {
    try {
      final String photoId = DateTime.now().millisecondsSinceEpoch.toString();
      final String storagePath =
          'tenants/$companyId/orders/$orderId/photos/$photoId.jpg';

      final Reference ref = _storage.ref().child(storagePath);

      final UploadTask uploadTask = ref.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      final OrderPhoto photo = OrderPhoto();
      photo.id = photoId;
      photo.url = downloadUrl;
      photo.storagePath = storagePath;
      photo.createdAt = DateTime.now();
      photo.createdBy = Global.userAggr;

      return photo;
    } catch (e) {
      print('Erro ao fazer upload da foto: $e');
      return null;
    }
  }

  /// Exclui uma foto do Firebase Storage
  Future<bool> deletePhoto(String storagePath) async {
    try {
      final Reference ref = _storage.ref().child(storagePath);
      await ref.delete();
      return true;
    } catch (e) {
      print('Erro ao excluir foto: $e');
      return false;
    }
  }

  /// Exclui todas as fotos de uma ordem de serviço
  Future<bool> deleteAllPhotos({
    required String companyId,
    required String orderId,
  }) async {
    try {
      final String folderPath = 'tenants/$companyId/orders/$orderId/photos';
      final Reference ref = _storage.ref().child(folderPath);
      final ListResult result = await ref.listAll();

      for (final Reference item in result.items) {
        await item.delete();
      }
      return true;
    } catch (e) {
      print('Erro ao excluir todas as fotos: $e');
      return false;
    }
  }
}
