import 'dart:io';
import 'dart:math';

import 'package:intl/intl.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/order_photo.dart';
import 'package:praticos/repositories/order_repository.dart';
import 'package:praticos/repositories/repository.dart';
import 'package:praticos/services/photo_service.dart';
import 'package:mobx/mobx.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;

import 'package:praticos/global.dart';
import 'package:shared_preferences/shared_preferences.dart';
part 'order_store.g.dart';

class OrderStore = _OrderStore with _$OrderStore;

abstract class _OrderStore with Store {
  final OrderRepository repository = OrderRepository();
  final PhotoService photoService = PhotoService();

  Order? order;

  @observable
  ObservableStream<List<Order?>>? orderList;

  @observable
  ObservableStream<Order?>? orderStream;

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
      if (this.orderStream == null ||
          this.orderStream!.data == null ||
          this.order == null) return;

      // Atualiza o número da OS a partir do stream
      this.order!.number = this.orderStream!.data.number;
    });
  }

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
    repository.getSingle(id).then((value) {
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
    this.createdAt = order.createdAt;

    // Se não tiver data de criação, define uma
    if (this.order!.createdAt == null) {
      this.order!.createdAt = DateTime.now();
      this.createdAt = this.order!.createdAt;
    }

    // Configura o stream se tiver ID
    if (orderId != null) {
      this.order!.id = orderId;
      this.orderStream = repository.streamSingle(orderId).asObservable();
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
    this.dueDate = dateToString(date);
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
    services = this.order!.services!.asObservable();
    products = this.order!.products!.asObservable();
    updatePayment();
    updateTotal();
    createItem();
  }

  @action
  Future<void> deleteOrder() {
    return repository.removeItem(order!.id);
  }

  void updatePayment() {
    if (this.order == null) return;

    if (['quote', 'canceled'].contains(this.order!.status)) {
      this.order!.payment = null;
      this.payment = '';
      return;
    }

    if (this.order!.payment == null) {
      this.order!.payment = 'unpaid';
    }

    if (this.order!.payment == 'paid') {
      this.payment = 'Pago';
    } else if (this.order!.payment == 'unpaid') {
      this.payment = 'A receber';
    }
  }

  @action
  loadOrders(String? status) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? companyId = prefs.getString('companyId');
    if (companyId == null) companyId = '';

    List<QueryArgs> filterList = [QueryArgs('company.id', companyId)];
    List<OrderBy>? orderBy;

    if (status != null) {
      if (['paid', 'unpaid'].contains(status)) {
        filterList.add(QueryArgs('payment', status));
      } else if (status == 'due_date') {
        filterList.add(
            QueryArgs('status', ['approved', 'progress'], oper: 'whereIn'));
        orderBy = orderBy = [OrderBy('dueDate')];
      } else {
        filterList.add(QueryArgs('status', status));
      }
    }

    if (customerFilter != null) {
      filterList.add(QueryArgs('customer.id', this.customerFilter!.id));
    }

    if (orderBy == null) orderBy = [OrderBy('createdAt', descending: true)];

    orderList = repository
        .streamQueryList(orderBy: orderBy, args: filterList)
        .asObservable();

    if (orderList!.hasError) {
      print(orderList!.error);
    }

    print(orderList);
  }

  @action
  addService(OrderService orderService) {
    if (orderService.id == null) {
      orderService.id = "${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(10000)}";
    }
    order!.services!.add(orderService);
    services!.add(orderService);
    updateTotal();
    createItem();
  }

  @action
  addProduct(OrderProduct orderProduct) {
    if (orderProduct.id == null) {
      orderProduct.id = "${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(10000)}";
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
  Future<bool> addPhotoFromGallery({String? itemId}) async {
    final File? file = await photoService.pickImageFromGallery();
    if (file != null) {
      return await _uploadPhoto(file, itemId: itemId);
    }
    return false;
  }

  /// Adiciona uma foto da câmera
  @action
  Future<bool> addPhotoFromCamera({String? itemId}) async {
    final File? file = await photoService.takePhoto();
    if (file != null) {
      return await _uploadPhoto(file, itemId: itemId);
    }
    return false;
  }

  /// Faz o upload de uma foto
  Future<bool> _uploadPhoto(File file, {String? itemId}) async {
    if (order == null) return false;

    // Garante que a OS seja salva antes do upload
    if (order!.id == null) {
      await repository.createItem(order);
    }

    if (order!.id == null || order!.company?.id == null) return false;

    isUploadingPhoto = true;

    try {
      final OrderPhoto? photo = await photoService.uploadPhoto(
        file: file,
        companyId: order!.company!.id!,
        orderId: order!.id!,
      );

      isUploadingPhoto = false;

      if (photo != null) {
        if (itemId != null) {
          photo.itemId = itemId;
        }

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
    this.discount = value;
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
    this.discount = order?.discount;
    temp -= order!.discount!;

    order?.total = temp;
    total = temp;
  }

  createItem() {
    if (order == null) return;

    if (order!.id == null) {
      // Para nova OS, verifica duplicação pelo número
      if (order!.number != null) {
        // Verifica se existe OS com o mesmo número
        repository.getOrderByNumber(order!.number!).then((existingOrder) {
          if (existingOrder != null) {
            // Se encontrou, usa o ID da existente
            order!.id = existingOrder.id;
            repository.updateItem(order);
            this.orderStream =
                repository.streamSingle(order!.id).asObservable();
          } else {
            // Cria nova se não encontrou
            repository.createItem(order).then((_) {
              if (order!.id != null) {
                this.orderStream =
                    repository.streamSingle(order!.id).asObservable();
              }
            });
          }
        });
      } else {
        // Cria nova OS sem número
        repository.createItem(order).then((_) {
          if (order!.id != null) {
            this.orderStream =
                repository.streamSingle(order!.id).asObservable();
          }
        });
      }
    } else {
      // Atualiza OS existente
      repository.updateItem(order).then((_) {
        if (this.orderStream == null ||
            this.orderStream!.value?.id != order!.id) {
          this.orderStream = repository.streamSingle(order!.id).asObservable();
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
    try {
      final orders = await repository.getOrdersByDateRange(start, end);

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
    try {
      final orders = await repository.getOrdersByCustomPeriod(
          selectedDashboardPeriod, periodOffset);

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
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? companyId = prefs.getString('companyId');
    if (companyId == null) companyId = '';

    try {
      firestore.Query query =
          firestore.FirebaseFirestore.instance.collection('orders');

      // Aplicar filtros
      query = query.where('company.id', isEqualTo: companyId);

      if (status != null) {
        if (['paid', 'unpaid'].contains(status)) {
          query = query.where('payment', isEqualTo: status);
        } else if (status == 'due_date') {
          query = query.where('status', whereIn: ['approved', 'progress']);
          query = query.orderBy('dueDate');
        } else if (status != 'Todos') {
          query = query.where('status', isEqualTo: status);
        }
      }

      if (customerFilter != null) {
        query = query.where('customer.id', isEqualTo: customerFilter!.id);
      }

      // Aplicar ordenação padrão se não for por data de entrega
      if (status != 'due_date') {
        query = query.orderBy('createdAt', descending: true);
      }

      // Aplicar paginação
      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      query = query.limit(_limit);

      // Buscar documentos
      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        hasMoreOrders = false;
        return;
      }

      _lastDocument = snapshot.docs.last;

      // Converter para objetos Order e adicionar à lista
      final newOrders = snapshot.docs
          .map((doc) => Order.fromJson(doc.data() as Map<String, dynamic>))
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
