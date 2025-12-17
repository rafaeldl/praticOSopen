import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

      print('Iniciando upload para: $storagePath');
      final Reference ref = _storage.ref().child(storagePath);

      // Tenta múltiplas estratégias de upload
      // Estratégia 1: putFile COM metadata (mais confiável)
      try {
        print('Tentativa 1: putFile com metadata');
        final UploadTask uploadTask = ref.putFile(
          file,
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
              file,
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
              final Uint8List fileBytes = await file.readAsBytes();
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
                final Uint8List fileBytes = await file.readAsBytes();
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
}
