import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:praticos/global.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/receipt.dart';
import 'package:praticos/repositories/tenant/tenant_order_repository.dart';
import 'package:praticos/repositories/tenant/tenant_receipt_repository.dart';
import 'package:praticos/services/asaas_api_service.dart';
import 'package:praticos/services/photo_service.dart';
import 'package:praticos/utils/payment_allocation.dart';
import 'package:praticos/utils/receipt_plan.dart';
import 'package:praticos/utils/receipt_undo.dart';

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

/// A receipt with the current state of the orders it covered (for the
/// "Recebimento" screen and the recibo PDF).
class ReceiptDetails {
  const ReceiptDetails({required this.receipt, required this.orders});

  final Receipt receipt;

  /// orderId -> current order (missing when it could not be read).
  final Map<String, Order> orders;
}

/// Why recording a customer receipt failed.
enum CustomerReceiptFailure { upload, failed, offline }

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
    TenantOrderRepository? orderRepository,
    AsaasApiService? api,
  }) : _repository = repository,
       _photoService = photoService,
       _orderRepository = orderRepository,
       _api = api;

  final AsaasApiService? _api;

  final TenantReceiptRepository? _repository;
  final PhotoService? _photoService;
  final TenantOrderRepository? _orderRepository;

  TenantOrderRepository get _orders =>
      _orderRepository ?? TenantOrderRepository();

  TenantReceiptRepository get _repo => _repository ?? TenantReceiptRepository();

  /// Returns the written [Receipt]. Throws [CustomerReceiptException].
  Future<Receipt> record(CustomerReceiptRequest request) async {
    final companyId = Global.companyAggr?.id;
    if (companyId == null || request.allocations.isEmpty) {
      throw const CustomerReceiptException(CustomerReceiptFailure.failed);
    }
    final repo = _repo;
    final receiptId = repo.newId(companyId);
    final file = await _upload(companyId, receiptId, request.file);
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

  /// The orders [orderIds] as the server has them now, or null when they
  /// can't all be read (offline): the caller then goes on with what it has.
  ///
  /// The screen's orders come from a snapshot (Financeiro), and [record]
  /// writes increments without reading: a payment booked meanwhile (an
  /// Asaas link paid, someone else receiving) would be paid again.
  Future<Map<String, Order>?> readFromServer(Iterable<String> orderIds) async {
    final companyId = Global.companyAggr?.id;
    if (companyId == null) return null;
    try {
      final orders = <String, Order>{};
      await Future.wait(
        orderIds.toSet().map((id) async {
          final order = await _orders
              .getFromServer(companyId, id)
              .timeout(const Duration(seconds: 8));
          if (order != null) orders[id] = order;
        }),
      );
      return orders;
    } catch (_) {
      return null;
    }
  }

  /// Uploads the picked receipt file under [receiptId] (needs connection).
  Future<ReceiptFile?> _upload(
    String companyId,
    String receiptId,
    PickedReceiptFile? picked,
  ) async {
    if (picked == null) return null;
    ReceiptFile? file;
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
    return file;
  }

  /// Records the receipt through the server ("Outras OS de João": a
  /// consultant including orders someone else created, which the Firestore
  /// rules do not let them write). Online only: on failure nothing was
  /// written and the screen keeps what was typed. Throws
  /// [CustomerReceiptException] ([CustomerReceiptFailure.offline] when the
  /// server could not be reached).
  Future<void> recordOnline(CustomerReceiptRequest request) async {
    final companyId = Global.companyAggr?.id;
    final customerId = request.customer?.id;
    if (companyId == null ||
        customerId == null ||
        request.allocations.isEmpty) {
      throw const CustomerReceiptException(CustomerReceiptFailure.failed);
    }
    final receiptId = _repo.newId(companyId);
    final file = await _upload(companyId, receiptId, request.file);
    try {
      await (_api ?? AsaasApiService.instance).registerCustomerReceipt(
        customerId,
        receiptId: receiptId,
        paidAt: request.paidAt,
        allocations: [
          for (final a in request.allocations)
            (orderId: a.orderId, amount: a.amount),
        ],
        receiptFile: file == null
            ? null
            : {
                'url': file.url,
                'storagePath': file.storagePath,
                if (file.fileName != null) 'fileName': file.fileName,
                'contentType': file.contentType,
              },
      );
    } on AsaasApiException catch (e) {
      throw CustomerReceiptException(
        e.code == 'NETWORK_ERROR'
            ? CustomerReceiptFailure.offline
            : CustomerReceiptFailure.failed,
      );
    } catch (_) {
      throw const CustomerReceiptException(CustomerReceiptFailure.failed);
    }
  }

  /// Reads receipt [receiptId] and the orders it covered. Null when the
  /// receipt does not exist.
  Future<ReceiptDetails?> load(String receiptId) async {
    final companyId = Global.companyAggr?.id;
    if (companyId == null) return null;
    final receipt = await _repo.getSingle(companyId, receiptId);
    if (receipt == null) return null;
    return ReceiptDetails(
      receipt: receipt,
      orders: await _readOrders(companyId, receipt),
    );
  }

  /// Fresh orders (server first, local cache when offline).
  Future<Map<String, Order>> _readOrders(
    String companyId,
    Receipt receipt,
  ) async {
    final ids = {
      for (final a in receipt.allocations ?? const <ReceiptAllocation>[])
        if (a.orderId != null) a.orderId!,
    };
    final orders = <String, Order>{};
    await Future.wait(
      ids.map((id) async {
        Order? order;
        try {
          order = await _orders.getFromServer(companyId, id);
        } catch (_) {
          try {
            order = await _orders.getSingle(companyId, id);
          } catch (_) {
            order = null;
          }
        }
        if (order != null) orders[id] = order;
      }),
    );
    return orders;
  }

  /// "Desfazer recebimento": cancels [receipt] and takes its share out of
  /// each order, in one batch (not awaited: works offline). The shared
  /// receipt file stays in Storage. Throws [CustomerReceiptException].
  Future<void> undo(Receipt receipt) async {
    final companyId = Global.companyAggr?.id;
    final receiptId = receipt.id;
    if (companyId == null ||
        receiptId == null ||
        receipt.status != ReceiptStatus.active) {
      throw const CustomerReceiptException(CustomerReceiptFailure.failed);
    }
    final orders = await _readOrders(companyId, receipt);
    final actor = Global.userAggr;
    final plan = buildReceiptUndo(
      receipt: receipt,
      orders: orders.values.toList(),
      now: DateTime.now(),
      actor: actor,
    );
    try {
      unawaited(
        _repo
            .cancel(companyId, receiptId, plan, actor: actor)
            .catchError(
              (Object e) =>
                  debugPrint('CustomerReceiptService: undo failed: $e'),
            ),
      );
    } catch (e) {
      debugPrint('CustomerReceiptService: could not queue undo: $e');
      throw const CustomerReceiptException(CustomerReceiptFailure.failed);
    }
    receipt.status = ReceiptStatus.canceled;
  }
}
