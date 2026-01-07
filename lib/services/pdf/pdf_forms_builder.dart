import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:praticos/models/company.dart';
import 'package:praticos/models/form_definition.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/order_form.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/services/pdf/pdf_styles.dart';

/// Builder para as paginas de formularios/checklists no PDF
class PdfFormsBuilder {
  final pw.Font baseFont;
  final pw.Font boldFont;
  final pw.MemoryImage? logoImage;
  final SegmentConfigProvider config;

  PdfFormsBuilder({
    required this.baseFont,
    required this.boldFont,
    this.logoImage,
    required this.config,
  });

  // ============================================
  // HEADER DO FORMULARIO
  // ============================================

  /// Constroi o header da pagina de formulario com fundo azul
  pw.Widget buildFormHeader({
    required Company company,
    required Order order,
    required OrderForm form,
  }) {
    final statusColor = _getFormStatusColor(form.status);
    final statusText = _getFormStatusText(form.status);
    final formDate = form.updatedAt ?? form.startedAt ?? DateTime.now();

    return pw.Column(
      children: [
        // Header com fundo azul gradiente
        pw.Container(
          width: double.infinity,
          decoration: pw.BoxDecoration(
            gradient: pw.LinearGradient(
              colors: [
                PdfStyles.primaryColor,
                const PdfColor.fromInt(0xFF0d47a1), // Azul mais escuro
              ],
              begin: pw.Alignment.centerLeft,
              end: pw.Alignment.centerRight,
            ),
          ),
          padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Logo + Form Title
              pw.Expanded(
                flex: 3,
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (logoImage != null) ...[
                      pw.Container(
                        width: 40,
                        height: 40,
                        decoration: pw.BoxDecoration(
                          color: PdfColors.white,
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Image(logoImage!, fit: pw.BoxFit.contain),
                      ),
                      pw.SizedBox(width: 12),
                    ],
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            form.title.toUpperCase(),
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: 14.0,
                              color: PdfColors.white,
                              letterSpacing: 1.0,
                            ),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            company.name ?? '',
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: 9.0,
                              color: PdfColors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // OS Number and Form Info
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    '${config.serviceOrder.toUpperCase()} Nº',
                    style: pw.TextStyle(
                      font: baseFont,
                      fontSize: 7.0,
                      color: PdfColors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  pw.Text(
                    order.number?.toString() ?? "NOVA",
                    style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 20.0,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    DateFormat('dd/MM/yyyy').format(formDate),
                    style: pw.TextStyle(
                      font: baseFont,
                      fontSize: 8.0,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: pw.BorderRadius.circular(2),
                    ),
                    child: pw.Text(
                      statusText.toUpperCase(),
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 6.5,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 12),
      ],
    );
  }

  PdfColor _getFormStatusColor(FormStatus status) {
    switch (status) {
      case FormStatus.completed:
        return PdfStyles.successColor;
      case FormStatus.inProgress:
        return PdfStyles.progressColor;
      case FormStatus.pending:
        return PdfStyles.warningColor;
    }
  }

  String _getFormStatusText(FormStatus status) {
    switch (status) {
      case FormStatus.completed:
        return 'Concluido';
      case FormStatus.inProgress:
        return 'Em Andamento';
      case FormStatus.pending:
        return 'Pendente';
    }
  }

  // ============================================
  // CARDS DE ITENS
  // ============================================

  /// Constroi um card para um item do formulario
  pw.Widget buildFormItemCard({
    required FormItemDefinition item,
    required FormResponse? response,
    required List<pw.MemoryImage> photos,
  }) {
    final hasPhotos = photos.isNotEmpty;
    final responseContent = _buildResponseContent(item, response);
    final hasContent = responseContent is! pw.SizedBox;

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 6),
      decoration: PdfStyles.cardDecoration(backgroundColor: PdfColors.white),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header do card com label e indicador
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: pw.BoxDecoration(
              color: PdfStyles.backgroundLight,
              borderRadius: hasContent || hasPhotos
                  ? const pw.BorderRadius.only(
                      topLeft: pw.Radius.circular(4),
                      topRight: pw.Radius.circular(4),
                    )
                  : pw.BorderRadius.circular(4),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    item.label,
                    style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 9,
                      color: PdfColors.grey800,
                    ),
                  ),
                ),
                if (item.type == FormItemType.boolean && response != null)
                  _buildBooleanIndicator(response.value == true),
              ],
            ),
          ),

          // Conteudo do card baseado no tipo (somente se houver conteudo ou fotos)
          if (hasContent || hasPhotos)
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Valor da resposta formatado
                  if (hasContent) responseContent,

                  // Fotos do item
                  if (hasPhotos) ...[
                    if (hasContent) pw.SizedBox(height: 8),
                    pw.Container(
                      padding: const pw.EdgeInsets.only(top: 6),
                      decoration: hasContent
                          ? const pw.BoxDecoration(
                              border: pw.Border(
                                top: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
                              ),
                            )
                          : null,
                      child: buildItemPhotosGrid(photos),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Constroi o conteudo da resposta baseado no tipo do item
  pw.Widget _buildResponseContent(FormItemDefinition item, FormResponse? response) {
    if (response == null) {
      return pw.Text(
        'Nao respondido',
        style: pw.TextStyle(
          font: baseFont,
          fontSize: 9,
          color: PdfStyles.textMuted,
          fontStyle: pw.FontStyle.italic,
        ),
      );
    }

    switch (item.type) {
      case FormItemType.boolean:
        // Indicador ja esta no header
        return pw.SizedBox();

      case FormItemType.checklist:
        return _buildChecklistItems(
          response.value as List<dynamic>? ?? [],
          item.options ?? [],
        );

      case FormItemType.select:
        return pw.Text(
          response.value?.toString() ?? 'Nao selecionado',
          style: pw.TextStyle(
            font: baseFont,
            fontSize: 10,
            color: PdfColors.grey800,
          ),
        );

      case FormItemType.photoOnly:
        // Apenas fotos, sem texto de resposta
        return pw.SizedBox();

      case FormItemType.text:
      case FormItemType.number:
        final value = response.value?.toString() ?? '';
        if (value.isEmpty) {
          return pw.Text(
            'Nao informado',
            style: pw.TextStyle(
              font: baseFont,
              fontSize: 9,
              color: PdfStyles.textMuted,
              fontStyle: pw.FontStyle.italic,
            ),
          );
        }
        return pw.Text(
          value,
          style: pw.TextStyle(
            font: baseFont,
            fontSize: 10,
            color: PdfColors.grey800,
          ),
        );
    }
  }

  /// Constroi o indicador visual SIM/NAO para itens booleanos
  pw.Widget _buildBooleanIndicator(bool value) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        // SIM
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: pw.BoxDecoration(
            color: value ? PdfStyles.successColor : PdfColors.white,
            borderRadius: const pw.BorderRadius.only(
              topLeft: pw.Radius.circular(4),
              bottomLeft: pw.Radius.circular(4),
            ),
            border: pw.Border.all(
              color: value ? PdfStyles.successColor : PdfColors.grey400,
              width: 1,
            ),
          ),
          child: pw.Row(
            children: [
              if (value)
                pw.Text(
                  'X ',
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 8,
                    color: PdfColors.white,
                  ),
                ),
              pw.Text(
                'SIM',
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 8,
                  color: value ? PdfColors.white : PdfColors.grey600,
                ),
              ),
            ],
          ),
        ),
        // NAO
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: pw.BoxDecoration(
            color: !value ? PdfStyles.dangerColor : PdfColors.white,
            borderRadius: const pw.BorderRadius.only(
              topRight: pw.Radius.circular(4),
              bottomRight: pw.Radius.circular(4),
            ),
            border: pw.Border.all(
              color: !value ? PdfStyles.dangerColor : PdfColors.grey400,
              width: 1,
            ),
          ),
          child: pw.Row(
            children: [
              if (!value)
                pw.Text(
                  'X ',
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 8,
                    color: PdfColors.white,
                  ),
                ),
              pw.Text(
                'NAO',
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 8,
                  color: !value ? PdfColors.white : PdfColors.grey600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Constroi a lista de itens do checklist
  pw.Widget _buildChecklistItems(List<dynamic> selectedItems, List<String> allOptions) {
    if (allOptions.isEmpty) {
      return pw.SizedBox();
    }

    final selectedSet = selectedItems.map((e) => e.toString()).toSet();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: allOptions.map((option) {
        final isSelected = selectedSet.contains(option);
        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 14,
                height: 14,
                margin: const pw.EdgeInsets.only(right: 8, top: 1),
                decoration: pw.BoxDecoration(
                  color: isSelected ? PdfStyles.successColor : PdfColors.white,
                  border: pw.Border.all(
                    color: isSelected ? PdfStyles.successColor : PdfColors.grey400,
                    width: 1,
                  ),
                  borderRadius: pw.BorderRadius.circular(2),
                ),
                child: isSelected
                    ? pw.Center(
                        child: pw.Text(
                          'X',
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 8,
                            color: PdfColors.white,
                          ),
                        ),
                      )
                    : null,
              ),
              pw.Expanded(
                child: pw.Text(
                  option,
                  style: pw.TextStyle(
                    font: isSelected ? boldFont : baseFont,
                    fontSize: 9,
                    color: isSelected ? PdfColors.grey800 : PdfColors.grey600,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Constroi o grid de fotos de um item
  pw.Widget buildItemPhotosGrid(List<pw.MemoryImage> photos) {
    if (photos.isEmpty) {
      return pw.SizedBox();
    }

    // Limita a 4 fotos por linha, max 2 linhas = 8 fotos
    final photosToShow = photos.take(8).toList();

    return pw.Wrap(
      spacing: 5,
      runSpacing: 5,
      children: photosToShow.map((image) {
        return pw.Container(
          width: 75,
          height: 75,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
            borderRadius: pw.BorderRadius.circular(3),
          ),
          child: pw.ClipRRect(
            verticalRadius: 3,
            horizontalRadius: 3,
            child: pw.Image(image, fit: pw.BoxFit.contain),
          ),
        );
      }).toList(),
    );
  }

  // ============================================
  // BUILDER PRINCIPAL
  // ============================================

  /// Constroi todo o conteudo de uma pagina de formulario
  List<pw.Widget> buildFormContent({
    required Company company,
    required Order order,
    required OrderForm form,
    required Map<String, List<pw.MemoryImage>> itemPhotosMap,
  }) {
    final widgets = <pw.Widget>[];

    // Header do formulario
    widgets.add(buildFormHeader(
      company: company,
      order: order,
      form: form,
    ));

    // Cards de cada item
    for (final item in form.items) {
      final response = form.getResponse(item.id);
      final photos = itemPhotosMap[item.id] ?? [];

      widgets.add(buildFormItemCard(
        item: item,
        response: response,
        photos: photos,
      ));
    }

    return widgets;
  }

  /// Constroi o footer para paginas de formulario com informacoes do PraticOS
  pw.Widget buildFormFooter(
    pw.Context context,
    OrderForm form,
    pw.MemoryImage? praticosLogo,
    pw.MemoryImage? appStoreBadge,
    pw.MemoryImage? playStoreBadge,
  ) {
    const appStoreUrl = 'https://apps.apple.com/br/app/praticos/id1534604555';
    const playStoreUrl = 'https://play.google.com/store/apps/details?id=br.com.rafsoft.praticos';
    const siteUrl = 'https://praticos.web.app';

    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 20),
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 20),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // Nome do formulario e paginacao (em coluna)
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Formulario: ${form.title}',
                style: pw.TextStyle(
                  font: baseFont,
                  fontSize: 7,
                  color: PdfStyles.textSecondary,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Pagina ${context.pageNumber} de ${context.pagesCount}',
                style: pw.TextStyle(
                  font: baseFont,
                  fontSize: 7,
                  color: PdfStyles.textSecondary,
                ),
              ),
            ],
          ),

          // Logo + Texto PraticOS + Site com link
          pw.Row(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              if (praticosLogo != null) ...[
                pw.Container(
                  width: 16,
                  height: 16,
                  child: pw.Image(praticosLogo, fit: pw.BoxFit.contain),
                ),
                pw.SizedBox(width: 6),
              ],
              pw.Text(
                'Gerado por PraticOS | ',
                style: pw.TextStyle(
                  font: baseFont,
                  fontSize: 7,
                  color: PdfStyles.textSecondary,
                ),
              ),
              pw.UrlLink(
                destination: siteUrl,
                child: pw.Text(
                  'https://praticos.web.app',
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 7,
                    color: PdfStyles.primaryColor,
                    decoration: pw.TextDecoration.underline,
                  ),
                ),
              ),
              pw.SizedBox(width: 10),

              // Badges das lojas
              pw.UrlLink(
                destination: appStoreUrl,
                child: appStoreBadge != null
                    ? pw.Container(
                        height: 18,
                        child: pw.Image(appStoreBadge, fit: pw.BoxFit.contain),
                      )
                    : pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.black,
                          borderRadius: pw.BorderRadius.circular(3),
                        ),
                        child: pw.Text(
                          'App Store',
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 5,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
              ),
              pw.SizedBox(width: 4),
              pw.UrlLink(
                destination: playStoreUrl,
                child: playStoreBadge != null
                    ? pw.Container(
                        height: 18,
                        child: pw.Image(playStoreBadge, fit: pw.BoxFit.contain),
                      )
                    : pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.black,
                          borderRadius: pw.BorderRadius.circular(3),
                        ),
                        child: pw.Text(
                          'Google Play',
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 5,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
