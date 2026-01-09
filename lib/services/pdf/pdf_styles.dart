import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Constantes de estilo para geracao de PDF
class PdfStyles {
  PdfStyles._();

  // ============================================
  // CORES PRINCIPAIS
  // ============================================

  /// Azul principal - usado em headers e badges
  static const PdfColor primaryColor = PdfColor.fromInt(0xFF2196F3);

  /// Azul escuro - usado em titulos de secao
  static const PdfColor primaryDark = PdfColor.fromInt(0xFF1565C0);

  /// Verde - status pago/concluido
  static const PdfColor successColor = PdfColor.fromInt(0xFF4CAF50);

  /// Laranja - status orcamento/pendente
  static const PdfColor warningColor = PdfColor.fromInt(0xFFFF9800);

  /// Vermelho - status cancelado
  static const PdfColor dangerColor = PdfColor.fromInt(0xFFF44336);

  /// Roxo - status em andamento
  static const PdfColor progressColor = PdfColor.fromInt(0xFF9C27B0);

  // ============================================
  // CORES DE TEXTO
  // ============================================

  /// Texto principal - cinza escuro
  static const PdfColor textPrimary = PdfColor.fromInt(0xFF212121);

  /// Texto secundario - cinza medio
  static const PdfColor textSecondary = PdfColor.fromInt(0xFF757575);

  /// Texto desabilitado - cinza claro
  static const PdfColor textMuted = PdfColor.fromInt(0xFF9E9E9E);

  // ============================================
  // CORES DE FUNDO E BORDA
  // ============================================

  /// Fundo claro - usado em cards
  static const PdfColor backgroundLight = PdfColor.fromInt(0xFFF5F5F5);

  /// Fundo mais claro - usado em tabelas
  static const PdfColor backgroundLighter = PdfColor.fromInt(0xFFF8F9FA);

  /// Cor de borda padrao
  static const PdfColor borderColor = PdfColor.fromInt(0xFFE0E0E0);

  /// Cor de divisor
  static const PdfColor dividerColor = PdfColor.fromInt(0xFFBDBDBD);

  // ============================================
  // CONFIGURACOES DE PAGINA
  // ============================================

  /// Formato A4
  static const pageFormat = PdfPageFormat.a4;

  /// Margens padrao da pagina (40px)
  static const pageMargin = pw.EdgeInsets.all(40);

  // ============================================
  // TAMANHOS DE FONTE
  // ============================================

  /// Titulo principal (18pt)
  static const double fontSizeTitle = 18.0;

  /// Subtitulo (14pt)
  static const double fontSizeSubtitle = 14.0;

  /// Texto grande (12pt)
  static const double fontSizeLarge = 12.0;

  /// Texto normal (10pt)
  static const double fontSizeNormal = 10.0;

  /// Texto pequeno (9pt)
  static const double fontSizeSmall = 9.0;

  /// Texto muito pequeno (8pt)
  static const double fontSizeXSmall = 8.0;

  // ============================================
  // ESPACAMENTOS
  // ============================================

  /// Espacamento grande (20pt)
  static const double spacingLarge = 20.0;

  /// Espacamento medio (12pt)
  static const double spacingMedium = 12.0;

  /// Espacamento pequeno (8pt)
  static const double spacingSmall = 8.0;

  /// Espacamento muito pequeno (4pt)
  static const double spacingXSmall = 4.0;

  // ============================================
  // METODOS UTILITARIOS
  // ============================================

  /// Retorna a cor correspondente ao status da OS
  static PdfColor getStatusColor(String? status) {
    switch (status) {
      case 'approved':
        return PdfColors.blue700;
      case 'done':
        return PdfColors.green700;
      case 'canceled':
        return PdfColors.red700;
      case 'quote':
        return PdfColors.orange700;
      case 'progress':
        return PdfColors.purple700;
      default:
        return PdfColors.grey600;
    }
  }

  /// Retorna a cor correspondente ao status do formulario
  static PdfColor getFormStatusColor(String? status) {
    switch (status) {
      case 'completed':
        return successColor;
      case 'in_progress':
        return progressColor;
      case 'pending':
      default:
        return warningColor;
    }
  }

  /// Cria um estilo de texto base
  static pw.TextStyle baseTextStyle(pw.Font font, {double? fontSize, PdfColor? color}) {
    return pw.TextStyle(
      font: font,
      fontSize: fontSize ?? fontSizeNormal,
      color: color ?? textPrimary,
    );
  }

  /// Cria um estilo de texto em negrito
  static pw.TextStyle boldTextStyle(pw.Font font, {double? fontSize, PdfColor? color}) {
    return pw.TextStyle(
      font: font,
      fontSize: fontSize ?? fontSizeNormal,
      color: color ?? textPrimary,
    );
  }

  /// Cria decoracao de card padrao
  static pw.BoxDecoration cardDecoration({PdfColor? backgroundColor}) {
    return pw.BoxDecoration(
      color: backgroundColor ?? backgroundLight,
      borderRadius: pw.BorderRadius.circular(6),
      border: pw.Border.all(color: borderColor, width: 0.5),
    );
  }

  /// Cria decoracao de badge de status
  static pw.BoxDecoration statusBadgeDecoration(PdfColor color) {
    return pw.BoxDecoration(
      color: color.shade(0.9),
      borderRadius: pw.BorderRadius.circular(3),
      border: pw.Border.all(color: color, width: 0.5),
    );
  }
}
