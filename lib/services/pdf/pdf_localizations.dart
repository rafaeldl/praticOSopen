import 'package:flutter/widgets.dart';
import 'package:praticos/extensions/context_extensions.dart';

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
  final String serviceLocation;
  final String summary;
  final String general;

  // Compact layout strings
  final String termsAndConditions;
  final String companySignature;
  final String clientSignature;
  final String technician;
  final String createdDate;
  final String completedDate;
  final String issuedDate;
  final String servicesSubtotal;
  final String partsSubtotal;
  final String paid;
  final String unitValue;

  // Multi-device / equipment block strings
  final String serviceType;
  final String productType;
  final String itemType;
  final String trackOnline;
  final String trackOnlineDescription;
  final String equipment;

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
    required this.serviceLocation,
    required this.summary,
    required this.general,
    required this.termsAndConditions,
    required this.companySignature,
    required this.clientSignature,
    required this.technician,
    required this.createdDate,
    required this.completedDate,
    required this.issuedDate,
    required this.servicesSubtotal,
    required this.partsSubtotal,
    required this.paid,
    required this.unitValue,
    required this.serviceType,
    required this.productType,
    required this.itemType,
    required this.trackOnline,
    required this.trackOnlineDescription,
    required this.equipment,
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
      newOrder: l10n.newOrder,
      notInformed: l10n.notInformed,
      generatedByPraticos: l10n.generatedByPraticos,
      serviceDescriptionColumn: l10n.serviceDescriptionColumn,
      descriptionColumn: l10n.descriptionColumn,
      value: l10n.valueColumn,
      quantityShort: l10n.quantityShort,
      unitShort: l10n.unitShort,
      total: l10n.total,
      services: l10n.services,
      products: l10n.products,
      subtotal: l10n.subtotal,
      discount: l10n.discount,
      alreadyPaid: l10n.alreadyPaid,
      totalPaid: l10n.totalPaid,
      remainingBalance: l10n.remainingBalance,
      totalToPay: l10n.totalToPay,
      customerSignature: l10n.customerSignature,
      photosAvailableDigitally: l10n.photosAvailableDigitally,
      photoRecord: l10n.photoRecord,
      partsAndProducts: l10n.partsAndProducts,
      serviceLocation: l10n.serviceLocation,
      summary: l10n.pdfSummary,
      general: l10n.pdfGeneral,
      termsAndConditions: l10n.pdfTermsAndConditions,
      companySignature: l10n.pdfCompanySignature,
      clientSignature: l10n.pdfClientSignature,
      technician: l10n.pdfTechnician,
      createdDate: l10n.pdfCreatedDate,
      completedDate: l10n.pdfCompletedDate,
      issuedDate: l10n.pdfIssuedDate,
      servicesSubtotal: l10n.pdfServicesSubtotal,
      partsSubtotal: l10n.pdfPartsSubtotal,
      paid: l10n.pdfPaid,
      unitValue: l10n.pdfUnitValue,
      serviceType: l10n.pdfServiceType,
      productType: l10n.pdfProductType,
      itemType: l10n.pdfItemType,
      trackOnline: l10n.pdfTrackOnline,
      trackOnlineDescription: l10n.pdfTrackOnlineDescription,
      equipment: l10n.pdfEquipment,
      statusCompleted: l10n.statusCompleted,
      statusInProgress: l10n.statusInProgress,
      statusPending: l10n.statusPending,
      notAnswered: l10n.notAnswered,
      notSelected: l10n.notSelected,
      formatPageOf: (current, total) => l10n.pageOf(current, total),
      formatItemsCount: (count) => l10n.nItemsCount(count),
      formatPhotosCount: (count) => l10n.nPhotosCount(count),
      formatAttachedPhotosCount: (count) => l10n.attachedPhotosCount(count),
      formatFormLabel: (title) => l10n.formLabelWithTitle(title),
    );
  }
}
