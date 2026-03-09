import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:praticos/models/device.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/services/pdf/pdf_localizations.dart';
import 'package:praticos/services/pdf/pdf_styles.dart';

/// Builder para a pagina principal da OS no PDF (layout compacto A4)
class PdfMainOsBuilder {
  final pw.Font baseFont;
  final pw.Font boldFont;
  final pw.MemoryImage? logoImage;
  final SegmentConfigProvider config;
  final PdfLocalizations localizations;

  PdfMainOsBuilder({
    required this.baseFont,
    required this.boldFont,
    this.logoImage,
    required this.config,
    required this.localizations,
  });

  // ============================================
  // FORMATACAO
  // ============================================

  String _formatCurrency(double? value) {
    return FormatService().formatCurrency(value ?? 0.0);
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '--';
    return FormatService().formatDate(date);
  }

  // ============================================
  // HEADER (gradient teal)
  // ============================================

  pw.Widget buildHeader(Company company, Order order) {
    return pw.Container(
      width: double.infinity,
      decoration: const pw.BoxDecoration(
        gradient: pw.LinearGradient(
          colors: [PdfStyles.headerGradientStart, PdfStyles.headerGradientEnd],
          begin: pw.Alignment.centerLeft,
          end: pw.Alignment.centerRight,
        ),
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Logo + Company Info
          pw.Expanded(
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (logoImage != null) ...[
                  pw.Container(
                    width: 40,
                    height: 40,
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: pw.BorderRadius.circular(8),
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
                        company.name ?? '',
                        style: pw.TextStyle(
                          font: boldFont,
                          fontSize: 10.0,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      if (company.address != null && company.address!.isNotEmpty)
                        pw.Text(
                          company.address!,
                          style: pw.TextStyle(
                            font: baseFont,
                            fontSize: 8.0,
                            color: const PdfColor.fromInt(0xBBFFFFFF),
                          ),
                        ),
                      if (company.phone != null && company.phone!.isNotEmpty)
                        pw.Text(
                          company.phone!,
                          style: pw.TextStyle(
                            font: baseFont,
                            fontSize: 8.0,
                            color: const PdfColor.fromInt(0xBBFFFFFF),
                          ),
                        ),
                      if (company.email != null && company.email!.isNotEmpty)
                        pw.Text(
                          company.email!,
                          style: pw.TextStyle(
                            font: baseFont,
                            fontSize: 8.0,
                            color: const PdfColor.fromInt(0xBBFFFFFF),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // OS Number
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                config.serviceOrder.toUpperCase(),
                style: pw.TextStyle(
                  font: baseFont,
                  fontSize: 9.0,
                  color: const PdfColor.fromInt(0x99FFFFFF),
                ),
              ),
              pw.Text(
                '#${order.number?.toString() ?? localizations.newOrder}',
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 22.0,
                  color: PdfColors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================
  // STATUS BAR
  // ============================================

  pw.Widget buildStatusBar(Order order) {
    final statusText = config.getStatus(order.status);
    final statusColor = PdfStyles.getStatusColor(order.status);
    final techName = order.assignedTo?.name;

    return pw.Container(
      width: double.infinity,
      color: PdfStyles.statusBarBg,
      padding: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          // Left: status dot + status text + technician
          pw.Row(
            children: [
              pw.Container(
                width: 6,
                height: 6,
                decoration: pw.BoxDecoration(
                  color: statusColor,
                  shape: pw.BoxShape.circle,
                ),
              ),
              pw.SizedBox(width: 4),
              pw.Text(
                statusText.toUpperCase(),
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 8,
                  color: statusColor,
                ),
              ),
              if (techName != null && techName.isNotEmpty) ...[
                pw.SizedBox(width: 6),
                pw.Text(
                  ' · ',
                  style: pw.TextStyle(
                    font: baseFont,
                    fontSize: 8,
                    color: PdfStyles.textMuted,
                  ),
                ),
                pw.Text(
                  '${localizations.technician}: $techName',
                  style: pw.TextStyle(
                    font: baseFont,
                    fontSize: 8,
                    color: PdfStyles.textSecondary,
                  ),
                ),
              ],
            ],
          ),

          // Right: dates
          pw.Row(
            children: [
              pw.Text(
                '${localizations.createdDate}: ${_formatDate(order.createdAt)}',
                style: pw.TextStyle(font: baseFont, fontSize: 7.5, color: PdfStyles.textMuted),
              ),
              if (order.status == 'done' && order.updatedAt != null) ...[
                pw.Text(
                  '  ·  ${localizations.completedDate}: ${_formatDate(order.updatedAt)}',
                  style: pw.TextStyle(font: baseFont, fontSize: 7.5, color: PdfStyles.textMuted),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ============================================
  // SECTION HEADER
  // ============================================

  pw.Widget _buildSectionHeader(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Text(
        title.toUpperCase(),
        style: pw.TextStyle(
          font: boldFont,
          fontSize: 7.5,
          color: PdfStyles.sectionIconColor,
          letterSpacing: 1,
        ),
      ),
    );
  }

  // ============================================
  // CLIENT + FINANCIAL (side by side)
  // ============================================

  pw.Widget buildClientAndFinancial(Customer? customer, Order order) {
    final customerParts = <String>[];
    if (customer?.phone != null && customer!.phone!.isNotEmpty) {
      customerParts.add(customer.phone!);
    }
    if (customer?.email != null && customer!.email!.isNotEmpty) {
      customerParts.add(customer.email!);
    }

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Client card (expanded)
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(config.customer),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: pw.BoxDecoration(
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: PdfStyles.borderColor, width: 0.5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      customer?.name ?? localizations.notInformed,
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 10,
                        color: PdfStyles.textPrimary,
                      ),
                    ),
                    if (customerParts.isNotEmpty) ...[
                      pw.SizedBox(height: 3),
                      pw.Text(
                        customerParts.join(' · '),
                        style: pw.TextStyle(
                          font: baseFont,
                          fontSize: 8,
                          color: PdfStyles.textSecondary,
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        pw.SizedBox(width: 12),

        // Financial summary (fixed width)
        _buildFinancialCard(order),
      ],
    );
  }

  // ============================================
  // FINANCIAL CARD
  // ============================================

  pw.Widget _buildFinancialSummaryRow(String label, String value, {bool isBold = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              font: isBold ? boldFont : baseFont,
              fontSize: 8.5,
              color: color ?? PdfStyles.textSecondary,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              font: isBold ? boldFont : baseFont,
              fontSize: isBold ? 12 : 8.5,
              color: color ?? PdfStyles.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFinancialCard(Order order) {
    final totalServices = order.services?.fold(0.0, (sum, s) => sum + (s.value ?? 0)) ?? 0.0;
    final totalProducts = order.products?.fold(0.0, (sum, p) => sum + (p.total ?? 0)) ?? 0.0;
    final discount = order.discount ?? 0.0;
    final total = order.total ?? 0.0;
    final paidAmount = order.paidAmount ?? 0.0;
    final isPaid = order.payment == 'paid';

    return pw.Container(
      width: 260,
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: PdfStyles.borderColor, width: 0.5),
      ),
      child: pw.Column(
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: pw.Column(
              children: [
                if (totalServices > 0)
                  _buildFinancialSummaryRow(localizations.services, _formatCurrency(totalServices)),
                if (totalProducts > 0)
                  _buildFinancialSummaryRow(localizations.products, _formatCurrency(totalProducts)),
                if (discount > 0)
                  _buildFinancialSummaryRow(localizations.discount, '- ${_formatCurrency(discount)}', color: PdfColors.red600),
                pw.Divider(color: PdfStyles.borderColor, height: 12),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        localizations.total.toUpperCase(),
                        style: pw.TextStyle(
                          font: boldFont,
                          fontSize: 10,
                          color: PdfStyles.sectionIconColor,
                        ),
                      ),
                      pw.Text(
                        _formatCurrency(total),
                        style: pw.TextStyle(
                          font: boldFont,
                          fontSize: 12,
                          color: PdfStyles.sectionIconColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isPaid || paidAmount > 0) ...[
                  pw.SizedBox(height: 4),
                  _buildFinancialSummaryRow(
                    localizations.paid,
                    _formatCurrency(paidAmount > 0 ? paidAmount : total),
                    color: const PdfColor.fromInt(0xFF16A34A),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // EQUIPMENT BLOCKS (multi-device)
  // ============================================

  pw.Widget _buildCompactTableHeader(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          font: boldFont,
          fontSize: 7.5,
          color: PdfStyles.sectionIconColor,
        ),
      ),
    );
  }

  pw.Widget _buildCompactTableCell(String text, {
    pw.TextAlign align = pw.TextAlign.left,
    bool isBold = false,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          font: isBold ? boldFont : baseFont,
          fontSize: 8.5,
          color: color ?? PdfStyles.textPrimary,
        ),
      ),
    );
  }

  /// Builds a type badge cell (Servico/Peca) with color
  pw.Widget _buildTypeBadge(String text, PdfColor color) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: boldFont,
          fontSize: 7,
          color: color,
        ),
      ),
    );
  }

  /// Builds a single equipment block with its services and products
  pw.Widget buildEquipmentBlock({
    required int deviceIndex,
    required DeviceAggr device,
    required List<OrderService> services,
    required List<OrderProduct> products,
    required bool showBadge,
  }) {
    final hasItems = services.isNotEmpty || products.isNotEmpty;

    final subtotal = services.fold(0.0, (sum, s) => sum + (s.value ?? 0)) +
        products.fold(0.0, (sum, p) => sum + (p.total ?? 0));

    // Device metadata
    final metaParts = <String>[];
    if (device.serial != null && device.serial!.isNotEmpty) {
      metaParts.add(device.serial!);
    }
    if (device.manufacturer != null && device.manufacturer!.isNotEmpty) {
      metaParts.add(device.manufacturer!);
    }

    return pw.ClipRRect(
      horizontalRadius: 6,
      verticalRadius: 6,
      child: pw.Container(
        width: double.infinity,
        decoration: pw.BoxDecoration(
          color: PdfStyles.equipmentCardBg,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: PdfStyles.equipmentCardBorder, width: 0.5),
        ),
        child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Equipment header
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: pw.Row(
              children: [
                if (showBadge) ...[
                  pw.Container(
                    width: 18,
                    height: 18,
                    decoration: const pw.BoxDecoration(
                      color: PdfStyles.primaryColor,
                      shape: pw.BoxShape.circle,
                    ),
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                      '${deviceIndex + 1}',
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 9,
                        color: PdfColors.white,
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 8),
                ],
                pw.Expanded(
                  child: pw.Row(
                    children: [
                      pw.Text(
                        device.name ?? localizations.equipment,
                        style: pw.TextStyle(
                          font: boldFont,
                          fontSize: 10,
                          color: PdfStyles.textPrimary,
                        ),
                      ),
                      if (metaParts.isNotEmpty) ...[
                        pw.SizedBox(width: 8),
                        pw.Text(
                          metaParts.join(' · '),
                          style: pw.TextStyle(
                            font: baseFont,
                            fontSize: 8,
                            color: PdfStyles.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Unified table (services + products) - only if has items
          if (hasItems)
            pw.Table(
              border: pw.TableBorder(
                horizontalInside: pw.BorderSide(color: PdfStyles.dividerColor, width: 0.5),
              ),
              columnWidths: {
                0: const pw.FixedColumnWidth(45),
                1: const pw.FlexColumnWidth(),
                2: const pw.FixedColumnWidth(28),
                3: const pw.FixedColumnWidth(70),
                4: const pw.FixedColumnWidth(70),
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfStyles.backgroundLighter),
                  children: [
                    _buildCompactTableHeader(localizations.itemType),
                    _buildCompactTableHeader(localizations.descriptionColumn),
                    _buildCompactTableHeader(localizations.quantityShort, align: pw.TextAlign.center),
                    _buildCompactTableHeader(localizations.unitValue, align: pw.TextAlign.right),
                    _buildCompactTableHeader(localizations.total, align: pw.TextAlign.right),
                  ],
                ),
                // Service rows
                ...services.map((s) {
                  final description = s.description != null && s.description!.isNotEmpty
                      ? '${s.service?.name ?? ''} - ${s.description}'
                      : s.service?.name ?? '';
                  return pw.TableRow(
                    children: [
                      _buildTypeBadge(localizations.serviceType, PdfStyles.serviceTypeColor),
                      _buildCompactTableCell(description),
                      _buildCompactTableCell('1', align: pw.TextAlign.center, color: PdfStyles.textSecondary),
                      _buildCompactTableCell(_formatCurrency(s.value), align: pw.TextAlign.right, color: PdfStyles.textSecondary),
                      _buildCompactTableCell(_formatCurrency(s.value), align: pw.TextAlign.right, isBold: true),
                    ],
                  );
                }),
                // Product rows
                ...products.map((p) {
                  final description = p.description != null && p.description!.isNotEmpty
                      ? '${p.product?.name ?? ''} - ${p.description}'
                      : p.product?.name ?? '';
                  return pw.TableRow(
                    children: [
                      _buildTypeBadge(localizations.productType, PdfStyles.productTypeColor),
                      _buildCompactTableCell(description),
                      _buildCompactTableCell(p.quantity?.toString() ?? '1', align: pw.TextAlign.center, color: PdfStyles.textSecondary),
                      _buildCompactTableCell(_formatCurrency(p.value), align: pw.TextAlign.right, color: PdfStyles.textSecondary),
                      _buildCompactTableCell(_formatCurrency(p.total), align: pw.TextAlign.right, isBold: true),
                    ],
                  );
                }),
                // Subtotal row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfStyles.backgroundLight),
                  children: [
                    pw.SizedBox(),
                    _buildCompactTableCell(localizations.subtotal, isBold: true, color: PdfStyles.sectionIconColor),
                    pw.SizedBox(),
                    pw.SizedBox(),
                    _buildCompactTableCell(_formatCurrency(subtotal), align: pw.TextAlign.right, isBold: true, color: PdfStyles.sectionIconColor),
                  ],
                ),
              ],
            ),
        ],
      ),
    ),
    );
  }

  /// Builds all equipment blocks for the order
  pw.Widget buildEquipmentBlocks(Order order) {
    final devices = order.effectiveDevices;
    final isMulti = order.isMultiDevice;

    // If no devices, render a single block with all items
    if (devices.isEmpty) {
      final hasItems = (order.services != null && order.services!.isNotEmpty) ||
          (order.products != null && order.products!.isNotEmpty);
      if (!hasItems) return pw.SizedBox();

      return buildEquipmentBlock(
        deviceIndex: 0,
        device: DeviceAggr()..name = localizations.equipment,
        services: order.services ?? [],
        products: order.products ?? [],
        showBadge: false,
      );
    }

    // Single device: render one block without badge
    if (!isMulti) {
      return buildEquipmentBlock(
        deviceIndex: 0,
        device: devices.first,
        services: order.services ?? [],
        products: order.products ?? [],
        showBadge: false,
      );
    }

    // Multi device: group items by deviceId
    final blocks = <pw.Widget>[];

    for (var i = 0; i < devices.length; i++) {
      final device = devices[i];
      final deviceId = device.id;

      final deviceServices = (order.services ?? [])
          .where((s) => s.deviceId == deviceId)
          .toList();
      final deviceProducts = (order.products ?? [])
          .where((p) => p.deviceId == deviceId)
          .toList();

      // For the first device, also include items without deviceId
      if (i == 0) {
        deviceServices.addAll(
          (order.services ?? []).where((s) => s.deviceId == null || s.deviceId!.isEmpty),
        );
        deviceProducts.addAll(
          (order.products ?? []).where((p) => p.deviceId == null || p.deviceId!.isEmpty),
        );
      }

      if (blocks.isNotEmpty) {
        blocks.add(pw.SizedBox(height: 10));
      }

      blocks.add(
        buildEquipmentBlock(
          deviceIndex: i,
          device: device,
          services: deviceServices,
          products: deviceProducts,
          showBadge: true,
        ),
      );
    }

    if (blocks.isEmpty) return pw.SizedBox();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: blocks,
    );
  }

  // ============================================
  // QR CODE BLOCK
  // ============================================

  pw.Widget buildQrCodeBlock(Order order) {
    final shareUrl = order.shareLink?.url;
    if (shareUrl == null) return pw.SizedBox();

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: PdfStyles.borderColor, width: 0.5),
      ),
      child: pw.Row(
        children: [
          pw.BarcodeWidget(
            barcode: pw.Barcode.qrCode(),
            data: shareUrl,
            width: 64,
            height: 64,
            color: PdfStyles.textPrimary,
          ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  localizations.trackOnline,
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 10,
                    color: PdfStyles.primaryColor,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  localizations.trackOnlineDescription,
                  style: pw.TextStyle(
                    font: baseFont,
                    fontSize: 8,
                    color: PdfStyles.textSecondary,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.UrlLink(
                  destination: shareUrl,
                  child: pw.Text(
                    shareUrl,
                    style: pw.TextStyle(
                      font: baseFont,
                      fontSize: 7.5,
                      color: PdfStyles.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // TERMS AND CONDITIONS
  // ============================================

  pw.Widget buildTermsSection(String? termsOfService) {
    if (termsOfService == null || termsOfService.trim().isEmpty) {
      return pw.SizedBox();
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(localizations.termsAndConditions),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: pw.BoxDecoration(
            color: PdfStyles.backgroundLight,
            borderRadius: pw.BorderRadius.circular(4),
            border: pw.Border.all(color: PdfStyles.borderColor, width: 0.5),
          ),
          child: pw.Text(
            termsOfService,
            style: pw.TextStyle(
              font: baseFont,
              fontSize: 7.5,
              color: PdfStyles.textSecondary,
              lineSpacing: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================
  // SIGNATURES (two columns)
  // ============================================

  pw.Widget buildSignatures(Customer? customer, Company company) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 20),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          _buildSignatureBlock(
            localizations.clientSignature,
            customer?.name,
          ),
          pw.SizedBox(width: 32),
          _buildSignatureBlock(
            localizations.companySignature,
            company.name,
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSignatureBlock(String label, String? name) {
    return pw.Column(
      children: [
        pw.Container(
          width: 200,
          child: pw.Divider(color: PdfStyles.textMuted, thickness: 0.5),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          label,
          style: pw.TextStyle(
            font: boldFont,
            fontSize: 8.5,
            color: PdfStyles.textPrimary,
          ),
        ),
        if (name != null && name.isNotEmpty) ...[
          pw.SizedBox(height: 2),
          pw.Text(
            name,
            style: pw.TextStyle(
              font: baseFont,
              fontSize: 7.5,
              color: PdfStyles.textSecondary,
            ),
          ),
        ],
      ],
    );
  }

  // ============================================
  // FOOTER (simplified)
  // ============================================

  pw.Widget buildFooter(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 32),
      decoration: const pw.BoxDecoration(
        color: PdfStyles.backgroundLight,
        border: pw.Border(
          top: pw.BorderSide(color: PdfStyles.borderColor, width: 0.5),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.UrlLink(
            destination: 'https://praticos.web.app',
            child: pw.Text(
              '${localizations.generatedByPraticos} · praticos.web.app',
              style: pw.TextStyle(
                font: baseFont,
                fontSize: 7,
                color: PdfStyles.footerTextColor,
              ),
            ),
          ),
          pw.Text(
            localizations.formatPageOf(context.pageNumber, context.pagesCount),
            style: pw.TextStyle(
              font: baseFont,
              fontSize: 7,
              color: PdfStyles.footerTextColor,
            ),
          ),
        ],
      ),
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
  }) {
    return [
      // Status Bar
      buildStatusBar(order),

      // Body with padding
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(
          horizontal: PdfStyles.bodyHorizontalPadding,
          vertical: PdfStyles.bodyVerticalPadding,
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Client + Financial Summary (side by side)
            buildClientAndFinancial(customer, order),

            // Service Location
            if (order.address != null && order.address!.isNotEmpty) ...[
              pw.SizedBox(height: 8),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: pw.BoxDecoration(
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: PdfStyles.borderColor, width: 0.5),
                ),
                child: pw.Row(
                  children: [
                    pw.Text(
                      '${localizations.serviceLocation}: ',
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 8,
                        color: PdfStyles.sectionIconColor,
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        order.address!,
                        style: pw.TextStyle(
                          font: baseFont,
                          fontSize: 8,
                          color: PdfStyles.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            pw.SizedBox(height: 14),

            // Equipment Blocks (multi-device)
            buildEquipmentBlocks(order),

            pw.SizedBox(height: 14),

            // QR Code Block
            buildQrCodeBlock(order),

            pw.SizedBox(height: 14),

            // Terms and Conditions
            buildTermsSection(company.termsOfService),

            // Signatures
            buildSignatures(customer, company),
          ],
        ),
      ),
    ];
  }
}
