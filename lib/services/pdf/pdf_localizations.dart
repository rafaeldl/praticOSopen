import 'package:flutter/widgets.dart';
import 'package:praticos/extensions/context_extensions.dart';

/// Helper function to remove accents for PDF fonts
String _latinCharactersOnly(String text) {
  if (text.isEmpty) return '';

  final Map<String, String> accentMap = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
    'ç': 'c', 'ñ': 'n',
    'Á': 'A', 'À': 'A', 'Â': 'A', 'Ã': 'A', 'Ä': 'A',
    'É': 'E', 'È': 'E', 'Ê': 'E', 'Ë': 'E',
    'Í': 'I', 'Ì': 'I', 'Î': 'I', 'Ï': 'I',
    'Ó': 'O', 'Ò': 'O', 'Ô': 'O', 'Õ': 'O', 'Ö': 'O',
    'Ú': 'U', 'Ù': 'U', 'Û': 'U', 'Ü': 'U',
    'Ç': 'C', 'Ñ': 'N',
  };

  try {
    String result = text;
    accentMap.forEach((key, value) {
      result = result.replaceAll(key, value);
    });
    result = result.replaceAll(RegExp(r'[^\x00-\x7F]'), '');
    return result;
  } catch (e) {
    return 'texto';
  }
}

/// Localized strings for PDF generation
class PdfLocalizations {
  final String newOrder;
  final String notInformed;
  final String generatedByPraticos;
  final String serviceDescriptionColumn;
  final String descriptionColumn;
  final String value;
  final String quantityShort;
  final String unitShort;
  final String total;
  final String services;
  final String products;
  final String subtotal;
  final String discount;
  final String alreadyPaid;
  final String totalPaid;
  final String remainingBalance;
  final String totalToPay;
  final String customerSignature;
  final String photosAvailableDigitally;
  final String photoRecord;
  final String partsAndProducts;

  // Form-related strings
  final String statusCompleted;
  final String statusInProgress;
  final String statusPending;
  final String notAnswered;
  final String notSelected;

  // Format functions for parametric strings
  final String Function(int current, int total) formatPageOf;
  final String Function(int count) formatItemsCount;
  final String Function(int count) formatPhotosCount;
  final String Function(int count) formatAttachedPhotosCount;
  final String Function(String title) formatFormLabel;

  const PdfLocalizations({
    required this.newOrder,
    required this.notInformed,
    required this.generatedByPraticos,
    required this.serviceDescriptionColumn,
    required this.descriptionColumn,
    required this.value,
    required this.quantityShort,
    required this.unitShort,
    required this.total,
    required this.services,
    required this.products,
    required this.subtotal,
    required this.discount,
    required this.alreadyPaid,
    required this.totalPaid,
    required this.remainingBalance,
    required this.totalToPay,
    required this.customerSignature,
    required this.photosAvailableDigitally,
    required this.photoRecord,
    required this.partsAndProducts,
    required this.statusCompleted,
    required this.statusInProgress,
    required this.statusPending,
    required this.notAnswered,
    required this.notSelected,
    required this.formatPageOf,
    required this.formatItemsCount,
    required this.formatPhotosCount,
    required this.formatAttachedPhotosCount,
    required this.formatFormLabel,
  });

  /// Creates PdfLocalizations from Flutter BuildContext
  factory PdfLocalizations.fromContext(BuildContext context) {
    final l10n = context.l10n;

    return PdfLocalizations(
      newOrder: _latinCharactersOnly(l10n.newOrder),
      notInformed: _latinCharactersOnly(l10n.notInformed),
      generatedByPraticos: _latinCharactersOnly(l10n.generatedByPraticos),
      serviceDescriptionColumn: _latinCharactersOnly(l10n.serviceDescriptionColumn),
      descriptionColumn: _latinCharactersOnly(l10n.descriptionColumn),
      value: _latinCharactersOnly(l10n.valueColumn),
      quantityShort: _latinCharactersOnly(l10n.quantityShort),
      unitShort: _latinCharactersOnly(l10n.unitShort),
      total: _latinCharactersOnly(l10n.total),
      services: _latinCharactersOnly(l10n.services),
      products: _latinCharactersOnly(l10n.products),
      subtotal: _latinCharactersOnly(l10n.subtotal),
      discount: _latinCharactersOnly(l10n.discount),
      alreadyPaid: _latinCharactersOnly(l10n.alreadyPaid),
      totalPaid: _latinCharactersOnly(l10n.totalPaid),
      remainingBalance: _latinCharactersOnly(l10n.remainingBalance),
      totalToPay: _latinCharactersOnly(l10n.totalToPay),
      customerSignature: _latinCharactersOnly(l10n.customerSignature),
      photosAvailableDigitally: _latinCharactersOnly(l10n.photosAvailableDigitally),
      photoRecord: _latinCharactersOnly(l10n.photoRecord),
      partsAndProducts: _latinCharactersOnly(l10n.partsAndProducts),
      statusCompleted: _latinCharactersOnly(l10n.statusCompleted),
      statusInProgress: _latinCharactersOnly(l10n.statusInProgress),
      statusPending: _latinCharactersOnly(l10n.statusPending),
      notAnswered: _latinCharactersOnly(l10n.notAnswered),
      notSelected: _latinCharactersOnly(l10n.notSelected),
      formatPageOf: (current, total) => _latinCharactersOnly(l10n.pageOf(current, total)),
      formatItemsCount: (count) => _latinCharactersOnly(l10n.nItemsCount(count)),
      formatPhotosCount: (count) => _latinCharactersOnly(l10n.nPhotosCount(count)),
      formatAttachedPhotosCount: (count) => _latinCharactersOnly(l10n.attachedPhotosCount(count)),
      formatFormLabel: (title) => _latinCharactersOnly(l10n.formLabelWithTitle(title)),
    );
  }
}
