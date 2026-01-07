import 'dart:typed_data';

import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/order_form.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/services/pdf/pdf_forms_builder.dart';
import 'package:praticos/services/pdf/pdf_image_loader.dart';
import 'package:praticos/services/pdf/pdf_main_os_builder.dart';
import 'package:praticos/services/pdf/pdf_styles.dart';

/// Dados necessarios para gerar o PDF da OS
class OsPdfData {
  final Order order;
  final Customer? customer;
  final Company company;
  final List<OrderForm> forms;
  final SegmentConfigProvider config;

  OsPdfData({
    required this.order,
    this.customer,
    required this.company,
    required this.forms,
    required this.config,
  });
}

/// Opcoes para geracao do PDF
class OsPdfOptions {
  /// Incluir pagina principal da OS
  final bool includeMainOs;

  /// Incluir paginas de formularios
  final bool includeForms;

  /// Incluir fotos na pagina principal
  final bool includeOsPhotos;

  /// Incluir fotos nos itens dos formularios
  final bool includeFormPhotos;

  /// Numero maximo de fotos na pagina principal
  final int maxOsPhotos;

  /// Numero maximo de fotos por item de formulario
  final int maxPhotosPerItem;

  const OsPdfOptions({
    this.includeMainOs = true,
    this.includeForms = true,
    this.includeOsPhotos = true,
    this.includeFormPhotos = true,
    this.maxOsPhotos = 6,
    this.maxPhotosPerItem = 8,
  });
}

/// Servico principal para geracao de PDFs de Ordens de Servico
class PdfService {
  final PdfImageLoader _imageLoader = PdfImageLoader();

  /// Gera o PDF e retorna os bytes
  Future<Uint8List> generateOsPdf(
    OsPdfData data, [
    OsPdfOptions options = const OsPdfOptions(),
  ]) async {
    // 1. Carregar fontes
    final (baseFont, boldFont) = await _loadFonts();

    // 2. Carregar imagens
    final images = await _loadImages(data, options);

    // 3. Criar builders
    final mainOsBuilder = PdfMainOsBuilder(
      baseFont: baseFont,
      boldFont: boldFont,
      logoImage: images.logo,
      config: data.config,
    );

    final formsBuilder = PdfFormsBuilder(
      baseFont: baseFont,
      boldFont: boldFont,
      logoImage: images.logo,
      config: data.config,
    );

    // 4. Criar documento
    final doc = pw.Document();

    // 5. Adicionar pagina principal da OS
    if (options.includeMainOs) {
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfStyles.pageFormat,
          margin: PdfStyles.pageMargin,
          header: (pw.Context context) {
            return mainOsBuilder.buildHeader(data.company, data.order);
          },
          footer: (pw.Context context) {
            return mainOsBuilder.buildFooter(context);
          },
          build: (pw.Context context) {
            return mainOsBuilder.buildContent(
              order: data.order,
              customer: data.customer,
              company: data.company,
              osPhotos: images.osPhotos,
            );
          },
        ),
      );
    }

    // 6. Adicionar paginas de formularios
    if (options.includeForms && data.forms.isNotEmpty) {
      for (final form in data.forms) {
        final itemPhotosMap = images.formItemPhotos[form.id] ?? {};

        doc.addPage(
          pw.MultiPage(
            pageFormat: PdfStyles.pageFormat,
            margin: PdfStyles.pageMargin,
            footer: (pw.Context context) {
              return formsBuilder.buildFormFooter(context, form);
            },
            build: (pw.Context context) {
              return formsBuilder.buildFormContent(
                company: data.company,
                order: data.order,
                form: form,
                itemPhotosMap: itemPhotosMap,
              );
            },
          ),
        );
      }
    }

    // 7. Salvar e retornar bytes
    return doc.save();
  }

  /// Gera o PDF e compartilha via sistema
  Future<void> shareOsPdf(
    OsPdfData data, [
    OsPdfOptions options = const OsPdfOptions(),
  ]) async {
    final bytes = await generateOsPdf(data, options);
    final filename = '${data.config.serviceOrder}-${data.order.number ?? "NOVA"}.pdf';
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }

  /// Carrega as fontes com fallback
  Future<(pw.Font, pw.Font)> _loadFonts() async {
    pw.Font baseFont;
    pw.Font boldFont;

    try {
      baseFont = await PdfGoogleFonts.nunitoSansRegular();
      boldFont = await PdfGoogleFonts.nunitoSansBold();
    } catch (e) {
      // Fallback para Helvetica se Google Fonts falhar
      baseFont = pw.Font.helvetica();
      boldFont = pw.Font.helveticaBold();
    }

    return (baseFont, boldFont);
  }

  /// Carrega todas as imagens necessarias
  Future<_PdfImages> _loadImages(OsPdfData data, OsPdfOptions options) async {
    // Logo da empresa
    final logo = await _imageLoader.loadLogo(data.company.logo);

    // Fotos da OS
    List<pw.MemoryImage> osPhotos = [];
    if (options.includeOsPhotos && data.order.photos != null) {
      final photoUrls = data.order.photos!
          .take(options.maxOsPhotos)
          .where((p) => p.url != null && p.url!.isNotEmpty)
          .map((p) => p.url!)
          .toList();
      osPhotos = await _imageLoader.loadPhotos(photoUrls, limit: options.maxOsPhotos);
    }

    // Fotos dos itens dos formularios
    // Map<formId, Map<itemId, List<Image>>>
    final Map<String, Map<String, List<pw.MemoryImage>>> formItemPhotos = {};

    if (options.includeFormPhotos && options.includeForms) {
      for (final form in data.forms) {
        final Map<String, List<pw.MemoryImage>> itemPhotos = {};

        for (final response in form.responses) {
          if (response.photoUrls.isNotEmpty) {
            final photos = await _imageLoader.loadPhotos(
              response.photoUrls,
              limit: options.maxPhotosPerItem,
            );
            if (photos.isNotEmpty) {
              itemPhotos[response.itemId] = photos;
            }
          }
        }

        if (itemPhotos.isNotEmpty) {
          formItemPhotos[form.id] = itemPhotos;
        }
      }
    }

    return _PdfImages(
      logo: logo,
      osPhotos: osPhotos,
      formItemPhotos: formItemPhotos,
    );
  }

  /// Limpa o cache de imagens
  void clearImageCache() {
    _imageLoader.clearCache();
  }
}

/// Classe interna para armazenar imagens carregadas
class _PdfImages {
  final pw.MemoryImage? logo;
  final List<pw.MemoryImage> osPhotos;
  final Map<String, Map<String, List<pw.MemoryImage>>> formItemPhotos;

  _PdfImages({
    this.logo,
    required this.osPhotos,
    required this.formItemPhotos,
  });
}
