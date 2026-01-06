import 'dart:io';

import 'package:intl/intl.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/order_photo.dart';
import 'package:praticos/models/order_form.dart' as of_model;
import 'package:praticos/services/forms_service.dart';
import 'package:praticos/repositories/v2/order_repository_v2.dart';
import 'package:praticos/services/photo_service.dart';
import 'package:mobx/mobx.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;

import 'package:praticos/global.dart';
part 'order_store.g.dart';

class OrderStore = _OrderStore with _$OrderStore;

abstract class _OrderStore with Store {
  final OrderRepositoryV2 repository = OrderRepositoryV2();
  final PhotoService photoService = PhotoService();
  final FormsService formsService = FormsService();

  Order? order;

  @observable
  ObservableStream<List<Order?>>? orderList;

  @observable
  ObservableStream<Order?>? orderStream;

  @observable
  ObservableStream<List<of_model.OrderForm>>? formsStream;

  @observable
  String? dueDate;

  @observable
  String? status;

  @observable
  DateTime? createdAt;

  @observable
  double? total;

  @observable
  double? discount;

  @observable
  String? payment;

  @observable
  CustomerAggr? customer;

  @observable
  DeviceAggr? device;

  @computed
  String? get customerName => customer?.name;

  late String orderServiceTitle;

  late String orderProductTitle;

  @observable
  Customer? customerFilter;

  @computed
  String? get deviceName {
    if (device == null) return null;
    return "${device?.name} - ${device?.serial}";
  }

  @computed
  String? get devicePhoto => device?.photo;

  @computed
  String? get customerInitials {
    if (customer?.name == null || customer!.name!.isEmpty) return null;
    final parts = customer!.name!.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return parts.first[0].toUpperCase();
  }

  @observable
  ObservableList<OrderService>? services = ObservableList();

  @observable
  ObservableList<OrderProduct>? products = ObservableList();

  @observable
  ObservableList<OrderPhoto> photos = ObservableList();

  @observable
  bool isUploadingPhoto = false;

  @observable
  double totalPaidAmount = 0.0;

  @observable
  double totalUnpaidAmount = 0.0;

  @observable
  double totalRevenue = 0.0;

  @observable
  int totalOrdersCount = 0;

  @observable
  int paidOrdersCount = 0;

  @observable
  ObservableList<Order?> recentOrders = ObservableList<Order?>();

  @observable
  String selectedDashboardPeriod = 'mês';

  @observable
  int periodOffset = 0;

  @observable
  ObservableMap<String, int> orderStatusCounts = ObservableMap<String, int>();

  @observable
  ObservableMap<String, double> paymentStatusCounts =
      ObservableMap<String, double>();

  @observable
  String? paymentFilter;

  @observable
  ObservableList<Order?> orders = ObservableList<Order?>();

  @observable
  bool isLoading = false;

  @observable
  bool hasMoreOrders = true;

  firestore.DocumentSnapshot? _lastDocument;
  final int _limit = 10;

  @observable
  ObservableMap<String, double> customerOrderTotals =
      ObservableMap<String, double>();

  @observable
  ObservableMap<String, double> customerUnpaidTotals =
      ObservableMap<String, double>();

  @observable
  ObservableList<Map<String, dynamic>> customerRanking =
      ObservableList<Map<String, dynamic>>();

  @observable
  Map<String, dynamic>? selectedCustomerInRanking;

  @observable
  String rankingSortType = 'total'; // 'total' ou 'unpaid'

  _OrderStore() {
    autorun((_) {
      // Protege contra valores nulos
      if (orderStream == null ||
          orderStream!.data == null ||
          order == null) {
        return;
      }

      // Atualiza o número da OS a partir do stream
      order!.number = orderStream!.data.number;
    });
  }

  String? get companyId => Global.companyAggr?.id;

  @action
  loadOrder({String? id}) {
    if (id == null) {
      order = Order();
      order!.company = Global.companyAggr;
      order!.total = 0.0;
      total = order!.total;
      order!.discount = 0.0;
      discount = order!.discount;
      order!.photos = [];
      photos = ObservableList<OrderPhoto>();
      order!.createdAt = DateTime.now();
      createdAt = order!.createdAt;
      order!.createdBy = Global.userAggr;
      order!.status = 'quote';
      status = order!.status;
      order!.payment = 'unpaid';
      payment = order!.payment;
      updatePayment();
      return;
    }
    if (companyId == null) return;
    repository.getSingle(companyId!, id).then((value) {
      setOrder(value);
    });
  }

  @action
  void setOrder(Order? order) {
    if (order == null) return;

    // Preserva o ID para garantir que não seja perdido
    String? orderId = order.id;

    this.order = order;

    // Atualiza a data de criação
    createdAt = order.createdAt;

    // Se não tiver data de criação, define uma
    if (this.order!.createdAt == null) {
      this.order!.createdAt = DateTime.now();
      createdAt = this.order!.createdAt;
    }

    // Configura o stream se tiver ID
    if (orderId != null && companyId != null) {
      this.order!.id = orderId;
      orderStream = repository.streamSingle(companyId!, orderId).asObservable();
      formsStream = formsService.getOrderForms(companyId!, orderId).asObservable();
    }

    customer = order.customer;
    device = order.device;
    services = order.services?.asObservable() ?? ObservableList<OrderService>();
    products = order.products?.asObservable() ?? ObservableList<OrderProduct>();
    photos = order.photos?.asObservable() ?? ObservableList<OrderPhoto>();
    dueDate = dateToString(order.dueDate);
    status = order.status;
    updateTotal();
    updatePayment();
  }

  @action
  setCustomer(Customer? c) {
    if (c == null) return;

    // Evita operações desnecessárias para o mesmo cliente
    if (customer?.id == c.id) return;

    order!.customer = c.toAggr();
    customer = order!.customer;
    createItem();
  }

  @action
  setDevice(Device? d) {
    if (d == null) return;
    order!.device = d.toAggr();
    device = order!.device;
    createItem();
  }

  setDueDate(DateTime date) {
    order!.dueDate = date;
    dueDate = dateToString(date);
    createItem();
  }

  @action
  setStatus(String? status) {
    if (status == null) return;
    order!.status = status;
    this.status = status;
    updatePayment();
    createItem();
  }

  String dateToString(DateTime? date) {
    if (date == null) return 'Não definida';
    DateFormat dateFormat = DateFormat('dd/MM/yyyy');
    return dateFormat.format(date);
  }

  @computed
  String get formattedCreatedDate {
    if (createdAt == null && order?.createdAt == null) return 'Data criação';
    DateTime date = createdAt ?? order!.createdAt!;
    return dateToString(date);
  }

  @action
  updateOrder() {
    services = order!.services!.asObservable();
    products = order!.products!.asObservable();
    updatePayment();
    updateTotal();
    createItem();
  }

  @action
  Future<void> deleteOrder() {
    if (companyId == null) return Future.value();
    return repository.removeItem(companyId!, order!.id);
  }

  void updatePayment() {
    if (order == null) return;

    if (['quote', 'canceled'].contains(order!.status)) {
      order!.payment = null;
      payment = '';
      return;
    }

    if (order!.payment == null) {
      order!.payment = 'unpaid';
    }

    if (order!.payment == 'paid') {
      payment = 'Pago';
    } else if (order!.payment == 'unpaid') {
      payment = 'A receber';
    }
  }

  @action
  loadOrders(String? status) async {
    if (companyId == null) return;

    orderList = repository
        .streamOrders(
          companyId!,
          status: status,
          customerId: customerFilter?.id,
        )
        .asObservable();

    if (orderList!.hasError) {
      print(orderList!.error);
    }

    print(orderList);
  }

  @action
  addService(OrderService orderService) {
    // Copia a foto do serviço se existir
    if (orderService.service?.photo != null) {
      orderService.photo = orderService.service?.photo;
    }
    order!.services!.add(orderService);
    services!.add(orderService);
    updateTotal();
    createItem();
  }

  @action
  addProduct(OrderProduct orderProduct) {
    // Copia a foto do produto se existir
    if (orderProduct.product?.photo != null) {
      orderProduct.photo = orderProduct.product?.photo;
    }
    order!.products!.add(orderProduct);
    products!.add(orderProduct);
    updateTotal();
    createItem();
  }

  @action
  deleteService(int index) {
    order!.services!.removeAt(index);
    services = order?.services?.asObservable();
    updateTotal();
    createItem();
  }

  @action
  deleteProduct(int index) {
    order!.products!.removeAt(index);
    products = order?.products?.asObservable();
    updateTotal();
    createItem();
  }

  /// Adiciona uma foto da galeria
  @action
  Future<bool> addPhotoFromGallery() async {
    final File? file = await photoService.pickImageFromGallery();
    if (file != null) {
      return await _uploadPhoto(file);
    }
    return false;
  }

  /// Adiciona uma foto da câmera
  @action
  Future<bool> addPhotoFromCamera() async {
    final File? file = await photoService.takePhoto();
    if (file != null) {
      return await _uploadPhoto(file);
    }
    return false;
  }

  /// Faz o upload de uma foto
  Future<bool> _uploadPhoto(File file) async {
    if (order == null || companyId == null) return false;

    // Garante que a OS seja salva antes do upload
    if (order!.id == null) {
      await repository.createItem(companyId!, order);
    }

    if (order!.id == null || order!.company?.id == null) return false;

    isUploadingPhoto = true;

    try {
      final OrderPhoto? photo = await photoService.uploadOrderPhoto(
        file: file,
        companyId: order!.company!.id!,
        orderId: order!.id!,
      );

      isUploadingPhoto = false;

      if (photo != null) {
        if (order!.photos == null) {
          order!.photos = [];
        }
        order!.photos!.add(photo);
        photos.add(photo);
        createItem();
        return true;
      }
      return false;
    } catch (e) {
      isUploadingPhoto = false;
      print('Erro no upload da foto: $e');
      return false;
    }
  }

  /// Remove uma foto pelo índice
  @action
  Future<bool> deletePhoto(int index) async {
    if (order == null || order!.photos == null || index >= order!.photos!.length) {
      return false;
    }

    final OrderPhoto photo = order!.photos![index];

    if (photo.storagePath != null) {
      final bool deleted = await photoService.deletePhoto(photo.storagePath!);
      if (!deleted) return false;
    }

    order!.photos!.removeAt(index);
    photos.removeAt(index);
    createItem();
    return true;
  }

  /// Reordena as fotos (move uma foto para a posição de capa)
  @action
  void setPhotoCover(int index) {
    if (order == null || order!.photos == null || index >= order!.photos!.length) {
      return;
    }

    final OrderPhoto photo = order!.photos!.removeAt(index);
    order!.photos!.insert(0, photo);

    final OrderPhoto observablePhoto = photos.removeAt(index);
    photos.insert(0, observablePhoto);

    createItem();
  }

  @action
  setDiscount(double value) {
    order!.discount = value;
    discount = value;
    updateTotal();
    createItem();
  }

  updateTotal() {
    double temp = 0.0;
    order?.services?.forEach((s) {
      temp += s.value!;
    });

    order?.products?.forEach((p) {
      temp += p.total!;
    });

    if (order?.discount == null) order!.discount = 0.0;
    discount = order?.discount;
    temp -= order!.discount!;

    order?.total = temp;
    total = temp;
  }

  createItem() {
    if (order == null || companyId == null) return;

    if (order!.id == null) {
      // Para nova OS, verifica duplicação pelo número
      if (order!.number != null) {
        // Verifica se existe OS com o mesmo número
        repository.getOrderByNumber(companyId!, order!.number!).then((existingOrder) {
          if (existingOrder != null) {
            // Se encontrou, usa o ID da existente
            order!.id = existingOrder.id;
            repository.updateItem(companyId!, order);
            orderStream =
                repository.streamSingle(companyId!, order!.id).asObservable();
          } else {
            // Cria nova se não encontrou
            repository.createItem(companyId!, order).then((_) {
              if (order!.id != null) {
                orderStream =
                    repository.streamSingle(companyId!, order!.id).asObservable();
              }
            });
          }
        });
      } else {
        // Cria nova OS sem número
        repository.createItem(companyId!, order).then((_) {
          if (order!.id != null) {
            orderStream =
                repository.streamSingle(companyId!, order!.id).asObservable();
          }
        });
      }
    } else {
      // Atualiza OS existente
      repository.updateItem(companyId!, order).then((_) {
        if (orderStream == null ||
            orderStream!.value?.id != order!.id) {
          orderStream = repository.streamSingle(companyId!, order!.id).asObservable();
        }
      });
    }
  }

  @action
  setCustomerFilter(Customer? customerFilter) {
    this.customerFilter = customerFilter;
  }

  @action
  void setDashboardPeriod(String period) {
    selectedDashboardPeriod = period;
    periodOffset = 0;
    loadOrdersForDashboard();
  }

  @observable
  DateTime? customStartDate;

  @observable
  DateTime? customEndDate;

  @action
  void setCustomPeriod(String period, int offset) {
    selectedDashboardPeriod = period;
    periodOffset = offset;
    customStartDate = null;
    customEndDate = null;
    loadOrdersForDashboard();
  }

  @action
  void setCustomDateRange(DateTime start, DateTime end) {
    selectedDashboardPeriod = 'custom';
    periodOffset = 0;
    customStartDate = start;
    customEndDate = end;
    loadOrdersForDashboardCustomRange(start, end);
  }

  @action
  Future<void> loadOrdersForDashboardCustomRange(DateTime start, DateTime end) async {
    if (companyId == null) return;
    try {
      final orders = await repository.getOrdersByDateRange(companyId!, start, end);

      // Filtrar ordens que não são orçamentos
      var filteredOrders =
          orders.where((order) => order?.status != 'quote').toList();

      // Aplicar filtro por cliente selecionado no ranking
      if (selectedCustomerInRanking != null) {
        String customerId = selectedCustomerInRanking!['id'];
        if (customerId == 'sem-cliente') {
          filteredOrders = filteredOrders
              .where((order) => order?.customer?.id == null)
              .toList();
        } else {
          filteredOrders = filteredOrders
              .where((order) => order?.customer?.id == customerId)
              .toList();
        }
      }

      // Calcular totais baseados nas ordens filtradas
      totalOrdersCount = filteredOrders.length;
      paidOrdersCount =
          filteredOrders.where((order) => order?.payment == 'paid').length;

      // Calcular o faturamento total (soma de todos os valores)
      totalRevenue =
          filteredOrders.fold(0.0, (sum, order) => sum + (order?.total ?? 0.0));

      // Calcular valores pagos e a receber
      totalPaidAmount = filteredOrders
          .where((order) => order?.payment == 'paid')
          .fold(0.0, (sum, order) => sum + (order?.total ?? 0.0));

      totalUnpaidAmount = filteredOrders
          .where((order) => order?.payment == 'unpaid')
          .fold(0.0, (sum, order) => sum + (order?.total ?? 0.0));

      // Atualizar paymentStatusCounts para o gráfico
      paymentStatusCounts.clear();
      paymentStatusCounts['paid'] = totalPaidAmount;
      paymentStatusCounts['unpaid'] = totalUnpaidAmount;

      // Calcular os totais por cliente
      customerOrderTotals.clear();
      customerUnpaidTotals.clear();

      double semClienteTotal = 0.0;
      double semClienteUnpaid = 0.0;

      for (var order in filteredOrders) {
        if (order?.total != null) {
          if (order?.customer?.id != null) {
            String customerId = order!.customer!.id!;
            double currentTotal = customerOrderTotals[customerId] ?? 0.0;
            customerOrderTotals[customerId] = currentTotal + order.total!;

            if (order.payment == 'unpaid') {
              double currentUnpaid = customerUnpaidTotals[customerId] ?? 0.0;
              customerUnpaidTotals[customerId] = currentUnpaid + order.total!;
            }
          } else {
            semClienteTotal += order!.total!;
            if (order.payment == 'unpaid') {
              semClienteUnpaid += order.total!;
            }
          }
        }
      }

      // Gerar o ranking de clientes
      customerRanking.clear();

      if (semClienteTotal > 0) {
        customerRanking.add({
          'id': 'sem-cliente',
          'name': 'Sem Cliente',
          'total': semClienteTotal,
          'unpaidTotal': semClienteUnpaid,
        });
      }

      customerOrderTotals.forEach((customerId, total) {
        if (total > 0) {
          var customerName = filteredOrders
                  .firstWhere((order) => order?.customer?.id == customerId,
                      orElse: () => null)
                  ?.customer
                  ?.name ??
              'Cliente sem nome';

          customerRanking.add({
            'id': customerId,
            'name': customerName,
            'total': total,
            'unpaidTotal': customerUnpaidTotals[customerId] ?? 0.0,
          });
        }
      });

      sortCustomerRanking();

      // Aplicar filtro de pagamento nas ordens recentes
      if (paymentFilter != null) {
        filteredOrders = filteredOrders
            .where((order) => order?.payment == paymentFilter)
            .toList();
      }

      // Ordenar ordens por data de atualização
      filteredOrders.sort((a, b) {
        if (a?.updatedAt == null || b?.updatedAt == null) return 0;
        return b!.updatedAt!.compareTo(a!.updatedAt!);
      });

      recentOrders.clear();
      recentOrders.addAll(filteredOrders);
    } catch (e) {
      print('Erro ao carregar dados para dashboard (custom range): $e');
    }
  }

  @action
  void setPaymentFilter(String? filter) {
    paymentFilter = filter;
    loadOrdersForDashboard();
  }

  @action
  Future<void> loadOrdersForDashboard() async {
    if (companyId == null) return;
    try {
      final orders = await repository.getOrdersByCustomPeriod(
          companyId!, selectedDashboardPeriod, periodOffset);

      // Filtrar ordens que não são orçamentos
      var filteredOrders =
          orders.where((order) => order?.status != 'quote').toList();

      // Aplicar filtro por cliente selecionado no ranking
      if (selectedCustomerInRanking != null) {
        String customerId = selectedCustomerInRanking!['id'];
        if (customerId == 'sem-cliente') {
          filteredOrders = filteredOrders
              .where((order) => order?.customer?.id == null)
              .toList();
        } else {
          filteredOrders = filteredOrders
              .where((order) => order?.customer?.id == customerId)
              .toList();
        }
      }

      // Calcular totais baseados nas ordens filtradas
      totalOrdersCount = filteredOrders.length;
      paidOrdersCount =
          filteredOrders.where((order) => order?.payment == 'paid').length;

      // Calcular o faturamento total (soma de todos os valores)
      totalRevenue =
          filteredOrders.fold(0.0, (sum, order) => sum + (order?.total ?? 0.0));

      // Calcular valores pagos e a receber
      totalPaidAmount = filteredOrders
          .where((order) => order?.payment == 'paid')
          .fold(0.0, (sum, order) => sum + (order?.total ?? 0.0));

      totalUnpaidAmount = filteredOrders
          .where((order) => order?.payment == 'unpaid')
          .fold(0.0, (sum, order) => sum + (order?.total ?? 0.0));

      // Atualizar paymentStatusCounts para o gráfico
      paymentStatusCounts.clear();
      paymentStatusCounts['paid'] = totalPaidAmount;
      paymentStatusCounts['unpaid'] = totalUnpaidAmount;

      // Calcular os totais por cliente usando as mesmas ordens filtradas
      customerOrderTotals.clear();
      customerUnpaidTotals.clear();

      // Inicializar totais para ordens sem cliente
      double semClienteTotal = 0.0;
      double semClienteUnpaid = 0.0;

      for (var order in filteredOrders) {
        if (order?.total != null) {
          if (order?.customer?.id != null) {
            String customerId = order!.customer!.id!;
            double currentTotal = customerOrderTotals[customerId] ?? 0.0;
            customerOrderTotals[customerId] = currentTotal + order.total!;

            if (order.payment == 'unpaid') {
              double currentUnpaid = customerUnpaidTotals[customerId] ?? 0.0;
              customerUnpaidTotals[customerId] = currentUnpaid + order.total!;
            }
          } else {
            semClienteTotal += order!.total!;
            if (order.payment == 'unpaid') {
              semClienteUnpaid += order.total!;
            }
          }
        }
      }

      // Gerar o ranking de clientes
      customerRanking.clear();

      if (semClienteTotal > 0) {
        customerRanking.add({
          'id': 'sem-cliente',
          'name': 'Sem Cliente',
          'total': semClienteTotal,
          'unpaidTotal': semClienteUnpaid,
        });
      }

      customerOrderTotals.forEach((customerId, total) {
        if (total > 0) {
          var customerName = filteredOrders
                  .firstWhere((order) => order?.customer?.id == customerId,
                      orElse: () => null)
                  ?.customer
                  ?.name ??
              'Cliente sem nome';

          customerRanking.add({
            'id': customerId,
            'name': customerName,
            'total': total,
            'unpaidTotal': customerUnpaidTotals[customerId] ?? 0.0,
          });
        }
      });

      sortCustomerRanking();

      // Aplicar filtro de pagamento nas ordens recentes
      if (paymentFilter != null) {
        filteredOrders = filteredOrders
            .where((order) => order?.payment == paymentFilter)
            .toList();
      }

      // Ordenar ordens por data de atualização
      filteredOrders.sort((a, b) {
        if (a?.updatedAt == null || b?.updatedAt == null) return 0;
        return b!.updatedAt!.compareTo(a!.updatedAt!);
      });

      recentOrders.clear();
      recentOrders.addAll(filteredOrders);
    } catch (e) {
      print('Erro ao carregar dados para dashboard: $e');
    }
  }

  @action
  void sortCustomerRanking() {
    // Sempre ordenar por valor total, independente do rankingSortType
    customerRanking
        .sort((a, b) => (b['total'] as double).compareTo(a['total'] as double));
  }

  @action
  void setRankingSortType(String sortType) {
    rankingSortType = sortType;
    sortCustomerRanking();
  }

  @action
  void selectCustomerInRanking(Map<String, dynamic>? customerData) {
    selectedCustomerInRanking = customerData;
    loadOrdersForDashboard();
  }

  @action
  void clearCustomerRankingSelection() {
    selectedCustomerInRanking = null;
    loadOrdersForDashboard();
  }

  // Métodos para scroll infinito na Home
  @action
  Future<void> loadOrdersInfinite(String? status) async {
    isLoading = true;
    _lastDocument = null;
    hasMoreOrders = true;
    orders.clear();

    await _fetchOrdersInfinite(status);

    isLoading = false;
  }

  @action
  Future<void> loadMoreOrdersInfinite(String? status) async {
    if (isLoading || !hasMoreOrders) return;

    isLoading = true;
    await _fetchOrdersInfinite(status);
    isLoading = false;
  }

  Future<void> _fetchOrdersInfinite(String? status) async {
    if (companyId == null) return;

    try {
      final snapshot = await repository.getOrdersWithPagination(
        companyId!,
        status: status,
        customerId: customerFilter?.id,
        limit: _limit,
        startAfterDocument: _lastDocument,
      );

      if (snapshot.docs.isEmpty) {
        hasMoreOrders = false;
        return;
      }

      _lastDocument = snapshot.docs.last;

      // Converter para objetos Order e adicionar à lista
      final newOrders = snapshot.docs
          .map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return Order.fromJson(data);
          })
          .toList();

      orders.addAll(newOrders);

      // Verificar se há mais resultados
      if (snapshot.docs.length < _limit) {
        hasMoreOrders = false;
      }
    } catch (e) {
      print('Erro ao buscar ordens: $e');
    }
  }
}
