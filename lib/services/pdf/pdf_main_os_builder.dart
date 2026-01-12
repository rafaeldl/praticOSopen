import 'package:pdf/pdf.dart';
import 'package:praticos/services/format_service.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:praticos/models/company.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/services/pdf/pdf_styles.dart';

/// Builder para a pagina principal da OS no PDF
class PdfMainOsBuilder {
  final pw.Font baseFont;
  final pw.Font boldFont;
  final pw.MemoryImage? logoImage;
  final SegmentConfigProvider config;

  PdfMainOsBuilder({
    required this.baseFont,
    required this.boldFont,
    this.logoImage,
    required this.config,
  });

  // ============================================
  // FORMATACAO
  // ============================================

  String _formatCurrency(double? value) {
    return FormatService().formatCurrency(value ?? 0.0);
  }

  // ============================================
  // HEADER
  // ============================================

  /// Constroi o header com fundo azul completo
  pw.Widget buildHeader(Company company, Order order) {
    final statusText = config.getStatus(order.status);

    return pw.Column(
      children: [
        // Header com fundo azul completo
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
              // Logo + Company Info
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
                            config.serviceOrder.toUpperCase(),
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: 16.0,
                              color: PdfColors.white,
                              letterSpacing: 1.5,
                            ),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            company.name ?? '',
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: 10.0,
                              color: PdfColors.white,
                            ),
                          ),
                          pw.SizedBox(height: 3),
                          // Contatos da empresa
                          if (company.phone != null && company.phone!.isNotEmpty)
                            pw.Text(
                              company.phone!,
                              style: pw.TextStyle(
                                font: baseFont,
                                fontSize: 8.0,
                                color: PdfColors.white,
                              ),
                            ),
                          if (company.email != null && company.email!.isNotEmpty)
                            pw.Text(
                              company.email!,
                              style: pw.TextStyle(
                                font: baseFont,
                                fontSize: 8.0,
                                color: PdfColors.white,
                              ),
                            ),
                          if (company.site != null && company.site!.isNotEmpty)
                            pw.Text(
                              company.site!,
                              style: pw.TextStyle(
                                font: baseFont,
                                fontSize: 8.0,
                                color: PdfColors.white,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // OS Number and Info
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
                  if (order.createdAt != null)
                    pw.Text(
                      FormatService().formatDate(order.createdAt!),
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
                        color: PdfStyles.primaryDark,
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

  // ============================================
  // FOOTER
  // ============================================

  /// Constroi o footer com informacoes do PraticOS
  pw.Widget buildFooter(
    pw.Context context,
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
          // Paginacao
          pw.Text(
            'Pagina ${context.pageNumber} de ${context.pagesCount}',
            style: pw.TextStyle(
              font: baseFont,
              fontSize: 7,
              color: PdfStyles.textSecondary,
            ),
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
            ],
          ),

          // Badges das lojas
          pw.Row(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              // App Store
              pw.UrlLink(
                destination: appStoreUrl,
                child: appStoreBadge != null
                    ? pw.Container(
                        height: 16,
                        child: pw.Image(appStoreBadge, fit: pw.BoxFit.contain),
                      )
                    : pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.black,
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Row(
                          mainAxisSize: pw.MainAxisSize.min,
                          children: [
                            pw.Text(
                              '',
                              style: pw.TextStyle(
                                font: baseFont,
                                fontSize: 10,
                                color: PdfColors.white,
                              ),
                            ),
                            pw.SizedBox(width: 3),
                            pw.Text(
                              'App Store',
                              style: pw.TextStyle(
                                font: boldFont,
                                fontSize: 6,
                                color: PdfColors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              pw.SizedBox(width: 6),
              // Play Store
              pw.UrlLink(
                destination: playStoreUrl,
                child: playStoreBadge != null
                    ? pw.Container(
                        height: 20,
                        child: pw.Image(playStoreBadge, fit: pw.BoxFit.contain),
                      )
                    : pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.black,
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Row(
                          mainAxisSize: pw.MainAxisSize.min,
                          children: [
                            pw.Text(
                              '▶',
                              style: pw.TextStyle(
                                font: baseFont,
                                fontSize: 8,
                                color: PdfColors.green400,
                              ),
                            ),
                            pw.SizedBox(width: 3),
                            pw.Text(
                              'Google Play',
                              style: pw.TextStyle(
                                font: boldFont,
                                fontSize: 6,
                                color: PdfColors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================
  // CARDS DE CLIENTE E EQUIPAMENTO
  // ============================================

  /// Constroi o card de cliente
  pw.Widget buildCustomerCard(Customer? customer) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: PdfStyles.cardDecoration(),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              config.customer.toUpperCase(),
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 8,
                color: PdfStyles.primaryDark,
                letterSpacing: 0.5,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              customer?.name ?? 'Nao informado',
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 12,
                color: PdfColors.grey800,
              ),
            ),
            if (customer?.phone != null && customer!.phone!.isNotEmpty) ...[
              pw.SizedBox(height: 4),
              pw.Text(
                customer.phone!,
                style: pw.TextStyle(
                  font: baseFont,
                  fontSize: 9,
                  color: PdfStyles.textSecondary,
                ),
              ),
            ],
            if (customer?.email != null && customer!.email!.isNotEmpty) ...[
              pw.SizedBox(height: 2),
              pw.Text(
                customer.email!,
                style: pw.TextStyle(
                  font: baseFont,
                  fontSize: 9,
                  color: PdfStyles.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Constroi o card de equipamento/dispositivo
  pw.Widget buildDeviceCard(Order order) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: PdfStyles.cardDecoration(),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              config.device.toUpperCase(),
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 8,
                color: PdfStyles.primaryDark,
                letterSpacing: 0.5,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              order.device?.name ?? 'Nao informado',
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 12,
                color: PdfColors.grey800,
              ),
            ),
            if (order.device?.serial != null && order.device!.serial!.isNotEmpty) ...[
              pw.SizedBox(height: 4),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey300,
                  borderRadius: pw.BorderRadius.circular(3),
                ),
                child: pw.Text(
                  order.device!.serial!,
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 10,
                    color: PdfColors.grey800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================
  // TABELAS
  // ============================================

  pw.Widget _buildTableHeader(String text, {bool alignRight = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: pw.Text(
        text,
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          font: boldFont,
          fontSize: 8.0,
          color: PdfStyles.textSecondary,
        ),
      ),
    );
  }

  pw.Widget _buildTableCell(String text, {bool alignRight = false, bool alignCenter = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: pw.Text(
        text,
        textAlign: alignRight ? pw.TextAlign.right : (alignCenter ? pw.TextAlign.center : pw.TextAlign.left),
        style: pw.TextStyle(
          font: baseFont,
          fontSize: 9.0,
          color: PdfColors.black,
        ),
      ),
    );
  }

  /// Constroi a tabela de servicos
  pw.Widget buildServicesTable(Order order) {
    if (order.services == null || order.services!.isEmpty) {
      return pw.SizedBox();
    }

    return pw.Table(
      border: pw.TableBorder(
        bottom: const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        horizontalInside: const pw.BorderSide(color: PdfColors.grey200, width: 0.5),
      ),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FixedColumnWidth(80),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfStyles.backgroundLight),
          children: [
            _buildTableHeader('DESCRICAO DO SERVICO'),
            _buildTableHeader('VALOR', alignRight: true),
          ],
        ),
        ...order.services!.map((s) {
          final description = s.description != null && s.description!.isNotEmpty
              ? '${s.service?.name ?? ''} - ${s.description}'
              : s.service?.name ?? '';
          return pw.TableRow(
            children: [
              _buildTableCell(description),
              _buildTableCell(_formatCurrency(s.value), alignRight: true),
            ],
          );
        }),
      ],
    );
  }

  /// Constroi a tabela de produtos
  pw.Widget buildProductsTable(Order order) {
    if (order.products == null || order.products!.isEmpty) {
      return pw.SizedBox();
    }

    return pw.Table(
      border: pw.TableBorder(
        bottom: const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        horizontalInside: const pw.BorderSide(color: PdfColors.grey200, width: 0.5),
      ),
      columnWidths: {
        0: const pw.FixedColumnWidth(40),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FixedColumnWidth(70),
        3: const pw.FixedColumnWidth(70),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfStyles.backgroundLight),
          children: [
            _buildTableHeader('QTD'),
            _buildTableHeader('DESCRICAO'),
            _buildTableHeader('UNIT.', alignRight: true),
            _buildTableHeader('TOTAL', alignRight: true),
          ],
        ),
        ...order.products!.map((p) {
          final description = p.description != null && p.description!.isNotEmpty
              ? '${p.product?.name ?? ''} - ${p.description}'
              : p.product?.name ?? '';
          return pw.TableRow(
            children: [
              _buildTableCell(p.quantity?.toString() ?? '1', alignCenter: true),
              _buildTableCell(description),
              _buildTableCell(_formatCurrency(p.value), alignRight: true),
              _buildTableCell(_formatCurrency(p.total), alignRight: true),
            ],
          );
        }),
      ],
    );
  }

  // ============================================
  // CABECALHOS DE SECAO
  // ============================================

  /// Constroi o cabecalho de uma secao
  pw.Widget buildSectionHeader(String title, String subtitle) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            font: boldFont,
            color: PdfStyles.primaryDark,
            fontSize: 10,
            letterSpacing: 0.5,
          ),
        ),
        pw.Text(
          subtitle,
          style: pw.TextStyle(
            font: baseFont,
            color: PdfColors.grey500,
            fontSize: 8,
          ),
        ),
      ],
    );
  }

  // ============================================
  // RESUMO E TOTAIS
  // ============================================

  pw.Widget _buildSummaryRow(String label, double value, {bool isBold = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              font: isBold ? boldFont : baseFont,
              fontSize: 10,
            ),
          ),
          pw.Text(
            _formatCurrency(value),
            style: pw.TextStyle(
              font: isBold ? boldFont : baseFont,
              fontSize: 10,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Constroi a secao de resumo com totais
  pw.Widget buildTotalsSummary(Order order) {
    final totalServices = order.services?.fold(0.0, (sum, s) => sum + (s.value ?? 0)) ?? 0.0;
    final totalProducts = order.products?.fold(0.0, (sum, p) => sum + (p.total ?? 0)) ?? 0.0;
    final subtotal = totalServices + totalProducts;
    final discount = order.discount ?? 0.0;
    final total = order.total ?? 0.0;
    final paidAmount = order.paidAmount ?? 0.0;
    final remaining = total - paidAmount;
    final isPaid = order.payment == 'paid';
    final hasPartialPayment = paidAmount > 0 && !isPaid;

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Container(
          width: 220,
          decoration: pw.BoxDecoration(
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: PdfStyles.borderColor, width: 0.5),
          ),
          child: pw.Column(
            children: [
              // Summary rows
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                child: pw.Column(
                  children: [
                    if (totalServices > 0) _buildSummaryRow('Servicos', totalServices),
                    if (totalProducts > 0) _buildSummaryRow('Produtos', totalProducts),
                    pw.Divider(color: PdfStyles.borderColor, height: 16),
                    _buildSummaryRow('Subtotal', subtotal),
                    if (discount > 0) _buildSummaryRow('Desconto', -discount, color: PdfColors.red600),
                    _buildSummaryRow('Total', total, isBold: true),
                    // Mostrar pagamentos parciais
                    if (hasPartialPayment) ...[
                      pw.SizedBox(height: 4),
                      pw.Divider(color: PdfStyles.borderColor, height: 8),
                      pw.SizedBox(height: 4),
                      _buildSummaryRow('Ja pago', paidAmount, color: PdfColors.green700),
                    ],
                  ],
                ),
              ),
              // Footer com status de pagamento
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                decoration: pw.BoxDecoration(
                  color: isPaid
                      ? PdfColors.green700
                      : (hasPartialPayment ? PdfColors.orange700 : PdfStyles.primaryDark),
                  borderRadius: const pw.BorderRadius.only(
                    bottomLeft: pw.Radius.circular(5),
                    bottomRight: pw.Radius.circular(5),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      isPaid
                          ? 'TOTAL PAGO'
                          : (hasPartialPayment ? 'SALDO RESTANTE' : 'TOTAL A PAGAR'),
                      style: pw.TextStyle(
                        font: boldFont,
                        color: PdfColors.white,
                        fontSize: 9,
                      ),
                    ),
                    pw.Text(
                      _formatCurrency(isPaid ? total : remaining),
                      style: pw.TextStyle(
                        font: boldFont,
                        color: PdfColors.white,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================
  // ASSINATURA
  // ============================================

  /// Constroi a linha de assinatura
  pw.Widget buildSignatureLine(Customer? customer) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.start,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: 250,
              child: pw.Divider(color: PdfColors.grey600, thickness: 0.5),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              customer?.name ?? config.customer,
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 10,
                color: PdfColors.grey800,
              ),
            ),
            pw.Text(
              'Assinatura do ${config.customer}',
              style: pw.TextStyle(
                font: baseFont,
                fontSize: 8,
                color: PdfColors.grey500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================
  // FOTOS
  // ============================================

  /// Constroi o grid de fotos da OS
  pw.Widget buildPhotosGrid(List<pw.MemoryImage>? photos, int totalCount) {
    if (photos == null || photos.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: PdfStyles.cardDecoration(),
        child: pw.Row(
          children: [
            pw.Icon(
              const pw.IconData(0xe412),
              size: 16,
              color: PdfStyles.textSecondary,
            ),
            pw.SizedBox(width: 8),
            pw.Text(
              'Fotos disponiveis no sistema digital',
              style: pw.TextStyle(
                font: baseFont,
                fontSize: 10.0,
                color: PdfStyles.textSecondary,
                fontStyle: pw.FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Fotos Anexadas ($totalCount)',
          style: pw.TextStyle(
            font: boldFont,
            fontSize: 14.0,
            color: PdfStyles.primaryColor,
          ),
        ),
        pw.SizedBox(height: 12),
        pw.GridView(
          crossAxisCount: 3,
          childAspectRatio: 1,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          children: photos.map((image) {
            return pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300, width: 1),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.ClipRRect(
                verticalRadius: 4,
                horizontalRadius: 4,
                child: pw.Image(image, fit: pw.BoxFit.contain),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ============================================
  // BUILDER PRINCIPAL
  // ============================================

  /// Constroi todo o conteudo da pagina principal da OS
  List<pw.Widget> buildContent({
    required Order order,
    required Customer? customer,
    required Company company,
    List<pw.MemoryImage>? osPhotos,
  }) {
    return [
      // Client & Device Cards
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          buildCustomerCard(customer),
          pw.SizedBox(width: 12),
          buildDeviceCard(order),
        ],
      ),

      pw.SizedBox(height: 20),

      // Services Section
      if (order.services != null && order.services!.isNotEmpty) ...[
        buildSectionHeader('SERVICOS', '${order.services!.length} itens'),
        pw.SizedBox(height: 8),
        buildServicesTable(order),
        pw.SizedBox(height: 16),
      ],

      // Products Section
      if (order.products != null && order.products!.isNotEmpty) ...[
        buildSectionHeader('PECAS E PRODUTOS', '${order.products!.length} itens'),
        pw.SizedBox(height: 8),
        buildProductsTable(order),
        pw.SizedBox(height: 16),
      ],

      // Summary Section
      buildTotalsSummary(order),

      pw.SizedBox(height: 30),

      // Signature Section
      buildSignatureLine(customer),

      // Photos Section
      if (order.photos != null && order.photos!.isNotEmpty) ...[
        pw.SizedBox(height: 20),
        pw.Divider(color: PdfStyles.borderColor),
        pw.SizedBox(height: 12),
        buildSectionHeader('REGISTRO FOTOGRAFICO', '${order.photos!.length} fotos'),
        pw.SizedBox(height: 10),
        buildPhotosGrid(osPhotos, order.photos!.length),
      ],
    ];
  }
}
