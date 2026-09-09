import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Grid de fotos reutilizavel entre a pagina principal da OS e os formularios.
///
/// Usa [pw.Wrap] (SpanningWidget) para que o grid possa quebrar entre paginas
/// quando usado como filho direto de um [pw.MultiPage].
class PdfPhotoGrid {
  PdfPhotoGrid._();

  /// Tamanho padrao de cada foto (lado do quadrado, em pontos)
  static const double defaultPhotoSize = 75;

  /// Constroi o grid de fotos
  ///
  /// [photos] Imagens ja carregadas em memoria
  /// [size] Lado do quadrado de cada foto
  /// [limit] Numero maximo de fotos exibidas (null = todas)
  static pw.Widget build(
    List<pw.MemoryImage> photos, {
    double size = defaultPhotoSize,
    int? limit,
  }) {
    if (photos.isEmpty) {
      return pw.SizedBox();
    }

    final photosToShow = limit == null ? photos : photos.take(limit).toList();

    return pw.Wrap(
      spacing: 5,
      runSpacing: 5,
      children: photosToShow.map((image) {
        return pw.Container(
          width: size,
          height: size,
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
}
