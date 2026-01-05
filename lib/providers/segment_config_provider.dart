import 'package:flutter/foundation.dart';
import '../models/custom_field.dart';
import '../services/segment_config_service.dart';

/// Provider que gerencia labels dinâmicos e campos customizados
/// baseado no segmento da empresa
class SegmentConfigProvider extends ChangeNotifier {
  final _service = SegmentConfigService();

  bool _isLoading = false;
  String? _error;

  /// Indica se está carregando
  bool get isLoading => _isLoading;

  /// Indica se já foi carregado
  bool get isLoaded => _service.isLoaded;

  /// Erro ocorrido durante o carregamento
  String? get error => _error;

  /// ID do segmento atual
  String? get segmentId => _service.currentSegmentId;

  /// Idioma atual
  String get locale => _service.currentLocale;

  /// Inicializa com um segmento específico
  Future<void> initialize(String segmentId, {String locale = 'pt-BR'}) async {
    if (_service.currentSegmentId == segmentId && _service.isLoaded) {
      return; // Já carregado
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _service.setLocale(locale);
      await _service.load(segmentId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Troca o idioma e recarrega os labels
  Future<void> setLocale(String locale) async {
    if (_service.currentSegmentId == null) {
      throw Exception('Nenhum segmento carregado');
    }

    _service.setLocale(locale);
    _service.clear();
    await _service.load(_service.currentSegmentId!);
    notifyListeners();
  }

  // ════════════════════════════════════════════════════════════
  // LABELS
  // ════════════════════════════════════════════════════════════

  /// Obtém um label genérico
  String label(String key) => _service.label(key);

  /// Atalhos para entidades comuns
  String get device => _service.device;
  String get devicePlural => _service.devicePlural;
  String get customer => _service.customer;
  String get customerPlural => _service.customerPlural;
  String get serviceOrder => _service.serviceOrder;
  String get serviceOrderPlural => _service.serviceOrderPlural;

  /// Obtém label de status customizado
  ///
  /// Mapeia chaves técnicas para labels customizados:
  /// - 'quote' → 'Orçamento'
  /// - 'approved' → 'Aprovado'
  /// - 'progress' → 'Em Andamento' / 'Em Conserto' / 'Em Manutenção'
  /// - 'done' → 'Concluído' / 'Pronto para Retirada'
  /// - 'canceled' → 'Cancelado'
  String getStatus(String? statusKey) => _service.getStatus(statusKey);

  // ════════════════════════════════════════════════════════════
  // CUSTOM FIELDS
  // ════════════════════════════════════════════════════════════

  /// Obtém campos customizados para um namespace (ex: "device")
  List<CustomField> fieldsFor(String namespace) =>
      _service.fieldsFor(namespace);

  /// Obtém campos customizados agrupados por section
  Map<String, List<CustomField>> fieldsGroupedBySection(String namespace) =>
      _service.fieldsGroupedBySection(namespace);

  // ════════════════════════════════════════════════════════════
  // UTILS
  // ════════════════════════════════════════════════════════════

  /// Limpa todo o estado
  void clear() {
    _service.clear();
    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _service.clear();
    super.dispose();
  }
}
