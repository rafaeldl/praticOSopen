import 'package:flutter/foundation.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:praticos/global.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/order_form.dart';
import 'package:praticos/models/subscription.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/services/feature_gate_service.dart';
import 'package:praticos/services/pdf/pdf_forms_builder.dart';
import 'package:praticos/services/pdf/pdf_image_loader.dart';
import 'package:praticos/services/pdf/pdf_localizations.dart';
import 'package:praticos/services/pdf/pdf_main_os_builder.dart';
import 'package:praticos/services/pdf/pdf_styles.dart';

/// Dados necessarios para gerar o PDF da OS
class OsPdfData {
  final Order order;
  final Customer? customer;
  final Company company;
  final List<OrderForm> forms;
  final SegmentConfigProvider config;
  final PdfLocalizations localizations;

  OsPdfData({
    required this.order,
    this.customer,
    required this.company,
    required this.forms,
    required this.config,
    required this.localizations,
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
    this.maxOsPhotos = 3,
    this.maxPhotosPerItem = 8,
  });
}

/// Servico principal para geracao de PDFs de Ordens de Servico
class PdfService {
  final PdfImageLoader _imageLoader = PdfImageLoader();

  /// Gera o PDF e retorna os bytes.
  ///
  /// Se [subscription] for null, usa [Global.subscription] para verificar
  /// se deve exibir marca d'água (planos Free exibem marca d'água).
  Future<Uint8List> generateOsPdf(
    OsPdfData data, [
    OsPdfOptions options = const OsPdfOptions(),
    Subscription? subscription,
  ]) async {
    // 0. Verificar se deve exibir marca d'agua
    final effectiveSubscription = subscription ?? Global.subscription;
    final showWatermark = FeatureGateService.shouldShowPdfWatermark(effectiveSubscription);

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
      localizations: data.localizations,
      showWatermark: showWatermark,
    );

    final formsBuilder = PdfFormsBuilder(
      baseFont: baseFont,
      boldFont: boldFont,
      logoImage: images.logo,
      config: data.config,
      localizations: data.localizations,
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
            final content = mainOsBuilder.buildContent(
              order: data.order,
              customer: data.customer,
              company: data.company,
            );
            // Adicionar marca d'agua como primeiro widget (background)
            if (showWatermark) {
              return [mainOsBuilder.buildWatermark(), ...content];
            }
            return content;
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
              return formsBuilder.buildFormFooter(
                context,
                form,
                images.praticosLogo,
                images.appStoreBadge,
                images.playStoreBadge,
              );
            },
            build: (pw.Context context) {
              final content = formsBuilder.buildFormContent(
                company: data.company,
                order: data.order,
                form: form,
                itemPhotosMap: itemPhotosMap,
              );
              // Adicionar marca d'agua nas paginas de formularios tambem
              if (showWatermark) {
                return [mainOsBuilder.buildWatermark(), ...content];
              }
              return content;
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

  /// Carrega as fontes (usando Helvetica nativa)
  Future<(pw.Font, pw.Font)> _loadFonts() async {
    // Usar fontes nativas do PDF (não requer assets)
    final baseFont = pw.Font.helvetica();
    final boldFont = pw.Font.helveticaBold();
    return (baseFont, boldFont);
  }

  /// Carrega todas as imagens necessarias
  Future<_PdfImages> _loadImages(OsPdfData data, OsPdfOptions options) async {
    // Logo da empresa
    final logo = await _imageLoader.loadLogo(data.company.logo);

    // Logo do PraticOS e badges das lojas
    final praticosLogo = await _imageLoader.loadPraticosLogo();
    final appStoreBadge = await _imageLoader.loadAppStoreBadge();
    final playStoreBadge = await _imageLoader.loadPlayStoreBadge();

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
      praticosLogo: praticosLogo,
      appStoreBadge: appStoreBadge,
      playStoreBadge: playStoreBadge,
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
  final pw.MemoryImage? praticosLogo;
  final pw.MemoryImage? appStoreBadge;
  final pw.MemoryImage? playStoreBadge;
  final Map<String, Map<String, List<pw.MemoryImage>>> formItemPhotos;

  _PdfImages({
    this.logo,
    this.praticosLogo,
    this.appStoreBadge,
    this.playStoreBadge,
    required this.formItemPhotos,
  });
}
