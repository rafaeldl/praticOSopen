import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:praticos/global.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/receipt.dart';
import 'package:praticos/repositories/tenant/tenant_receipt_repository.dart';
import 'package:praticos/services/photo_service.dart';
import 'package:praticos/utils/payment_allocation.dart';
import 'package:praticos/utils/receipt_plan.dart';

/// File picked on the "Receber de …" screen, uploaded only on save.
class PickedReceiptFile {
  const PickedReceiptFile(this.file, this.contentType, this.name);

  final File file;
  final String contentType;
  final String name;
}

/// What the "Receber de …" screen asks to record.
class CustomerReceiptRequest {
  const CustomerReceiptRequest({
    required this.customer,
    required this.orders,
    required this.allocations,
    required this.paidAt,
    this.file,
  });

  final CustomerAggr? customer;
  final List<Order> orders;
  final List<PaymentAllocation> allocations;
  final DateTime paidAt;
  final PickedReceiptFile? file;
}

/// Why recording a customer receipt failed.
enum CustomerReceiptFailure { upload, failed }

class CustomerReceiptException implements Exception {
  const CustomerReceiptException(this.reason);

  final CustomerReceiptFailure reason;

  @override
  String toString() => 'CustomerReceiptException($reason)';
}

/// Records one payment from a customer split over several orders: uploads
/// the receipt file once (needs connection), then writes the receipt and
/// every order payment in one batch (works offline; not awaited).
class CustomerReceiptService {
  CustomerReceiptService({
    TenantReceiptRepository? repository,
    PhotoService? photoService,
  })  : _repository = repository,
        _photoService = photoService;

  final TenantReceiptRepository? _repository;
  final PhotoService? _photoService;

  TenantReceiptRepository get _repo =>
      _repository ?? TenantReceiptRepository();

  /// Returns the written [Receipt]. Throws [CustomerReceiptException].
  Future<Receipt> record(CustomerReceiptRequest request) async {
    final companyId = Global.companyAggr?.id;
    if (companyId == null || request.allocations.isEmpty) {
      throw const CustomerReceiptException(CustomerReceiptFailure.failed);
    }
    final repo = _repo;
    final receiptId = repo.newId(companyId);

    ReceiptFile? file;
    final picked = request.file;
    if (picked != null) {
      try {
        file = await (_photoService ?? PhotoService()).uploadCustomerReceipt(
          file: picked.file,
          companyId: companyId,
          receiptId: receiptId,
          contentType: picked.contentType,
          fileName: picked.name,
        );
      } catch (_) {
        file = null;
      }
      if (file == null) {
        throw const CustomerReceiptException(CustomerReceiptFailure.upload);
      }
    }

    final actor = Global.userAggr;
    final plan = buildReceiptPlan(
      receiptId: receiptId,
      customer: request.customer,
      orders: request.orders,
      allocations: request.allocations,
      paidAt: request.paidAt,
      now: DateTime.now(),
      actor: actor,
      company: Global.companyAggr,
      file: file,
    );

    try {
      // Not awaited: the commit completes only when the server confirms,
      // which never happens offline. The local cache already has it.
      unawaited(
        repo.save(companyId, plan, actor: actor).catchError((Object e) {
          debugPrint('CustomerReceiptService: batch failed: $e');
        }),
      );
    } catch (e) {
      debugPrint('CustomerReceiptService: could not queue batch: $e');
      throw const CustomerReceiptException(CustomerReceiptFailure.failed);
    }
    return plan.receipt;
  }
}
