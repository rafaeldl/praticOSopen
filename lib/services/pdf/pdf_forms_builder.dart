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

  /// Constroi o header da pagina de formulario
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
        pw.Row(
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
                      child: pw.Image(logoImage!, fit: pw.BoxFit.contain),
                    ),
                    pw.SizedBox(width: 12),
                  ],
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          form.title,
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 14.0,
                            color: PdfColors.grey800,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          company.name ?? '',
                          style: pw.TextStyle(
                            font: baseFont,
                            fontSize: 9.0,
                            color: PdfStyles.textSecondary,
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
                // OS Badge (smaller)
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: PdfStyles.primaryColor,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(
                    '${config.serviceOrder.toUpperCase()} #${order.number?.toString() ?? "NOVA"}',
                    style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 9.0,
                      color: PdfColors.white,
                    ),
                  ),
                ),
                pw.SizedBox(height: 6),
                // Date
                pw.Text(
                  'Data: ${DateFormat('dd/MM/yyyy').format(formDate)}',
                  style: pw.TextStyle(
                    font: baseFont,
                    fontSize: 9.0,
                    color: PdfStyles.textSecondary,
                  ),
                ),
                pw.SizedBox(height: 4),
                // Status Badge
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: PdfStyles.statusBadgeDecoration(statusColor),
                  child: pw.Text(
                    statusText.toUpperCase(),
                    style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 8.0,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Container(
          height: 1,
          color: PdfStyles.borderColor,
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
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      decoration: PdfStyles.cardDecoration(backgroundColor: PdfColors.white),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header do card com label e indicador
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfStyles.backgroundLight,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(6),
                topRight: pw.Radius.circular(6),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    item.label,
                    style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 10,
                      color: PdfColors.grey800,
                    ),
                  ),
                ),
                if (item.type == FormItemType.boolean && response != null)
                  _buildBooleanIndicator(response.value == true),
              ],
            ),
          ),

          // Conteudo do card baseado no tipo
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Valor da resposta formatado
                _buildResponseContent(item, response),

                // Fotos do item
                if (photos.isNotEmpty) ...[
                  pw.SizedBox(height: 10),
                  pw.Container(
                    padding: const pw.EdgeInsets.only(top: 8),
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        top: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
                      ),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'FOTOS DO ITEM:',
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 8,
                            color: PdfStyles.textSecondary,
                          ),
                        ),
                        pw.SizedBox(height: 6),
                        buildItemPhotosGrid(photos),
                      ],
                    ),
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
      spacing: 6,
      runSpacing: 6,
      children: photosToShow.map((image) {
        return pw.Container(
          width: 80,
          height: 80,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300, width: 1),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.ClipRRect(
            verticalRadius: 4,
            horizontalRadius: 4,
            child: pw.Image(image, fit: pw.BoxFit.cover),
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

    // Informacao de progresso
    final answeredCount = form.responses.length;
    final totalCount = form.items.length;
    widgets.add(
      pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 16),
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfStyles.backgroundLighter,
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Itens do Formulario',
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 10,
                color: PdfStyles.primaryDark,
              ),
            ),
            pw.Text(
              '$answeredCount de $totalCount respondidos',
              style: pw.TextStyle(
                font: baseFont,
                fontSize: 9,
                color: PdfStyles.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );

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

  /// Constroi o footer para paginas de formulario
  pw.Widget buildFormFooter(pw.Context context, OrderForm form) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 20),
      padding: const pw.EdgeInsets.only(top: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Formulario: ${form.title}',
            style: pw.TextStyle(
              font: baseFont,
              fontSize: 8,
              color: PdfStyles.textSecondary,
            ),
          ),
          pw.Text(
            'Pagina ${context.pageNumber} de ${context.pagesCount}',
            style: pw.TextStyle(
              font: baseFont,
              fontSize: 8,
              color: PdfStyles.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
