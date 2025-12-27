import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:praticos/models/order_photo.dart';
import 'package:praticos/global.dart';

/// Serviço centralizado para gerenciamento de fotos
/// - Seleção de imagens (galeria/câmera)
/// - Conversão para JPEG
/// - Upload para Firebase Storage
/// - Compatível com iOS HEIC
class PhotoService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  // Proteção contra chamadas múltiplas (static para funcionar entre instâncias)
  static bool _isPickingImage = false;

  // Detecta se está no iOS
  bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  // ============================================================
  // SELEÇÃO DE IMAGENS
  // ============================================================

  /// Abre a galeria para selecionar uma imagem
  /// No iOS usa file_picker para evitar bug do HEIC no simulador
  Future<File?> pickImageFromGallery() async {
    if (_isPickingImage) {
      print('PhotoService: Picker já ativo, ignorando');
      return null;
    }

    _isPickingImage = true;
    try {
      if (_isIOS) {
        return await _pickWithFilePicker();
      }
      return await _pickWithImagePicker(ImageSource.gallery);
    } finally {
      _isPickingImage = false;
    }
  }

  /// Abre a câmera para tirar uma foto
  Future<File?> takePhoto() async {
    if (_isPickingImage) {
      print('PhotoService: Camera já ativa, ignorando');
      return null;
    }

    _isPickingImage = true;
    try {
      return await _pickWithImagePicker(ImageSource.camera);
    } finally {
      _isPickingImage = false;
    }
  }

  Future<File?> _pickWithImagePicker(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        requestFullMetadata: false,
        imageQuality: 100,
      );
      return image != null ? File(image.path) : null;
    } catch (e) {
      print('PhotoService: image_picker erro: $e');
      return null;
    }
  }

  Future<File?> _pickWithFilePicker() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null) {
        return File(result.files.single.path!);
      }
      return null;
    } catch (e) {
      print('PhotoService: file_picker erro: $e');
      return null;
    }
  }

  // ============================================================
  // CONVERSÃO DE IMAGEM
  // ============================================================

  /// Converte qualquer imagem para JPEG
  /// Resolve problemas de HEIC/HEIF e cores incorretas
  Future<File> _convertToJpeg(File input, {int quality = 80}) async {
    final tempDir = await getTemporaryDirectory();
    final photoId = DateTime.now().millisecondsSinceEpoch.toString();
    final outputPath = '${tempDir.path}/$photoId.jpg';

    final originalSize = await input.length();
    print('PhotoService: Convertendo ${(originalSize / 1024).toStringAsFixed(0)}KB -> JPEG');

    final result = await FlutterImageCompress.compressAndGetFile(
      input.absolute.path,
      outputPath,
      format: CompressFormat.jpeg,
      quality: quality,
      keepExif: true,
    );

    if (result == null) {
      throw Exception('Falha na conversão para JPEG');
    }

    final convertedFile = File(result.path);
    final convertedSize = await convertedFile.length();
    final reduction = ((1 - convertedSize / originalSize) * 100).toStringAsFixed(0);
    print('PhotoService: Convertido ${(convertedSize / 1024).toStringAsFixed(0)}KB (-$reduction%)');

    return convertedFile;
  }

  // ============================================================
  // UPLOAD PARA FIREBASE STORAGE
  // ============================================================

  /// Upload genérico para qualquer caminho no Storage
  /// Usado por: devices, products, services
  Future<String?> uploadImage({
    required File file,
    required String storagePath,
  }) async {
    try {
      await _validateAuth();
      _validateTenantPath(storagePath);

      final jpegFile = await _convertToJpeg(file);
      return await _uploadWithFallback(jpegFile, storagePath);
    } catch (e) {
      print('PhotoService: Erro no upload: $e');
      return null;
    }
  }

  /// Upload específico para fotos de ordens de serviço
  /// Retorna OrderPhoto com metadados
  Future<OrderPhoto?> uploadOrderPhoto({
    required File file,
    required String companyId,
    required String orderId,
  }) async {
    try {
      await _validateAuth();

      if (Global.companyAggr?.id != companyId) {
        throw Exception('Sem permissão para upload nesta empresa');
      }

      final now = DateTime.now();
      final photoId = '${now.millisecondsSinceEpoch}-${now.microsecondsSinceEpoch % 1000000}';
      final storagePath = 'tenants/$companyId/orders/$orderId/photos/$photoId.jpg';

      final jpegFile = await _convertToJpeg(file);
      final downloadUrl = await _uploadWithFallback(jpegFile, storagePath);

      if (downloadUrl == null) return null;

      return OrderPhoto()
        ..id = photoId
        ..url = downloadUrl
        ..storagePath = storagePath
        ..createdAt = now
        ..createdBy = Global.userAggr;
    } catch (e) {
      print('PhotoService: Erro no upload de foto da OS: $e');
      rethrow;
    }
  }

  /// Upload com estratégias de fallback
  Future<String?> _uploadWithFallback(File file, String storagePath) async {
    final ref = _storage.ref().child(storagePath);
    final bytes = await file.readAsBytes();

    // Estratégia 1: putData com metadata (mais confiável)
    try {
      print('PhotoService: Upload para $storagePath');
      final snapshot = await ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      return await _getDownloadUrl(snapshot.ref);
    } on FirebaseException catch (e) {
      print('PhotoService: Tentativa 1 falhou: ${e.code}');
    }

    // Estratégia 2: putFile
    try {
      final snapshot = await ref.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      return await _getDownloadUrl(snapshot.ref);
    } on FirebaseException catch (e) {
      print('PhotoService: Tentativa 2 falhou: ${e.code}');
    }

    // Estratégia 3: putData sem metadata
    try {
      final snapshot = await ref.putData(bytes);
      return await _getDownloadUrl(snapshot.ref);
    } catch (e) {
      print('PhotoService: Todas as tentativas falharam: $e');
      return null;
    }
  }

  Future<String> _getDownloadUrl(Reference ref, {int maxRetries = 3}) async {
    for (var i = 1; i <= maxRetries; i++) {
      try {
        return await ref.getDownloadURL();
      } catch (e) {
        if (i == maxRetries) rethrow;
        await Future.delayed(Duration(milliseconds: i * 500));
      }
    }
    throw Exception('Falha ao obter URL');
  }

  // ============================================================
  // EXCLUSÃO DE FOTOS
  // ============================================================

  /// Exclui uma foto pelo storagePath
  Future<bool> deletePhoto(String storagePath) async {
    try {
      _validateTenantPath(storagePath);
      await _storage.ref().child(storagePath).delete();
      return true;
    } catch (e) {
      print('PhotoService: Erro ao excluir: $e');
      return false;
    }
  }

  /// Exclui todas as fotos de uma ordem
  Future<bool> deleteAllOrderPhotos({
    required String companyId,
    required String orderId,
  }) async {
    try {
      if (Global.companyAggr?.id != companyId) {
        throw Exception('Sem permissão');
      }

      final folderPath = 'tenants/$companyId/orders/$orderId/photos';
      final result = await _storage.ref().child(folderPath).listAll();

      for (final item in result.items) {
        await item.delete();
      }
      return true;
    } catch (e) {
      print('PhotoService: Erro ao excluir fotos: $e');
      return false;
    }
  }

  // ============================================================
  // VALIDAÇÕES
  // ============================================================

  Future<void> _validateAuth() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Usuário não autenticado');
    }
    // Força refresh do token
    await user.getIdToken(true);
  }

  void _validateTenantPath(String path) {
    final expectedPrefix = 'tenants/${Global.companyAggr?.id}/';
    if (!path.startsWith(expectedPrefix)) {
      throw Exception('Path inválido para o tenant atual');
    }
  }
}
