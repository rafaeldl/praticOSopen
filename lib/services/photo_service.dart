import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:praticos/models/order_photo.dart';
import 'package:praticos/global.dart';

class PhotoService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  /// Converte qualquer imagem para JPEG válido
  /// Isso resolve o problema de fotos HEIC/HEIF/PNG que podem causar cores esverdeadas
  ///
  /// [input] - Arquivo de imagem original (qualquer formato suportado)
  /// [photoId] - ID único para nomear o arquivo temporário
  /// [quality] - Qualidade da compressão (0-100, padrão 80)
  ///
  /// Retorna um File com o JPEG convertido
  Future<File> _ensureJpeg(File input, String photoId, {int quality = 80}) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final outputPath = '${tempDir.path}/$photoId.jpg';

      // Log do arquivo original para debug
      final originalSize = await input.length();
      final originalExtension = input.path.split('.').last.toLowerCase();
      print('Convertendo imagem: $originalExtension -> JPEG');
      print('Tamanho original: ${(originalSize / 1024).toStringAsFixed(1)} KB');

      // Converte para JPEG usando flutter_image_compress
      // Preserva EXIF (orientação) quando possível
      final XFile? result = await FlutterImageCompress.compressAndGetFile(
        input.absolute.path,
        outputPath,
        format: CompressFormat.jpeg,
        quality: quality,
        keepExif: true, // Preserva orientação da foto
      );

      if (result == null) {
        throw Exception('Falha na conversão da imagem para JPEG');
      }

      final convertedFile = File(result.path);
      final convertedSize = await convertedFile.length();

      print('Conversão concluída: ${(convertedSize / 1024).toStringAsFixed(1)} KB');
      print('Redução: ${((1 - convertedSize / originalSize) * 100).toStringAsFixed(1)}%');

      return convertedFile;
    } catch (e) {
      print('Erro na conversão para JPEG: $e');
      throw Exception('Não foi possível processar a imagem. Tente novamente ou escolha outra foto.');
    }
  }

  /// Abre a galeria para selecionar uma imagem
  Future<File?> pickImageFromGallery() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      requestFullMetadata: false, // Helps with HEIC on iOS
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
      requestFullMetadata: false, // Helps with HEIC on iOS
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
      // Verifica se o usuário está autenticado e obtém o token
      final auth = FirebaseAuth.instance;
      final user = auth.currentUser;

      if (user == null) {
        throw Exception('Usuário não autenticado. Faça login novamente.');
      }

      // Força a atualização do token para garantir que está válido
      try {
        await user.getIdToken(true); // true = força refresh do token
      } catch (tokenError) {
        print('Erro ao atualizar token: $tokenError');
        throw Exception('Erro de autenticação. Faça login novamente.');
      }

      // Validação adicional: verifica se o companyId corresponde ao Global.companyAggr
      // Isso previne tentativas de upload para outras empresas
      if (Global.companyAggr?.id == null || Global.companyAggr!.id != companyId) {
        print('SECURITY: Tentativa de upload para companyId diferente do usuário logado');
        print('  Global.companyAggr.id: ${Global.companyAggr?.id}');
        print('  companyId fornecido: $companyId');
        throw Exception('Você não tem permissão para fazer upload de fotos para esta empresa.');
      }

      // Gera um ID único usando timestamp + random para evitar conflitos
      final DateTime now = DateTime.now();
      // Usa um UUID-like approach: milliseconds + random de 6 dígitos
      final int randomSuffix = (now.microsecondsSinceEpoch % 1000000);
      final String photoId = '${now.millisecondsSinceEpoch}-$randomSuffix';
      final String storagePath =
          'tenants/$companyId/orders/$orderId/photos/$photoId.jpg';

      // IMPORTANTE: Converte a imagem para JPEG antes do upload
      // Isso garante que HEIC/HEIF/PNG sejam convertidos corretamente,
      // evitando o problema de cores esverdeadas
      print('Convertendo imagem para JPEG antes do upload...');
      final File jpegFile = await _ensureJpeg(file, photoId);

      print('Iniciando upload para: $storagePath');
      final Reference ref = _storage.ref().child(storagePath);

      // Tenta múltiplas estratégias de upload
      // Estratégia 1: putFile COM metadata (mais confiável)
      try {
        print('Tentativa 1: putFile com metadata');
        final UploadTask uploadTask = ref.putFile(
          jpegFile, // Usa o arquivo JPEG convertido
          SettableMetadata(contentType: 'image/jpeg'),
        );

        // Monitora o progresso
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          final progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
          print('Upload progress: ${progress.toStringAsFixed(2)}%');
        });

        final TaskSnapshot snapshot = await uploadTask;
        print('Upload concluído. Tamanho: ${snapshot.totalBytes} bytes');

        // Tenta obter a URL com retry (às vezes demora um pouco para ficar disponível)
        final String downloadUrl = await _getDownloadUrlWithRetry(snapshot.ref);
        print('URL obtida: $downloadUrl');

        return _createOrderPhoto(photoId, storagePath, downloadUrl, now);
      } on FirebaseException catch (uploadError) {
        print('Erro na tentativa 1: ${uploadError.code} - ${uploadError.message}');
        
        // Estratégia 2: putFile com contentType
        // Relaxando a condição: tenta fallback para qualquer erro 'unknown' ou 'canceled'
        if (uploadError.code == 'unknown' || uploadError.code == 'canceled' || uploadError.message?.contains('412') == true) {
          try {
            print('Tentativa 2: putFile com contentType (Fallback)');
            final UploadTask uploadTask = ref.putFile(
              jpegFile, // Usa o arquivo JPEG convertido
              SettableMetadata(contentType: 'image/jpeg'),
            );

            final TaskSnapshot snapshot = await uploadTask;
            final String downloadUrl = await _getDownloadUrlWithRetry(snapshot.ref);

            return _createOrderPhoto(photoId, storagePath, downloadUrl, now);
          } catch (retryError) {
            print('Erro na tentativa 2: $retryError');

            // Estratégia 3: putData (converte arquivo para bytes)
            try {
              print('Tentativa 3: putData (bytes)');
              final Uint8List fileBytes = await jpegFile.readAsBytes(); // Usa o arquivo JPEG convertido
              final UploadTask uploadTask = ref.putData(
                fileBytes,
                SettableMetadata(contentType: 'image/jpeg'),
              );

              final TaskSnapshot snapshot = await uploadTask;
              final String downloadUrl = await _getDownloadUrlWithRetry(snapshot.ref);

              return _createOrderPhoto(photoId, storagePath, downloadUrl, now);
            } catch (dataError) {
              print('Erro na tentativa 3: $dataError');

              // Estratégia 4: putData sem metadata
              try {
                print('Tentativa 4: putData sem metadata');
                final Uint8List fileBytes = await jpegFile.readAsBytes(); // Usa o arquivo JPEG convertido
                final UploadTask uploadTask = ref.putData(fileBytes);

                final TaskSnapshot snapshot = await uploadTask;
                final String downloadUrl = await _getDownloadUrlWithRetry(snapshot.ref);

                return _createOrderPhoto(photoId, storagePath, downloadUrl, now);
              } catch (finalError) {
                print('Erro na tentativa 4: $finalError');
                rethrow;
              }
            }
          }
        }
        rethrow;
      }
    } on FirebaseException catch (e) {
      print('Erro Firebase: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('Erro ao fazer upload da foto: $e');
      rethrow;
    }
  }

  /// Tenta obter a URL de download com retry
  Future<String> _getDownloadUrlWithRetry(Reference ref, {int maxRetries = 3}) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('Obtendo download URL (tentativa $attempt de $maxRetries)...');
        final url = await ref.getDownloadURL();
        return url;
      } catch (e) {
        print('Erro ao obter URL (tentativa $attempt): $e');

        if (attempt < maxRetries) {
          // Aguarda antes de tentar novamente (aumenta o delay a cada tentativa)
          final delayMs = attempt * 500; // 500ms, 1000ms, 1500ms...
          print('Aguardando ${delayMs}ms antes de tentar novamente...');
          await Future.delayed(Duration(milliseconds: delayMs));
        } else {
          // Última tentativa falhou
          rethrow;
        }
      }
    }
    throw Exception('Falha ao obter URL após $maxRetries tentativas');
  }

  /// Cria um objeto OrderPhoto com os dados fornecidos
  OrderPhoto _createOrderPhoto(
    String photoId,
    String storagePath,
    String downloadUrl,
    DateTime createdAt,
  ) {
    final OrderPhoto photo = OrderPhoto();
    photo.id = photoId;
    photo.url = downloadUrl;
    photo.storagePath = storagePath;
    photo.createdAt = createdAt;
    photo.createdBy = Global.userAggr;
    return photo;
  }

  /// Exclui uma foto do Firebase Storage
  Future<bool> deletePhoto(String storagePath) async {
    try {
      // Valida que o storagePath começa com o tenant correto
      final expectedPrefix = 'tenants/${Global.companyAggr?.id}/';
      if (!storagePath.startsWith(expectedPrefix)) {
        print('SECURITY: Tentativa de excluir foto de outro tenant');
        print('  Path fornecido: $storagePath');
        print('  Esperado começar com: $expectedPrefix');
        throw Exception('Você não tem permissão para excluir esta foto.');
      }

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
      // Validação adicional: verifica se o companyId corresponde ao Global.companyAggr
      if (Global.companyAggr?.id == null || Global.companyAggr!.id != companyId) {
        print('SECURITY: Tentativa de excluir fotos de companyId diferente do usuário logado');
        print('  Global.companyAggr.id: ${Global.companyAggr?.id}');
        print('  companyId fornecido: $companyId');
        throw Exception('Você não tem permissão para excluir fotos desta empresa.');
      }

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

  /// Faz upload de uma imagem genérica para um caminho específico
  /// Retorna a URL de download
  Future<String?> uploadImage({
    required File file,
    required String storagePath,
  }) async {
    try {
      final auth = FirebaseAuth.instance;
      final user = auth.currentUser;

      if (user == null) {
        throw Exception('Usuário não autenticado.');
      }

      // Valida que o storagePath começa com o tenant correto
      final expectedPrefix = 'tenants/${Global.companyAggr?.id}/';
      if (!storagePath.startsWith(expectedPrefix)) {
         print('SECURITY: Tentativa de upload para outro tenant');
         throw Exception('Você não tem permissão para fazer upload para esta empresa.');
      }

      // Gera um ID único para a conversão
      final String photoId = DateTime.now().millisecondsSinceEpoch.toString();

      // Converte para JPEG
      final File jpegFile = await _ensureJpeg(file, photoId);

      final Reference ref = _storage.ref().child(storagePath);

      print('Uploading to path: $storagePath'); // DEBUG: Print exact path

      final UploadTask uploadTask = ref.putFile(
        jpegFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await _getDownloadUrlWithRetry(snapshot.ref);

      return downloadUrl;
    } catch (e) {
      print('Erro ao fazer upload da imagem: $e');
      return null;
    }
  }
}
